class MusicItem {
  const MusicItem({
    required this.id,
    required this.platform,
    required this.title,
    required this.raw,
    this.artist,
    this.album,
    this.duration,
    this.artworkUrl,
  });

  final String id;
  final String platform;
  final String title;
  final String? artist;
  final String? album;
  final Duration? duration;
  final String? artworkUrl;
  final Map<String, Object?> raw;
}
