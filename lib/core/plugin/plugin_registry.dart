import 'package:robyne/core/plugin/plugin_models.dart';
import 'package:robyne/core/plugin/plugin_protocol.dart';
import 'package:logging/logging.dart';

final _log = Logger('PluginRegistry');

/// 插件注册表 - 管理已加载的插件，单例模式
class PluginRegistry {
  static final PluginRegistry _instance = PluginRegistry._internal();

  factory PluginRegistry() => _instance;

  PluginRegistry._internal();

  final Map<String, MusicSourcePlugin> _plugins = {};

  /// 注册插件
  void register(MusicSourcePlugin plugin) {
    final id = plugin.meta.id;
    if (_plugins.containsKey(id)) {
      _log.warning('Plugin "$id" already registered, will be replaced');
    }
    _plugins[id] = plugin;
    _log.info('Plugin registered: ${plugin.meta.name} ($id)');
  }

  /// 注销插件
  void unregister(String pluginId) {
    if (_plugins.remove(pluginId) != null) {
      _log.info('Plugin unregistered: $pluginId');
    } else {
      _log.warning('Plugin "$pluginId" not found, cannot unregister');
    }
  }

  /// 获取指定插件
  MusicSourcePlugin? get(String pluginId) => _plugins[pluginId];

  /// 所有已注册插件
  List<MusicSourcePlugin> get all => _plugins.values.toList();

  /// 所有已启用的插件（状态为 enabled）
  List<MusicSourcePlugin> get enabled => _plugins.values
      .where((p) => p is PluginInstanceHolder && p.status == PluginStatus.enabled)
      .toList();

  /// 是否包含指定插件
  bool contains(String pluginId) => _plugins.containsKey(pluginId);

  /// 清空所有插件
  void clear() {
    _plugins.clear();
    _log.info('All plugins cleared');
  }
}

/// 扩展接口：持有 PluginInstance 状态的插件
mixin PluginInstanceHolder on MusicSourcePlugin {
  PluginStatus get status;
  set status(PluginStatus value);
  String? get errorMessage;
  set errorMessage(String? value);
  String get sourcePath;
}
