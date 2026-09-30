import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/debug/ime_trace.dart';
import '../../../core/layout/window_size_class.dart';
import '../../../core/theme/application/theme_providers.dart';
import '../../../core/theme/domain/theme_strings.dart';
import '../../../core/theme/infrastructure/token_resolver.dart';
import '../../../core/theme/presentation/theme_material.dart';
import '../../player/domain/playback_item.dart';
import '../../player/application/player_providers.dart';
import '../../player/presentation/artwork_view.dart';
import '../application/playlist_providers.dart';
import '../domain/music_playlist.dart';
import '../infrastructure/playlist_repository.dart';

class PlaylistsPage extends ConsumerWidget {
  const PlaylistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final metrics = ref.watch(activeThemeContentMetricsProvider);
    final sizeClass = WindowSizeClass.of(context);
    final compactWidth = sizeClass.width != WindowWidthClass.expanded;
    final playlistsValue = ref.watch(playlistControllerProvider);
    final selectedPlaylistId = ref.watch(selectedPlaylistIdProvider);
    final rawSelectedPlaylist = playlistsValue.value
        ?.where((playlist) => playlist.id == selectedPlaylistId)
        .firstOrNull;
    // `null` means liked songs, which is a real detail view of the favourites
    // playlist — not the overview. Resolving it here keeps the liked list
    // renderable below instead of falling through to the overview cards.
    final selectedPlaylist = selectedPlaylistId == null
        ? playlistsValue.value
              ?.where((playlist) => playlist.isFavorites)
              .firstOrNull
        : playlistsValue.value
              ?.where((playlist) => playlist.id == selectedPlaylistId)
              .firstOrNull;
    final isLikedView =
        selectedPlaylistId == null ||
        (rawSelectedPlaylist?.isFavorites ?? false);
    final isOverview =
        selectedPlaylistId == overviewPlaylistId ||
        (!isLikedView && selectedPlaylist == null);
    final isCollectionsView =
        selectedPlaylistId == overviewCollectionsPlaylistId;
    // On a phone the title and the create button do not fit one line, so the
    // button drops to its own row instead of squeezing the title.
    final title = Text(
      strings.resolve(
        isLikedView
            ? ThemeStringKey.playlistsLikedTitle
            : ThemeStringKey.playlistsTitle,
      ),
      style: TextStyle(
        fontSize: tokens.typography.resolvedPageTitleSize,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
      ),
    );
    final categories = _PlaylistSectionTabs(
      ownedSelected: isOverview,
      collectionsSelected: isCollectionsView,
      onOwned: () =>
          ref.read(selectedPlaylistIdProvider.notifier).showOverview(),
      onCollections: () =>
          ref.read(selectedPlaylistIdProvider.notifier).showCollections(),
    );
    final newButton = isLikedView || isCollectionsView
        ? null
        : FilledButton.icon(
            onPressed: () => _showCreateDialog(context, ref),
            icon: const Icon(Icons.playlist_add),
            label: Text(strings.resolve(ThemeStringKey.playlistsNew)),
          );
    final header = compactWidth
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              title,
              if (isOverview || isCollectionsView) ...[
                const SizedBox(height: 12),
                categories,
              ],
              if (newButton != null) ...<Widget>[
                const SizedBox(height: 12),
                newButton,
              ],
            ],
          )
        : Row(
            children: <Widget>[
              Expanded(child: title),
              if (isOverview || isCollectionsView) ...<Widget>[
                categories,
                const SizedBox(width: 12),
              ],
              ?newButton,
            ],
          );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.gutterFor(compact: compactWidth),
        20,
        metrics.gutterFor(compact: compactWidth),
        20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          header,
          if (compactWidth && isLikedView) ...<Widget>[
            const SizedBox(height: 10),
            _AllPlaylistsRow(
              label: strings.resolve(ThemeStringKey.playlistsAll),
              onTap: () =>
                  ref.read(selectedPlaylistIdProvider.notifier).showOverview(),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: playlistsValue.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Text(
                  error.toString(),
                  style: TextStyle(color: colors.danger),
                ),
              ),
              data: (playlists) {
                final visible = isLikedView
                    ? playlists
                          .where((playlist) => playlist.isFavorites)
                          .toList(growable: false)
                    : isCollectionsView
                    ? playlists
                          .where(
                            (playlist) =>
                                !playlist.isFavorites &&
                                isCollectionPlaylistId(playlist.id),
                          )
                          .toList(growable: false)
                    : isOverview
                    ? playlists
                          .where(
                            (playlist) =>
                                !playlist.isFavorites &&
                                !isCollectionPlaylistId(playlist.id),
                          )
                          .toList(growable: false)
                    : playlists
                          .where(
                            (playlist) => playlist.id == selectedPlaylistId,
                          )
                          .toList(growable: false);
                if (visible.isEmpty) {
                  return Center(
                    child: Text(
                      strings.resolve(
                        isLikedView
                            ? ThemeStringKey.playlistsEmpty
                            : ThemeStringKey.navPlaylistsEmpty,
                      ),
                      style: TextStyle(color: colors.textMuted),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: visible.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final playlist = visible[index];
                    if (isOverview || isCollectionsView) {
                      return _PlaylistCard(
                        playlist: playlist,
                        onTap: () {
                          final notifier = ref.read(
                            selectedPlaylistIdProvider.notifier,
                          );
                          if (playlist.isFavorites) {
                            notifier.showLiked();
                          } else {
                            notifier.select(playlist.id);
                          }
                        },
                      );
                    }
                    return _SelectedPlaylistCard(
                      playlist: playlist,
                      onDelete: playlist.id == PlaylistRepository.favoritesId
                          ? null
                          : () async {
                              final confirmed = await _confirmDestructiveAction(
                                context,
                                title: strings.resolve(
                                  ThemeStringKey.playlistsDeleteTitle,
                                ),
                                message: strings
                                    .resolve(
                                      ThemeStringKey.playlistsDeleteMessage,
                                    )
                                    .replaceAll('{name}', playlist.name),
                                actionLabel: strings.resolve(
                                  ThemeStringKey.playlistsDelete,
                                ),
                                cancelLabel: strings.resolve(
                                  ThemeStringKey.actionCancel,
                                ),
                              );
                              if (confirmed) {
                                await ref
                                    .read(playlistControllerProvider.notifier)
                                    .deletePlaylist(playlist.id);
                              }
                            },
                      onPlayItem: (PlaybackItem item) => ref
                          .read(playerControllerProvider.notifier)
                          .playItem(item),
                      onRemoveItem: (PlaybackItem item) async {
                        final confirmed = await _confirmDestructiveAction(
                          context,
                          title: strings.resolve(
                            ThemeStringKey.playlistsRemoveTitle,
                          ),
                          message: strings
                              .resolve(ThemeStringKey.playlistsRemoveMessage)
                              .replaceAll('{track}', item.title)
                              .replaceAll('{playlist}', playlist.name),
                          actionLabel: strings.resolve(
                            ThemeStringKey.actionRemove,
                          ),
                          cancelLabel: strings.resolve(
                            ThemeStringKey.actionCancel,
                          ),
                        );
                        if (confirmed) {
                          await ref
                              .read(playlistControllerProvider.notifier)
                              .removeItem(playlist.id, item.id);
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (context) => const _CreatePlaylistDialog(),
    );
  }

  Future<bool> _confirmDestructiveAction(
    BuildContext context, {
    required String title,
    required String message,
    required String actionLabel,
    required String cancelLabel,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelLabel),
              ),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.delete_outline),
                label: Text(actionLabel),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _PlaylistSectionTabs extends StatelessWidget {
  const _PlaylistSectionTabs({
    required this.ownedSelected,
    required this.collectionsSelected,
    required this.onOwned,
    required this.onCollections,
  });

  final bool ownedSelected;
  final bool collectionsSelected;
  final VoidCallback onOwned;
  final VoidCallback onCollections;

  @override
  Widget build(BuildContext context) {
    final strings = ProviderScope.containerOf(
      context,
    ).read(activeThemeStringsProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _PlaylistSectionTab(
          label: strings.resolve(ThemeStringKey.playlistsOwnedTab),
          selected: ownedSelected,
          onTap: onOwned,
        ),
        const SizedBox(width: 4),
        _PlaylistSectionTab(
          label: strings.resolve(ThemeStringKey.playlistsCollectionsTab),
          selected: collectionsSelected,
          onTap: onCollections,
        ),
      ],
    );
  }
}

class _PlaylistSectionTab extends StatelessWidget {
  const _PlaylistSectionTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? colors.brandBase : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _AllPlaylistsRow extends StatelessWidget {
  const _AllPlaylistsRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    return ThemedSurface(
      material: tokens.materials.card,
      tokens: tokens,
      fallbackColor: tokens.components.card.surface,
      radius: tokens.radius.md,
      onTap: onTap,
      child: Padding(
        key: const Key('playlists-all-entry'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            Icon(Icons.library_music_outlined, color: colors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// One row on the "我的歌单" overview.
///
/// Collection favourites arrive here as ordinary local playlists, so this
/// surface never needs a second "online collection" branch.
class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({required this.playlist, required this.onTap});

  final MusicPlaylist playlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final coverUrl = playlist.items
        .map((item) => item.artworkUrl)
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .firstOrNull;
    return ThemedSurface(
      material: tokens.materials.card,
      tokens: tokens,
      fallbackColor: tokens.components.card.surface,
      radius: tokens.radius.md,
      onTap: onTap,
      child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(tokens.radius.sm),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: coverUrl == null
                      ? ColoredBox(
                          color: colors.surfaceBase,
                          child: Icon(
                            Icons.queue_music,
                            color: colors.textMuted,
                          ),
                        )
                      : ArtworkView(artworkUrl: coverUrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: tokens.typography.resolvedListPrimarySize,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${playlist.items.length} 首',
                      style: TextStyle(fontSize: 11, color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: colors.textMuted),
            ],
          ),
        ),
    );
  }
}

/// The selected playlist detail card.
///
/// ExpansionTile paints its own hover/press overlay above the caller's selected
/// fill, so the two states stack and flicker. This card owns the selected
/// chrome and keeps hover feedback on a dedicated header button instead.
class _SelectedPlaylistCard extends ConsumerWidget {
  const _SelectedPlaylistCard({
    required this.playlist,
    required this.onDelete,
    required this.onPlayItem,
    required this.onRemoveItem,
  });

  final MusicPlaylist playlist;
  final Future<void> Function()? onDelete;
  final ValueChanged<PlaybackItem> onPlayItem;
  final ValueChanged<PlaybackItem> onRemoveItem;

  @override
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final strings = ref.watch(activeThemeStringsProvider);
    return Container(
      key: ValueKey<String>('selected-playlist-${playlist.id}'),
      decoration: BoxDecoration(
        color: tokens.components.list.itemSelected,
        borderRadius: BorderRadius.circular(tokens.radius.md),
        border: Border.all(color: colors.brandBase),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(tokens.radius.md),
            ),
            child: InkWell(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(tokens.radius.md),
              ),
              hoverColor: colors.surfaceHover.withValues(alpha: 0.45),
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Row(
                  children: <Widget>[
                    Icon(
                      playlist.isFavorites ? Icons.favorite : Icons.queue_music,
                      color: playlist.isFavorites
                          ? colors.brandBase
                          : colors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            playlist.name,
                            style: TextStyle(
                              fontSize:
                                  tokens.typography.resolvedListPrimarySize,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            strings
                                .resolve(ThemeStringKey.playlistsTrackCount)
                                .replaceAll(
                                  '{count}',
                                  '${playlist.items.length}',
                                ),
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onDelete != null)
                      IconButton(
                        tooltip: strings.resolve(
                          ThemeStringKey.playlistsDeleteTitle,
                        ),
                        icon: const Icon(Icons.delete_outline),
                        onPressed: onDelete,
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (playlist.items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                strings.resolve(ThemeStringKey.playlistsEmptyTracks),
                style: TextStyle(fontSize: 12, color: colors.textMuted),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: <Widget>[
                  for (final item in playlist.items)
                    ListTile(
                      leading: ArtworkView(artworkUrl: item.artworkUrl),
                      title: Text(item.title),
                      subtitle: Text(item.artist ?? item.platform ?? ''),
                      onTap: () => onPlayItem(item),
                      trailing: IconButton(
                        tooltip: strings.resolve(ThemeStringKey.actionRemove),
                        icon: const Icon(Icons.close),
                        onPressed: () => onRemoveItem(item),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CreatePlaylistDialog extends ConsumerStatefulWidget {
  const _CreatePlaylistDialog();

  @override
  ConsumerState<_CreatePlaylistDialog> createState() =>
      _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends ConsumerState<_CreatePlaylistDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    attachImeTextControllerTrace(_controller, 'playlists.createName');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(activeThemeStringsProvider);
    final tokens = RobyneTheme.of(context).tokens;
    return AlertDialog(
      title: Text(strings.resolve(ThemeStringKey.playlistsNewTitle)),
      content: SizedBox(
        width: RobyneDialogWidth.forContext(context, 360),
        child: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(tokens.radius.md)),
            ),
            labelText: strings.resolve(ThemeStringKey.playlistsNameField),
          ),
          onSubmitted: (_) => _create(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.resolve(ThemeStringKey.actionCancel)),
        ),
        FilledButton(
          onPressed: _create,
          child: Text(strings.resolve(ThemeStringKey.actionCreate)),
        ),
      ],
    );
  }

  Future<void> _create() async {
    final name = _controller.text;
    FocusManager.instance.primaryFocus?.unfocus();
    await ref.read(playlistControllerProvider.notifier).createPlaylist(name);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
