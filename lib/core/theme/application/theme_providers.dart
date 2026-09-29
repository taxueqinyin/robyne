import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/settings/domain/user_settings.dart';
import '../../../features/settings/application/settings_providers.dart';
import '../domain/theme_layout.dart';
import '../domain/theme_components.dart';
import '../domain/theme_icons.dart';
import '../domain/theme_package.dart';
import '../domain/theme_navigation.dart';
import '../domain/theme_strings.dart';
import '../domain/theme_tokens.dart';
import '../infrastructure/theme_importer.dart';
import '../infrastructure/theme_exporter.dart';
import '../infrastructure/theme_font_loader.dart';
import '../infrastructure/theme_path_guard.dart';
import '../infrastructure/token_patcher.dart';
import '../infrastructure/token_resolver.dart';
import 'theme_controller.dart';
import 'theme_mode_providers.dart';

/// The id of the skin the user picked, persisted through [UserSettings].
final activeThemeIdProvider = Provider<String>((ref) {
  final settings = ref.watch(settingsControllerProvider).value;
  return settings?.activeThemeId ?? 'xuan';
});

/// The skin as authored, before any user L2 layout override.
///
/// Tests override this provider directly; [activeThemePackageProvider] only
/// adds the persisted override on top, so both `overrideWithValue` and the
/// production path compose correctly.
final baseThemePackageProvider = Provider<ThemePackage>((ref) {
  return ref.watch(themeControllerProvider).value?.package ?? _placeholder;
});

/// The [ThemePackage] currently in effect, including the user's L2 layout.
final activeThemePackageProvider = Provider<ThemePackage>((ref) {
  final package = ref.watch(baseThemePackageProvider);
  final settings = ref.watch(settingsControllerProvider);
  final override = settings.maybeWhen(
    data: (value) => value.themeLayoutOverrides[package.id],
    orElse: () => null,
  );
  return override == null ? package : override.apply(package);
});

/// The [RobyneRegion.content] presentation for one destination.
///
/// The design's §2.5 table is per surface — 本地库 uses `list`, 发现页 uses
/// `grid`, a recommendation strip uses `banner` — so reading one global value
/// forced a skin to pick a single look for every page it does not own.
///
/// It is a *style of the content region*, not a region of its own, which is
/// why a skin cannot invent a "recommendation region" — it can only restyle
/// `content`, and it can do so per destination.
final contentStyleForProvider =
    Provider.family<ThemeListStyle, ThemeContentSurface>((ref, surface) {
      return ref
          .watch(activeThemePackageProvider)
          .layout
          .content
          .styleFor(surface);
    });

/// The content region's geometry in effect for the active skin.
///
/// Gutters, row heights and card sizing used to be literals inside feature
/// pages, so "make the rows a bit shorter" was a code change rather than a
/// manifest edit.
final activeThemeContentMetricsProvider = Provider<ThemeContentMetrics>((ref) {
  return ref.watch(activeThemeTokensProvider).components.content;
});

/// Knob values in effect for the active skin, keyed by [ThemeSetting.key].
///
/// This is what the settings UI renders and what it writes back: `key` is a
/// knob's storage identity and is stable even when its target changes.
final activeThemeSettingValuesProvider = Provider<Map<String, Object>>((ref) {
  final package = ref.watch(activeThemePackageProvider);
  if (package.settings.isEmpty) {
    return const <String, Object>{};
  }
  final stored = ref
      .watch(settingsControllerProvider)
      .value
      ?.themeSettingValues;
  return themeSettingValuesFor(package, stored);
});

/// The overrides the active skin's knobs apply to the token tree.
///
/// Keyed by [ThemeSetting.target] rather than `key`, because that is the
/// address [TokenPatcher] understands. Keeping this separate from the UI map
/// is what lets a knob's name and its token path differ — which every
/// bundled skin does (`brandColor` -> `color.brand.base`).
final activeThemeTokenPatchProvider = Provider<Map<String, Object>>((ref) {
  final package = ref.watch(activeThemePackageProvider);
  if (package.settings.isEmpty) {
    return const <String, Object>{};
  }
  final stored = ref
      .watch(settingsControllerProvider)
      .value
      ?.themeSettingValues;
  return themeSettingPatchValues(package, stored);
});

/// Registers the active skin's bundled font and returns its family name.
///
/// `null` until the load settles or when the skin ships no font. Font loading
/// is inherently async, so this is the one part of the theme pipeline that
/// cannot be derived synchronously; consumers watch it and rebuild when it
/// resolves. See `THEME_ROADMAP.md` defect A: before this existed, `assets.font`
/// was parsed and budgeted but never registered, so skins could only name
/// platform-installed fonts.
final activeSkinFontFamilyProvider = FutureProvider<String?>((ref) async {
  final package = ref.watch(activeThemePackageProvider);
  return const ThemeFontLoader().loadFamilyFor(package);
});

/// The skin's own typography preference, overridden by a bundled font when
/// the skin ships one that loads successfully.
///
/// Falls back to the skin's declared `typography.family` (a platform font) so
/// a corrupt or oversized font degrades quietly instead of breaking the skin.
final resolvedThemeTypographyProvider = Provider<ThemeTypography>((ref) {
  final tokens = ref.watch(activeThemeTokensProvider);
  final fontValue = ref.watch(activeSkinFontFamilyProvider);
  final skinFamily = fontValue.maybeWhen(
    data: (family) => family,
    orElse: () => null,
  );
  if (skinFamily == null || skinFamily.isEmpty) {
    return tokens.typography;
  }
  return tokens.typography.copyWith(fontFamily: skinFamily);
});

/// The semantic tokens in effect: the skin's tokens with the user's knob
/// tweaks applied on top.
final activeThemeTokensProvider = Provider<ThemeTokens>((ref) {
  final package = ref.watch(activeThemePackageProvider);
  final values = ref.watch(activeThemeTokenPatchProvider);
  if (values.isEmpty) {
    return package.tokens;
  }
  return const TokenPatcher().apply(package.tokens, values);
});

/// The chrome strings in effect for the active skin.
///
/// Call sites read a slot through this rather than holding a literal, so a
/// skin that renames `nav.library` renames it everywhere the label appears.
final activeThemeStringsProvider = Provider<ThemeStrings>((ref) {
  return ref.watch(activeThemePackageProvider).strings;
});

/// The navigation entries the active skin hides, per form factor.
final activeThemeNavigationProvider = Provider<ThemeNavigation>((ref) {
  return ref.watch(activeThemePackageProvider).navigation;
});

/// The active skin's motion rhythm: how long transitions take and how they
/// ease.
///
/// Exposed as a provider so animated surfaces read one shared answer instead
/// of each inventing a duration. Before this, `components.motion` was parsed,
/// exported and round-tripped by tests while no widget read it, so a skin
/// could declare a rhythm that changed nothing on screen.
final activeThemeMotionProvider = Provider<ThemeMotionComponents>((ref) {
  return ref.watch(activeThemeTokensProvider).components.motion;
});

/// The chrome glyphs the active skin redraws.
///
/// Call sites render through `ThemeIconView` rather than an `Icon` literal, so
/// a skin that redraws `play` changes it everywhere it appears.
final activeThemeIconsProvider = Provider<ThemeIcons>((ref) {
  return ref.watch(activeThemePackageProvider).icons;
});

/// Registers the active skin's icon font and returns its family name.
///
/// `null` until the load settles or when the skin ships no icon font. Icon
/// declarations fall back to Material `codePoint`s and then to the built-in
/// glyph, so a font that fails to load costs a skin its custom shapes but
/// never a control.
final activeSkinIconFontFamilyProvider = FutureProvider<String?>((ref) async {
  final package = ref.watch(activeThemePackageProvider);
  return const ThemeFontLoader().loadIconFamilyFor(package);
});

/// The skin's declared brightness preference, needed so the resolver can
/// adapt neutrals when the user forces the opposite mode.
final activeThemeModePreferenceProvider = Provider<ThemeModePreference>((ref) {
  return ref.watch(activeThemePackageProvider).mode;
});

/// Whether a skin authored for [preference] can render [mode].
///
/// A single-brightness skin may still let the user choose "follow skin"; it
/// just cannot be forced into the opposite brightness without looking like a
/// different, broken skin. Keeping this rule next to the resolver means the
/// settings control and the actual theme resolution cannot drift apart.
extension ThemeModePreferenceSupport on ThemeModePreference {
  bool supports(ThemeMode mode) {
    if (mode == ThemeMode.system) {
      return true;
    }
    return switch (this) {
      ThemeModePreference.auto => true,
      ThemeModePreference.light => mode != ThemeMode.dark,
      ThemeModePreference.dark => mode != ThemeMode.light,
    };
  }
}

/// Applies the resolved typography (skin font, when loaded) onto [tokens].
ThemeTokens _withResolvedFont(ThemeTokens tokens, ThemeTypography typography) {
  return tokens.copyWith(typography: typography);
}

/// Resolved Material light theme for the active skin.
final lightThemeDataProvider = Provider<ThemeData>((ref) {
  final tokens = _withResolvedFont(
    ref.watch(activeThemeTokensProvider),
    ref.watch(resolvedThemeTypographyProvider),
  );
  final mode = ref.watch(activeThemeModePreferenceProvider);
  return const TokenResolver().resolve(
    tokens,
    Brightness.light,
    mode,
    ref.watch(activeThemeStringsProvider),
  );
});

/// Resolved Material dark theme for the active skin.
final darkThemeDataProvider = Provider<ThemeData>((ref) {
  final tokens = _withResolvedFont(
    ref.watch(activeThemeTokensProvider),
    ref.watch(resolvedThemeTypographyProvider),
  );
  final mode = ref.watch(activeThemeModePreferenceProvider);
  return const TokenResolver().resolve(
    tokens,
    Brightness.dark,
    mode,
    ref.watch(activeThemeStringsProvider),
  );
});

/// Brightness chosen by combining the user override, the skin preference and
/// the platform setting. See [ThemeModePreference].
///
/// "跟随皮肤" (`ThemeMode.system`) is not the same as "跟随系统": it defers to
/// the skin first, and only an `auto` skin passes the decision on to the
/// platform. A dark-only skin therefore stays dark even when the OS is in
/// light mode, which is what makes the label honest.
final themeModeProvider = Provider<ThemeMode>((ref) {
  final override = ref.watch(themeModeOverrideProvider);
  final preference = ref.watch(activeThemeModePreferenceProvider);
  if (override == ThemeMode.system) {
    return switch (preference) {
      ThemeModePreference.light => ThemeMode.light,
      ThemeModePreference.dark => ThemeMode.dark,
      ThemeModePreference.auto => ThemeMode.system,
    };
  }
  if (preference.supports(override)) {
    return override;
  }
  return switch (preference) {
    ThemeModePreference.light => ThemeMode.light,
    ThemeModePreference.dark => ThemeMode.dark,
    ThemeModePreference.auto => ThemeMode.system,
  };
});

/// Used before the very first settings load completes.
///
/// The shell paints on the first frame, a few milliseconds before the skin
/// arrives, so this stand-in has to look like where the app is going rather
/// than like a generic default. `ThemeTokens.baseline()` is the *light*
/// palette; pairing it with a dark mode preference is what made every cold
/// start flash white before settling into《玄》.
final ThemePackage _placeholder = ThemePackage(
  id: 'xuan',
  name: '玄',
  author: 'Robyne',
  authorUrl: null,
  version: '1.0.0',
  description: '',
  preview: null,
  tags: const <String>[],
  mode: ThemeModePreference.dark,
  schemaVersion: 1,
  tokens: const ThemeTokens.darkBaseline(),
  layout: const ThemeLayout.baseline(),
  settings: const <ThemeSetting>[],
  assets: const ThemeAssets.empty(),
  source: ThemeSource.builtIn,
);

/// Resolves knob values for [package], keyed by [ThemeSetting.key].
///
/// What the user actually sees and edits. `key` is the knob's stable storage
/// identity, so a stored override is found even if the skin later retargets
/// the knob. Falls back to the skin's own default.
Map<String, Object> themeSettingValuesFor(
  ThemePackage package,
  Map<String, Object>? stored,
) {
  return <String, Object>{
    for (final setting in package.settings)
      setting.key:
          stored?['${package.id}/${setting.key}'] ?? setting.defaultValue,
  };
}

/// Resolves the overrides [package]'s knobs write into the token tree.
///
/// Keyed by [ThemeSetting.target], since that is the address [TokenPatcher]
/// understands. Keying this by `key` would silently no-op every knob whose
/// key differs from its target, which is exactly what the bundled skins
/// declare. Knobs without a target are skipped: there is nowhere to write
/// them.
Map<String, Object> themeSettingPatchValues(
  ThemePackage package,
  Map<String, Object>? stored,
) {
  return <String, Object>{
    for (final setting in package.settings)
      if (setting.target != null && setting.target!.isNotEmpty)
        if (_safeKnobValue(
              setting.target!,
              stored?['${package.id}/${setting.key}'] ?? setting.defaultValue,
            )
            case final Object safe)
          setting.target!: safe,
  };
}

/// Rejects a knob value that would smuggle a path through the patcher.
///
/// Static manifests are screened at parse time, but a knob's default travels
/// a different route into [TokenPatcher]. Only `background.image` can reach
/// the file system, and only relative in-package references are allowed.
Object? _safeKnobValue(String target, Object value) {
  if (target != 'background.image') {
    return value;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : ThemePathGuard.sanitizeAsset(text);
}

/// Import/delete operations on user-installed skins.
final themeImporterProvider = Provider<ThemeImporter>((ref) {
  return ThemeImporter(
    themesDirectory: () =>
        ref.read(themeRepositoryProvider).userThemesDirectory(),
  );
});

/// Copies a loaded skin into the user themes directory.
///
/// Backs the D5 promise that an official skin has no privileges: whatever a
/// built-in skin can do, a copy living in the user directory can do too.
final themeExporterProvider = Provider<ThemeExporter>((ref) {
  return ThemeExporter(
    themesDirectory: () =>
        ref.read(themeRepositoryProvider).userThemesDirectory(),
  );
});

/// The directory a skin author edits to hot-reload the active skin.
///
/// Skin authoring happens in files, not in the client, so the appearance panel
/// has to be able to say *which* file. A built-in skin has no editable path:
/// its manifest is compiled into the bundle, and the answer for it is
/// "duplicate it first".
final userThemesDirectoryPathProvider = FutureProvider<String?>((ref) async {
  try {
    final directory = await ref
        .watch(themeRepositoryProvider)
        .userThemesDirectory();
    return directory.path;
  } on Object {
    return null;
  }
});

/// Imports a skin from a folder or a `.rtheme` archive.
///
/// Returns the error message on failure, or `null` on success.
final themeImportControllerProvider = Provider<ThemeImportController>((ref) {
  return ThemeImportController(ref);
});

class ThemeImportController {
  const ThemeImportController(this._ref);

  final Ref _ref;

  Future<String?> importFrom(String path) async {
    final result = await _ref.read(themeImporterProvider).importFrom(path);
    if (!result.isSuccess) {
      return result.error?.message ?? '导入失败';
    }
    await _ref.read(themeControllerProvider.notifier).refresh();
    return null;
  }

  Future<void> delete(String id) async {
    await _ref.read(themeRepositoryProvider).deleteTheme(id);
    await _ref.read(themeControllerProvider.notifier).refresh();
  }

  /// Copies [theme] into the user directory and switches to the copy.
  ///
  /// Adopting the copy is what proves the promise: from here on the app
  /// renders a skin loaded through exactly the path a community skin uses.
  Future<String?> duplicate(ThemePackage theme) async {
    final result = await _ref.read(themeExporterProvider).export(theme);
    if (!result.isSuccess) {
      return result.error?.message ?? '复制失败';
    }
    await _ref.read(themeControllerProvider.notifier).refresh();
    await _ref.read(themeControllerProvider.notifier).selectTheme(theme.id);
    return null;
  }
}
