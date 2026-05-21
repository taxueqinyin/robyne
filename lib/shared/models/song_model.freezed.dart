// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'song_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SongModel _$SongModelFromJson(Map<String, dynamic> json) {
  return _SongModel.fromJson(json);
}

/// @nodoc
mixin _$SongModel {
  int get id => throw _privateConstructorUsedError;
  String? get sourceId => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get artist => throw _privateConstructorUsedError;
  String? get album => throw _privateConstructorUsedError;
  String? get coverUrl => throw _privateConstructorUsedError;
  String? get coverLocal => throw _privateConstructorUsedError;
  String? get audioUrl => throw _privateConstructorUsedError;
  int? get durationMs => throw _privateConstructorUsedError;
  bool get isLocal => throw _privateConstructorUsedError;
  String? get localPath => throw _privateConstructorUsedError;
  int? get pluginId => throw _privateConstructorUsedError;

  /// Serializes this SongModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SongModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SongModelCopyWith<SongModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SongModelCopyWith<$Res> {
  factory $SongModelCopyWith(SongModel value, $Res Function(SongModel) then) =
      _$SongModelCopyWithImpl<$Res, SongModel>;
  @useResult
  $Res call({
    int id,
    String? sourceId,
    String title,
    String? artist,
    String? album,
    String? coverUrl,
    String? coverLocal,
    String? audioUrl,
    int? durationMs,
    bool isLocal,
    String? localPath,
    int? pluginId,
  });
}

/// @nodoc
class _$SongModelCopyWithImpl<$Res, $Val extends SongModel>
    implements $SongModelCopyWith<$Res> {
  _$SongModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SongModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sourceId = freezed,
    Object? title = null,
    Object? artist = freezed,
    Object? album = freezed,
    Object? coverUrl = freezed,
    Object? coverLocal = freezed,
    Object? audioUrl = freezed,
    Object? durationMs = freezed,
    Object? isLocal = null,
    Object? localPath = freezed,
    Object? pluginId = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int,
            sourceId: freezed == sourceId
                ? _value.sourceId
                : sourceId // ignore: cast_nullable_to_non_nullable
                      as String?,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            artist: freezed == artist
                ? _value.artist
                : artist // ignore: cast_nullable_to_non_nullable
                      as String?,
            album: freezed == album
                ? _value.album
                : album // ignore: cast_nullable_to_non_nullable
                      as String?,
            coverUrl: freezed == coverUrl
                ? _value.coverUrl
                : coverUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            coverLocal: freezed == coverLocal
                ? _value.coverLocal
                : coverLocal // ignore: cast_nullable_to_non_nullable
                      as String?,
            audioUrl: freezed == audioUrl
                ? _value.audioUrl
                : audioUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            durationMs: freezed == durationMs
                ? _value.durationMs
                : durationMs // ignore: cast_nullable_to_non_nullable
                      as int?,
            isLocal: null == isLocal
                ? _value.isLocal
                : isLocal // ignore: cast_nullable_to_non_nullable
                      as bool,
            localPath: freezed == localPath
                ? _value.localPath
                : localPath // ignore: cast_nullable_to_non_nullable
                      as String?,
            pluginId: freezed == pluginId
                ? _value.pluginId
                : pluginId // ignore: cast_nullable_to_non_nullable
                      as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SongModelImplCopyWith<$Res>
    implements $SongModelCopyWith<$Res> {
  factory _$$SongModelImplCopyWith(
    _$SongModelImpl value,
    $Res Function(_$SongModelImpl) then,
  ) = __$$SongModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int id,
    String? sourceId,
    String title,
    String? artist,
    String? album,
    String? coverUrl,
    String? coverLocal,
    String? audioUrl,
    int? durationMs,
    bool isLocal,
    String? localPath,
    int? pluginId,
  });
}

/// @nodoc
class __$$SongModelImplCopyWithImpl<$Res>
    extends _$SongModelCopyWithImpl<$Res, _$SongModelImpl>
    implements _$$SongModelImplCopyWith<$Res> {
  __$$SongModelImplCopyWithImpl(
    _$SongModelImpl _value,
    $Res Function(_$SongModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SongModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sourceId = freezed,
    Object? title = null,
    Object? artist = freezed,
    Object? album = freezed,
    Object? coverUrl = freezed,
    Object? coverLocal = freezed,
    Object? audioUrl = freezed,
    Object? durationMs = freezed,
    Object? isLocal = null,
    Object? localPath = freezed,
    Object? pluginId = freezed,
  }) {
    return _then(
      _$SongModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        sourceId: freezed == sourceId
            ? _value.sourceId
            : sourceId // ignore: cast_nullable_to_non_nullable
                  as String?,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        artist: freezed == artist
            ? _value.artist
            : artist // ignore: cast_nullable_to_non_nullable
                  as String?,
        album: freezed == album
            ? _value.album
            : album // ignore: cast_nullable_to_non_nullable
                  as String?,
        coverUrl: freezed == coverUrl
            ? _value.coverUrl
            : coverUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        coverLocal: freezed == coverLocal
            ? _value.coverLocal
            : coverLocal // ignore: cast_nullable_to_non_nullable
                  as String?,
        audioUrl: freezed == audioUrl
            ? _value.audioUrl
            : audioUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        durationMs: freezed == durationMs
            ? _value.durationMs
            : durationMs // ignore: cast_nullable_to_non_nullable
                  as int?,
        isLocal: null == isLocal
            ? _value.isLocal
            : isLocal // ignore: cast_nullable_to_non_nullable
                  as bool,
        localPath: freezed == localPath
            ? _value.localPath
            : localPath // ignore: cast_nullable_to_non_nullable
                  as String?,
        pluginId: freezed == pluginId
            ? _value.pluginId
            : pluginId // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SongModelImpl implements _SongModel {
  const _$SongModelImpl({
    required this.id,
    this.sourceId,
    required this.title,
    this.artist,
    this.album,
    this.coverUrl,
    this.coverLocal,
    this.audioUrl,
    this.durationMs,
    this.isLocal = false,
    this.localPath,
    this.pluginId,
  });

  factory _$SongModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$SongModelImplFromJson(json);

  @override
  final int id;
  @override
  final String? sourceId;
  @override
  final String title;
  @override
  final String? artist;
  @override
  final String? album;
  @override
  final String? coverUrl;
  @override
  final String? coverLocal;
  @override
  final String? audioUrl;
  @override
  final int? durationMs;
  @override
  @JsonKey()
  final bool isLocal;
  @override
  final String? localPath;
  @override
  final int? pluginId;

  @override
  String toString() {
    return 'SongModel(id: $id, sourceId: $sourceId, title: $title, artist: $artist, album: $album, coverUrl: $coverUrl, coverLocal: $coverLocal, audioUrl: $audioUrl, durationMs: $durationMs, isLocal: $isLocal, localPath: $localPath, pluginId: $pluginId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SongModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.sourceId, sourceId) ||
                other.sourceId == sourceId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.artist, artist) || other.artist == artist) &&
            (identical(other.album, album) || other.album == album) &&
            (identical(other.coverUrl, coverUrl) ||
                other.coverUrl == coverUrl) &&
            (identical(other.coverLocal, coverLocal) ||
                other.coverLocal == coverLocal) &&
            (identical(other.audioUrl, audioUrl) ||
                other.audioUrl == audioUrl) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            (identical(other.isLocal, isLocal) || other.isLocal == isLocal) &&
            (identical(other.localPath, localPath) ||
                other.localPath == localPath) &&
            (identical(other.pluginId, pluginId) ||
                other.pluginId == pluginId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    sourceId,
    title,
    artist,
    album,
    coverUrl,
    coverLocal,
    audioUrl,
    durationMs,
    isLocal,
    localPath,
    pluginId,
  );

  /// Create a copy of SongModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SongModelImplCopyWith<_$SongModelImpl> get copyWith =>
      __$$SongModelImplCopyWithImpl<_$SongModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SongModelImplToJson(this);
  }
}

abstract class _SongModel implements SongModel {
  const factory _SongModel({
    required final int id,
    final String? sourceId,
    required final String title,
    final String? artist,
    final String? album,
    final String? coverUrl,
    final String? coverLocal,
    final String? audioUrl,
    final int? durationMs,
    final bool isLocal,
    final String? localPath,
    final int? pluginId,
  }) = _$SongModelImpl;

  factory _SongModel.fromJson(Map<String, dynamic> json) =
      _$SongModelImpl.fromJson;

  @override
  int get id;
  @override
  String? get sourceId;
  @override
  String get title;
  @override
  String? get artist;
  @override
  String? get album;
  @override
  String? get coverUrl;
  @override
  String? get coverLocal;
  @override
  String? get audioUrl;
  @override
  int? get durationMs;
  @override
  bool get isLocal;
  @override
  String? get localPath;
  @override
  int? get pluginId;

  /// Create a copy of SongModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SongModelImplCopyWith<_$SongModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
