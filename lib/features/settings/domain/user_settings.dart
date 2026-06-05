class UserSettings {
  const UserSettings({
    required this.cacheSizeBytes,
    required this.cacheDirectoryPath,
    required this.downloadsDirectoryPath,
  });

  final int cacheSizeBytes;
  final String cacheDirectoryPath;
  final String downloadsDirectoryPath;

  UserSettings copyWith({
    int? cacheSizeBytes,
    String? cacheDirectoryPath,
    String? downloadsDirectoryPath,
  }) {
    return UserSettings(
      cacheSizeBytes: cacheSizeBytes ?? this.cacheSizeBytes,
      cacheDirectoryPath: cacheDirectoryPath ?? this.cacheDirectoryPath,
      downloadsDirectoryPath:
          downloadsDirectoryPath ?? this.downloadsDirectoryPath,
    );
  }
}
