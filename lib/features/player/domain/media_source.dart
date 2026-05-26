class MediaSource {
  const MediaSource({
    required this.url,
    this.headers = const <String, String>{},
    this.quality,
    this.mimeType,
    this.expiresAt,
    this.raw,
  });

  final String url;
  final Map<String, String> headers;
  final String? quality;
  final String? mimeType;
  final DateTime? expiresAt;
  final Map<String, Object?>? raw;
}
