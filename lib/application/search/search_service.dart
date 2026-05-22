import 'package:robyne/shared/models/track.dart';
import 'package:robyne/core/plugin/plugin_registry.dart';
import 'package:robyne/core/plugin/plugin_protocol.dart';
import 'package:logging/logging.dart';

final _log = Logger('SearchService');

/// 搜索应用服务 - 编排多插件搜索
class SearchService {
  final PluginRegistry _registry;

  SearchService(this._registry);

  /// 在所有已启用的插件中搜索
  ///
  /// 返回 `Map<String, List<RemoteTrack>>`，单个插件搜索失败不影响其他插件
  Future<Map<String, List<RemoteTrack>>> searchAll(String keyword) async {
    if (keyword.trim().isEmpty) {
      _log.warning('Search keyword is empty, returning empty results');
      return {};
    }

    final enabledPlugins = _registry.enabled;
    if (enabledPlugins.isEmpty) {
      _log.info('No enabled plugins, returning empty results');
      return {};
    }

    _log.info('Searching "$keyword" across ${enabledPlugins.length} plugins');

    final results = <String, List<RemoteTrack>>{};
    final futures = <Future<void>>[];

    for (final plugin in enabledPlugins) {
      futures.add(_searchPluginSafe(plugin, keyword, results));
    }

    await Future.wait(futures);

    final total = results.values.fold<int>(0, (sum, list) => sum + list.length);
    _log.info('Search completed: $total results from ${results.length} plugins');

    return results;
  }

  /// 在指定插件中搜索
  Future<List<RemoteTrack>> searchPlugin(String pluginId, String keyword) async {
    if (keyword.trim().isEmpty) {
      _log.warning('Search keyword is empty');
      return [];
    }

    final plugin = _registry.get(pluginId);
    if (plugin == null) {
      _log.warning('Plugin not found: $pluginId');
      throw Exception('Plugin not found: $pluginId');
    }

    _log.info('Searching "$keyword" in plugin ${plugin.meta.name} ($pluginId)');

    try {
      final results = await plugin.search(keyword);
      _log.info('Plugin $pluginId returned ${results.length} results');
      return results;
    } catch (e) {
      _log.warning('Search failed in plugin $pluginId: $e');
      rethrow;
    }
  }

  /// 安全搜索单个插件，捕获异常避免影响其他插件
  Future<void> _searchPluginSafe(
    MusicSourcePlugin plugin,
    String keyword,
    Map<String, List<RemoteTrack>> results,
  ) async {
    try {
      final tracks = await plugin.search(keyword);
      results[plugin.meta.id] = tracks;
    } catch (e) {
      _log.warning(
        'Search failed in plugin ${plugin.meta.name} (${plugin.meta.id}): $e',
      );
      // 单个插件失败时放入空列表，保持 key 存在以标识该插件已尝试
      results[plugin.meta.id] = [];
    }
  }
}
