import 'dart:io';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:robyne/core/database/app_database.dart';
import 'package:robyne/core/database/repositories/plugin_repository.dart';
import 'package:robyne/core/database/repositories/song_repository.dart';
import 'package:robyne/core/js_sandbox/sandbox_manager.dart';
import 'package:robyne/core/plugin/plugin_executor.dart';
import 'package:robyne/core/plugin/plugin_models.dart';
import 'package:robyne/shared/providers/database_provider.dart';

part 'plugin_manager.g.dart';

@Riverpod(keepAlive: true)
class PluginManager extends _$PluginManager {
  late PluginExecutor _executor;
  late PluginRepository _pluginRepo;
  late SongRepository _songRepo;

  @override
  PluginManagerState build() {
    _pluginRepo = ref.watch(pluginRepositoryProvider);
    _songRepo = ref.watch(songRepositoryProvider);

    final sandbox = ref.watch(sandboxManagerProvider.notifier);
    _executor = PluginExecutor(sandbox);

    _loadInstalledPlugins();

    return PluginManagerState.initial();
  }

  Future<void> _loadInstalledPlugins() async {
    final plugins = await _pluginRepo.getAllPlugins();
    state = state.copyWith(installedPlugins: plugins);
  }

  Future<PluginMetadata?> parsePluginMetadata(String jsCode, {String? filePath}) async {
    // Try standard metadata format with @name/@author/@version
    final metaRegex = RegExp(
      r'/\*\*[\s\S]*?@name\s+(.+?)[\s\S]*?@author\s+(.+?)[\s\S]*?@version\s+(.+?)[\s\S]*?\*/',
      caseSensitive: false,
    );

    final match = metaRegex.firstMatch(jsCode);
    if (match != null) {
      return PluginMetadata(
        name: match.group(1)!.trim(),
        author: match.group(2)!.trim(),
        version: match.group(3)!.trim(),
      );
    }

    // Try to detect if it's a valid MusicFree plugin (has module.exports with required methods)
    if (jsCode.contains('module.exports') &&
        (jsCode.contains('getMediaSource') || jsCode.contains('search'))) {
      // Extract name from filename or use default
      String pluginName = 'Unknown Plugin';
      if (filePath != null) {
        pluginName = filePath.split(RegExp(r'[/\\]')).last.replaceAll('.js', '');
      }

      return PluginMetadata(
        name: pluginName,
        author: 'MusicFree Community',
        version: '1.0.0',
      );
    }

    return null;
  }

  Future<int> installPlugin(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Plugin file not found: $filePath');
    }

    final jsCode = await file.readAsString();
    final metadata = await parsePluginMetadata(jsCode, filePath: filePath);

    if (metadata == null) {
      throw Exception('Invalid plugin format: missing metadata or invalid plugin structure');
    }

    final pluginId = await _pluginRepo.insertPlugin(PluginsCompanion(
      name: Value(metadata.name),
      author: Value(metadata.author),
      version: Value(metadata.version),
      localPath: Value(filePath),
      isEnabled: const Value(true),
    ));

    await _loadInstalledPlugins();
    return pluginId;
  }

  Future<void> uninstallPlugin(int pluginId) async {
    final plugin = await _pluginRepo.getPluginById(pluginId);
    if (plugin == null) return;

    ref.read(sandboxManagerProvider.notifier).unloadPlugin(plugin.name);
    await _pluginRepo.deletePlugin(pluginId);
    await _loadInstalledPlugins();
  }

  Future<void> enablePlugin(int pluginId) async {
    final plugin = await _pluginRepo.getPluginById(pluginId);
    if (plugin == null) return;

    await _pluginRepo.updatePlugin(PluginsCompanion(
      id: Value(pluginId),
      name: Value(plugin.name),
      author: Value(plugin.author),
      version: Value(plugin.version),
      localPath: Value(plugin.localPath),
      isEnabled: const Value(true),
    ));
    await _loadInstalledPlugins();
  }

  Future<void> disablePlugin(int pluginId) async {
    final plugin = await _pluginRepo.getPluginById(pluginId);
    if (plugin == null) return;

    ref.read(sandboxManagerProvider.notifier).unloadPlugin(plugin.name);
    await _pluginRepo.updatePlugin(PluginsCompanion(
      id: Value(pluginId),
      name: Value(plugin.name),
      author: Value(plugin.author),
      version: Value(plugin.version),
      localPath: Value(plugin.localPath),
      isEnabled: const Value(false),
    ));
    await _loadInstalledPlugins();
  }

  Future<void> loadPlugin(int pluginId) async {
    final plugin = await _pluginRepo.getPluginById(pluginId);
    if (plugin == null || !plugin.isEnabled) return;

    final file = File(plugin.localPath);
    if (!await file.exists()) return;

    final jsCode = await file.readAsString();
    await ref.read(sandboxManagerProvider.notifier).loadPlugin(
          jsCode,
          plugin.name,
        );
  }

  Future<List<SearchResult>> search(
    int pluginId,
    String query, {
    int page = 1,
    String type = 'song',
  }) async {
    final plugin = await _pluginRepo.getPluginById(pluginId);
    if (plugin == null || !plugin.isEnabled) return [];

    await loadPlugin(pluginId);
    return await _executor.search(plugin.name, query, page: page, type: type);
  }

  Future<MediaSource?> getMediaSource(
    int pluginId,
    Map<String, dynamic> musicItem,
  ) async {
    final plugin = await _pluginRepo.getPluginById(pluginId);
    if (plugin == null || !plugin.isEnabled) return null;

    await loadPlugin(pluginId);
    return await _executor.getMediaSource(plugin.name, musicItem);
  }

  Future<LyricResult?> getLyric(
    int pluginId,
    Map<String, dynamic> musicItem,
  ) async {
    final plugin = await _pluginRepo.getPluginById(pluginId);
    if (plugin == null || !plugin.isEnabled) return null;

    await loadPlugin(pluginId);
    return await _executor.getLyric(plugin.name, musicItem);
  }

  Future<void> saveSearchResults(
    List<SearchResult> results,
    int pluginId,
  ) async {
    final songs = results.map((r) => SongsCompanion(
      sourceId: Value(r.id),
      title: Value(r.title),
      artist: Value(r.artist),
      album: Value(r.album),
      coverUrl: Value(r.cover),
      durationMs: Value(r.duration),
      pluginId: Value(pluginId),
    )).toList();

    await _songRepo.insertSongs(songs);
  }
}

class PluginManagerState {
  final List<Plugin> installedPlugins;
  final bool isLoading;
  final String? error;

  const PluginManagerState({
    this.installedPlugins = const [],
    this.isLoading = false,
    this.error,
  });

  PluginManagerState copyWith({
    List<Plugin>? installedPlugins,
    bool? isLoading,
    String? error,
  }) {
    return PluginManagerState(
      installedPlugins: installedPlugins ?? this.installedPlugins,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  factory PluginManagerState.initial() => const PluginManagerState();
}
