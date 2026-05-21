// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PluginMetadataImpl _$$PluginMetadataImplFromJson(Map<String, dynamic> json) =>
    _$PluginMetadataImpl(
      name: json['name'] as String,
      author: json['author'] as String,
      version: json['version'] as String,
      description: json['description'] as String?,
      platform: json['platform'] as String?,
    );

Map<String, dynamic> _$$PluginMetadataImplToJson(
  _$PluginMetadataImpl instance,
) => <String, dynamic>{
  'name': instance.name,
  'author': instance.author,
  'version': instance.version,
  'description': instance.description,
  'platform': instance.platform,
};

_$SearchResultImpl _$$SearchResultImplFromJson(Map<String, dynamic> json) =>
    _$SearchResultImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String?,
      album: json['album'] as String?,
      cover: json['cover'] as String?,
      duration: (json['duration'] as num?)?.toInt(),
      extra: json['extra'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$SearchResultImplToJson(_$SearchResultImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'artist': instance.artist,
      'album': instance.album,
      'cover': instance.cover,
      'duration': instance.duration,
      'extra': instance.extra,
    };

_$MediaSourceImpl _$$MediaSourceImplFromJson(Map<String, dynamic> json) =>
    _$MediaSourceImpl(
      url: json['url'] as String,
      size: (json['size'] as num?)?.toInt(),
      headers: (json['headers'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      quality: json['quality'] as String?,
    );

Map<String, dynamic> _$$MediaSourceImplToJson(_$MediaSourceImpl instance) =>
    <String, dynamic>{
      'url': instance.url,
      'size': instance.size,
      'headers': instance.headers,
      'quality': instance.quality,
    };

_$LyricResultImpl _$$LyricResultImplFromJson(Map<String, dynamic> json) =>
    _$LyricResultImpl(
      rawLrc: json['rawLrc'] as String?,
      translation: json['translation'] as String?,
    );

Map<String, dynamic> _$$LyricResultImplToJson(_$LyricResultImpl instance) =>
    <String, dynamic>{
      'rawLrc': instance.rawLrc,
      'translation': instance.translation,
    };

_$AlbumInfoImpl _$$AlbumInfoImplFromJson(Map<String, dynamic> json) =>
    _$AlbumInfoImpl(
      musicList: (json['musicList'] as List<dynamic>)
          .map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      description: json['description'] as String?,
      cover: json['cover'] as String?,
    );

Map<String, dynamic> _$$AlbumInfoImplToJson(_$AlbumInfoImpl instance) =>
    <String, dynamic>{
      'musicList': instance.musicList,
      'description': instance.description,
      'cover': instance.cover,
    };
