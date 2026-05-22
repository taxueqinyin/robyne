import 'package:robyne/core/plugin/plugin_executor.dart';
import 'package:robyne/core/plugin/plugin_registry.dart';
import 'package:robyne/core/plugin/plugin_protocol.dart';
import 'package:logging/logging.dart';

final _log = Logger('PluginService');

/// 插件管理应用服务 - 提供插件的加载、卸载、查询等操作
class PluginService {
  final PluginExecutor _executor;
  final PluginRegistry _registry;

  PluginService(this._executor, this._registry);

  /// 从文件内容加载插件
  Future<MusicSourcePlugin> loadPlugin(String sourceCode, String sourcePath) async {
    _log.info('Loading plugin from: $sourcePath');

    try {
      final plugin = await _executor.loadPlugin(sourceCode, sourcePath);
      _log.info('Plugin loaded successfully: ${plugin.meta.name} (${plugin.meta.id})');
      return plugin;
    } catch (e) {
      _log.severe('Failed to load plugin from $sourcePath: $e');
      rethrow;
    }
  }

  /// 卸载插件
  Future<void> unloadPlugin(String pluginId) async {
    _log.info('Unloading plugin: $pluginId');

    if (!_registry.contains(pluginId)) {
      _log.warning('Plugin $pluginId not found, cannot unload');
      throw Exception('Plugin not found: $pluginId');
    }

    try {
      await _executor.unloadPlugin(pluginId);
      _log.info('Plugin unloaded: $pluginId');
    } catch (e) {
      _log.severe('Failed to unload plugin $pluginId: $e');
      rethrow;
    }
  }

  /// 获取所有已注册插件
  List<MusicSourcePlugin> get plugins => _registry.all;

  /// 根据 ID 获取插件
  MusicSourcePlugin? getPlugin(String pluginId) => _registry.get(pluginId);
}
