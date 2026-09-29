import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../../player/application/player_providers.dart';
import '../../player/domain/playback_item.dart';
import '../../plugin/application/plugin_controller.dart';
import '../../plugin/application/plugin_providers.dart';
import '../../plugin/domain/plugin_definition.dart';
import '../../search/domain/music_item.dart';
import '../../settings/application/settings_providers.dart';
import '../../settings/domain/user_settings.dart';
import '../domain/online_collection.dart';
import 'discover_controller.dart';

/// Plays an online collection's tracks into the player queue.
///
/// The queue decision (append vs replace) is the user's, not the app's, so the
/// first play asks and any later play reuses the pinned answer. Keeping that
/// policy here rather than in the widget means the dialog, the setting and the
/// playback all agree on one source of truth.
class CollectionPlayController {
  const CollectionPlayController(this._ref);

  final Ref _ref;

  /// Loads [collection]'s tracks and puts them in the queue.
  ///
  /// Returns the resolved action so a caller can show a confirmation, or
  /// `null` when the user cancelled the choice or the plugin had nothing to
  /// give.
  Future<PlaylistOpenAction?> play(OnlineCollectionItem collection) async {
    final tracks = await loadTracks(collection);
    if (tracks.isEmpty) {
      return null;
    }

    final action = await _resolveAction();
    if (action == null) {
      // Nothing pinned yet: the caller asks, then replays with the answer.
      return null;
    }
    await _apply(collection, tracks, action);
    return action;
  }

  /// Applies a caller-resolved [action] to already-loaded [tracks].
  Future<void> apply(List<MusicItem> tracks, PlaylistOpenAction action) async {
    await _apply(null, tracks, action);
  }

  /// Pins [action] so later plays skip the dialog.
  Future<void> remember(PlaylistOpenAction action) async {
    await _ref
        .read(settingsControllerProvider.notifier)
        .setPlaylistOpenAction(action);
  }

  Future<void> _apply(
    OnlineCollectionItem? collection,
    List<MusicItem> tracks,
    PlaylistOpenAction action,
  ) async {
    final items = tracks
        .map(PlaybackItem.fromMusicItem)
        .toList(growable: false);
    final player = _ref.read(playerControllerProvider.notifier);
    switch (action) {
      case PlaylistOpenAction.append:
        await player.enqueueItems(items);
      case PlaylistOpenAction.replace:
        await player.replaceQueueWithItems(items);
      case PlaylistOpenAction.alwaysAsk:
        // Unreachable: callers resolve `alwaysAsk` into a concrete choice.
        break;
    }
  }

  /// The pinned answer, or `null` when the user still has to be asked.
  Future<PlaylistOpenAction?> _resolveAction() async {
    final settings = _ref.read(settingsControllerProvider).value;
    final saved = settings?.playlistOpenAction ?? PlaylistOpenAction.alwaysAsk;
    if (saved != PlaylistOpenAction.alwaysAsk) {
      return saved;
    }
    return null;
  }

  /// Fetches the collection's track page from its plugin.
  ///
  /// Reuses the discover controller's cached detail when the collection is
  /// already open, so "play" right after browsing costs no second request.
  Future<List<MusicItem>> loadTracks(OnlineCollectionItem collection) async {
    final open = _ref.read(discoverControllerProvider).detail;
    if (open != null &&
        open.collection.uniqueKey == collection.uniqueKey &&
        open.items.isNotEmpty &&
        open.isEnd) {
      return open.items;
    }

    final plugins = _ref.read(pluginControllerProvider).value;
    if (plugins == null) {
      return const <MusicItem>[];
    }
    PluginDefinition? plugin;
    for (final candidate in plugins) {
      if (candidate.id == collection.pluginId) {
        plugin = candidate;
        break;
      }
    }
    if (plugin == null) {
      return const <MusicItem>[];
    }

    try {
      final source = await File(plugin.sourcePath).readAsString();
      final executor = _ref.read(pluginDiscoveryExecutorProvider);
      if (collection.kind == OnlineCollectionKind.topList) {
        final value = await executor.getTopListDetail(
          plugin: plugin,
          source: source,
          topList: collection.raw,
        );
        return _adaptDetail(
          value,
          collection: collection,
          page: 1,
          assumeComplete: true,
        );
      }

      // A saved local playlist must hold the whole collection. The plugin
      // paginates sheets, so saving only page 1 silently dropped the tail of
      // long user playlists.
      final items = <MusicItem>[];
      var page = 1;
      while (true) {
        final value = await executor.getMusicSheetInfo(
          plugin: plugin,
          source: source,
          sheetItem: collection.raw,
          page: page,
        );
        switch (value) {
          case Ok<Object?>(:final value):
            final adapted = _ref
                .read(musicFreeCompatAdapterProvider)
                .collectionDetailFromPluginValue(
                  value,
                  collection: collection,
                  page: page,
                );
            switch (adapted) {
              case Ok<OnlineCollectionDetail>(:final value):
                final known = items.map((item) => item.id).toSet();
                items.addAll(value.items.where((item) => known.add(item.id)));
                if (value.isEnd || value.items.isEmpty) {
                  return items;
                }
                page = value.page + 1;
              case Failure<OnlineCollectionDetail>():
                return const <MusicItem>[];
            }
          case Failure<Object?>():
            return const <MusicItem>[];
        }
      }
    } catch (_) {
      return const <MusicItem>[];
    }
  }

  List<MusicItem> _adaptDetail(
    Result<Object?> value, {
    required OnlineCollectionItem collection,
    required int page,
    bool assumeComplete = false,
  }) {
    switch (value) {
      case Ok<Object?>(:final value):
        final adapted = _ref
            .read(musicFreeCompatAdapterProvider)
            .collectionDetailFromPluginValue(
              value,
              collection: collection,
              page: page,
              assumeComplete: assumeComplete,
            );
        switch (adapted) {
          case Ok<OnlineCollectionDetail>(:final value):
            return value.items;
          case Failure<OnlineCollectionDetail>():
            return const <MusicItem>[];
        }
      case Failure<Object?>():
        return const <MusicItem>[];
    }
  }
}

final collectionPlayControllerProvider = Provider<CollectionPlayController>((
  ref,
) {
  return CollectionPlayController(ref);
});
