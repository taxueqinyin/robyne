import '../../downloads/domain/download_audio_format.dart';

class UserSettings {
  const UserSettings({
    required this.cacheSizeBytes,
    required this.cacheDirectoryPath,
    required this.downloadsDirectoryPath,
    required this.downloadAudioFormat,
  });

  final int cacheSizeBytes;
  final String cacheDirectoryPath;
  final String downloadsDirectoryPath;
  final DownloadAudioFormat downloadAudioFormat;

  UserSettings copyWith({
    int? cacheSizeBytes,
    String? cacheDirectoryPath,
    String? downloadsDirectoryPath,
    DownloadAudioFormat? downloadAudioFormat,
  }) {
    return UserSettings(
      cacheSizeBytes: cacheSizeBytes ?? this.cacheSizeBytes,
      cacheDirectoryPath: cacheDirectoryPath ?? this.cacheDirectoryPath,
      downloadsDirectoryPath:
          downloadsDirectoryPath ?? this.downloadsDirectoryPath,
      downloadAudioFormat: downloadAudioFormat ?? this.downloadAudioFormat,
    );
  }
}
