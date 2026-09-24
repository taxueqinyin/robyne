import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/application/theme_providers.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/result/result.dart';
import '../../player/application/player_providers.dart';
import '../../player/domain/playback_item.dart';
import '../../plugin/application/plugin_providers.dart';
import '../../plugin/application/plugin_runtime_config.dart';
import '../../plugin/domain/plugin_definition.dart';
import '../../plugin/domain/plugin_runtime.dart';
import '../../settings/domain/lyric_settings.dart';
import '../../settings/application/settings_providers.dart';
import '../../settings/domain/shortcut_action.dart';
import 'desktop_lyric_theme_service.dart';
import 'desktop_lyric_window_controller.dart';
import '../domain/lyric_document.dart';
import '../infrastructure/lyric_repository.dart';

final lyricRepositoryProvider = Provider<LyricRepository>((ref) {
  return LyricRepository(
    database: ref.watch(appDatabaseProvider),
    legacyMigration: ref.watch(legacyStorageMigrationProvider),
  );
});

final currentPlaybackItemProvider = Provider<PlaybackItem?>((ref) {
  return ref.watch(
    playerControllerProvider.select((value) => value.value?.currentItem),
  );
});

final currentPlaybackPositionProvider = Provider<Duration>((ref) {
  final snapshot = ref.watch(playerSnapshotsProvider).value;
  if (snapshot?.currentSource != null) {
    return snapshot!.position;
  }
  return ref.watch(
    playerControllerProvider.select(
      (value) => value.value?.lastPosition ?? Duration.zero,
    ),
  );
});

final storedCurrentLyricsProvider = FutureProvider<LyricDocument?>((ref) async {
  final item = ref.watch(currentPlaybackItemProvider);
  if (item == null) {
    return null;
  }
  return ref.watch(lyricRepositoryProvider).loadForItem(item);
});

final lyricLiveOffsetProvider =
    NotifierProvider.family<LyricLiveOffsetNotifier, Duration?, String>(
      LyricLiveOffsetNotifier.new,
    );

class LyricLiveOffsetNotifier extends Notifier<Duration?> {
  LyricLiveOffsetNotifier(String _);

  @override
  Duration? build() => null;

  void setOffset(Duration? offset) {
    state = offset;
  }
}

final currentLyricsProvider = Provider<AsyncValue<LyricDocument?>>((ref) {
  final item = ref.watch(currentPlaybackItemProvider);
  if (item == null) {
    return const AsyncData(null);
  }
  final lyrics = ref.watch(storedCurrentLyricsProvider);
  final liveOffset = ref.watch(lyricLiveOffsetProvider(item.id));
  if (liveOffset == null) {
    return lyrics;
  }
  return lyrics.whenData((document) => document?.copyWith(offset: liveOffset));
});

final desktopLyricThemeProvider = FutureProvider<DesktopLyricTheme>((
  ref,
) async {
  final artworkUrl = ref.watch(currentPlaybackItemProvider)?.artworkUrl;
  return ref.read(desktopLyricThemeServiceProvider).resolve(artworkUrl);
});

final currentDesktopLyricPayloadProvider = Provider<DesktopLyricPayload>((ref) {
  final item = ref.watch(currentPlaybackItemProvider);
  // With artwork the lyric window follows the cover art; without it, fall
  // back to the active skin so the window never looks unrelated to the app.
  final theme =
      ref.watch(desktopLyricThemeProvider).value ??
      DesktopLyricTheme.fromTokens(ref.watch(activeThemeTokensProvider));
  final userSettings = ref.watch(settingsControllerProvider).value;
  final lyricSettings =
      userSettings?.lyricSettings ?? const LyricSettings.defaults();
  final toggleBinding = userSettings?.shortcuts[ShortcutAction.desktopLyrics];
  final isPlaying = ref.watch(playerSnapshotsProvider).value?.playing ?? false;
  if (item == null) {
    return DesktopLyricPayload(
      title: 'Robyne',
      lyric: '未在播放',
      nextLyric: '',
      subtitle: '',
      theme: theme,
      lyricSettings: lyricSettings,
      isPlaying: isPlaying,
      toggleBinding: toggleBinding,
    );
  }
  final lyrics = ref.watch(currentLyricsProvider).value;
  if (lyrics == null || lyrics.lines.isEmpty) {
    return DesktopLyricPayload(
      title: item.title,
      lyric: '暂无歌词',
      nextLyric: '',
      subtitle: _desktopLyricSubtitle(item),
      theme: theme,
      lyricSettings: lyricSettings,
      isPlaying: isPlaying,
      toggleBinding: toggleBinding,
    );
  }
  final index = lyrics.activeIndex(ref.watch(currentPlaybackPositionProvider));
  final lyricText = index >= 0 ? lyrics.lines[index].text.trim() : '等待歌词...';
  final nextLyricText = _desktopNextLyric(lyrics, index);
  return DesktopLyricPayload(
    title: item.title,
    lyric: lyricText.isEmpty ? '...' : lyricText,
    nextLyric: nextLyricText,
    subtitle: _desktopLyricSubtitle(item),
    theme: theme,
    lyricSettings: lyricSettings,
    isPlaying: isPlaying,
    toggleBinding: toggleBinding,
  );
});

final lyricSearchControllerProvider =
    AsyncNotifierProvider<LyricSearchController, LyricSearchState>(
      LyricSearchController.new,
    );

class LyricSearchState {
  const LyricSearchState({
    this.keyword = '',
    this.selectedPluginId,
    this.pluginResults = const <LyricPluginSearchState>[],
    this.error,
    this.isSearching = false,
    this.isAssociating = false,
  });

  final String keyword;
  final String? selectedPluginId;
  final List<LyricPluginSearchState> pluginResults;
  final AppError? error;
  final bool isSearching;
  final bool isAssociating;

  LyricPluginSearchState? get selectedPluginResult {
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

  LyricSearchState copyWith({
    String? keyword,
    String? selectedPluginId,
    List<LyricPluginSearchState>? pluginResults,
    AppError? error,
    bool? isSearching,
    bool? isAssociating,
    bool clearError = false,
  }) {
    return LyricSearchState(
      keyword: keyword ?? this.keyword,
      selectedPluginId: selectedPluginId ?? this.selectedPluginId,
      pluginResults: pluginResults ?? this.pluginResults,
      error: clearError ? null : error ?? this.error,
      isSearching: isSearching ?? this.isSearching,
      isAssociating: isAssociating ?? this.isAssociating,
    );
  }
}

class LyricPluginSearchState {
  const LyricPluginSearchState({
    required this.pluginId,
    required this.platform,
    this.items = const <LyricSearchCandidate>[],
    this.error,
    this.isSearching = false,
  });

  final String pluginId;
  final String platform;
  final List<LyricSearchCandidate> items;
  final AppError? error;
  final bool isSearching;

  LyricPluginSearchState copyWith({
    List<LyricSearchCandidate>? items,
    AppError? error,
    bool? isSearching,
    bool clearError = false,
  }) {
    return LyricPluginSearchState(
      pluginId: pluginId,
      platform: platform,
      items: items ?? this.items,
      error: clearError ? null : error ?? this.error,
      isSearching: isSearching ?? this.isSearching,
    );
  }
}

class LyricSearchCandidate {
  const LyricSearchCandidate({
    required this.pluginId,
    required this.platform,
    required this.title,
    required this.raw,
    this.artist,
    this.album,
  });

  final String pluginId;
  final String platform;
  final String title;
  final String? artist;
  final String? album;
  final Map<String, Object?> raw;
}

class LyricSearchController extends AsyncNotifier<LyricSearchState> {
  static const _maxConcurrentSearches = 3;
  int _generation = 0;

  @override
  LyricSearchState build() => const LyricSearchState();

  void selectPlugin(String id) {
    state = AsyncData(
      (state.value ?? const LyricSearchState()).copyWith(
        selectedPluginId: id,
        clearError: true,
      ),
    );
  }

  void updateKeyword(String keyword) {
    state = AsyncData(
      (state.value ?? const LyricSearchState()).copyWith(
        keyword: keyword,
        clearError: true,
      ),
    );
  }

  void cancel() {
    final current = state.value ?? const LyricSearchState();
    if (!current.isSearching) {
      return;
    }

    _generation += 1;
    final updated = current.pluginResults
        .map((result) {
          if (!result.isSearching) {
            return result;
          }
          return result.copyWith(
            isSearching: false,
            error: const AppError(
              code: 'lyric.search_cancelled',
              message: 'Search stopped.',
            ),
          );
        })
        .toList(growable: false);
    state = AsyncData(
      current.copyWith(
        pluginResults: updated,
        isSearching: false,
        clearError: true,
      ),
    );
  }

  Future<void> search(String keyword, List<PluginDefinition> plugins) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      state = AsyncData(
        (state.value ?? const LyricSearchState()).copyWith(
          error: const AppError(
            code: 'lyric.empty_keyword',
            message: 'Enter a keyword before searching lyrics.',
          ),
        ),
      );
      return;
    }

    final lyricPlugins = plugins
        .where(
          (plugin) =>
              plugin.enabled && plugin.supportedSearchTypes.contains('lyric'),
        )
        .toList(growable: false);
    if (lyricPlugins.isEmpty) {
      state = AsyncData(
        (state.value ?? const LyricSearchState()).copyWith(
          keyword: trimmed,
          error: const AppError(
            code: 'lyric.plugin_not_found',
            message: 'Enable at least one lyric plugin before searching.',
          ),
        ),
      );
      return;
    }

    final generation = _generation + 1;
    _generation = generation;
    state = AsyncData(
      LyricSearchState(
        keyword: trimmed,
        selectedPluginId: lyricPlugins.first.id,
        isSearching: true,
        pluginResults: lyricPlugins
            .map(
              (plugin) => LyricPluginSearchState(
                pluginId: plugin.id,
                platform: plugin.platform,
                isSearching: true,
              ),
            )
            .toList(growable: false),
      ),
    );

    await _searchPluginsLimited(generation, lyricPlugins, trimmed);
    if (_generation == generation) {
      state = AsyncData(
        (state.value ?? const LyricSearchState()).copyWith(isSearching: false),
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
      while (_generation == generation) {
        final index = nextIndex;
        nextIndex += 1;
        if (index >= plugins.length) {
          return;
        }
        await Future<void>.delayed(Duration.zero);
        final result = await _searchPlugin(plugins[index], keyword);
        if (_generation == generation) {
          _replacePluginResult(result);
        }
        await Future<void>.delayed(Duration.zero);
      }
    }

    await Future.wait<void>(
      List<Future<void>>.generate(workerCount, (_) => worker()),
    );
  }

  Future<AppError?> associateCandidate({
    required PlaybackItem item,
    required LyricSearchCandidate candidate,
    required List<PluginDefinition> plugins,
  }) async {
    PluginDefinition? plugin;
    for (final candidatePlugin in plugins) {
      if (candidatePlugin.id == candidate.pluginId && candidatePlugin.enabled) {
        plugin = candidatePlugin;
        break;
      }
    }
    if (plugin == null) {
      return const AppError(
        code: 'plugin.not_found',
        message: 'Selected lyric plugin is no longer enabled.',
      );
    }

    state = AsyncData(
      (state.value ?? const LyricSearchState()).copyWith(
        isAssociating: true,
        clearError: true,
      ),
    );
    final runtimeFactory = ref.read(pluginRuntimeFactoryProvider);
    final compat = ref.read(musicFreeCompatAdapterProvider);
    PluginRuntime? runtime;
    try {
      runtime = await runtimeFactory.create();
      final loaded = await runtime.loadPlugin(
        await File(plugin.sourcePath).readAsString(),
        userVariables: plugin.userVariableValues,
      );
      if (loaded case Failure<Map<String, Object?>>(:final error)) {
        return error;
      }

      final lyricResult = await runtime.callMethod('getLyric', <Object?>[
        candidate.raw,
      ], timeout: pluginMethodTimeout);
      switch (lyricResult) {
        case Ok<Object?>(:final value):
          final adapted = compat.lyricFromPluginValue(value);
          switch (adapted) {
            case Ok<String>(:final value):
              await ref
                  .read(lyricRepositoryProvider)
                  .associatePluginLyric(
                    item: item,
                    rawLyric: value,
                    pluginPlatform: candidate.platform,
                    pluginRaw: candidate.raw,
                  );
              ref.invalidate(storedCurrentLyricsProvider);
              return null;
            case Failure<String>(:final error):
              return error;
          }
        case Failure<Object?>(:final error):
          return error;
      }
    } catch (error, stackTrace) {
      return AppError(
        code: 'lyric.association_failed',
        message: 'Failed to associate plugin lyric.',
        cause: error,
        stackTrace: stackTrace,
      );
    } finally {
      await runtime?.dispose();
      state = AsyncData(
        (state.value ?? const LyricSearchState()).copyWith(
          isAssociating: false,
        ),
      );
    }
  }

  Future<LyricPluginSearchState> _searchPlugin(
    PluginDefinition plugin,
    String keyword,
  ) async {
    final executor = ref.read(pluginSearchExecutorProvider);
    final compat = ref.read(musicFreeCompatAdapterProvider);
    try {
      final result = await executor.search(
        plugin: plugin,
        source: await File(plugin.sourcePath).readAsString(),
        keyword: keyword,
        page: 1,
        searchType: 'lyric',
      );
      switch (result) {
        case Ok<Object?>(:final value):
          final adapted = compat.searchResultFromPluginValue(
            value,
            pluginId: plugin.id,
            platform: plugin.platform,
            page: 1,
          );
          return adapted.fold(
            (result) => LyricPluginSearchState(
              pluginId: plugin.id,
              platform: plugin.platform,
              items: result.items
                  .map(
                    (item) => LyricSearchCandidate(
                      pluginId: plugin.id,
                      platform: plugin.platform,
                      title: item.title,
                      artist: item.artist,
                      album: item.album,
                      raw: item.raw,
                    ),
                  )
                  .toList(growable: false),
            ),
            (error) => LyricPluginSearchState(
              pluginId: plugin.id,
              platform: plugin.platform,
              error: error,
            ),
          );
        case Failure<Object?>(:final error):
          return LyricPluginSearchState(
            pluginId: plugin.id,
            platform: plugin.platform,
            error: error,
          );
      }
    } catch (error, stackTrace) {
      return LyricPluginSearchState(
        pluginId: plugin.id,
        platform: plugin.platform,
        error: AppError(
          code: 'lyric.search_failed',
          message: 'Plugin ${plugin.platform} lyric search failed.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  void _replacePluginResult(LyricPluginSearchState result) {
    final current = state.value ?? const LyricSearchState();
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

String _desktopLyricSubtitle(PlaybackItem item) {
  return <String?>[
    item.artist,
    item.album,
    item.platform,
  ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' - ');
}

String _desktopNextLyric(LyricDocument lyrics, int activeIndex) {
  final start = activeIndex < 0 ? 0 : activeIndex + 1;
  for (var index = start; index < lyrics.lines.length; index += 1) {
    final line = lyrics.lines[index];
    final text = line.text.trim();
    if (line.timestamp != null && text.isNotEmpty) {
      return text;
    }
  }
  return '';
}
