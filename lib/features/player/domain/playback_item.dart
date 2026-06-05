import 'dart:io';

import '../../search/domain/music_item.dart';

enum PlaybackItemType { plugin, local }

enum PlaybackMode { sequence, random, allLoop, singleLoop }

class PlaybackItem {
  const PlaybackItem({
    required this.id,
    required this.type,
    required this.title,
    this.platform,
    this.musicId,
    this.localPath,
    this.artist,
    this.album,
    this.duration,
    this.artworkUrl,
    this.raw = const <String, Object?>{},
  });

  factory PlaybackItem.plugin({
    required String platform,
    required String musicId,
    required String title,
    required Map<String, Object?> raw,
    String? artist,
    String? album,
    Duration? duration,
    String? artworkUrl,
  }) {
    return PlaybackItem(
      id: 'plugin:$platform:$musicId',
      type: PlaybackItemType.plugin,
      platform: platform,
      musicId: musicId,
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      artworkUrl: artworkUrl,
      raw: raw,
    );
  }

  factory PlaybackItem.fromMusicItem(MusicItem item) {
    return PlaybackItem.plugin(
      platform: item.platform,
      musicId: item.id,
      title: item.title,
      artist: item.artist,
      album: item.album,
      duration: item.duration,
      artworkUrl: item.artworkUrl,
      raw: item.raw,
    );
  }

  factory PlaybackItem.local({
    required String path,
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    String? artworkUrl,
  }) {
    final normalized = normalizePath(path);
    return PlaybackItem(
      id: 'local:$normalized',
      type: PlaybackItemType.local,
      localPath: normalized,
      title: title ?? _titleFromPath(normalized),
      artist: artist,
      album: album,
      duration: duration,
      artworkUrl: artworkUrl,
      raw: <String, Object?>{'path': normalized},
    );
  }

  final String id;
  final PlaybackItemType type;
  final String title;
  final String? platform;
  final String? musicId;
  final String? localPath;
  final String? artist;
  final String? album;
  final Duration? duration;
  final String? artworkUrl;
  final Map<String, Object?> raw;

  bool get isLocal => type == PlaybackItemType.local;
  bool get isPlugin => type == PlaybackItemType.plugin;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'type': type.name,
      'title': title,
      'platform': platform,
      'musicId': musicId,
      'localPath': localPath,
      'artist': artist,
      'album': album,
      'durationMs': duration?.inMilliseconds,
      'artworkUrl': artworkUrl,
      'raw': raw,
    };
  }

  static PlaybackItem fromJson(Map<String, Object?> json) {
    final typeName = json['type']?.toString();
    return PlaybackItem(
      id: json['id']?.toString() ?? '',
      type: typeName == PlaybackItemType.local.name
          ? PlaybackItemType.local
          : PlaybackItemType.plugin,
      title: json['title']?.toString() ?? '',
      platform: json['platform']?.toString(),
      musicId: json['musicId']?.toString(),
      localPath: json['localPath']?.toString(),
      artist: json['artist']?.toString(),
      album: json['album']?.toString(),
      duration: json['durationMs'] is num
          ? Duration(milliseconds: (json['durationMs']! as num).toInt())
          : null,
      artworkUrl: json['artworkUrl']?.toString(),
      raw: json['raw'] is Map
          ? (json['raw']! as Map).map(
              (key, dynamic value) =>
                  MapEntry(key.toString(), value as Object?),
            )
          : const <String, Object?>{},
    );
  }

  static String normalizePath(String path) {
    return File(path).absolute.path.replaceAll(r'\', '/');
  }

  static String _titleFromPath(String path) {
    final normalized = path.replaceAll(r'\', '/');
    final fileName = normalized.split('/').last;
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0) {
      return fileName;
    }
    return fileName.substring(0, dot);
  }
}

class PlaybackHistoryEntry {
  const PlaybackHistoryEntry({required this.item, required this.playedAt});

  final PlaybackItem item;
  final DateTime playedAt;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'item': item.toJson(),
      'playedAt': playedAt.toIso8601String(),
    };
  }

  static PlaybackHistoryEntry fromJson(Map<String, Object?> json) {
    return PlaybackHistoryEntry(
      item: PlaybackItem.fromJson(
        (json['item'] as Map).map(
          (key, dynamic value) => MapEntry(key.toString(), value as Object?),
        ),
      ),
      playedAt:
          DateTime.tryParse(json['playedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
