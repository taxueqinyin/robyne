// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

PluginMetadata _$PluginMetadataFromJson(Map<String, dynamic> json) {
  return _PluginMetadata.fromJson(json);
}

/// @nodoc
mixin _$PluginMetadata {
  String get name => throw _privateConstructorUsedError;
  String get author => throw _privateConstructorUsedError;
  String get version => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String? get platform => throw _privateConstructorUsedError;

  /// Serializes this PluginMetadata to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PluginMetadata
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PluginMetadataCopyWith<PluginMetadata> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PluginMetadataCopyWith<$Res> {
  factory $PluginMetadataCopyWith(
    PluginMetadata value,
    $Res Function(PluginMetadata) then,
  ) = _$PluginMetadataCopyWithImpl<$Res, PluginMetadata>;
  @useResult
  $Res call({
    String name,
    String author,
    String version,
    String? description,
    String? platform,
  });
}

/// @nodoc
class _$PluginMetadataCopyWithImpl<$Res, $Val extends PluginMetadata>
    implements $PluginMetadataCopyWith<$Res> {
  _$PluginMetadataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PluginMetadata
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? author = null,
    Object? version = null,
    Object? description = freezed,
    Object? platform = freezed,
  }) {
    return _then(
      _value.copyWith(
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            author: null == author
                ? _value.author
                : author // ignore: cast_nullable_to_non_nullable
                      as String,
            version: null == version
                ? _value.version
                : version // ignore: cast_nullable_to_non_nullable
                      as String,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            platform: freezed == platform
                ? _value.platform
                : platform // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PluginMetadataImplCopyWith<$Res>
    implements $PluginMetadataCopyWith<$Res> {
  factory _$$PluginMetadataImplCopyWith(
    _$PluginMetadataImpl value,
    $Res Function(_$PluginMetadataImpl) then,
  ) = __$$PluginMetadataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String name,
    String author,
    String version,
    String? description,
    String? platform,
  });
}

/// @nodoc
class __$$PluginMetadataImplCopyWithImpl<$Res>
    extends _$PluginMetadataCopyWithImpl<$Res, _$PluginMetadataImpl>
    implements _$$PluginMetadataImplCopyWith<$Res> {
  __$$PluginMetadataImplCopyWithImpl(
    _$PluginMetadataImpl _value,
    $Res Function(_$PluginMetadataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PluginMetadata
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? author = null,
    Object? version = null,
    Object? description = freezed,
    Object? platform = freezed,
  }) {
    return _then(
      _$PluginMetadataImpl(
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        author: null == author
            ? _value.author
            : author // ignore: cast_nullable_to_non_nullable
                  as String,
        version: null == version
            ? _value.version
            : version // ignore: cast_nullable_to_non_nullable
                  as String,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        platform: freezed == platform
            ? _value.platform
            : platform // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PluginMetadataImpl implements _PluginMetadata {
  const _$PluginMetadataImpl({
    required this.name,
    required this.author,
    required this.version,
    this.description,
    this.platform,
  });

  factory _$PluginMetadataImpl.fromJson(Map<String, dynamic> json) =>
      _$$PluginMetadataImplFromJson(json);

  @override
  final String name;
  @override
  final String author;
  @override
  final String version;
  @override
  final String? description;
  @override
  final String? platform;

  @override
  String toString() {
    return 'PluginMetadata(name: $name, author: $author, version: $version, description: $description, platform: $platform)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PluginMetadataImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.platform, platform) ||
                other.platform == platform));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, name, author, version, description, platform);

  /// Create a copy of PluginMetadata
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PluginMetadataImplCopyWith<_$PluginMetadataImpl> get copyWith =>
      __$$PluginMetadataImplCopyWithImpl<_$PluginMetadataImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$PluginMetadataImplToJson(this);
  }
}

abstract class _PluginMetadata implements PluginMetadata {
  const factory _PluginMetadata({
    required final String name,
    required final String author,
    required final String version,
    final String? description,
    final String? platform,
  }) = _$PluginMetadataImpl;

  factory _PluginMetadata.fromJson(Map<String, dynamic> json) =
      _$PluginMetadataImpl.fromJson;

  @override
  String get name;
  @override
  String get author;
  @override
  String get version;
  @override
  String? get description;
  @override
  String? get platform;

  /// Create a copy of PluginMetadata
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PluginMetadataImplCopyWith<_$PluginMetadataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SearchResult _$SearchResultFromJson(Map<String, dynamic> json) {
  return _SearchResult.fromJson(json);
}

/// @nodoc
mixin _$SearchResult {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get artist => throw _privateConstructorUsedError;
  String? get album => throw _privateConstructorUsedError;
  String? get cover => throw _privateConstructorUsedError;
  int? get duration => throw _privateConstructorUsedError;
  Map<String, dynamic>? get extra => throw _privateConstructorUsedError;

  /// Serializes this SearchResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SearchResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SearchResultCopyWith<SearchResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SearchResultCopyWith<$Res> {
  factory $SearchResultCopyWith(
    SearchResult value,
    $Res Function(SearchResult) then,
  ) = _$SearchResultCopyWithImpl<$Res, SearchResult>;
  @useResult
  $Res call({
    String id,
    String title,
    String? artist,
    String? album,
    String? cover,
    int? duration,
    Map<String, dynamic>? extra,
  });
}

/// @nodoc
class _$SearchResultCopyWithImpl<$Res, $Val extends SearchResult>
    implements $SearchResultCopyWith<$Res> {
  _$SearchResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SearchResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? artist = freezed,
    Object? album = freezed,
    Object? cover = freezed,
    Object? duration = freezed,
    Object? extra = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
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
            cover: freezed == cover
                ? _value.cover
                : cover // ignore: cast_nullable_to_non_nullable
                      as String?,
            duration: freezed == duration
                ? _value.duration
                : duration // ignore: cast_nullable_to_non_nullable
                      as int?,
            extra: freezed == extra
                ? _value.extra
                : extra // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SearchResultImplCopyWith<$Res>
    implements $SearchResultCopyWith<$Res> {
  factory _$$SearchResultImplCopyWith(
    _$SearchResultImpl value,
    $Res Function(_$SearchResultImpl) then,
  ) = __$$SearchResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    String? artist,
    String? album,
    String? cover,
    int? duration,
    Map<String, dynamic>? extra,
  });
}

/// @nodoc
class __$$SearchResultImplCopyWithImpl<$Res>
    extends _$SearchResultCopyWithImpl<$Res, _$SearchResultImpl>
    implements _$$SearchResultImplCopyWith<$Res> {
  __$$SearchResultImplCopyWithImpl(
    _$SearchResultImpl _value,
    $Res Function(_$SearchResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SearchResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? artist = freezed,
    Object? album = freezed,
    Object? cover = freezed,
    Object? duration = freezed,
    Object? extra = freezed,
  }) {
    return _then(
      _$SearchResultImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
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
        cover: freezed == cover
            ? _value.cover
            : cover // ignore: cast_nullable_to_non_nullable
                  as String?,
        duration: freezed == duration
            ? _value.duration
            : duration // ignore: cast_nullable_to_non_nullable
                  as int?,
        extra: freezed == extra
            ? _value._extra
            : extra // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SearchResultImpl implements _SearchResult {
  const _$SearchResultImpl({
    required this.id,
    required this.title,
    this.artist,
    this.album,
    this.cover,
    this.duration,
    final Map<String, dynamic>? extra,
  }) : _extra = extra;

  factory _$SearchResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$SearchResultImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String? artist;
  @override
  final String? album;
  @override
  final String? cover;
  @override
  final int? duration;
  final Map<String, dynamic>? _extra;
  @override
  Map<String, dynamic>? get extra {
    final value = _extra;
    if (value == null) return null;
    if (_extra is EqualUnmodifiableMapView) return _extra;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'SearchResult(id: $id, title: $title, artist: $artist, album: $album, cover: $cover, duration: $duration, extra: $extra)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SearchResultImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.artist, artist) || other.artist == artist) &&
            (identical(other.album, album) || other.album == album) &&
            (identical(other.cover, cover) || other.cover == cover) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            const DeepCollectionEquality().equals(other._extra, _extra));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    title,
    artist,
    album,
    cover,
    duration,
    const DeepCollectionEquality().hash(_extra),
  );

  /// Create a copy of SearchResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SearchResultImplCopyWith<_$SearchResultImpl> get copyWith =>
      __$$SearchResultImplCopyWithImpl<_$SearchResultImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SearchResultImplToJson(this);
  }
}

abstract class _SearchResult implements SearchResult {
  const factory _SearchResult({
    required final String id,
    required final String title,
    final String? artist,
    final String? album,
    final String? cover,
    final int? duration,
    final Map<String, dynamic>? extra,
  }) = _$SearchResultImpl;

  factory _SearchResult.fromJson(Map<String, dynamic> json) =
      _$SearchResultImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String? get artist;
  @override
  String? get album;
  @override
  String? get cover;
  @override
  int? get duration;
  @override
  Map<String, dynamic>? get extra;

  /// Create a copy of SearchResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SearchResultImplCopyWith<_$SearchResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MediaSource _$MediaSourceFromJson(Map<String, dynamic> json) {
  return _MediaSource.fromJson(json);
}

/// @nodoc
mixin _$MediaSource {
  String get url => throw _privateConstructorUsedError;
  int? get size => throw _privateConstructorUsedError;
  Map<String, String>? get headers => throw _privateConstructorUsedError;
  String? get quality => throw _privateConstructorUsedError;

  /// Serializes this MediaSource to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MediaSource
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MediaSourceCopyWith<MediaSource> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MediaSourceCopyWith<$Res> {
  factory $MediaSourceCopyWith(
    MediaSource value,
    $Res Function(MediaSource) then,
  ) = _$MediaSourceCopyWithImpl<$Res, MediaSource>;
  @useResult
  $Res call({
    String url,
    int? size,
    Map<String, String>? headers,
    String? quality,
  });
}

/// @nodoc
class _$MediaSourceCopyWithImpl<$Res, $Val extends MediaSource>
    implements $MediaSourceCopyWith<$Res> {
  _$MediaSourceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MediaSource
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? url = null,
    Object? size = freezed,
    Object? headers = freezed,
    Object? quality = freezed,
  }) {
    return _then(
      _value.copyWith(
            url: null == url
                ? _value.url
                : url // ignore: cast_nullable_to_non_nullable
                      as String,
            size: freezed == size
                ? _value.size
                : size // ignore: cast_nullable_to_non_nullable
                      as int?,
            headers: freezed == headers
                ? _value.headers
                : headers // ignore: cast_nullable_to_non_nullable
                      as Map<String, String>?,
            quality: freezed == quality
                ? _value.quality
                : quality // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MediaSourceImplCopyWith<$Res>
    implements $MediaSourceCopyWith<$Res> {
  factory _$$MediaSourceImplCopyWith(
    _$MediaSourceImpl value,
    $Res Function(_$MediaSourceImpl) then,
  ) = __$$MediaSourceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String url,
    int? size,
    Map<String, String>? headers,
    String? quality,
  });
}

/// @nodoc
class __$$MediaSourceImplCopyWithImpl<$Res>
    extends _$MediaSourceCopyWithImpl<$Res, _$MediaSourceImpl>
    implements _$$MediaSourceImplCopyWith<$Res> {
  __$$MediaSourceImplCopyWithImpl(
    _$MediaSourceImpl _value,
    $Res Function(_$MediaSourceImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MediaSource
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? url = null,
    Object? size = freezed,
    Object? headers = freezed,
    Object? quality = freezed,
  }) {
    return _then(
      _$MediaSourceImpl(
        url: null == url
            ? _value.url
            : url // ignore: cast_nullable_to_non_nullable
                  as String,
        size: freezed == size
            ? _value.size
            : size // ignore: cast_nullable_to_non_nullable
                  as int?,
        headers: freezed == headers
            ? _value._headers
            : headers // ignore: cast_nullable_to_non_nullable
                  as Map<String, String>?,
        quality: freezed == quality
            ? _value.quality
            : quality // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MediaSourceImpl implements _MediaSource {
  const _$MediaSourceImpl({
    required this.url,
    this.size,
    final Map<String, String>? headers,
    this.quality,
  }) : _headers = headers;

  factory _$MediaSourceImpl.fromJson(Map<String, dynamic> json) =>
      _$$MediaSourceImplFromJson(json);

  @override
  final String url;
  @override
  final int? size;
  final Map<String, String>? _headers;
  @override
  Map<String, String>? get headers {
    final value = _headers;
    if (value == null) return null;
    if (_headers is EqualUnmodifiableMapView) return _headers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  final String? quality;

  @override
  String toString() {
    return 'MediaSource(url: $url, size: $size, headers: $headers, quality: $quality)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MediaSourceImpl &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.size, size) || other.size == size) &&
            const DeepCollectionEquality().equals(other._headers, _headers) &&
            (identical(other.quality, quality) || other.quality == quality));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    url,
    size,
    const DeepCollectionEquality().hash(_headers),
    quality,
  );

  /// Create a copy of MediaSource
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MediaSourceImplCopyWith<_$MediaSourceImpl> get copyWith =>
      __$$MediaSourceImplCopyWithImpl<_$MediaSourceImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MediaSourceImplToJson(this);
  }
}

abstract class _MediaSource implements MediaSource {
  const factory _MediaSource({
    required final String url,
    final int? size,
    final Map<String, String>? headers,
    final String? quality,
  }) = _$MediaSourceImpl;

  factory _MediaSource.fromJson(Map<String, dynamic> json) =
      _$MediaSourceImpl.fromJson;

  @override
  String get url;
  @override
  int? get size;
  @override
  Map<String, String>? get headers;
  @override
  String? get quality;

  /// Create a copy of MediaSource
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MediaSourceImplCopyWith<_$MediaSourceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

LyricResult _$LyricResultFromJson(Map<String, dynamic> json) {
  return _LyricResult.fromJson(json);
}

/// @nodoc
mixin _$LyricResult {
  String? get rawLrc => throw _privateConstructorUsedError;
  String? get translation => throw _privateConstructorUsedError;

  /// Serializes this LyricResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LyricResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LyricResultCopyWith<LyricResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LyricResultCopyWith<$Res> {
  factory $LyricResultCopyWith(
    LyricResult value,
    $Res Function(LyricResult) then,
  ) = _$LyricResultCopyWithImpl<$Res, LyricResult>;
  @useResult
  $Res call({String? rawLrc, String? translation});
}

/// @nodoc
class _$LyricResultCopyWithImpl<$Res, $Val extends LyricResult>
    implements $LyricResultCopyWith<$Res> {
  _$LyricResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LyricResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? rawLrc = freezed, Object? translation = freezed}) {
    return _then(
      _value.copyWith(
            rawLrc: freezed == rawLrc
                ? _value.rawLrc
                : rawLrc // ignore: cast_nullable_to_non_nullable
                      as String?,
            translation: freezed == translation
                ? _value.translation
                : translation // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LyricResultImplCopyWith<$Res>
    implements $LyricResultCopyWith<$Res> {
  factory _$$LyricResultImplCopyWith(
    _$LyricResultImpl value,
    $Res Function(_$LyricResultImpl) then,
  ) = __$$LyricResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String? rawLrc, String? translation});
}

/// @nodoc
class __$$LyricResultImplCopyWithImpl<$Res>
    extends _$LyricResultCopyWithImpl<$Res, _$LyricResultImpl>
    implements _$$LyricResultImplCopyWith<$Res> {
  __$$LyricResultImplCopyWithImpl(
    _$LyricResultImpl _value,
    $Res Function(_$LyricResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LyricResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? rawLrc = freezed, Object? translation = freezed}) {
    return _then(
      _$LyricResultImpl(
        rawLrc: freezed == rawLrc
            ? _value.rawLrc
            : rawLrc // ignore: cast_nullable_to_non_nullable
                  as String?,
        translation: freezed == translation
            ? _value.translation
            : translation // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$LyricResultImpl implements _LyricResult {
  const _$LyricResultImpl({this.rawLrc, this.translation});

  factory _$LyricResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$LyricResultImplFromJson(json);

  @override
  final String? rawLrc;
  @override
  final String? translation;

  @override
  String toString() {
    return 'LyricResult(rawLrc: $rawLrc, translation: $translation)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LyricResultImpl &&
            (identical(other.rawLrc, rawLrc) || other.rawLrc == rawLrc) &&
            (identical(other.translation, translation) ||
                other.translation == translation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, rawLrc, translation);

  /// Create a copy of LyricResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LyricResultImplCopyWith<_$LyricResultImpl> get copyWith =>
      __$$LyricResultImplCopyWithImpl<_$LyricResultImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LyricResultImplToJson(this);
  }
}

abstract class _LyricResult implements LyricResult {
  const factory _LyricResult({
    final String? rawLrc,
    final String? translation,
  }) = _$LyricResultImpl;

  factory _LyricResult.fromJson(Map<String, dynamic> json) =
      _$LyricResultImpl.fromJson;

  @override
  String? get rawLrc;
  @override
  String? get translation;

  /// Create a copy of LyricResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LyricResultImplCopyWith<_$LyricResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AlbumInfo _$AlbumInfoFromJson(Map<String, dynamic> json) {
  return _AlbumInfo.fromJson(json);
}

/// @nodoc
mixin _$AlbumInfo {
  List<SearchResult> get musicList => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String? get cover => throw _privateConstructorUsedError;

  /// Serializes this AlbumInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AlbumInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AlbumInfoCopyWith<AlbumInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AlbumInfoCopyWith<$Res> {
  factory $AlbumInfoCopyWith(AlbumInfo value, $Res Function(AlbumInfo) then) =
      _$AlbumInfoCopyWithImpl<$Res, AlbumInfo>;
  @useResult
  $Res call({List<SearchResult> musicList, String? description, String? cover});
}

/// @nodoc
class _$AlbumInfoCopyWithImpl<$Res, $Val extends AlbumInfo>
    implements $AlbumInfoCopyWith<$Res> {
  _$AlbumInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AlbumInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? musicList = null,
    Object? description = freezed,
    Object? cover = freezed,
  }) {
    return _then(
      _value.copyWith(
            musicList: null == musicList
                ? _value.musicList
                : musicList // ignore: cast_nullable_to_non_nullable
                      as List<SearchResult>,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            cover: freezed == cover
                ? _value.cover
                : cover // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AlbumInfoImplCopyWith<$Res>
    implements $AlbumInfoCopyWith<$Res> {
  factory _$$AlbumInfoImplCopyWith(
    _$AlbumInfoImpl value,
    $Res Function(_$AlbumInfoImpl) then,
  ) = __$$AlbumInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<SearchResult> musicList, String? description, String? cover});
}

/// @nodoc
class __$$AlbumInfoImplCopyWithImpl<$Res>
    extends _$AlbumInfoCopyWithImpl<$Res, _$AlbumInfoImpl>
    implements _$$AlbumInfoImplCopyWith<$Res> {
  __$$AlbumInfoImplCopyWithImpl(
    _$AlbumInfoImpl _value,
    $Res Function(_$AlbumInfoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AlbumInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? musicList = null,
    Object? description = freezed,
    Object? cover = freezed,
  }) {
    return _then(
      _$AlbumInfoImpl(
        musicList: null == musicList
            ? _value._musicList
            : musicList // ignore: cast_nullable_to_non_nullable
                  as List<SearchResult>,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        cover: freezed == cover
            ? _value.cover
            : cover // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AlbumInfoImpl implements _AlbumInfo {
  const _$AlbumInfoImpl({
    required final List<SearchResult> musicList,
    this.description,
    this.cover,
  }) : _musicList = musicList;

  factory _$AlbumInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$AlbumInfoImplFromJson(json);

  final List<SearchResult> _musicList;
  @override
  List<SearchResult> get musicList {
    if (_musicList is EqualUnmodifiableListView) return _musicList;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_musicList);
  }

  @override
  final String? description;
  @override
  final String? cover;

  @override
  String toString() {
    return 'AlbumInfo(musicList: $musicList, description: $description, cover: $cover)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AlbumInfoImpl &&
            const DeepCollectionEquality().equals(
              other._musicList,
              _musicList,
            ) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.cover, cover) || other.cover == cover));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_musicList),
    description,
    cover,
  );

  /// Create a copy of AlbumInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AlbumInfoImplCopyWith<_$AlbumInfoImpl> get copyWith =>
      __$$AlbumInfoImplCopyWithImpl<_$AlbumInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AlbumInfoImplToJson(this);
  }
}

abstract class _AlbumInfo implements AlbumInfo {
  const factory _AlbumInfo({
    required final List<SearchResult> musicList,
    final String? description,
    final String? cover,
  }) = _$AlbumInfoImpl;

  factory _AlbumInfo.fromJson(Map<String, dynamic> json) =
      _$AlbumInfoImpl.fromJson;

  @override
  List<SearchResult> get musicList;
  @override
  String? get description;
  @override
  String? get cover;

  /// Create a copy of AlbumInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AlbumInfoImplCopyWith<_$AlbumInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
