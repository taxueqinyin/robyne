class PluginDefinition {
  const PluginDefinition({
    required this.id,
    required this.platform,
    required this.sourcePath,
    required this.enabled,
    required this.installedAt,
    required this.updatedAt,
    this.version,
    this.author,
    this.description,
    this.supportedSearchTypes = const <String>[],
    this.userVariables = const <Map<String, Object?>>[],
    this.userVariableValues = const <String, String>{},
  });

  final String id;
  final String platform;
  final String? version;
  final String? author;
  final String? description;
  final String sourcePath;
  final bool enabled;
  final DateTime installedAt;
  final DateTime updatedAt;
  final List<String> supportedSearchTypes;
  final List<Map<String, Object?>> userVariables;
  final Map<String, String> userVariableValues;

  PluginDefinition copyWith({
    String? id,
    String? platform,
    String? version,
    String? author,
    String? description,
    String? sourcePath,
    bool? enabled,
    DateTime? installedAt,
    DateTime? updatedAt,
    List<String>? supportedSearchTypes,
    List<Map<String, Object?>>? userVariables,
    Map<String, String>? userVariableValues,
  }) {
    return PluginDefinition(
      id: id ?? this.id,
      platform: platform ?? this.platform,
      version: version ?? this.version,
      author: author ?? this.author,
      description: description ?? this.description,
      sourcePath: sourcePath ?? this.sourcePath,
      enabled: enabled ?? this.enabled,
      installedAt: installedAt ?? this.installedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      supportedSearchTypes: supportedSearchTypes ?? this.supportedSearchTypes,
      userVariables: userVariables ?? this.userVariables,
      userVariableValues: userVariableValues ?? this.userVariableValues,
    );
  }

  factory PluginDefinition.fromJson(Map<String, Object?> json) {
    return PluginDefinition(
      id: json['id'] as String,
      platform: json['platform'] as String,
      version: json['version'] as String?,
      author: json['author'] as String?,
      description: json['description'] as String?,
      sourcePath: json['sourcePath'] as String,
      enabled: json['enabled'] as bool? ?? true,
      installedAt: DateTime.parse(json['installedAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      supportedSearchTypes:
          (json['supportedSearchTypes'] as List<dynamic>? ?? const <dynamic>[])
              .map((type) => type.toString())
              .toList(growable: false),
      userVariables:
          (json['userVariables'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (variable) => variable.map(
                  (key, value) => MapEntry(key.toString(), value as Object?),
                ),
              )
              .toList(growable: false),
      userVariableValues:
          (json['userVariableValues'] as Map<dynamic, dynamic>? ??
                  const <dynamic, dynamic>{})
              .map(
                (key, value) =>
                    MapEntry(key.toString(), value?.toString() ?? ''),
              ),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'platform': platform,
      'version': version,
      'author': author,
      'description': description,
      'sourcePath': sourcePath,
      'enabled': enabled,
      'installedAt': installedAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'supportedSearchTypes': supportedSearchTypes,
      'userVariables': userVariables,
      'userVariableValues': userVariableValues,
    };
  }
}
