// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'song_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SongModelImpl _$$SongModelImplFromJson(Map<String, dynamic> json) =>
    _$SongModelImpl(
      id: (json['id'] as num).toInt(),
      sourceId: json['sourceId'] as String?,
      title: json['title'] as String,
      artist: json['artist'] as String?,
      album: json['album'] as String?,
      coverUrl: json['coverUrl'] as String?,
      coverLocal: json['coverLocal'] as String?,
      audioUrl: json['audioUrl'] as String?,
      durationMs: (json['durationMs'] as num?)?.toInt(),
      isLocal: json['isLocal'] as bool? ?? false,
      localPath: json['localPath'] as String?,
      pluginId: (json['pluginId'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$SongModelImplToJson(_$SongModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sourceId': instance.sourceId,
      'title': instance.title,
      'artist': instance.artist,
      'album': instance.album,
      'coverUrl': instance.coverUrl,
      'coverLocal': instance.coverLocal,
      'audioUrl': instance.audioUrl,
      'durationMs': instance.durationMs,
      'isLocal': instance.isLocal,
      'localPath': instance.localPath,
      'pluginId': instance.pluginId,
    };
