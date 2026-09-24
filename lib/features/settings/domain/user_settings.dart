import '../../downloads/domain/download_audio_format.dart';
import 'lyric_settings.dart';
import 'shortcut_settings.dart';

class UserSettings {
  const UserSettings({
    required this.cacheSizeBytes,
    required this.cacheDirectoryPath,
    required this.downloadsDirectoryPath,
    required this.downloadAudioFormat,
    required this.shortcuts,
    required this.lyricSettings,
    required this.activeThemeId,
    required this.themeModeOverrideName,
    required this.themeSettingValues,
  });

  static const String defaultActiveThemeId = 'official.light';
  static const String defaultThemeModeOverrideName = 'system';

  final int cacheSizeBytes;
  final String cacheDirectoryPath;
  final String downloadsDirectoryPath;
  final DownloadAudioFormat downloadAudioFormat;
  final ShortcutSettings shortcuts;
  final LyricSettings lyricSettings;

  /// Id of the skin currently applied.
  final String activeThemeId;

  /// `ThemeMode.system` defers to the skin's own brightness preference.
  final String themeModeOverrideName;

  /// User tweaks to skin-declared knobs, keyed by `<themeId>/<settingKey>`.
  final Map<String, Object> themeSettingValues;

  UserSettings copyWith({
    int? cacheSizeBytes,
    String? cacheDirectoryPath,
    String? downloadsDirectoryPath,
    DownloadAudioFormat? downloadAudioFormat,
    ShortcutSettings? shortcuts,
    LyricSettings? lyricSettings,
    String? activeThemeId,
    String? themeModeOverrideName,
    Map<String, Object>? themeSettingValues,
  }) {
    return UserSettings(
      cacheSizeBytes: cacheSizeBytes ?? this.cacheSizeBytes,
      cacheDirectoryPath: cacheDirectoryPath ?? this.cacheDirectoryPath,
      downloadsDirectoryPath:
          downloadsDirectoryPath ?? this.downloadsDirectoryPath,
      downloadAudioFormat: downloadAudioFormat ?? this.downloadAudioFormat,
      shortcuts: shortcuts ?? this.shortcuts,
      lyricSettings: lyricSettings ?? this.lyricSettings,
      activeThemeId: activeThemeId ?? this.activeThemeId,
      themeModeOverrideName:
          themeModeOverrideName ?? this.themeModeOverrideName,
      themeSettingValues: themeSettingValues ?? this.themeSettingValues,
    );
  }
}
