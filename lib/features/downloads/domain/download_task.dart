import '../../player/domain/playback_item.dart';

enum DownloadStatus { queued, downloading, completed, failed }

class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.item,
    required this.status,
    required this.progress,
    required this.createdAt,
    required this.updatedAt,
    this.sourceUrl,
    this.filePath,
    this.errorMessage,
    this.completedAt,
  });

  final String id;
  final PlaybackItem item;
  final DownloadStatus status;
  final double progress;
  final String? sourceUrl;
  final String? filePath;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
}
