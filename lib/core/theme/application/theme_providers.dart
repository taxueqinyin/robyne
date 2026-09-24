import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/settings/domain/user_settings.dart';
import '../../../features/settings/application/settings_providers.dart';
import '../domain/theme_layout.dart';
import '../domain/theme_package.dart';
import '../domain/theme_tokens.dart';
import '../infrastructure/theme_importer.dart';
import '../infrastructure/theme_font_loader.dart';
import '../infrastructure/theme_path_guard.dart';
import '../infrastructure/token_patcher.dart';
import '../infrastructure/token_resolver.dart';
import 'theme_controller.dart';
import 'theme_mode_providers.dart';

/// The id of the skin the user picked, persisted through [UserSettings].
final activeThemeIdProvider = Provider<String>((ref) {
  final settings = ref.watch(settingsControllerProvider).value;
  return settings?.activeThemeId ?? 'official.light';
});

/// The [ThemePackage] currently in effect.
final activeThemePackageProvider = Provider<ThemePackage>((ref) {
  return ref.watch(themeControllerProvider).value?.package ?? _placeholder;
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

/// The skin's declared brightness preference, needed so the resolver can
/// adapt neutrals when the user forces the opposite mode.
final activeThemeModePreferenceProvider = Provider<ThemeModePreference>((ref) {
  return ref.watch(activeThemePackageProvider).mode;
});

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
  return const TokenResolver().resolve(tokens, Brightness.light, mode);
});

/// Resolved Material dark theme for the active skin.
final darkThemeDataProvider = Provider<ThemeData>((ref) {
  final tokens = _withResolvedFont(
    ref.watch(activeThemeTokensProvider),
    ref.watch(resolvedThemeTypographyProvider),
  );
  final mode = ref.watch(activeThemeModePreferenceProvider);
  return const TokenResolver().resolve(tokens, Brightness.dark, mode);
});

/// Brightness chosen by combining the user override, the skin preference and
/// the platform setting. See [ThemeModePreference].
final themeModeProvider = Provider<ThemeMode>((ref) {
  final override = ref.watch(themeModeOverrideProvider);
  if (override != ThemeMode.system) {
    return override;
  }
  final preference = ref.watch(activeThemePackageProvider).mode;
  return switch (preference) {
    ThemeModePreference.light => ThemeMode.light,
    ThemeModePreference.dark => ThemeMode.dark,
    ThemeModePreference.auto => ThemeMode.system,
  };
});

/// Used before the very first settings load completes.
final ThemePackage _placeholder = ThemePackage(
  id: 'official.light',
  name: 'Robyne',
  author: 'Robyne',
  authorUrl: null,
  version: '1.0.0',
  description: '',
  preview: null,
  tags: const <String>[],
  mode: ThemeModePreference.light,
  schemaVersion: 1,
  tokens: const ThemeTokens.baseline(),
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
}
