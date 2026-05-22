import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robyne/core/runtime/js_runtime.dart';
import 'package:robyne/core/runtime/runtime_bridge.dart';
import 'package:robyne/core/plugin/plugin_registry.dart';
import 'package:robyne/core/plugin/plugin_executor.dart';
import 'package:robyne/core/plugin/plugin_protocol.dart';
import 'package:robyne/core/audio/audio_player_service.dart';
import 'package:robyne/core/metadata/local_scanner.dart';
import 'package:robyne/application/search/search_service.dart';
import 'package:robyne/application/plugin/plugin_service.dart';
import 'package:robyne/application/playback/playback_service.dart';
import 'package:robyne/application/local_music/local_music_service.dart';
import 'package:robyne/shared/models/track.dart';
import 'package:robyne/core/audio/playback_state.dart';

// Core singletons - created once, not managed by Riverpod
final _jsRuntime = JsRuntime();
final _registry = PluginRegistry();

// Core providers - just expose
final jsRuntimeProvider = Provider<JsRuntime>((ref) => _jsRuntime);
final registryProvider = Provider<PluginRegistry>((ref) => _registry);

final runtimeBridgeProvider = Provider<RuntimeBridge>((ref) {
  return RuntimeBridge(_jsRuntime);
});

final pluginExecutorProvider = Provider<PluginExecutor>((ref) {
  final bridge = ref.watch(runtimeBridgeProvider);
  return PluginExecutor(runtime: bridge.runtime, registry: _registry);
});

final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  return AudioPlayerService();
});

final localScannerProvider = Provider<LocalScanner>((ref) {
  return LocalScanner();
});

// Application service providers
final pluginServiceProvider = Provider<PluginService>((ref) {
  final executor = ref.watch(pluginExecutorProvider);
  return PluginService(executor, _registry);
});

final searchServiceProvider = Provider<SearchService>((ref) {
  return SearchService(_registry);
});

final playbackServiceProvider = Provider<PlaybackService>((ref) {
  final audioService = ref.watch(audioPlayerServiceProvider);
  return PlaybackService(audioService, _registry);
});

final localMusicServiceProvider = Provider<LocalMusicService>((ref) {
  final scanner = ref.watch(localScannerProvider);
  return LocalMusicService(scanner);
});

// ViewState providers - UI only listens to these
final playbackStateProvider = StreamProvider<PlaybackState>((ref) {
  final service = ref.watch(playbackServiceProvider);
  return service.stateStream;
});

// Search state
final searchResultsProvider = StateNotifierProvider<SearchResultsNotifier, AsyncValue<Map<String, List<RemoteTrack>>>>((ref) {
  return SearchResultsNotifier(ref.watch(searchServiceProvider));
});

class SearchResultsNotifier extends StateNotifier<AsyncValue<Map<String, List<RemoteTrack>>>> {
  final SearchService _service;

  SearchResultsNotifier(this._service) : super(const AsyncValue.data({}));

  Future<void> search(String keyword) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _service.searchAll(keyword));
  }

  void clear() {
    state = const AsyncValue.data({});
  }
}

// Plugin list state
final pluginListProvider = StateNotifierProvider<PluginListNotifier, List<MusicSourcePlugin>>((ref) {
  return PluginListNotifier(ref.watch(pluginServiceProvider));
});

class PluginListNotifier extends StateNotifier<List<MusicSourcePlugin>> {
  final PluginService _service;

  PluginListNotifier(this._service) : super([]);

  Future<void> loadPlugin(String sourceCode, String sourcePath) async {
    await _service.loadPlugin(sourceCode, sourcePath);
    state = _service.plugins;
  }

  Future<void> unloadPlugin(String pluginId) async {
    await _service.unloadPlugin(pluginId);
    state = _service.plugins;
  }

  void refresh() {
    state = _service.plugins;
  }
}

// Local tracks state
final localTracksProvider = StateNotifierProvider<LocalTracksNotifier, List<LocalTrack>>((ref) {
  return LocalTracksNotifier(ref.watch(localMusicServiceProvider));
});

class LocalTracksNotifier extends StateNotifier<List<LocalTrack>> {
  final LocalMusicService _service;

  LocalTracksNotifier(this._service) : super([]);

  Future<void> scan(String path) async {
    state = await _service.scanDirectory(path);
  }
}
