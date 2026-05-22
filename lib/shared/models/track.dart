// 统一歌曲模型 - 在线/本地共用
sealed class Track {
  String get id;
  String get title;
  String get artist;
  String? get album => null;
  String? get coverUrl => null;
}

/// 本地歌曲
class LocalTrack extends Track {
  @override
  final String id;
  @override
  final String title;
  @override
  final String artist;
  @override
  final String? album;
  @override
  final String? coverUrl;
  final String path;
  final Duration? duration;

  LocalTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.coverUrl,
    required this.path,
    this.duration,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalTrack && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// 在线歌曲
class RemoteTrack extends Track {
  @override
  final String id;
  @override
  final String title;
  @override
  final String artist;
  @override
  final String? album;
  @override
  final String? coverUrl;
  final String pluginId;

  RemoteTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.coverUrl,
    required this.pluginId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemoteTrack &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          pluginId == other.pluginId;

  @override
  int get hashCode => Object.hash(id, pluginId);
}

/// 媒体源 - 播放地址信息
class MediaSource {
  final String url;
  final Map<String, String>? headers;
  final String? contentType;

  MediaSource({
    required this.url,
    this.headers,
    this.contentType,
  });
}

/// 歌词数据
class LyricData {
  final String rawLrc;
  final List<LyricLine> lines;

  LyricData({required this.rawLrc, required this.lines});
}

/// 歌词行
class LyricLine {
  final Duration timestamp;
  final String text;

  LyricLine({required this.timestamp, required this.text});
}

/// 队列项
class QueueItem {
  final String queueId;
  final Track track;

  QueueItem({required this.queueId, required this.track});

  static int _counter = 0;

  factory QueueItem.fromTrack(Track track) {
    _counter++;
    return QueueItem(queueId: 'q_${_counter}_${track.id}', track: track);
  }
}
