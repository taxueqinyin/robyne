import 'package:freezed_annotation/freezed_annotation.dart';

part 'plugin_models.freezed.dart';
part 'plugin_models.g.dart';

@freezed
class PluginMetadata with _$PluginMetadata {
  const factory PluginMetadata({
    required String name,
    required String author,
    required String version,
    String? description,
    String? platform,
  }) = _PluginMetadata;

  factory PluginMetadata.fromJson(Map<String, dynamic> json) =>
      _$PluginMetadataFromJson(json);
}

@freezed
class SearchResult with _$SearchResult {
  const factory SearchResult({
    required String id,
    required String title,
    String? artist,
    String? album,
    String? cover,
    int? duration,
    Map<String, dynamic>? extra,
  }) = _SearchResult;

  factory SearchResult.fromJson(Map<String, dynamic> json) =>
      _$SearchResultFromJson(json);
}

@freezed
class MediaSource with _$MediaSource {
  const factory MediaSource({
    required String url,
    int? size,
    Map<String, String>? headers,
    String? quality,
  }) = _MediaSource;

  factory MediaSource.fromJson(Map<String, dynamic> json) =>
      _$MediaSourceFromJson(json);
}

@freezed
class LyricResult with _$LyricResult {
  const factory LyricResult({
    String? rawLrc,
    String? translation,
  }) = _LyricResult;

  factory LyricResult.fromJson(Map<String, dynamic> json) =>
      _$LyricResultFromJson(json);
}

@freezed
class AlbumInfo with _$AlbumInfo {
  const factory AlbumInfo({
    required List<SearchResult> musicList,
    String? description,
    String? cover,
  }) = _AlbumInfo;

  factory AlbumInfo.fromJson(Map<String, dynamic> json) =>
      _$AlbumInfoFromJson(json);
}
