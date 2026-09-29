import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/theme/application/theme_controller.dart';
import 'package:robyne/core/theme/application/theme_providers.dart';
import 'package:robyne/core/theme/domain/theme_layout_override.dart';
import 'package:robyne/core/theme/domain/theme_package.dart';
import 'package:robyne/core/theme/infrastructure/theme_repository.dart';
import 'package:robyne/features/downloads/domain/download_audio_format.dart';
import 'package:robyne/features/settings/application/settings_providers.dart';
import 'package:robyne/features/settings/domain/user_settings.dart';
import 'package:robyne/features/settings/domain/lyric_settings.dart';
import 'package:robyne/features/settings/domain/shortcut_settings.dart';

/// A skin id that is no longer shipped must not be resurrected.
///
/// Removing `official-*` from the bundle left persisted settings pointing at
/// them. If the built-in repository synthesises a stand-in for *any* id, that
/// stand-in wins, so the app never falls through to 《玄》 and the user keeps
/// the retired light skin with none of 《玄》's tokens or strings.
void main() {
  final repository = BuiltInThemeRepository();

  test('a retired id does not resolve to a synthetic skin', () async {
    final loaded = await repository.loadTheme('official.light');

    expect(loaded, isNull, reason: 'unknown ids must fall through to 《玄》');
  });

  test('the flagship id still resolves', () async {
    // The asset bundle needs binding initialisation before it can be read.
    WidgetsFlutterBinding.ensureInitialized();
    final loaded = await repository.loadTheme('xuan');

    expect(loaded, isNotNull);
    expect(loaded!.id, 'xuan');
    expect(loaded.name, '玄');
    expect(loaded.strings.isEmpty, isFalse);
  });

  test('the catalog contains only the flagship', () async {
    final themes = await repository.listThemes();

    expect(themes.map((theme) => theme.id), <String>['xuan']);
  });

  test('a retired id self-heals and shows the fallback notice once', () async {
    WidgetsFlutterBinding.ensureInitialized();
    final container = ProviderContainer(
      overrides: <Object>[
        themeRepositoryProvider.overrideWithValue(_FlagshipOnlyRepository()),
        settingsControllerProvider.overrideWith(_StaticSettingsController.new),
      ].cast(),
    );
    addTearDown(container.dispose);

    await container.read(settingsControllerProvider.future);

    final state = await container.read(themeControllerProvider.future);
    expect(state.package.id, 'xuan');
    expect(container.read(activeThemeIdProvider), 'official.light');
    expect(state.lastError, isNotNull);
    expect(state.showFallbackNotice, isTrue);
    expect(
      container.read(themeFallbackNoticeProvider),
      state.lastError,
      reason: 'the notice must outlive the self-heal rebuild',
    );
    expect(_StaticSettingsController.savedActiveThemeIds.single, 'xuan');
  });
}

class _FlagshipOnlyRepository implements ThemeRepository {
  @override
  Future<List<ThemePackage>> listThemes() async {
    WidgetsFlutterBinding.ensureInitialized();
    final flagship = await BuiltInThemeRepository().loadTheme('xuan');
    return flagship == null ? <ThemePackage>[] : <ThemePackage>[flagship];
  }

  @override
  Future<ThemePackage?> loadTheme(String id) async {
    WidgetsFlutterBinding.ensureInitialized();
    if (id == 'xuan') {
      return BuiltInThemeRepository().loadTheme('xuan');
    }
    return null;
  }

  @override
  Future<Directory> userThemesDirectory() async =>
      Directory.systemTemp.createTemp('robyne_theme_self_heal_');

  @override
  Future<bool> deleteTheme(String id) async => false;
}

class _StaticSettingsController extends SettingsController {
  static final savedActiveThemeIds = <String>[];

  @override
  Future<UserSettings> build() async {
    return UserSettings(
      cacheSizeBytes: 1024,
      cacheDirectoryPath: 'cache',
      downloadsDirectoryPath: 'downloads',
      downloadAudioFormat: DownloadAudioFormat.original,
      shortcuts: ShortcutSettings.defaults(),
      lyricSettings: LyricSettings.defaults(),
      activeThemeId: 'official.light',
      themeModeOverrideName: UserSettings.defaultThemeModeOverrideName,
      themeSettingValues: <String, Object>{},
      themeLayoutOverrides: <String, ThemeLayoutOverride>{},
    );
  }

  @override
  Future<void> setActiveThemeId(String id) async {
    savedActiveThemeIds.add(id);
  }
}
