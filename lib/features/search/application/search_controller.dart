import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/result/result.dart';
import '../../plugin/application/plugin_providers.dart';
import '../../plugin/domain/plugin_definition.dart';
import '../domain/search_result.dart';

final searchControllerProvider =
    AsyncNotifierProvider<SearchController, SearchState>(SearchController.new);

class SearchState {
  const SearchState({
    this.keyword = '',
    this.selectedPluginId,
    this.result,
    this.error,
    this.isSearching = false,
  });

  final String keyword;
  final String? selectedPluginId;
  final SearchResult? result;
  final AppError? error;
  final bool isSearching;

  SearchState copyWith({
    String? keyword,
    String? selectedPluginId,
    SearchResult? result,
    AppError? error,
    bool? isSearching,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return SearchState(
      keyword: keyword ?? this.keyword,
      selectedPluginId: selectedPluginId ?? this.selectedPluginId,
      result: clearResult ? null : result ?? this.result,
      error: clearError ? null : error ?? this.error,
      isSearching: isSearching ?? this.isSearching,
    );
  }
}

class SearchController extends AsyncNotifier<SearchState> {
  @override
  SearchState build() => const SearchState();

  void selectPlugin(String? id) {
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

    final selectedPlugin = _selectedPlugin(current, plugins);
    if (selectedPlugin == null) {
      state = AsyncData(
        current.copyWith(
          error: const AppError(
            code: 'plugin.not_found',
            message: 'Choose an enabled plugin before searching.',
          ),
        ),
      );
      return;
    }

    state = AsyncData(
      current.copyWith(
        selectedPluginId: selectedPlugin.id,
        isSearching: true,
        clearError: true,
      ),
    );

    final runtimeFactory = ref.read(pluginRuntimeFactoryProvider);
    final compat = ref.read(musicFreeCompatAdapterProvider);
    final runtime = await runtimeFactory.create();
    try {
      final source = await File(selectedPlugin.sourcePath).readAsString();
      final loaded = await runtime.loadPlugin(source);
      if (loaded case Failure<Map<String, Object?>>(:final error)) {
        state = AsyncData(current.copyWith(error: error, isSearching: false));
        return;
      }

      final searchResult = await runtime.callMethod('search', <Object?>[
        keyword,
        1,
        'music',
      ], timeout: const Duration(seconds: 15));
      switch (searchResult) {
        case Ok<Object?>(:final value):
          final adapted = compat.searchResultFromPluginValue(
            value,
            platform: selectedPlugin.platform,
            page: 1,
          );
          state = AsyncData(
            adapted.fold(
              (result) => (state.value ?? current).copyWith(
                result: result,
                isSearching: false,
                clearError: true,
              ),
              (error) => (state.value ?? current).copyWith(
                error: error,
                isSearching: false,
              ),
            ),
          );
        case Failure<Object?>(:final error):
          state = AsyncData(
            (state.value ?? current).copyWith(error: error, isSearching: false),
          );
      }
    } finally {
      await runtime.dispose();
    }
  }

  PluginDefinition? _selectedPlugin(
    SearchState state,
    List<PluginDefinition> plugins,
  ) {
    final enabledPlugins = plugins.where((plugin) => plugin.enabled).toList();
    if (enabledPlugins.isEmpty) {
      return null;
    }
    return enabledPlugins.cast<PluginDefinition?>().firstWhere(
      (plugin) => plugin?.id == state.selectedPluginId,
      orElse: () => enabledPlugins.first,
    );
  }
}
