import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/plugin_http_client.dart';
import '../../../core/storage/local_file_store.dart';
import '../domain/plugin_definition.dart';
import '../domain/plugin_repository.dart';
import '../domain/plugin_runtime.dart';
import '../infrastructure/local_plugin_repository.dart';
import '../infrastructure/music_free_compat_adapter.dart';
import '../infrastructure/quickjs_plugin_runtime.dart';

final sharedPreferencesProvider = Provider<SharedPreferencesAsync>((ref) {
  return SharedPreferencesAsync();
});

final localFileStoreProvider = Provider<LocalFileStore>((ref) {
  return LocalFileStore();
});

final pluginHttpClientProvider = Provider<PluginHttpClient>((ref) {
  return PluginHttpClient();
});

final musicFreeCompatAdapterProvider = Provider<MusicFreeCompatAdapter>((ref) {
  return MusicFreeCompatAdapter();
});

final pluginRuntimeFactoryProvider = Provider<PluginRuntimeFactory>((ref) {
  return QuickJsPluginRuntimeFactory(
    httpClient: ref.watch(pluginHttpClientProvider),
  );
});

final pluginRepositoryProvider = Provider<PluginRepository>((ref) {
  return LocalPluginRepository(
    fileStore: ref.watch(localFileStoreProvider),
    preferences: ref.watch(sharedPreferencesProvider),
    runtimeFactory: ref.watch(pluginRuntimeFactoryProvider),
    compatAdapter: ref.watch(musicFreeCompatAdapterProvider),
  );
});

final installedPluginsProvider = FutureProvider<List<PluginDefinition>>((
  ref,
) async {
  final result = await ref.watch(pluginRepositoryProvider).listPlugins();
  return result.fold((plugins) => plugins, (error) => throw error);
});
