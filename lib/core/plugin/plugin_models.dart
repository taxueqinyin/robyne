/// 插件元信息
class PluginMeta {
  final String id;
  final String name;
  final String version;
  final int apiVersion;

  PluginMeta({
    required this.id,
    required this.name,
    required this.version,
    required this.apiVersion,
  });

  factory PluginMeta.fromJson(Map<String, dynamic> json) {
    return PluginMeta(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      version: json['version'] as String? ?? '0.0.0',
      apiVersion: json['apiVersion'] as int? ?? 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PluginMeta && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// 插件状态
enum PluginStatus {
  unloaded,
  loaded,
  enabled,
  disabled,
  error,
}

/// 插件实例
class PluginInstance {
  final PluginMeta meta;
  final String sourcePath;
  PluginStatus status;
  String? errorMessage;

  PluginInstance({
    required this.meta,
    required this.sourcePath,
    this.status = PluginStatus.unloaded,
    this.errorMessage,
  });
}
