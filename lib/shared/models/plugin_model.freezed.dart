// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

PluginModel _$PluginModelFromJson(Map<String, dynamic> json) {
  return _PluginModel.fromJson(json);
}

/// @nodoc
mixin _$PluginModel {
  int get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get author => throw _privateConstructorUsedError;
  String get version => throw _privateConstructorUsedError;
  String get localPath => throw _privateConstructorUsedError;
  String? get subscriptionUrl => throw _privateConstructorUsedError;
  bool get isEnabled => throw _privateConstructorUsedError;
  DateTime get installedAt => throw _privateConstructorUsedError;

  /// Serializes this PluginModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PluginModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PluginModelCopyWith<PluginModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PluginModelCopyWith<$Res> {
  factory $PluginModelCopyWith(
    PluginModel value,
    $Res Function(PluginModel) then,
  ) = _$PluginModelCopyWithImpl<$Res, PluginModel>;
  @useResult
  $Res call({
    int id,
    String name,
    String author,
    String version,
    String localPath,
    String? subscriptionUrl,
    bool isEnabled,
    DateTime installedAt,
  });
}

/// @nodoc
class _$PluginModelCopyWithImpl<$Res, $Val extends PluginModel>
    implements $PluginModelCopyWith<$Res> {
  _$PluginModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PluginModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? author = null,
    Object? version = null,
    Object? localPath = null,
    Object? subscriptionUrl = freezed,
    Object? isEnabled = null,
    Object? installedAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int,
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
            localPath: null == localPath
                ? _value.localPath
                : localPath // ignore: cast_nullable_to_non_nullable
                      as String,
            subscriptionUrl: freezed == subscriptionUrl
                ? _value.subscriptionUrl
                : subscriptionUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            isEnabled: null == isEnabled
                ? _value.isEnabled
                : isEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            installedAt: null == installedAt
                ? _value.installedAt
                : installedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PluginModelImplCopyWith<$Res>
    implements $PluginModelCopyWith<$Res> {
  factory _$$PluginModelImplCopyWith(
    _$PluginModelImpl value,
    $Res Function(_$PluginModelImpl) then,
  ) = __$$PluginModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int id,
    String name,
    String author,
    String version,
    String localPath,
    String? subscriptionUrl,
    bool isEnabled,
    DateTime installedAt,
  });
}

/// @nodoc
class __$$PluginModelImplCopyWithImpl<$Res>
    extends _$PluginModelCopyWithImpl<$Res, _$PluginModelImpl>
    implements _$$PluginModelImplCopyWith<$Res> {
  __$$PluginModelImplCopyWithImpl(
    _$PluginModelImpl _value,
    $Res Function(_$PluginModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PluginModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? author = null,
    Object? version = null,
    Object? localPath = null,
    Object? subscriptionUrl = freezed,
    Object? isEnabled = null,
    Object? installedAt = null,
  }) {
    return _then(
      _$PluginModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
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
        localPath: null == localPath
            ? _value.localPath
            : localPath // ignore: cast_nullable_to_non_nullable
                  as String,
        subscriptionUrl: freezed == subscriptionUrl
            ? _value.subscriptionUrl
            : subscriptionUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        isEnabled: null == isEnabled
            ? _value.isEnabled
            : isEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        installedAt: null == installedAt
            ? _value.installedAt
            : installedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PluginModelImpl implements _PluginModel {
  const _$PluginModelImpl({
    required this.id,
    required this.name,
    required this.author,
    required this.version,
    required this.localPath,
    this.subscriptionUrl,
    this.isEnabled = true,
    required this.installedAt,
  });

  factory _$PluginModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$PluginModelImplFromJson(json);

  @override
  final int id;
  @override
  final String name;
  @override
  final String author;
  @override
  final String version;
  @override
  final String localPath;
  @override
  final String? subscriptionUrl;
  @override
  @JsonKey()
  final bool isEnabled;
  @override
  final DateTime installedAt;

  @override
  String toString() {
    return 'PluginModel(id: $id, name: $name, author: $author, version: $version, localPath: $localPath, subscriptionUrl: $subscriptionUrl, isEnabled: $isEnabled, installedAt: $installedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PluginModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.localPath, localPath) ||
                other.localPath == localPath) &&
            (identical(other.subscriptionUrl, subscriptionUrl) ||
                other.subscriptionUrl == subscriptionUrl) &&
            (identical(other.isEnabled, isEnabled) ||
                other.isEnabled == isEnabled) &&
            (identical(other.installedAt, installedAt) ||
                other.installedAt == installedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    author,
    version,
    localPath,
    subscriptionUrl,
    isEnabled,
    installedAt,
  );

  /// Create a copy of PluginModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PluginModelImplCopyWith<_$PluginModelImpl> get copyWith =>
      __$$PluginModelImplCopyWithImpl<_$PluginModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PluginModelImplToJson(this);
  }
}

abstract class _PluginModel implements PluginModel {
  const factory _PluginModel({
    required final int id,
    required final String name,
    required final String author,
    required final String version,
    required final String localPath,
    final String? subscriptionUrl,
    final bool isEnabled,
    required final DateTime installedAt,
  }) = _$PluginModelImpl;

  factory _PluginModel.fromJson(Map<String, dynamic> json) =
      _$PluginModelImpl.fromJson;

  @override
  int get id;
  @override
  String get name;
  @override
  String get author;
  @override
  String get version;
  @override
  String get localPath;
  @override
  String? get subscriptionUrl;
  @override
  bool get isEnabled;
  @override
  DateTime get installedAt;

  /// Create a copy of PluginModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PluginModelImplCopyWith<_$PluginModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
