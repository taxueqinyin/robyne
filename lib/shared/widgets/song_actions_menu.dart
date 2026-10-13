import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/application/theme_providers.dart';
import '../../core/theme/domain/theme_strings.dart';
import '../../features/downloads/application/download_providers.dart';
import '../../features/playlists/application/playlist_providers.dart';
import '../../features/player/application/player_providers.dart';
import '../../features/player/domain/playback_item.dart';

/// The menu currently on screen, if any.
///
/// Surfaces nest: the Now Playing page wraps everything in a song menu while
/// the lyric pane wraps itself in a lyric menu, so one right-click can reach
/// two detectors. Left alone that opens both menus at once. A single "which
/// surface owns the click" flag is simpler and more reliable than trying to
/// make the gesture arena pick a winner.
bool _menuOpen = false;

/// True while any song/lyric context menu is on screen.
///
/// The lyric menu lives in the player rather than here, but it shares the same
/// gesture surface, so it has to share the same "one menu at a time" flag.
bool get isSongMenuOpen => _menuOpen;

/// Marks the gesture as consumed by a menu that is not [showSongActionsMenu].
///
/// Returns false when another menu already owns the click, in which case the
/// caller must not open anything.
bool beginSongMenu() {
  if (_menuOpen) {
    return false;
  }
  _menuOpen = true;
  return true;
}

void endSongMenu() {
  _menuOpen = false;
}

/// The global right-click menu for a song.
///
/// Every song surface (search, discover, local library, playlist, queue and
/// Now Playing) should offer the same set of actions. Putting that set here
/// instead of inside one page is the difference between a capability and a
/// patch: a new surface gets the menu for free, and a new action lands in all
/// of them at once.
///
/// Two entry points:
///
/// * [showSongActionsMenu] opens at a pointer position, for right-click.
/// * [SongActionsMenuButton] renders the same menu from an on-screen `…`
///   button, for the player bar and the Now Playing header.
Future<void> showSongActionsMenu(
  BuildContext context,
  WidgetRef ref,
  Offset position,
  PlaybackItem item, {
  bool inQueue = false,
  ThemeStringKey? headerKey,
  Future<void> Function()? onDelete,
}) async {
  // A second detector in the same gesture must not stack a second menu.
  if (_menuOpen) {
    return;
  }
  _menuOpen = true;
  try {
    await _showSongActionsMenu(
      context,
      ref,
      position,
      item,
      inQueue: inQueue,
      headerKey: headerKey,
      onDelete: onDelete,
    );
  } finally {
    _menuOpen = false;
  }
}

Future<void> _showSongActionsMenu(
  BuildContext context,
  WidgetRef ref,
  Offset position,
  PlaybackItem item, {
  bool inQueue = false,
  ThemeStringKey? headerKey,
  Future<void> Function()? onDelete,
}) async {
  final strings = ref.read(activeThemeStringsProvider);
  final selected = await showMenu<SongMenuAction>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx,
      position.dy,
    ),
    items: _menuItems(
      strings: strings,
      inQueue: inQueue,
      showDelete: inQueue || onDelete != null,
      header: headerKey == null ? null : strings.resolve(headerKey),
    ),
  );
  if (selected != null && context.mounted) {
    await _handleAction(context, ref, selected, item, onDelete: onDelete);
  }
}

/// The `…` button form of [showSongActionsMenu].
///
/// The button owns its own anchor math, so a caller only has to place it.
class SongActionsMenuButton extends ConsumerWidget {
  const SongActionsMenuButton({
    super.key,
    required this.item,
    this.inQueue = false,
    this.icon = Icons.more_horiz,
    this.iconSize,
    this.tooltipKey = ThemeStringKey.playerMore,
    this.color,
    this.headerKey,
    this.onDelete,
  });

  final PlaybackItem item;
  final bool inQueue;
  final IconData icon;
  final double? iconSize;
  final ThemeStringKey tooltipKey;
  final Color? color;

  /// Optional group name rendered above the actions.
  ///
  /// The Now Playing surface layers its menu ("song actions" then "lyric
  /// actions"); a plain result list has no such split and leaves this null.
  final ThemeStringKey? headerKey;

  /// Removes the song from the surface the user is looking at.
  ///
  /// The queue removes itself, a local library row deletes the file entry and
  /// a playlist detaches the track, so the caller owns the meaning and the
  /// menu only owns the gesture. Null hides the row: a plugin search result
  /// has nothing to delete, and offering a dead action is worse than a shorter
  /// menu.
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    return Builder(
      builder: (context) => IconButton(
        tooltip: strings.resolve(tooltipKey),
        iconSize: iconSize,
        color: color,
        icon: Icon(icon),
        onPressed: () {
          final box = context.findRenderObject() as RenderBox?;
          final origin = box == null
              ? Offset.zero
              : box.localToGlobal(box.size.bottomLeft(Offset.zero));
          showSongActionsMenu(
            context,
            ref,
            origin + const Offset(0, 4),
            item,
            inQueue: inQueue,
            headerKey: headerKey,
            onDelete: onDelete,
          );
        },
      ),
    );
  }
}

/// Wraps [child] so a secondary tap opens [showSongActionsMenu].
///
/// Right-click on desktop and long-press on touch both funnel here, so a row
/// does not have to know which platform it is on.
///
/// A long-press gesture spans every subsequent pointer event, so on a trackpad
/// it swallowed the window-drag pan that should have followed a stationary
/// chord. Right-click stays immediate because it is a single event; the menu
/// that a touch long-press opens is provided by the surface's own handlers
/// where the trade-off is acceptable.
class SongContextMenuRegion extends ConsumerWidget {
  const SongContextMenuRegion({
    super.key,
    required this.item,
    required this.child,
    this.inQueue = false,
    this.headerKey,
    this.onDelete,
  });

  final PlaybackItem item;
  final bool inQueue;
  final Widget child;

  /// Optional group name; see [SongActionsMenuButton.headerKey].
  final ThemeStringKey? headerKey;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (details) => showSongActionsMenu(
        context,
        ref,
        details.globalPosition,
        item,
        inQueue: inQueue,
        headerKey: headerKey,
        onDelete: onDelete,
      ),
      child: child,
    );
  }
}

Future<void> _handleAction(
  BuildContext context,
  WidgetRef ref,
  SongMenuAction action,
  PlaybackItem item, {
  Future<void> Function()? onDelete,
}) async {
  final player = ref.read(playerControllerProvider.notifier);
  switch (action) {
    case SongMenuAction.play:
      await player.playItem(item);
    case SongMenuAction.playNext:
      await _playNext(ref, item);
    case SongMenuAction.addToLiked:
      await ref.read(playlistControllerProvider.notifier).toggleFavorite(item);
    case SongMenuAction.addToPlaylist:
      await showDialog<void>(
        context: context,
        builder: (context) => SongAddToPlaylistDialog(item: item),
      );
    case SongMenuAction.download:
      await ref.read(downloadControllerProvider.notifier).startDownload(item);
    case SongMenuAction.share:
      await Clipboard.setData(ClipboardData(text: songShareText(item)));
      if (context.mounted) {
        _toast(context, ref, ThemeStringKey.actionCopiedShareLink);
      }
    case SongMenuAction.delete:
      if (onDelete != null) {
        await onDelete();
      } else {
        await player.removeFromQueue(item.id);
      }
    case SongMenuAction.copyInfo:
      await Clipboard.setData(ClipboardData(text: songInfoText(item)));
      if (context.mounted) {
        _toast(context, ref, ThemeStringKey.actionCopiedSongInfo);
      }
  }
}

/// Inserts [item] directly behind whatever is playing.
///
/// The queue edit lives in the controller because only it can change the list
/// without disturbing the audio engine. An earlier version rebuilt the whole
/// queue from here and reloaded the current track to put the playhead back,
/// which restarted the song the user was listening to; queueing a track must
/// never touch what is playing.
Future<void> _playNext(WidgetRef ref, PlaybackItem item) async {
  await ref.read(playerControllerProvider.notifier).insertAfterCurrent(item);
}

List<PopupMenuEntry<SongMenuAction>> _menuItems({
  required ThemeStrings strings,
  required bool inQueue,
  required bool showDelete,
  String? header,
}) {
  return <PopupMenuEntry<SongMenuAction>>[
    if (header != null) ...<PopupMenuEntry<SongMenuAction>>[
      PopupMenuItem<SongMenuAction>(
        enabled: false,
        height: 30,
        child: Text(
          header,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
      const PopupMenuDivider(),
    ],
    PopupMenuItem<SongMenuAction>(
      value: SongMenuAction.play,
      child: _MenuRow(
        icon: Icons.play_arrow,
        label: strings.resolve(ThemeStringKey.actionPlay),
      ),
    ),
    PopupMenuItem<SongMenuAction>(
      value: SongMenuAction.playNext,
      child: _MenuRow(
        icon: Icons.skip_next,
        label: strings.resolve(ThemeStringKey.actionPlayNext),
      ),
    ),
    const PopupMenuDivider(),
    PopupMenuItem<SongMenuAction>(
      value: SongMenuAction.addToLiked,
      child: _MenuRow(
        icon: Icons.favorite_border,
        label: strings.resolve(ThemeStringKey.playerAddToLiked),
      ),
    ),
    PopupMenuItem<SongMenuAction>(
      value: SongMenuAction.addToPlaylist,
      child: _MenuRow(
        icon: Icons.playlist_add,
        label: strings.resolve(ThemeStringKey.playerAddToPlaylist),
        trailing: Icons.chevron_right,
      ),
    ),
    PopupMenuItem<SongMenuAction>(
      value: SongMenuAction.download,
      child: _MenuRow(
        icon: Icons.download_outlined,
        label: strings.resolve(ThemeStringKey.actionDownload),
        trailing: Icons.chevron_right,
      ),
    ),
    PopupMenuItem<SongMenuAction>(
      value: SongMenuAction.share,
      child: _MenuRow(
        icon: Icons.share_outlined,
        label: strings.resolve(ThemeStringKey.actionShare),
      ),
    ),
    const PopupMenuDivider(),
    if (showDelete)
      PopupMenuItem<SongMenuAction>(
        value: SongMenuAction.delete,
        child: _MenuRow(
          icon: Icons.delete_outline,
          label: strings.resolve(ThemeStringKey.actionDelete),
        ),
      ),
    PopupMenuItem<SongMenuAction>(
      value: SongMenuAction.copyInfo,
      child: _MenuRow(
        icon: Icons.copy_outlined,
        label: strings.resolve(ThemeStringKey.actionCopySongInfo),
      ),
    ),
  ];
}

/// One menu row.
///
/// `ListTile` inside a `PopupMenuItem` is the usual shortcut, but its default
/// 56dp minimum height made the menu taller than the mockup. This draws the
/// icon + label + optional chevron at the design's denser rhythm.
class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.trailing});

  final IconData icon;
  final String label;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5),
          ),
        ),
        if (trailing != null) Icon(trailing, size: 16),
      ],
    );
  }
}

void _toast(BuildContext context, WidgetRef ref, ThemeStringKey key) {
  if (!context.mounted) {
    return;
  }
  final strings = ref.read(activeThemeStringsProvider);
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(strings.resolve(key))));
}

/// Human-readable song information, used by "copy song info" and sharing.
String songInfoText(PlaybackItem item) {
  return <String>[
    item.title,
    if (item.artist?.trim().isNotEmpty == true) item.artist!.trim(),
    if (item.album?.trim().isNotEmpty == true) item.album!.trim(),
  ].join(' - ');
}

/// A link-shaped share string.
///
/// Plugin songs have an opaque `musicId` and no public URL, so this is a
/// descriptive identifier rather than a claim that the link resolves.
String songShareText(PlaybackItem item) {
  if (item.isPlugin) {
    return '${item.platform ?? 'music'}://${item.musicId ?? item.id}';
  }
  return item.localPath ?? songInfoText(item);
}

/// The shared "add to playlist" dialog.
class SongAddToPlaylistDialog extends ConsumerWidget {
  const SongAddToPlaylistDialog({super.key, required this.item});

  final PlaybackItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistControllerProvider);
    final strings = ref.watch(activeThemeStringsProvider);
    return AlertDialog(
      title: Text(strings.resolve(ThemeStringKey.playerAddToPlaylist)),
      // The dialog sizes its content with `IntrinsicWidth`, which a lazy
      // viewport cannot answer: a shrink-wrapping `ListView` here threw on
      // every layout pass, so nothing painted, every frame logged a
      // `RenderShrinkWrappingViewport` assertion, and the dialog's barrier
      // stayed on top — the app looked frozen until it was restarted.
      // A `SingleChildScrollView` around a plain `Column` answers intrinsic
      // width, and still scrolls because the dialog clips it to the space it
      // can spare.
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: playlists.when(
            loading: () => const SizedBox(
              height: 64,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => Text(error.toString()),
            data: (playlists) {
              final normal = playlists
                  .where((playlist) => !playlist.isFavorites)
                  .toList(growable: false);
              if (normal.isEmpty) {
                return Text(
                  strings.resolve(ThemeStringKey.playerPlaylistEmpty),
                );
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final playlist in normal)
                    ListTile(
                      leading: const Icon(Icons.queue_music),
                      title: Text(playlist.name),
                      onTap: () async {
                        await ref
                            .read(playlistControllerProvider.notifier)
                            .addItem(playlist.id, item);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.resolve(ThemeStringKey.actionCancel)),
        ),
      ],
    );
  }
}

enum SongMenuAction {
  play,
  playNext,
  addToLiked,
  addToPlaylist,
  download,
  share,
  delete,
  copyInfo,
}
