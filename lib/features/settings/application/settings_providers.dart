import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/domain/theme_layout_override.dart';
import '../../downloads/domain/download_audio_format.dart';
import '../domain/lyric_settings.dart';
import '../domain/shortcut_action.dart';
import '../domain/shortcut_binding.dart';
import '../../plugin/application/plugin_providers.dart';
import '../domain/user_settings.dart';
import '../infrastructure/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(
    database: ref.watch(appDatabaseProvider),
    fileStore: ref.watch(localFileStoreProvider),
    legacyMigration: ref.watch(legacyStorageMigrationProvider),
  );
});

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, UserSettings>(
      SettingsController.new,
    );

class SettingsController extends AsyncNotifier<UserSettings> {
  @override
  Future<UserSettings> build() async {
    return ref.watch(settingsRepositoryProvider).load();
  }

  Future<void> setCacheSizeBytes(int bytes) async {
    state = AsyncData(
      await ref.read(settingsRepositoryProvider).setCacheSizeBytes(bytes),
    );
  }

  /// Pins how opening an online collection treats the queue.
  Future<void> setPlaylistOpenAction(PlaylistOpenAction action) async {
    state = AsyncData(
      await ref.read(settingsRepositoryProvider).setPlaylistOpenAction(action),
    );
  }

  /// Remembers whether the queue panel is docked between launches.
  Future<void> setQueuePanelVisible(bool visible) async {
    state = AsyncData(
      await ref.read(settingsRepositoryProvider).setQueuePanelVisible(visible),
    );
  }

  /// Remembers what the desktop close button should do after the first ask.
  Future<void> setTrayCloseAction(TrayCloseAction action) async {
    state = AsyncData(
      await ref.read(settingsRepositoryProvider).setTrayCloseAction(action),
    );
  }

  /// Persists an explicit rail width, or resets to the active skin's ratio.
  Future<void> setSidebarWidth(double? width) async {
    state = AsyncData(
      await ref.read(settingsRepositoryProvider).setSidebarWidth(width),
    );
  }

  Future<void> setCacheDirectory(String path) async {
    state = AsyncData(
      await ref.read(settingsRepositoryProvider).setCacheDirectory(path),
    );
  }

  Future<void> setDownloadsDirectory(String path) async {
    state = AsyncData(
      await ref.read(settingsRepositoryProvider).setDownloadsDirectory(path),
    );
  }

  Future<void> setDownloadAudioFormat(DownloadAudioFormat format) async {
    state = AsyncData(
      await ref.read(settingsRepositoryProvider).setDownloadAudioFormat(format),
    );
  }

  Future<void> setActiveThemeId(String id) async {
    state = AsyncData(
      await ref.read(settingsRepositoryProvider).setActiveThemeId(id),
    );
  }

  Future<void> setThemeModeOverride(String name) async {
    state = AsyncData(
      await ref.read(settingsRepositoryProvider).setThemeModeOverride(name),
    );
  }

  Future<void> setThemeSettingValue(
    String themeId,
    String key,
    Object? value,
  ) async {
    state = AsyncData(
      await ref
          .read(settingsRepositoryProvider)
          .setThemeSettingValue(themeId, key, value),
    );
  }

  Future<void> setThemeLayoutOverride(
    String themeId,
    ThemeLayoutOverride? override,
  ) async {
    state = AsyncData(
      await ref
          .read(settingsRepositoryProvider)
          .setThemeLayoutOverride(themeId, override),
    );
  }

  Future<void> setShortcutBinding(
    ShortcutAction action,
    ShortcutBinding? binding,
  ) async {
    state = AsyncData(
      await ref
          .read(settingsRepositoryProvider)
          .setShortcutBinding(action, binding),
    );
  }

  Future<void> setDesktopLyricsEnabled(bool enabled) async {
    await _setLyricSettings(
      (await _currentSettings()).lyricSettings.copyWith(
        desktopLyricsEnabled: enabled,
      ),
    );
  }

  Future<void> toggleDesktopLyricsEnabled() async {
    final settings = await _currentSettings();
    await _setLyricSettings(
      settings.lyricSettings.copyWith(
        desktopLyricsEnabled: !settings.lyricSettings.desktopLyricsEnabled,
      ),
    );
  }

  Future<void> setDesktopLyricsAlwaysOnTop(bool alwaysOnTop) async {
    await _setLyricSettings(
      (await _currentSettings()).lyricSettings.copyWith(
        desktopLyricsAlwaysOnTop: alwaysOnTop,
      ),
    );
  }

  Future<void> toggleDesktopLyricsAlwaysOnTop() async {
    final settings = await _currentSettings();
    await _setLyricSettings(
      settings.lyricSettings.copyWith(
        desktopLyricsAlwaysOnTop:
            !settings.lyricSettings.desktopLyricsAlwaysOnTop,
      ),
    );
  }

  Future<void> setDesktopLyricsLocked(bool locked) async {
    await _setLyricSettings(
      (await _currentSettings()).lyricSettings.copyWith(
        desktopLyricsLocked: locked,
      ),
    );
  }

  Future<void> toggleDesktopLyricsLocked() async {
    final settings = await _currentSettings();
    await _setLyricSettings(
      settings.lyricSettings.copyWith(
        desktopLyricsLocked: !settings.lyricSettings.desktopLyricsLocked,
      ),
    );
  }

  Future<void> setDesktopLyricsDoubleLine(bool enabled) async {
    await _setLyricSettings(
      (await _currentSettings()).lyricSettings.copyWith(
        desktopLyricsDoubleLine: enabled,
      ),
    );
  }

  Future<void> setDesktopLyricFontFamily(String? fontFamily) async {
    await _setLyricSettings(
      (await _currentSettings()).lyricSettings.copyWith(
        desktopLyricFontFamily: fontFamily,
        clearDesktopLyricFontFamily:
            fontFamily == null || fontFamily.trim().isEmpty,
      ),
    );
  }

  Future<void> setDesktopLyricFontSize(int size) async {
    await _setLyricSettings(
      (await _currentSettings()).lyricSettings.copyWith(
        desktopLyricFontSize: size,
      ),
    );
  }

  Future<void> adjustDesktopLyricFontSize(int delta) async {
    final settings = await _currentSettings();
    await _setLyricSettings(
      settings.lyricSettings.copyWith(
        desktopLyricFontSize:
            settings.lyricSettings.desktopLyricFontSize + delta,
      ),
    );
  }

  Future<void> setDesktopLyricTextColorValue(int colorValue) async {
    await _setLyricSettings(
      (await _currentSettings()).lyricSettings.copyWith(
        desktopLyricTextColorValue: colorValue,
      ),
    );
  }

  Future<void> setDesktopLyricStrokeColorValue(int colorValue) async {
    await _setLyricSettings(
      (await _currentSettings()).lyricSettings.copyWith(
        desktopLyricStrokeColorValue: colorValue,
      ),
    );
  }

  Future<void> setDesktopLyricWindowPosition({
    required double left,
    required double top,
  }) async {
    final settings = await _currentSettings();
    final lyricSettings = settings.lyricSettings;
    if (lyricSettings.desktopLyricWindowLeft == left &&
        lyricSettings.desktopLyricWindowTop == top) {
      return;
    }
    await _setLyricSettings(
      lyricSettings.copyWith(
        desktopLyricWindowLeft: left,
        desktopLyricWindowTop: top,
      ),
    );
  }

  Future<UserSettings> _currentSettings() async {
    return state.value ?? await ref.read(settingsRepositoryProvider).load();
  }

  Future<void> _setLyricSettings(LyricSettings lyricSettings) async {
    state = AsyncData(
      await ref
          .read(settingsRepositoryProvider)
          .setLyricSettings(lyricSettings),
    );
  }
}
