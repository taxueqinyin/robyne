// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PluginModelImpl _$$PluginModelImplFromJson(Map<String, dynamic> json) =>
    _$PluginModelImpl(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      author: json['author'] as String,
      version: json['version'] as String,
      localPath: json['localPath'] as String,
      subscriptionUrl: json['subscriptionUrl'] as String?,
      isEnabled: json['isEnabled'] as bool? ?? true,
      installedAt: DateTime.parse(json['installedAt'] as String),
    );

Map<String, dynamic> _$$PluginModelImplToJson(_$PluginModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'author': instance.author,
      'version': instance.version,
      'localPath': instance.localPath,
      'subscriptionUrl': instance.subscriptionUrl,
      'isEnabled': instance.isEnabled,
      'installedAt': instance.installedAt.toIso8601String(),
    };
