import 'package:drift/drift.dart';
import 'package:robyne/core/database/app_database.dart';
import 'package:robyne/core/database/tables/plugins.dart';

part 'plugin_repository.g.dart';

@DriftAccessor(tables: [Plugins])
class PluginRepository extends DatabaseAccessor<AppDatabase>
    with _$PluginRepositoryMixin {
  PluginRepository(super.db);

  Future<List<Plugin>> getAllPlugins() => select(plugins).get();

  Stream<List<Plugin>> watchAllPlugins() => select(plugins).watch();

  Future<Plugin?> getPluginById(int id) =>
      (select(plugins)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertPlugin(PluginsCompanion plugin) =>
      into(plugins).insert(plugin);

  Future<bool> updatePlugin(PluginsCompanion plugin) =>
      update(plugins).replace(plugin);

  Future<int> deletePlugin(int id) =>
      (delete(plugins)..where((t) => t.id.equals(id))).go();

  Future<List<Plugin>> getEnabledPlugins() =>
      (select(plugins)..where((t) => t.isEnabled.equals(true))).get();

  Stream<List<Plugin>> watchEnabledPlugins() =>
      (select(plugins)..where((t) => t.isEnabled.equals(true))).watch();
}
