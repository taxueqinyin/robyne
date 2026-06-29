import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/result/result.dart';
import '../../plugin/application/plugin_providers.dart';
import '../../plugin/domain/plugin_definition.dart';
import '../domain/music_item.dart';
import '../domain/search_result.dart';

final searchControllerProvider =
    AsyncNotifierProvider<SearchController, SearchState>(SearchController.new);

class SearchState {
  const SearchState({
    this.keyword = '',
    this.selectedPluginId,
    this.pluginResults = const <PluginSearchState>[],
    this.error,
    this.isSearching = false,
  });

  final String keyword;
  final String? selectedPluginId;
  final List<PluginSearchState> pluginResults;
  final AppError? error;
  final bool isSearching;

  PluginSearchState? get selectedPluginResult {
    if (pluginResults.isEmpty) {
      return null;
    }
    for (final result in pluginResults) {
      if (result.pluginId == selectedPluginId) {
        return result;
      }
    }
    return pluginResults.first;
  }

  SearchState copyWith({
    String? keyword,
    String? selectedPluginId,
    List<PluginSearchState>? pluginResults,
    AppError? error,
    bool? isSearching,
    bool clearError = false,
  }) {
    return SearchState(
      keyword: keyword ?? this.keyword,
      selectedPluginId: selectedPluginId ?? this.selectedPluginId,
      pluginResults: pluginResults ?? this.pluginResults,
      error: clearError ? null : error ?? this.error,
      isSearching: isSearching ?? this.isSearching,
    );
  }
}

class PluginSearchState {
  const PluginSearchState({
    required this.pluginId,
    required this.platform,
    this.result,
    this.error,
    this.isSearching = false,
    this.isLoadingMore = false,
  });

  final String pluginId;
  final String platform;
  final SearchResult? result;
  final AppError? error;
  final bool isSearching;
  final bool isLoadingMore;

  int get resultCount => result?.items.length ?? 0;

  PluginSearchState copyWith({
    SearchResult? result,
    AppError? error,
    bool? isSearching,
    bool? isLoadingMore,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return PluginSearchState(
      pluginId: pluginId,
      platform: platform,
      result: clearResult ? null : result ?? this.result,
      error: clearError ? null : error ?? this.error,
      isSearching: isSearching ?? this.isSearching,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class SearchController extends AsyncNotifier<SearchState> {
  static const _maxConcurrentSearches = 3;
  int _searchGeneration = 0;

  @override
  SearchState build() => const SearchState();

  void selectPlugin(String id) {
    state = AsyncData(
      (state.value ?? const SearchState()).copyWith(
        selectedPluginId: id,
        clearError: true,
      ),
    );
  }

  void updateKeyword(String keyword) {
    state = AsyncData(
      (state.value ?? const SearchState()).copyWith(
        keyword: keyword,
        clearError: true,
      ),
    );
  }

  Future<void> search(List<PluginDefinition> plugins) async {
    final current = state.value ?? const SearchState();
    if (current.isSearching) {
      return;
    }

    final keyword = current.keyword.trim();
    if (keyword.isEmpty) {
      state = AsyncData(
        current.copyWith(
          error: const AppError(
            code: 'search.empty_keyword',
            message: 'Enter a keyword before searching.',
          ),
        ),
      );
      return;
    }

    final enabledPlugins = plugins.where((plugin) => plugin.enabled).toList();
    if (enabledPlugins.isEmpty) {
      state = AsyncData(
        current.copyWith(
          error: const AppError(
            code: 'plugin.not_found',
            message: 'Enable at least one plugin before searching.',
          ),
        ),
      );
      return;
    }

    final generation = _searchGeneration + 1;
    _searchGeneration = generation;
    final selectedPluginId =
        enabledPlugins.any((plugin) => plugin.id == current.selectedPluginId)
        ? current.selectedPluginId
        : enabledPlugins.first.id;
    final initialResults = enabledPlugins
        .map(
          (plugin) => PluginSearchState(
            pluginId: plugin.id,
            platform: plugin.platform,
            isSearching: true,
          ),
        )
        .toList(growable: false);

    state = AsyncData(
      current.copyWith(
        selectedPluginId: selectedPluginId,
        pluginResults: initialResults,
        isSearching: true,
        clearError: true,
      ),
    );

    await _searchPluginsLimited(generation, enabledPlugins, keyword);

    if (_searchGeneration == generation) {
      state = AsyncData(
        (state.value ?? const SearchState()).copyWith(isSearching: false),
      );
    }
  }

  Future<void> _searchPluginsLimited(
    int generation,
    List<PluginDefinition> plugins,
    String keyword,
  ) async {
    var nextIndex = 0;
    final workerCount = plugins.length < _maxConcurrentSearches
        ? plugins.length
        : _maxConcurrentSearches;
    Future<void> worker() async {
      while (_searchGeneration == generation) {
        final index = nextIndex;
        nextIndex += 1;
        if (index >= plugins.length) {
          return;
        }
        await Future<void>.delayed(Duration.zero);
        final result = await _searchPlugin(plugins[index], keyword, 1);
        if (_searchGeneration == generation) {
          _replacePluginResult(result);
        }
        await Future<void>.delayed(Duration.zero);
      }
    }

    await Future.wait<void>(
      List<Future<void>>.generate(workerCount, (_) => worker()),
    );
  }

  Future<void> loadMoreSelected(List<PluginDefinition> plugins) async {
    final current = state.value ?? const SearchState();
    final pluginResult = current.selectedPluginResult;
    final result = pluginResult?.result;
    if (pluginResult == null ||
        result == null ||
        result.isEnd ||
        pluginResult.isSearching ||
        pluginResult.isLoadingMore) {
      return;
    }

    final keyword = current.keyword.trim();
    if (keyword.isEmpty) {
      return;
    }

    PluginDefinition? selectedPlugin;
    for (final plugin in plugins) {
      if (plugin.enabled && plugin.id == pluginResult.pluginId) {
        selectedPlugin = plugin;
        break;
      }
    }
    if (selectedPlugin == null) {
      _replacePluginResult(
        pluginResult.copyWith(
          error: const AppError(
            code: 'plugin.not_found',
            message: 'Selected plugin is no longer enabled.',
          ),
          isLoadingMore: false,
        ),
      );
      return;
    }

    final generation = _searchGeneration;
    _replacePluginResult(
      pluginResult.copyWith(isLoadingMore: true, clearError: true),
    );

    final nextPage = result.page + 1;
    final nextResult = await _searchPlugin(selectedPlugin, keyword, nextPage);
    if (_searchGeneration != generation) {
      return;
    }

    final latest = _pluginResultById(selectedPlugin.id);
    if (latest == null) {
      return;
    }

    if (nextResult.error != null) {
      _replacePluginResult(
        latest.copyWith(error: nextResult.error, isLoadingMore: false),
      );
      return;
    }

    final loaded = nextResult.result;
    if (loaded == null) {
      _replacePluginResult(
        latest.copyWith(isLoadingMore: false, clearError: true),
      );
      return;
    }

    final previous = latest.result ?? result;
    _replacePluginResult(
      latest.copyWith(
        result: SearchResult(
          items: <MusicItem>[...previous.items, ...loaded.items],
          page: loaded.page,
          isEnd: loaded.isEnd,
          raw: loaded.raw,
        ),
        isLoadingMore: false,
        clearError: true,
      ),
    );
  }

  Future<PluginSearchState> _searchPlugin(
    PluginDefinition plugin,
    String keyword,
    int page,
  ) async {
    final executor = ref.read(pluginSearchExecutorProvider);
    final compat = ref.read(musicFreeCompatAdapterProvider);
    try {
      final source = await File(plugin.sourcePath).readAsString();
      final searchResult = await executor.search(
        plugin: plugin,
        source: source,
        keyword: keyword,
        page: page,
        searchType: 'music',
      );
      switch (searchResult) {
        case Ok<Object?>(:final value):
          final adapted = compat.searchResultFromPluginValue(
            value,
            pluginId: plugin.id,
            platform: plugin.platform,
            page: page,
          );
          return adapted.fold(
            (result) => PluginSearchState(
              pluginId: plugin.id,
              platform: plugin.platform,
              result: result,
            ),
            (error) => PluginSearchState(
              pluginId: plugin.id,
              platform: plugin.platform,
              error: error,
            ),
          );
        case Failure<Object?>(:final error):
          return PluginSearchState(
            pluginId: plugin.id,
            platform: plugin.platform,
            error: error,
          );
      }
    } catch (error, stackTrace) {
      return PluginSearchState(
        pluginId: plugin.id,
        platform: plugin.platform,
        error: AppError(
          code: 'search.failed',
          message: 'Plugin ${plugin.platform} search failed.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  PluginSearchState? _pluginResultById(String pluginId) {
    final current = state.value ?? const SearchState();
    for (final pluginResult in current.pluginResults) {
      if (pluginResult.pluginId == pluginId) {
        return pluginResult;
      }
    }
    return null;
  }

  void _replacePluginResult(PluginSearchState result) {
    final current = state.value ?? const SearchState();
    final updated = current.pluginResults
        .map(
          (existing) =>
              existing.pluginId == result.pluginId ? result : existing,
        )
        .toList(growable: false);
    state = AsyncData(
      current.copyWith(
        pluginResults: updated,
        isSearching: updated.any((pluginResult) => pluginResult.isSearching),
        clearError: true,
      ),
    );
  }
}
