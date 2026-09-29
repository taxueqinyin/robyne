import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/application/theme_providers.dart';
import '../../../core/theme/domain/theme_strings.dart';
import '../../../core/theme/infrastructure/token_resolver.dart';
import '../../player/domain/playback_item.dart';
import '../../playlists/application/playlist_providers.dart';
import '../../playlists/infrastructure/playlist_repository.dart';
import '../application/collection_play_controller.dart';
import '../domain/online_collection.dart';
import 'collection_play_dialog.dart';

/// Play-the-whole-collection and favourite controls for the detail header.
///
/// Both act on the collection rather than on one track, which is why they sit
/// in the header: the rows below are per-track and cannot express either.
class CollectionActions extends ConsumerWidget {
  const CollectionActions({super.key, required this.collection});

  final OnlineCollectionItem collection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final strings = ref.watch(activeThemeStringsProvider);
    final localPlaylistId = PlaylistRepository.importedPlaylistId(
      collection.uniqueKey,
    );
    final favorite =
        ref
            .watch(playlistControllerProvider)
            .value
            ?.any((playlist) => playlist.id == localPlaylistId) ??
        false;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: () => _play(context, ref),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.brandBase,
            side: BorderSide(color: colors.borderDefault),
          ),
          icon: const Icon(Icons.play_arrow, size: 18),
          label: Text(strings.resolve(ThemeStringKey.discoverPlayCollection)),
        ),
        OutlinedButton.icon(
          onPressed: () => _toggleLocalCollection(context, ref, favorite),
          style: OutlinedButton.styleFrom(
            foregroundColor: favorite ? colors.brandBase : colors.textSecondary,
            side: BorderSide(
              color: favorite ? colors.brandBase : colors.borderDefault,
            ),
          ),
          icon: Icon(
            favorite ? Icons.favorite : Icons.favorite_border,
            size: 18,
          ),
          label: Text(
            favorite
                ? strings.resolve(ThemeStringKey.discoverUnfavoriteCollection)
                : strings.resolve(ThemeStringKey.discoverFavoriteCollection),
          ),
        ),
      ],
    );
  }

  /// Saves the collection as a normal local playlist, or removes it.
  ///
  /// The plugin is read once at the moment of collection. From then on every
  /// surface reads `PlaylistItems`, exactly like a playlist the user built by
  /// hand; an offline launch never needs to reopen the plugin.
  Future<void> _toggleLocalCollection(
    BuildContext context,
    WidgetRef ref,
    bool favorite,
  ) async {
    final playlists = ref.read(playlistControllerProvider.notifier);
    final playlistId = PlaylistRepository.importedPlaylistId(
      collection.uniqueKey,
    );
    if (favorite) {
      await playlists.deletePlaylist(playlistId);
      return;
    }

    final tracks = await ref
        .read(collectionPlayControllerProvider)
        .loadTracks(collection);
    if (!context.mounted) {
      return;
    }
    if (tracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref
                .read(activeThemeStringsProvider)
                .resolve(ThemeStringKey.discoverFavoriteCollectionFailed),
          ),
        ),
      );
      return;
    }
    try {
      await playlists.saveCollectionAsPlaylist(
        collectionKey: collection.uniqueKey,
        name: collection.title,
        items: tracks.map(PlaybackItem.fromMusicItem).toList(growable: false),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${ref.read(activeThemeStringsProvider).resolve(ThemeStringKey.discoverFavoriteCollectionFailed)} $error',
          ),
        ),
      );
    }
  }

  /// Asks once, then applies the answer; a pinned answer skips the dialog.
  Future<void> _play(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(collectionPlayControllerProvider);
    final action = await controller.play(collection);
    if (!context.mounted) {
      return;
    }
    // `null` means the user has not pinned a choice yet, so the dialog owns
    // the decision and re-runs the play with the answer it gets.
    if (action != null) {
      return;
    }
    final tracks = await controller.loadTracks(collection);
    if (!context.mounted || tracks.isEmpty) {
      return;
    }
    final choice = await showCollectionPlayDialog(
      context,
      collectionTitle: collection.title,
      trackCount: tracks.length,
    );
    if (choice == null) {
      return;
    }
    if (choice.remember) {
      await controller.remember(choice.action);
    }
    await controller.apply(tracks, choice.action);
  }
}
