import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../shared/widgets/song_actions_menu.dart';
import '../../discover/application/collection_play_controller.dart';
import '../../discover/presentation/collection_play_dialog.dart';
import '../../downloads/application/download_providers.dart';
import '../../settings/application/settings_providers.dart';
import '../application/playlist_providers.dart';
import '../domain/music_playlist.dart';
import '../infrastructure/playlist_repository.dart';

/// Key prefix used by the lazily-built playlist detail rows.
const String playlistTrackKeyPrefix = 'track-';

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
    final isCollectionsView =
        selectedPlaylistId == overviewCollectionsPlaylistId;
    // The overview must not claim the collections section: the collections
    // sentinel matches no real playlist, so "selectedPlaylist == null" alone
    // used to light up 自建歌单 while 收藏歌单 was the section on screen.
    final isOverview =
        selectedPlaylistId == overviewPlaylistId ||
        (!isLikedView && !isCollectionsView && selectedPlaylist == null);
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
    // Creating belongs to the playlist list, not to an opened playlist.
    final canCreatePlaylist = isOverview || isCollectionsView;
    final newButton = canCreatePlaylist
        ? FilledButton.icon(
            key: const Key('playlists-new-button'),
            onPressed: () => _showCreateDialog(context, ref),
            icon: const Icon(Icons.playlist_add),
            label: Text(strings.resolve(ThemeStringKey.playlistsNew)),
          )
        : const SizedBox.shrink();
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: title),
            const SizedBox(width: 12),
            newButton,
          ],
        ),
        if (isOverview || isCollectionsView) ...<Widget>[
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerLeft, child: categories),
        ],
        if (compactWidth && isLikedView) ...<Widget>[
          const SizedBox(height: 10),
          _AllPlaylistsRow(
            label: strings.resolve(ThemeStringKey.playlistsAll),
            onTap: () =>
                ref.read(selectedPlaylistIdProvider.notifier).showOverview(),
          ),
        ],
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
                if (!isOverview && !isCollectionsView && visible.length == 1) {
                  final playlist = visible.single;
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
                  );
                }
                return ListView.separated(
                  itemCount: visible.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final playlist = visible[index];
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
          tabKey: const Key('playlists-tab-owned'),
          label: strings.resolve(ThemeStringKey.playlistsOwnedTab),
          selected: ownedSelected,
          onTap: onOwned,
        ),
        const SizedBox(width: 6),
        _PlaylistSectionTab(
          tabKey: const Key('playlists-tab-collections'),
          label: strings.resolve(ThemeStringKey.playlistsCollectionsTab),
          selected: collectionsSelected,
          onTap: onCollections,
        ),
      ],
    );
  }
}

/// One half of the 我的歌单 section switch.
///
/// The selection is a filled pill rather than a colour change on the text
/// alone: two sections that differ only by tint made it easy to read the
/// wrong one as current, and a pill keeps the two states visibly exclusive.
class _PlaylistSectionTab extends StatelessWidget {
  const _PlaylistSectionTab({
    required this.tabKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key tabKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final comp = tokens.components.navBar;
    final radius = BorderRadius.all(Radius.circular(tokens.radius.full));
    return Semantics(
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        hoverColor: selected
            ? Colors.transparent
            : colors.surfaceHover.withValues(alpha: 0.45),
        child: Container(
          key: tabKey,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? comp.selectedIndicatorFill : colors.surfaceBase,
            borderRadius: radius,
            border: Border.all(
              color: selected ? comp.selectedIndicator : colors.borderDefault,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? comp.selectedItem : colors.textSecondary,
            ),
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
class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({required this.playlist, required this.onTap});

  final MusicPlaylist playlist;
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
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            _PlaylistCover(coverUrl: playlist.resolvedCoverUrl, size: 56),
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

class _PlaylistCover extends StatelessWidget {
  const _PlaylistCover({required this.coverUrl, required this.size});

  final String? coverUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radius.sm),
      child: SizedBox(
        width: size,
        height: size,
        child: coverUrl == null
            ? ColoredBox(
                color: colors.surfaceBase,
                child: Icon(Icons.queue_music, color: colors.textMuted),
              )
            : ArtworkView(artworkUrl: coverUrl),
      ),
    );
  }
}

/// The three faces of one playlist detail: browse, batch download and batch
/// edit. The header and the track list stay in one scrollable surface; each
/// mode owns only its toolbar and its row controls.
enum _PlaylistMode { browse, download, batch }

class _SelectedPlaylistCard extends ConsumerStatefulWidget {
  const _SelectedPlaylistCard({required this.playlist, required this.onDelete});

  final MusicPlaylist playlist;
  final Future<void> Function()? onDelete;

  @override
  ConsumerState<_SelectedPlaylistCard> createState() =>
      _SelectedPlaylistCardState();
}

class _SelectedPlaylistCardState extends ConsumerState<_SelectedPlaylistCard> {
  _PlaylistMode _mode = _PlaylistMode.browse;
  _DownloadQuality _quality = _DownloadQuality.standard;
  final Set<String> _selected = <String>{};

  MusicPlaylist get playlist => widget.playlist;

  @override
  void didUpdateWidget(covariant _SelectedPlaylistCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playlist.id != widget.playlist.id) {
      _mode = _PlaylistMode.browse;
      _selected.clear();
    } else {
      final ids = widget.playlist.items.map((item) => item.id).toSet();
      _selected.removeWhere((id) => !ids.contains(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final strings = ref.watch(activeThemeStringsProvider);
    final toolbar = switch (_mode) {
      _PlaylistMode.browse => null,
      _PlaylistMode.download => _DownloadToolbar(
        quality: _quality,
        onQualityChanged: (quality) => setState(() => _quality = quality),
        onExit: _exitMode,
        onStart: () => _startDownloads(_selection),
        selectedCount: _selected.length,
        totalCount: playlist.items.length,
      ),
      _PlaylistMode.batch => _BatchToolbar(
        selectedCount: _selected.length,
        onExit: _exitMode,
        onSelectAll: _selectAll,
        onPlay: () => unawaited(_playSelection(context)),
        onAdd: () => unawaited(_addSelection(context)),
        onDownload: () => unawaited(_downloadSelection()),
        onDelete: () => unawaited(_deleteSelection(context)),
      ),
    };
    return Container(
      key: ValueKey<String>('selected-playlist-${playlist.id}'),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(tokens.radius.md),
      ),
      child: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(child: _buildHeader(context)),
          if (toolbar != null) SliverToBoxAdapter(child: toolbar),
          if (playlist.items.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  strings.resolve(ThemeStringKey.playlistsEmptyTracks),
                  style: TextStyle(fontSize: 12, color: colors.textMuted),
                ),
              ),
            )
          else ...<Widget>[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              sliver: SliverToBoxAdapter(
                child: _TrackColumnHeader(mode: _mode),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              sliver: SliverList.builder(
                itemCount: playlist.items.length,
                itemBuilder: (context, index) {
                  final item = playlist.items[index];
                  return _PlaylistTrackRow(
                    key: ValueKey<String>('$playlistTrackKeyPrefix${item.id}'),
                    item: item,
                    mode: _mode,
                    selected: _selected.contains(item.id),
                    onToggleSelected: () => _toggleSelected(item.id),
                    onPlay: () => ref
                        .read(playerControllerProvider.notifier)
                        .playItem(item),
                    onRemove: () => ref
                        .read(playlistControllerProvider.notifier)
                        .removeItem(playlist.id, item.id),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final strings = ref.watch(activeThemeStringsProvider);
    final sizeClass = WindowSizeClass.of(context);
    final compact = sizeClass.width != WindowWidthClass.expanded;
    final coverSize = compact ? 88.0 : 112.0;
    final actions = <Widget>[
      _HeaderPill(
        key: const Key('playlists-play-button'),
        icon: Icons.play_arrow,
        label: strings.resolve(ThemeStringKey.playlistsPlay),
        onTap: () => unawaited(_playPlaylist(context)),
      ),
      _HeaderPill(
        key: const Key('playlists-download-button'),
        icon: Icons.download_outlined,
        label: strings.resolve(ThemeStringKey.playlistsDownload),
        onTap: () => setState(() {
          _mode = _PlaylistMode.download;
          _selected
            ..clear()
            ..addAll(playlist.items.map((item) => item.id));
        }),
      ),
      _HeaderPill(
        key: const Key('playlists-batch-button'),
        icon: Icons.checklist_outlined,
        label: strings.resolve(ThemeStringKey.playlistsBatch),
        onTap: () => setState(() {
          _mode = _PlaylistMode.batch;
          _selected.clear();
        }),
      ),
      _HeaderPill(
        key: const Key('playlists-share-button'),
        icon: Icons.share_outlined,
        label: strings.resolve(ThemeStringKey.playlistsShare),
        onTap: () => _showShareDialog(context),
      ),
    ];
    final edit = TextButton.icon(
      key: const Key('playlists-edit-button'),
      onPressed: () => _showEditDialog(context),
      icon: const Icon(Icons.edit_outlined, size: 16),
      label: Text(strings.resolve(ThemeStringKey.playlistsEdit)),
      style: TextButton.styleFrom(
        foregroundColor: colors.textSecondary,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _PlaylistCover(
                coverUrl: playlist.resolvedCoverUrl,
                size: coverSize,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            playlist.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 20 : 24,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        if (!compact) edit,
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _authorLine(strings),
                      style: TextStyle(fontSize: 12, color: colors.textMuted),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      playlist.description.trim().isEmpty
                          ? strings
                                .resolve(ThemeStringKey.playlistsTrackCount)
                                .replaceAll(
                                  '{count}',
                                  '${playlist.items.length}',
                                )
                          : playlist.description.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onDelete != null && !compact)
                IconButton(
                  key: const Key('playlists-delete-button'),
                  tooltip: strings.resolve(ThemeStringKey.playlistsDeleteTitle),
                  icon: const Icon(Icons.delete_outline, size: 19),
                  onPressed: widget.onDelete,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
          if (compact) ...<Widget>[
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                edit,
                const Spacer(),
                if (widget.onDelete != null)
                  IconButton(
                    key: const Key('playlists-delete-button'),
                    tooltip: strings.resolve(
                      ThemeStringKey.playlistsDeleteTitle,
                    ),
                    icon: const Icon(Icons.delete_outline, size: 19),
                    onPressed: widget.onDelete,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _authorLine(ThemeStrings strings) {
    final count = strings
        .resolve(ThemeStringKey.playlistsTrackCount)
        .replaceAll('{count}', '${playlist.items.length}');
    final owner = playlist.isFavorites
        ? strings.resolve(ThemeStringKey.playlistsLikedTitle)
        : strings.resolve(ThemeStringKey.playlistsTitle);
    return '${playlist.isFavorites ? '♥ ' : ''}$count · $owner · ${strings.resolve(ThemeStringKey.actionAddTo)}';
  }

  void _exitMode() {
    setState(() {
      _mode = _PlaylistMode.browse;
      _selected.clear();
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      if (!_selected.remove(id)) {
        _selected.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selected.length == playlist.items.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(playlist.items.map((item) => item.id));
      }
    });
  }

  List<PlaybackItem> get _selection => playlist.items
      .where((item) => _selected.contains(item.id))
      .toList(growable: false);

  Future<void> _playPlaylist(BuildContext context) =>
      _playItems(context, playlist.items);

  Future<void> _playSelection(BuildContext context) =>
      _playItems(context, _selection);

  Future<void> _playItems(
    BuildContext context,
    List<PlaybackItem> items,
  ) async {
    if (items.isEmpty) {
      return;
    }
    final controller = ref.read(collectionPlayControllerProvider);
    final pinned = await controller.resolveAction();
    if (!context.mounted) {
      return;
    }
    var action = pinned;
    if (action == null) {
      final choice = await showCollectionPlayDialog(
        context,
        collectionTitle: playlist.name,
        trackCount: items.length,
      );
      if (choice == null) {
        return;
      }
      if (choice.remember) {
        await controller.remember(choice.action);
      }
      action = choice.action;
    }
    await controller.applyPlaybackItems(items, action);
  }

  void _showShareDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => _SharePlaylistDialog(playlist: playlist),
    );
  }

  void _showEditDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => _EditPlaylistDialog(playlist: playlist),
    );
  }

  Future<void> _downloadSelection() => _startDownloads(_selection);

  Future<void> _startDownloads(List<PlaybackItem> items) async {
    final controller = ref.read(downloadControllerProvider.notifier);
    for (final item in items) {
      await controller.startDownload(item, quality: _quality.pluginValue);
    }
  }

  Future<void> _addSelection(BuildContext context) async {
    final items = _selection;
    if (items.isEmpty) {
      return;
    }
    await ref.read(playerControllerProvider.notifier).enqueueItems(items);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ref
              .read(activeThemeStringsProvider)
              .resolve(ThemeStringKey.settingsPlaylistActionAppend),
        ),
      ),
    );
  }

  Future<void> _deleteSelection(BuildContext context) async {
    final count = _selection.length;
    if (count == 0) {
      return;
    }
    final strings = ref.read(activeThemeStringsProvider);
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              strings.resolve(ThemeStringKey.playlistsBatchDeleteTitle),
            ),
            content: Text(
              strings
                  .resolve(ThemeStringKey.playlistsBatchDeleteMessage)
                  .replaceAll('{count}', '$count'),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(strings.resolve(ThemeStringKey.actionCancel)),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  strings.resolve(ThemeStringKey.playlistsBatchDelete),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    await ref
        .read(playlistControllerProvider.notifier)
        .removeItems(playlist.id, _selected.toSet());
    if (mounted) {
      setState(_selected.clear);
    }
  }
}

/// The small dark pills in the playlist detail header.
class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.all(Radius.circular(tokens.radius.full)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.all(Radius.circular(tokens.radius.full)),
        hoverColor: colors.surfaceHover.withValues(alpha: 0.6),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: colors.surfaceBase,
            borderRadius: BorderRadius.all(Radius.circular(tokens.radius.full)),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 17, color: colors.textPrimary),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _DownloadQuality {
  standard('standard'),
  high('high'),
  lossless('lossless'),
  hires('hires'),
  surround('surround'),
  master('master');

  const _DownloadQuality(this.pluginValue);

  final String pluginValue;

  ThemeStringKey get labelKey => switch (this) {
    _DownloadQuality.standard => ThemeStringKey.playlistsQualityStandard,
    _DownloadQuality.high => ThemeStringKey.playlistsQualityHigh,
    _DownloadQuality.lossless => ThemeStringKey.playlistsQualityLossless,
    _DownloadQuality.hires => ThemeStringKey.playlistsQualityHires,
    _DownloadQuality.surround => ThemeStringKey.playlistsQualitySurround,
    _DownloadQuality.master => ThemeStringKey.playlistsQualityMaster,
  };
}

class _DownloadToolbar extends ConsumerWidget {
  const _DownloadToolbar({
    required this.quality,
    required this.onQualityChanged,
    required this.onExit,
    required this.onStart,
    required this.selectedCount,
    required this.totalCount,
  });

  final _DownloadQuality quality;
  final ValueChanged<_DownloadQuality> onQualityChanged;
  final VoidCallback onExit;
  final Future<void> Function() onStart;
  final int selectedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final settings = ref.watch(settingsControllerProvider).value;
    final directory = settings?.downloadsDirectoryPath ?? '';
    return Container(
      key: const Key('playlists-download-toolbar'),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: colors.surfaceBase,
        border: Border(
          top: BorderSide(color: colors.borderSubtle),
          bottom: BorderSide(color: colors.borderSubtle),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _HeaderPill(
                key: const Key('playlists-download-start'),
                icon: Icons.download,
                label: strings.resolve(ThemeStringKey.playlistsDownload),
                onTap: () => unawaited(onStart()),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  strings
                      .resolve(ThemeStringKey.playlistsDownloadLocation)
                      .replaceAll('{path}', directory),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: colors.textMuted),
                ),
              ),
              TextButton(
                onPressed: () => _changeDirectory(context, ref),
                child: Text(
                  strings.resolve(ThemeStringKey.playlistsChangeDirectory),
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                key: const Key('playlists-exit-download'),
                onPressed: onExit,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.textPrimary,
                  side: BorderSide(color: colors.borderDefault),
                  shape: StadiumBorder(),
                ),
                child: Text(
                  strings.resolve(ThemeStringKey.playlistsExitBatchDownload),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    strings.resolve(ThemeStringKey.playlistsDownloadQuality),
                    style: TextStyle(fontSize: 12, color: colors.textMuted),
                  ),
                ),
                for (final option in _DownloadQuality.values) ...<Widget>[
                  InkWell(
                    onTap: () => onQualityChanged(option),
                    borderRadius: BorderRadius.all(
                      Radius.circular(tokens.radius.full),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            quality == option
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 16,
                            color: quality == option
                                ? colors.accentBase
                                : colors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            strings.resolve(option.labelKey),
                            style: TextStyle(
                              fontSize: 12,
                              color: quality == option
                                  ? colors.textPrimary
                                  : colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${strings.resolve(ThemeStringKey.playlistsBatchDownloadCount).replaceAll('{count}', '$selectedCount')} / $totalCount',
            style: TextStyle(fontSize: 11, color: colors.success),
          ),
        ],
      ),
    );
  }

  Future<void> _changeDirectory(BuildContext context, WidgetRef ref) async {
    final directory = await FilePicker.getDirectoryPath();
    if (directory != null) {
      await ref
          .read(settingsControllerProvider.notifier)
          .setDownloadsDirectory(directory);
    }
  }
}

class _BatchToolbar extends StatelessWidget {
  const _BatchToolbar({
    required this.selectedCount,
    required this.onExit,
    required this.onSelectAll,
    required this.onPlay,
    required this.onAdd,
    required this.onDownload,
    required this.onDelete,
  });

  final int selectedCount;
  final VoidCallback onExit;
  final VoidCallback onSelectAll;
  final VoidCallback onPlay;
  final VoidCallback onAdd;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = ProviderScope.containerOf(
      context,
    ).read(activeThemeStringsProvider);
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    return Container(
      key: const Key('playlists-batch-toolbar'),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: colors.surfaceBase,
        border: Border(
          top: BorderSide(color: colors.borderSubtle),
          bottom: BorderSide(color: colors.borderSubtle),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _HeaderPill(
                      icon: Icons.play_arrow,
                      label: strings.resolve(ThemeStringKey.actionPlay),
                      onTap: onPlay,
                    ),
                    _HeaderPill(
                      icon: Icons.add,
                      label: strings.resolve(ThemeStringKey.playlistsBatchAdd),
                      onTap: onAdd,
                    ),
                    _HeaderPill(
                      icon: Icons.download_outlined,
                      label: strings.resolve(ThemeStringKey.playlistsDownload),
                      onTap: onDownload,
                    ),
                    _HeaderPill(
                      icon: Icons.delete_outline,
                      label: strings.resolve(
                        ThemeStringKey.playlistsBatchDelete,
                      ),
                      onTap: onDelete,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                key: const Key('playlists-exit-batch'),
                onPressed: onExit,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.textPrimary,
                  side: BorderSide(color: colors.borderDefault),
                  shape: StadiumBorder(),
                ),
                child: Text(strings.resolve(ThemeStringKey.playlistsExitBatch)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              InkWell(
                key: const Key('playlists-select-all'),
                onTap: onSelectAll,
                borderRadius: BorderRadius.all(
                  Radius.circular(tokens.radius.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      selectedCount > 0
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      strings.resolve(ThemeStringKey.playlistsSelectAll),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Text(
                strings
                    .resolve(ThemeStringKey.playlistsSelectedCount)
                    .replaceAll('{count}', '$selectedCount'),
                style: TextStyle(fontSize: 12, color: colors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Reserved width for the two hover-only row actions and their gutter.
/// Keeping this constant in the row and column header avoids a horizontal
/// jump when the buttons appear.
const double _trackActionsWidth = 88;
const double _trackActionsGutter = 4;

class _TrackColumnHeader extends StatelessWidget {
  const _TrackColumnHeader({required this.mode});

  final _PlaylistMode mode;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 6),
      child: Row(
        children: <Widget>[
          if (mode != _PlaylistMode.browse) const SizedBox(width: 32),
          const SizedBox(width: 56),
          Expanded(
            flex: 3,
            child: Text(
              mode == _PlaylistMode.browse ? '歌名/歌手' : '',
              style: TextStyle(fontSize: 11, color: colors.textMuted),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              mode == _PlaylistMode.download ? '大小' : '专辑',
              style: TextStyle(fontSize: 11, color: colors.textMuted),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              '时长',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 11, color: colors.textMuted),
            ),
          ),
          if (mode == _PlaylistMode.browse)
            const SizedBox(width: _trackActionsGutter + _trackActionsWidth),
        ],
      ),
    );
  }
}

class _PlaylistTrackRow extends ConsumerStatefulWidget {
  const _PlaylistTrackRow({
    super.key,
    required this.item,
    required this.mode,
    required this.selected,
    required this.onToggleSelected,
    required this.onPlay,
    required this.onRemove,
  });

  final PlaybackItem item;
  final _PlaylistMode mode;
  final bool selected;
  final VoidCallback onToggleSelected;
  final VoidCallback onPlay;
  final Future<void> Function() onRemove;

  @override
  ConsumerState<_PlaylistTrackRow> createState() => _PlaylistTrackRowState();
}

class _PlaylistTrackRowState extends ConsumerState<_PlaylistTrackRow> {
  final FocusNode _rowFocusNode = FocusNode(debugLabel: 'Playlist track row');
  bool _hovered = false;
  bool _focused = false;

  bool get _showRowActions => _hovered || _focused;

  @override
  void dispose() {
    _rowFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final strings = ref.watch(activeThemeStringsProvider);
    final item = widget.item;
    final mode = widget.mode;
    final selected = widget.selected;
    final selectable = mode != _PlaylistMode.browse;
    final task = mode == _PlaylistMode.download
        ? ref
              .watch(downloadControllerProvider)
              .value
              ?.where((candidate) => candidate.id == item.id)
              .firstOrNull
        : null;
    return SongContextMenuRegion(
      item: item,
      // From a playlist, "delete" means detach from this playlist — the
      // same action as the row button.
      onDelete: widget.onRemove,
      child: InkWell(
        focusNode: _rowFocusNode,
        onTap: selectable ? widget.onToggleSelected : widget.onPlay,
        onHover: (hovered) {
          if (_hovered != hovered) {
            setState(() => _hovered = hovered);
          }
        },
        onFocusChange: (focused) {
          if (_focused != focused) {
            setState(() => _focused = focused);
          }
        },
        borderRadius: BorderRadius.circular(tokens.radius.sm),
        hoverColor: colors.surfaceHover.withValues(alpha: 0.3),
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.fromLTRB(8, 7, 12, 7),
          decoration: BoxDecoration(
            color: selected
                ? colors.surfaceHover.withValues(alpha: 0.35)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(tokens.radius.sm),
          ),
          child: Row(
            children: <Widget>[
              if (selectable)
                SizedBox(
                  width: 32,
                  child: Icon(
                    selected
                        ? (mode == _PlaylistMode.download
                              ? Icons.check_circle
                              : Icons.check_circle_outline)
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: selected ? colors.success : colors.textMuted,
                  ),
                ),
              SizedBox(
                width: 44,
                height: 44,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(tokens.radius.sm),
                  child: ArtworkView(artworkUrl: item.artworkUrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.artist ?? item.platform ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Text(
                  mode == _PlaylistMode.download
                      ? (task?.status.name ??
                            strings.resolve(
                              ThemeStringKey.playlistsQualityStandard,
                            ))
                      : item.album ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: colors.textMuted),
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  _duration(item.duration),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, color: colors.textMuted),
                ),
              ),
              if (!selectable) ...<Widget>[
                const SizedBox(width: _trackActionsGutter),
                SizedBox(
                  width: _trackActionsWidth,
                  child: _showRowActions
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            IconButton(
                              tooltip: strings.resolve(
                                ThemeStringKey.actionRemove,
                              ),
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                size: 18,
                              ),
                              visualDensity: VisualDensity.compact,
                              onPressed: widget.onRemove,
                            ),
                            SongActionsMenuButton(
                              item: item,
                              iconSize: 18,
                              tooltipKey: ThemeStringKey.playerMore,
                            ),
                          ],
                        )
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _duration(Duration? duration) {
    if (duration == null) {
      return '--:--';
    }
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// The editable share text: playlist identity, then one song per line.
String playlistShareText(MusicPlaylist playlist) {
  final lines = <String>[
    playlist.name,
    if (playlist.description.trim().isNotEmpty) playlist.description.trim(),
  ];
  for (final item in playlist.items) {
    final source = item.isLocal
        ? '本地'
        : item.platform?.trim().isNotEmpty == true
        ? item.platform!.trim()
        : '未知来源';
    final artist = item.artist?.trim().isNotEmpty == true
        ? item.artist!.trim()
        : '未知歌手';
    lines.add('${item.title} | $artist | $source');
  }
  return lines.join('\n');
}

class _SharePlaylistDialog extends ConsumerStatefulWidget {
  const _SharePlaylistDialog({required this.playlist});

  final MusicPlaylist playlist;

  @override
  ConsumerState<_SharePlaylistDialog> createState() =>
      _SharePlaylistDialogState();
}

class _SharePlaylistDialogState extends ConsumerState<_SharePlaylistDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: playlistShareText(widget.playlist),
    );
    attachImeTextControllerTrace(_controller, 'playlists.shareText');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(activeThemeStringsProvider);
    return AlertDialog(
      key: const Key('playlists-share-dialog'),
      title: Text(strings.resolve(ThemeStringKey.playlistsShareTitle)),
      content: SizedBox(
        width: RobyneDialogWidth.forContext(context, 520),
        child: TextField(
          key: const Key('playlists-share-text'),
          controller: _controller,
          maxLines: 14,
          minLines: 8,
          style: const TextStyle(fontSize: 13, height: 1.5),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
            labelText: widget.playlist.name,
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.resolve(ThemeStringKey.actionCancel)),
        ),
        FilledButton.icon(
          key: const Key('playlists-share-copy'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: _controller.text));
            if (context.mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    strings.resolve(ThemeStringKey.playlistsCopied),
                  ),
                ),
              );
            }
          },
          icon: const Icon(Icons.copy_outlined, size: 17),
          label: Text(strings.resolve(ThemeStringKey.playlistsCopy)),
        ),
      ],
    );
  }
}

class _EditPlaylistDialog extends ConsumerStatefulWidget {
  const _EditPlaylistDialog({required this.playlist});

  final MusicPlaylist playlist;

  @override
  ConsumerState<_EditPlaylistDialog> createState() =>
      _EditPlaylistDialogState();
}

class _EditPlaylistDialogState extends ConsumerState<_EditPlaylistDialog> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _cover;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.playlist.name);
    _description = TextEditingController(text: widget.playlist.description);
    _cover = TextEditingController(text: widget.playlist.coverUrl ?? '');
    attachImeTextControllerTrace(_name, 'playlists.editName');
    attachImeTextControllerTrace(_description, 'playlists.editDescription');
    attachImeTextControllerTrace(_cover, 'playlists.editCover');
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _cover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(activeThemeStringsProvider);
    return AlertDialog(
      key: const Key('playlists-edit-dialog'),
      title: Text(strings.resolve(ThemeStringKey.playlistsEditTitle)),
      content: SizedBox(
        width: RobyneDialogWidth.forContext(context, 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                key: const Key('playlists-edit-name'),
                controller: _name,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: strings.resolve(ThemeStringKey.playlistsNameField),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('playlists-edit-description'),
                controller: _description,
                maxLines: 3,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                  labelText: strings.resolve(
                    ThemeStringKey.playlistsDescriptionField,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('playlists-edit-cover'),
                controller: _cover,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: strings.resolve(
                    ThemeStringKey.playlistsCoverField,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.resolve(ThemeStringKey.actionCancel)),
        ),
        FilledButton(
          key: const Key('playlists-edit-save'),
          onPressed: () async {
            await ref
                .read(playlistControllerProvider.notifier)
                .updatePlaylistInfo(
                  widget.playlist.id,
                  name: _name.text,
                  description: _description.text,
                  coverUrl: _cover.text.trim().isEmpty
                      ? null
                      : _cover.text.trim(),
                );
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Text(strings.resolve(ThemeStringKey.playlistsSave)),
        ),
      ],
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
