import 'package:freezed_annotation/freezed_annotation.dart';

part 'plugin_model.freezed.dart';
part 'plugin_model.g.dart';

@freezed
class PluginModel with _$PluginModel {
  const factory PluginModel({
    required int id,
    required String name,
    required String author,
    required String version,
    required String localPath,
    String? subscriptionUrl,
    @Default(true) bool isEnabled,
    required DateTime installedAt,
  }) = _PluginModel;

  factory PluginModel.fromJson(Map<String, dynamic> json) =>
      _$PluginModelFromJson(json);
}
