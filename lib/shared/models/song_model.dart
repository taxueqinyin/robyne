import 'package:freezed_annotation/freezed_annotation.dart';

part 'song_model.freezed.dart';
part 'song_model.g.dart';

@freezed
class SongModel with _$SongModel {
  const factory SongModel({
    required int id,
    String? sourceId,
    required String title,
    String? artist,
    String? album,
    String? coverUrl,
    String? coverLocal,
    String? audioUrl,
    int? durationMs,
    @Default(false) bool isLocal,
    String? localPath,
    int? pluginId,
  }) = _SongModel;

  factory SongModel.fromJson(Map<String, dynamic> json) =>
      _$SongModelFromJson(json);
}
