import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/legacy_storage_migration.dart';
import '../../../core/network/plugin_http_client.dart';
import '../../../core/storage/local_file_store.dart';
import '../domain/plugin_definition.dart';
import '../domain/plugin_discovery_executor.dart';
import '../domain/plugin_repository.dart';
import '../domain/plugin_runtime.dart';
import '../domain/plugin_search_executor.dart';
import '../infrastructure/local_plugin_repository.dart';
import '../infrastructure/music_free_compat_adapter.dart';
import '../infrastructure/quickjs_plugin_runtime.dart';

final sharedPreferencesProvider = Provider<SharedPreferencesAsync?>((ref) {
  try {
    return SharedPreferencesAsync();
  } catch (_) {
    return null;
  }
});

final localFileStoreProvider = Provider<LocalFileStore>((ref) {
  return LocalFileStore();
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.open(ref.watch(localFileStoreProvider));
  ref.onDispose(database.close);
  return database;
});

final legacyStorageMigrationProvider = Provider<LegacyStorageMigration>((ref) {
  return LegacyStorageMigration(
    database: ref.watch(appDatabaseProvider),
    fileStore: ref.watch(localFileStoreProvider),
    preferences: ref.watch(sharedPreferencesProvider),
  );
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

final pluginSearchExecutorProvider = Provider<PluginSearchExecutor>((ref) {
  return QuickJsIsolatePluginSearchExecutor();
});

final pluginDiscoveryExecutorProvider = Provider<PluginDiscoveryExecutor>((
  ref,
) {
  return QuickJsIsolatePluginDiscoveryExecutor();
});

final pluginRepositoryProvider = Provider<PluginRepository>((ref) {
  return LocalPluginRepository(
    fileStore: ref.watch(localFileStoreProvider),
    database: ref.watch(appDatabaseProvider),
    preferences: ref.watch(sharedPreferencesProvider),
    legacyMigration: ref.watch(legacyStorageMigrationProvider),
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
