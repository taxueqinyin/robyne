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
  });

  final int cacheSizeBytes;
  final String cacheDirectoryPath;
  final String downloadsDirectoryPath;
  final DownloadAudioFormat downloadAudioFormat;
  final ShortcutSettings shortcuts;
  final LyricSettings lyricSettings;

  UserSettings copyWith({
    int? cacheSizeBytes,
    String? cacheDirectoryPath,
    String? downloadsDirectoryPath,
    DownloadAudioFormat? downloadAudioFormat,
    ShortcutSettings? shortcuts,
    LyricSettings? lyricSettings,
  }) {
    return UserSettings(
      cacheSizeBytes: cacheSizeBytes ?? this.cacheSizeBytes,
      cacheDirectoryPath: cacheDirectoryPath ?? this.cacheDirectoryPath,
      downloadsDirectoryPath:
          downloadsDirectoryPath ?? this.downloadsDirectoryPath,
      downloadAudioFormat: downloadAudioFormat ?? this.downloadAudioFormat,
      shortcuts: shortcuts ?? this.shortcuts,
      lyricSettings: lyricSettings ?? this.lyricSettings,
    );
  }
}
