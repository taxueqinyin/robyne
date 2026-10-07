import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/result/result.dart';
import '../domain/plugin_definition.dart';
import '../domain/plugin_repository.dart';
import '../domain/plugin_sort.dart';
import 'plugin_providers.dart';

final pluginControllerProvider =
    AsyncNotifierProvider<PluginController, List<PluginDefinition>>(
      PluginController.new,
    );

final pluginImportProgressProvider =
    NotifierProvider<PluginImportProgressNotifier, PluginImportProgress?>(
      PluginImportProgressNotifier.new,
    );

/// The ordering the plugin page applies on top of the stored list.
///
/// Separate from [pluginControllerProvider] because sorting is a view
/// preference, not plugin data: changing it must not re-read the database or
/// disturb an import in flight, and it survives a refresh of the list.
final pluginSortOrderProvider =
    NotifierProvider<PluginSortOrderNotifier, PluginSortOrder>(
      PluginSortOrderNotifier.new,
    );

class PluginSortOrderNotifier extends Notifier<PluginSortOrder> {
  @override
  /// The user's own arrangement, which is what the plugin rows carry once a
  /// row has been dragged. Starting here rather than at [PluginSortOrder.added]
  /// means the page the user is looking at is the order discover and search
  /// will use too.
  PluginSortOrder build() => PluginSortOrder.manual;

  void set(PluginSortOrder order) => state = order;
}

/// The plugin list in the order the user arranged it.
///
/// Every surface that offers plugins as *sources* reads this instead of
/// [pluginControllerProvider], so dragging a row on the plugin page shows up
/// in the discover source row and the search result tabs. Derived from the
/// controller rather than from its own repository read: there is one cache of
/// installed plugins, and a second one would drift after an import.
final orderedPluginsProvider = Provider<List<PluginDefinition>>((ref) {
  final value = ref.watch(pluginControllerProvider);
  return sortPlugins(
    value.value ?? const <PluginDefinition>[],
    PluginSortOrder.manual,
  );
});

/// The subset of [orderedPluginsProvider] that can actually serve content.
final orderedEnabledPluginsProvider = Provider<List<PluginDefinition>>((ref) {
  return ref
      .watch(orderedPluginsProvider)
      .where((plugin) => plugin.enabled)
      .toList(growable: false);
});

class PluginImportProgressNotifier extends Notifier<PluginImportProgress?> {
  @override
  PluginImportProgress? build() => null;

  void setProgress(PluginImportProgress? progress) {
    state = progress;
  }
}

class PluginImportProgress {
  const PluginImportProgress({
    required this.total,
    required this.completed,
    required this.importedCount,
    required this.updatedCount,
    required this.skippedCount,
    required this.failedCount,
    this.currentLabel,
  });

  final int total;
  final int completed;
  final int importedCount;
  final int updatedCount;
  final int skippedCount;
  final int failedCount;
  final String? currentLabel;

  double? get fraction => total <= 0 ? null : completed / total;
}

class PluginController extends AsyncNotifier<List<PluginDefinition>> {
  @override
  Future<List<PluginDefinition>> build() async {
    final result = await ref.watch(pluginRepositoryProvider).listPlugins();
    return result.fold((plugins) => plugins, (error) => throw error);
  }

  Future<AppError?> importFromPath(String path) async {
    final repository = ref.read(pluginRepositoryProvider);
    final result = await repository.importPluginFromPath(path);
    return _refreshAfterImport(result, repository);
  }

  Future<PluginImportBatchResult> importFromPaths(List<String> paths) async {
    final repository = ref.read(pluginRepositoryProvider);
    final progress = ref.read(pluginImportProgressProvider.notifier);

    try {
      final result = await repository.importPluginsFromPaths(
        paths,
        onProgress: _forwardProgress(progress),
      );

      if (result.changedPlugins) {
        await _applyImportResult(result, repository);
      } else {
        _restorePreviousPlugins();
      }

      return result;
    } finally {
      progress.setProgress(null);
    }
  }

  Future<AppError?> importFromUrl(String url) async {
    final repository = ref.read(pluginRepositoryProvider);
    final result = await repository.importPluginFromUrl(url);
    return _refreshAfterImport(result, repository);
  }

  /// Imports every plugin reachable from [url].
  ///
  /// Plugins that landed are always published, even when some entries from a
  /// plugin list failed; per-entry failures are reported alongside them.
  Future<PluginImportBatchResult> importFromUrlBatch(String url) async {
    final repository = ref.read(pluginRepositoryProvider);
    final progress = ref.read(pluginImportProgressProvider.notifier);

    try {
      final result = await repository.importPluginBatchFromUrl(
        url,
        onProgress: _forwardProgress(progress),
      );
      await _applyImportResult(result, repository);
      return result;
    } finally {
      progress.setProgress(null);
    }
  }

  PluginImportProgressCallback _forwardProgress(
    PluginImportProgressNotifier progress,
  ) {
    DateTime? lastProgressAt;
    return (snapshot) {
      final now = DateTime.now();
      final shouldEmit =
          snapshot.completed == 0 ||
          snapshot.completed >= snapshot.total ||
          lastProgressAt == null ||
          now.difference(lastProgressAt!) >= const Duration(milliseconds: 100);
      if (!shouldEmit) {
        return;
      }
      lastProgressAt = now;
      progress.setProgress(
        PluginImportProgress(
          total: snapshot.total,
          completed: snapshot.completed,
          importedCount: snapshot.importedCount,
          updatedCount: snapshot.updatedCount,
          skippedCount: snapshot.skippedCount,
          failedCount: snapshot.failedCount,
          currentLabel: snapshot.currentLabel,
        ),
      );
    };
  }

  /// Publishes [result] whenever anything changed, tolerating partial failures.
  Future<void> _applyImportResult(
    PluginImportBatchResult result,
    PluginRepository repository,
  ) async {
    if (!result.changedPlugins) {
      _restorePreviousPlugins();
      return;
    }
    final refreshError = await _refreshPlugins(repository);
    if (refreshError == null) {
      ref.invalidate(installedPluginsProvider);
    }
  }

  Future<AppError?> _refreshAfterImport(
    Result<PluginDefinition> result,
    PluginRepository repository,
  ) async {
    return result.fold(
      (_) async {
        final error = await _refreshPlugins(repository);
        if (error == null) {
          ref.invalidate(installedPluginsProvider);
        }
        return error;
      },
      (error) {
        _restorePreviousPlugins();
        return error;
      },
    );
  }

  Future<void> setEnabled(String id, bool enabled) async {
    final repository = ref.read(pluginRepositoryProvider);
    final result = await repository.setEnabled(id, enabled);
    await _refreshAfterPluginUpdate(result, repository);
  }

  Future<void> updateUserVariableValues(
    String id,
    Map<String, String> values,
  ) async {
    final repository = ref.read(pluginRepositoryProvider);
    final result = await repository.updateUserVariableValues(id, values);
    await _refreshAfterPluginUpdate(result, repository);
  }

  /// Persists a drag-ordered list of plugin ids.
  ///
  /// The state is replaced with the repository's answer rather than with the
  /// reorder the caller computed, because the repository re-reads and applies
  /// the manual ordering — including any row the caller did not mention.
  Future<void> reorderPlugins(List<String> orderedIds) async {
    final repository = ref.read(pluginRepositoryProvider);
    // Captured before the optimistic update, so a failed write can put the
    // list back exactly where the user left it.
    final previous = state.value ?? const <PluginDefinition>[];
    // Paint the dragged order immediately: a drag is a direct manipulation,
    // and waiting for the write would make the row snap back before settling.
    state = AsyncData(applyPluginOrder(previous, orderedIds));
    final result = await repository.reorderPlugins(orderedIds);
    await result.fold(
      (plugins) async {
        state = AsyncData(plugins);
        ref.invalidate(installedPluginsProvider);
      },
      (error) async {
        state = AsyncData(previous);
      },
    );
  }

  Future<void> _refreshAfterPluginUpdate(
    Result<PluginDefinition> result,
    PluginRepository repository,
  ) async {
    await result.fold(
      (_) async {
        final error = await _refreshPlugins(repository);
        if (error == null) {
          ref.invalidate(installedPluginsProvider);
        }
      },
      (error) async {
        _restorePreviousPlugins();
      },
    );
  }

  Future<void> delete(String id) async {
    final repository = ref.read(pluginRepositoryProvider);
    final result = await repository.deletePlugin(id);
    await result.fold(
      (_) async {
        final error = await _refreshPlugins(repository);
        if (error == null) {
          ref.invalidate(installedPluginsProvider);
        }
      },
      (error) async {
        _restorePreviousPlugins();
      },
    );
  }

  void _restorePreviousPlugins() {
    final plugins = state.value ?? const <PluginDefinition>[];
    state = AsyncData(plugins);
  }

  Future<AppError?> _refreshPlugins(PluginRepository repository) async {
    final refreshed = await repository.listPlugins();
    return refreshed.fold(
      (plugins) {
        state = AsyncData(plugins);
        return null;
      },
      (error) {
        _restorePreviousPlugins();
        return error;
      },
    );
  }
}
