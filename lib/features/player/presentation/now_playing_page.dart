import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../../app/desktop_tray_controller.dart';
import '../../../core/debug/ime_trace.dart';
import '../../../core/layout/window_size_class.dart';
import '../../../core/theme/application/theme_providers.dart';
import '../../../core/theme/domain/theme_strings.dart';
import '../../../core/theme/infrastructure/token_resolver.dart';
import '../../../shared/widgets/search_action_button.dart';
import '../../../shared/widgets/horizontal_wheel_scroll.dart';
import '../../../shared/widgets/window_control_button.dart';
import '../../lyrics/application/lyrics_providers.dart';
import '../../playlists/application/playlist_providers.dart';
import '../../playlists/infrastructure/playlist_repository.dart';
import '../../plugin/application/plugin_controller.dart';
import '../../plugin/domain/plugin_definition.dart';
import '../application/player_providers.dart';
import '../domain/playback_item.dart';
import 'artwork_view.dart';
import 'progress_slider.dart';

const _lyricsSystemEnabled = true;

/// Keeps the lyric pane scrollable while suppressing the transient scrollbar.
///
/// Auto-following the active line calls `jumpTo`, and Material's scrollbar
/// animates in for even programmatic jumps. The lyrics are a reading surface,
/// not a scrollable document chrome; wheel drag and touch still work.
class _NoScrollbarScrollBehavior extends MaterialScrollBehavior {
  const _NoScrollbarScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class NowPlayingPage extends ConsumerWidget {
  const NowPlayingPage({
    super.key,
    this.immersive = false,
    this.onClose,
    this.showWindowControls = false,
  });

  /// True when this page is covering the whole shell as an immersive layer.
  ///
  /// The immersive variant owns its close affordance and never pushes a
  /// route, so opening and closing it does not disturb the shell's tab.
  final bool immersive;
  final VoidCallback? onClose;
  final bool showWindowControls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sizeClass = WindowSizeClass.of(context);
    final desktopWindowControls =
        showWindowControls && !sizeClass.isCompactWidth;
    final item = ref.watch(
      playerControllerProvider.select((value) => value.value?.currentItem),
    );
    final strings = ref.watch(activeThemeStringsProvider);
    final content = item == null
        ? Center(
            child: Text(strings.resolve(ThemeStringKey.playerNothingPlaying)),
          )
        : _PlayerContent(item: item, immersive: immersive);
    if (!immersive) {
      return content;
    }
    final tokens = RobyneTheme.of(context).tokens;
    return _ImmersivePlayerChrome(
      showWindowControls: desktopWindowControls,
      onClose: onClose,
      onCloseWindow: () async {
        await ref.read(desktopTrayControllerProvider).onTitleBarClose();
      },
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ColoredBox(color: tokens.color.backgroundBase),
          if (item?.artworkUrl != null)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: tokens.effects.blur.clamp(1, 40),
                  sigmaY: tokens.effects.blur.clamp(1, 40),
                ),
                child: ArtworkView(
                  artworkUrl: item!.artworkUrl,
                  size: MediaQuery.sizeOf(context).longestSide,
                ),
              ),
            ),
          Positioned.fill(
            child: ColoredBox(
              color: tokens.color.backgroundBase.withValues(alpha: 0.72),
            ),
          ),
          // Reserve the close row above the body: the body used to start at
          // y=0 and fight the button for the same pixels, which is what pushed
          // the two-pane layout 13dp past a 900dp viewport.
          Positioned.fill(top: 56, child: SafeArea(top: false, child: content)),
        ],
      ),
    );
  }
}

/// Owns the immersive player's auto-hiding desktop chrome.
class _ImmersivePlayerChrome extends StatefulWidget {
  const _ImmersivePlayerChrome({
    required this.showWindowControls,
    required this.onClose,
    required this.onCloseWindow,
    required this.child,
  });

  final bool showWindowControls;
  final VoidCallback? onClose;
  final Future<void> Function() onCloseWindow;
  final Widget child;

  @override
  State<_ImmersivePlayerChrome> createState() => _ImmersivePlayerChromeState();
}

class _ImmersivePlayerChromeState extends State<_ImmersivePlayerChrome> {
  Timer? _hideTimer;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    if (widget.showWindowControls) {
      _scheduleHide();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showWindowControls) {
      // Touch has no hover state, so the phone's close control is a
      // persistent part of the layout rather than part of the auto-hiding
      // desktop chrome: hiding it is what stranded the user in this surface.
      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          widget.child,
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 40,
                child: IconButton(
                  key: const Key('now-playing-close'),
                  tooltip: '返回',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                ),
              ),
            ),
          ),
        ],
      );
    }
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    return MouseRegion(
      onEnter: (_) {
        _show();
      },
      onHover: (_) => _show(),
      onExit: (_) {
        _hideTimer?.cancel();
        _hideTimer = Timer(const Duration(seconds: 1), _hide);
      },
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          widget.child,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 56,
            child: GestureDetector(
              key: const Key('now-playing-drag-region'),
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => windowManager.startDragging(),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !_visible,
              child: AnimatedOpacity(
                key: const Key('now-playing-window-controls'),
                opacity: _visible ? 1 : 0,
                duration: tokens.components.motion.short,
                curve: tokens.components.motion.curve.toCurve,
                child: SafeArea(
                  bottom: false,
                  child: SizedBox(
                    height: 40,
                    child: Row(
                      children: <Widget>[
                        if (widget.onClose != null)
                          IconButton(
                            key: const Key('now-playing-close'),
                            tooltip: '返回',
                            color: colors.textSecondary,
                            onPressed: widget.onClose,
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              size: 20,
                            ),
                          ),
                        const Spacer(),
                        WindowControlButton(
                          key: const Key('now-playing-window-minimize'),
                          icon: Icons.horizontal_rule,
                          tooltip: '最小化',
                          onPressed: () => unawaited(windowManager.minimize()),
                        ),
                        WindowControlButton(
                          key: const Key('now-playing-window-maximize'),
                          icon: Icons.crop_square,
                          tooltip: '最大化',
                          onPressed: () => unawaited(_toggleMaximize()),
                        ),
                        WindowControlButton(
                          key: const Key('now-playing-window-close'),
                          icon: Icons.close,
                          tooltip: '关闭',
                          destructive: true,
                          onPressed: () => unawaited(widget.onCloseWindow()),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _show() {
    _hideTimer?.cancel();
    if (!_visible && mounted) {
      setState(() => _visible = true);
    }
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 1), _hide);
  }

  void _hide() {
    _hideTimer = null;
    if (mounted && _visible) {
      setState(() => _visible = false);
    }
  }

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
      return;
    }
    await windowManager.maximize();
  }
}

class _PlayerContent extends ConsumerWidget {
  const _PlayerContent({required this.item, this.immersive = false});

  final PlaybackItem item;

  /// True when this is the full-window player. The design drops the per-track
  /// actions there (spec §4.3: "不出现第二套播放按钮") and gives the artwork a
  /// progress line instead, so the immersive variant is not just a bigger
  /// copy of the destination page.
  final bool immersive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    final playlists = ref.watch(playlistControllerProvider).value;
    final favorite =
        playlists
            ?.where((playlist) => playlist.id == PlaylistRepository.favoritesId)
            .any(
              (playlist) => playlist.items.any(
                (playlistItem) => playlistItem.id == item.id,
              ),
            ) ??
        false;

    final sizeClass = WindowSizeClass.of(context);
    final padding = sizeClass.isCompactWidth ? 16.0 : 32.0;

    // The 340dp art column was fixed: on a 400dp-wide phone the content area
    // is ~336dp, so art + divider + lyrics overflowed and the lyrics pane was
    // pushed off-screen entirely. Every extent is now derived from the
    // viewport. See ADR-001 decision D4.
    final artSize = sizeClass.clampDimension(300, maxRatio: 0.62);
    final metadata = _NowPlayingMetadata(
      item: item,
      favorite: favorite,
      artworkSize: artSize,
      immersive: immersive,
    );

    if (sizeClass.isCompactWidth) {
      // Compact width: the two panes cannot share the axis, so they become
      // tabs. This is the Material list-detail pattern; stacking them would
      // give each pane ~80dp of height on a landscape phone.
      return DefaultTabController(
        length: 2,
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            children: <Widget>[
              TabBar(
                tabs: <Tab>[
                  Tab(
                    icon: const Icon(Icons.album_outlined),
                    text: strings.resolve(ThemeStringKey.nowPlayingTabNow),
                  ),
                  Tab(
                    icon: const Icon(Icons.lyrics_outlined),
                    text: strings.resolve(ThemeStringKey.nowPlayingTabLyrics),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: <Widget>[
                    SingleChildScrollView(child: metadata),
                    _lyricsSystemEnabled
                        ? _LyricsPane(item: item)
                        : const _LyricsDisabledPane(),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Compact *height* with a non-compact width (landscape phone): keep both
    // panes side by side but shrink the art so the lyrics keep usable height.
    final artColumnWidth = artSize + (sizeClass.isCompactHeight ? 16 : 40);

    // Two panes share the width. Both are allowed to scroll internally, but
    // neither is wrapped in an outer scroll view: the lyrics pane is itself a
    // viewport, and nesting it under an unbounded axis is what produced the
    // compact-height overflow this layout used to have.
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: artColumnWidth,
            child: SingleChildScrollView(child: metadata),
          ),
          const VerticalDivider(width: 48),
          Expanded(
            child: _lyricsSystemEnabled
                ? _LyricsPane(item: item)
                : const _LyricsDisabledPane(),
          ),
        ],
      ),
    );
  }
}

/// Cover art plus title/artist/actions, shared by every layout variant.
class _NowPlayingMetadata extends StatelessWidget {
  const _NowPlayingMetadata({
    required this.item,
    required this.favorite,
    required this.artworkSize,
    this.immersive = false,
  });

  final PlaybackItem item;
  final bool favorite;
  final double artworkSize;
  final bool immersive;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      // The full-window player centres the art and its caption into a single
      // column (`desktop-library.png`); the in-shell page keeps them
      // left-aligned because it shares the row with the lyrics pane.
      crossAxisAlignment: immersive
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: <Widget>[
        ArtworkView(artworkUrl: item.artworkUrl, size: artworkSize),
        if (immersive) ...<Widget>[
          const SizedBox(height: 12),
          const _NowPlayingProgressLine(),
        ],
        const SizedBox(height: 16),
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: immersive ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: tokens.typography.resolvedSectionTitleSize,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          // The mockup's caption is artist over album; the platform is a
          // routing detail that does not belong in the artwork lockup.
          immersive
              ? <String?>[item.artist, item.album]
                    .whereType<String>()
                    .where((value) => value.isNotEmpty)
                    .join(' · ')
              : <String?>[item.artist, item.album, item.platform]
                    .whereType<String>()
                    .where((value) => value.isNotEmpty)
                    .join(' - '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: immersive ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: immersive
                ? tokens.typography.resolvedLabelSize
                : tokens.typography.resolvedListSecondarySize,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        // The immersive page used to drop the actions entirely, so the lyric
        // search, the local-lyric import and add-to-playlist had no way to be
        // reached from the player the user actually sees. They centre there
        // because the whole column does, and align left on the split layout.
        Align(
          alignment: immersive ? Alignment.center : Alignment.centerLeft,
          child: _NowPlayingActions(item: item, favorite: favorite),
        ),
      ],
    );
  }
}

/// The draggable scrub line under the artwork on the full-window player.
class _NowPlayingProgressLine extends ConsumerWidget {
  const _NowPlayingProgressLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RobyneTheme.of(context).tokens;
    final comp = tokens.components.playerBar;
    final snapshotValue = ref.watch(playerSnapshotsProvider);
    final playerState = ref.watch(playerControllerProvider).value;
    final snapshot = snapshotValue.value;
    final duration =
        snapshot?.duration ??
        playerState?.lastDuration ??
        playerState?.currentItem?.duration ??
        Duration.zero;
    final position =
        snapshot?.position ?? playerState?.lastPosition ?? Duration.zero;
    final maxPosition = duration.inMilliseconds <= 0
        ? 1.0
        : duration.inMilliseconds.toDouble();
    final currentPosition = position.inMilliseconds
        .clamp(0, maxPosition.toInt())
        .toDouble();
    final canSeek =
        snapshot?.currentSource != null || playerState?.currentItem != null;
    return ProgressSlider(
      key: const Key('now-playing-progress'),
      value: currentPosition,
      max: maxPosition,
      activeColor: comp.progressActive,
      inactiveColor: comp.progressTrack,
      onChangeEnd: canSeek
          ? (value) => ref
                .read(playerControllerProvider.notifier)
                .seek(Duration(milliseconds: value.round()))
          : null,
    );
  }
}

class _NowPlayingActions extends ConsumerWidget {
  const _NowPlayingActions({required this.item, required this.favorite});

  final PlaybackItem item;
  final bool favorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    return Row(
      children: <Widget>[
        IconButton.filledTonal(
          tooltip: favorite
              ? strings.resolve(ThemeStringKey.playerRemoveFromLiked)
              : strings.resolve(ThemeStringKey.playerAddToLiked),
          icon: Icon(favorite ? Icons.favorite : Icons.favorite_border),
          onPressed: () => ref
              .read(playlistControllerProvider.notifier)
              .toggleFavorite(item),
        ),
        const SizedBox(width: 8),
        _NowPlayingMenu(item: item),
      ],
    );
  }
}

class _NowPlayingMenu extends ConsumerWidget {
  const _NowPlayingMenu({required this.item});

  final PlaybackItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    return PopupMenuButton<String>(
      tooltip: strings.resolve(ThemeStringKey.playerMore),
      icon: const Icon(Icons.more_horiz),
      onSelected: (value) async {
        switch (value) {
          case 'search':
            await showDialog<void>(
              context: context,
              builder: (context) => _LyricSearchDialog(item: item),
            );
          case 'local':
            final path = await FilePicker.pickFiles(
              type: FileType.custom,
              allowedExtensions: const <String>['lrc', 'txt'],
            );
            final filePath = path?.files.single.path;
            if (filePath != null) {
              await ref
                  .read(lyricRepositoryProvider)
                  .associateLocalFile(item, filePath);
              ref.invalidate(storedCurrentLyricsProvider);
            }
          case 'playlist':
            await showDialog<void>(
              context: context,
              builder: (context) => _AddToPlaylistDialog(item: item),
            );
          case 'clear':
            await ref.read(lyricRepositoryProvider).clearAssociation(item);
            ref.read(lyricLiveOffsetProvider(item.id).notifier).setOffset(null);
            ref.invalidate(storedCurrentLyricsProvider);
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        if (_lyricsSystemEnabled) ...<PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            value: 'search',
            child: ListTile(
              leading: Icon(Icons.manage_search),
              title: Text(strings.resolve(ThemeStringKey.playerSearchLyric)),
            ),
          ),
          PopupMenuItem<String>(
            value: 'local',
            child: ListTile(
              leading: Icon(Icons.file_open),
              title: Text(strings.resolve(ThemeStringKey.playerLinkLocalLyric)),
            ),
          ),
          PopupMenuItem<String>(
            value: 'offset',
            enabled: false,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            height: 124,
            child: _LyricOffsetMenuPanel(item: item),
          ),
        ],
        PopupMenuItem<String>(
          value: 'playlist',
          child: ListTile(
            leading: Icon(Icons.playlist_add),
            title: Text(strings.resolve(ThemeStringKey.playerAddToPlaylist)),
          ),
        ),
        if (_lyricsSystemEnabled)
          PopupMenuItem<String>(
            value: 'clear',
            child: ListTile(
              leading: const Icon(Icons.link_off),
              title: Text(strings.resolve(ThemeStringKey.playerClearLyricLink)),
            ),
          ),
      ],
    );
  }
}

class _LyricsDisabledPane extends ConsumerWidget {
  const _LyricsDisabledPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    return Center(
      child: Text(
        strings.resolve(ThemeStringKey.playerLyricsDisabled),
        style: TextStyle(
          fontSize: RobyneTheme.of(
            context,
          ).tokens.typography.resolvedListPrimarySize,
          color: RobyneTheme.of(context).tokens.color.textMuted,
        ),
      ),
    );
  }
}

class _AddToPlaylistDialog extends ConsumerWidget {
  const _AddToPlaylistDialog({required this.item});

  final PlaybackItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistControllerProvider);
    final strings = ref.watch(activeThemeStringsProvider);
    return AlertDialog(
      title: Text(strings.resolve(ThemeStringKey.playerAddToPlaylist)),
      // A 420dp dialog on a 400dp screen overflows by 400dp. The width is a
      // preference, not a requirement. See ADR-001 decision D4.
      content: SizedBox(
        width: RobyneDialogWidth.forContext(context, 420),
        child: playlists.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Text(error.toString()),
          data: (playlists) {
            final normalPlaylists = playlists
                .where((playlist) => !playlist.isFavorites)
                .toList(growable: false);
            if (normalPlaylists.isEmpty) {
              return Text(strings.resolve(ThemeStringKey.playerPlaylistEmpty));
            }
            return ListView(
              shrinkWrap: true,
              children: <Widget>[
                for (final playlist in normalPlaylists)
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
    );
  }
}

class _LyricsPane extends ConsumerStatefulWidget {
  const _LyricsPane({required this.item});

  final PlaybackItem item;

  @override
  ConsumerState<_LyricsPane> createState() => _LyricsPaneState();
}

class _LyricsPaneState extends ConsumerState<_LyricsPane> {
  static const _lyricLineExtent = 56.0;

  final _scrollController = ScrollController();
  int _lastActiveIndex = -1;
  Duration? _lastDocumentOffset;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshotPosition = ref.watch(
      playerSnapshotsProvider.select((value) {
        final snapshot = value.value;
        return (
          hasSource: snapshot?.currentSource != null,
          seconds: snapshot?.position.inSeconds ?? 0,
        );
      }),
    );
    final position = snapshotPosition.hasSource
        ? Duration(seconds: snapshotPosition.seconds)
        : ref.watch(
            playerControllerProvider.select(
              (value) => value.value?.lastPosition ?? Duration.zero,
            ),
          );
    final lyrics = ref.watch(currentLyricsProvider);
    final tokens = RobyneTheme.of(context).tokens;
    final strings = ref.watch(activeThemeStringsProvider);
    return lyrics.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text(error.toString())),
      data: (document) {
        if (document == null || document.lines.isEmpty) {
          return Center(
            child: Text(strings.resolve(ThemeStringKey.playerLyricsEmpty)),
          );
        }
        if (document.offset != _lastDocumentOffset) {
          _lastDocumentOffset = document.offset;
          _lastActiveIndex = -1;
        }
        final activeIndex = document.activeIndex(position);
        if (activeIndex != _lastActiveIndex && activeIndex >= 0) {
          _lastActiveIndex = activeIndex;
          _scrollActiveLineIntoView(activeIndex);
        }
        return ExcludeSemantics(
          child: ScrollConfiguration(
            behavior: const _NoScrollbarScrollBehavior(),
            child: ListView.builder(
              controller: _scrollController,
              itemExtent: _lyricLineExtent,
              itemCount: document.lines.length,
              itemBuilder: (context, index) {
                final line = document.lines[index];
                final active = index == activeIndex;
                return DefaultTextStyle(
                  style: TextStyle(
                    fontSize: active
                        ? tokens.typography.resolvedSectionTitleSize
                        : tokens.typography.resolvedListPrimarySize,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    color: active
                        ? tokens.components.lyric.activeLine
                        : tokens.components.lyric.inactiveLine,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      line.text.isEmpty ? '...' : line.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _scrollActiveLineIntoView(int activeIndex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final position = _scrollController.position;
      final target =
          activeIndex * _lyricLineExtent -
          (position.viewportDimension - _lyricLineExtent) / 2;
      _scrollController.jumpTo(
        target.clamp(0, position.maxScrollExtent).toDouble(),
      );
    });
  }
}

class _LyricOffsetMenuPanel extends ConsumerStatefulWidget {
  const _LyricOffsetMenuPanel({required this.item});

  final PlaybackItem item;

  @override
  ConsumerState<_LyricOffsetMenuPanel> createState() =>
      _LyricOffsetMenuPanelState();
}

class _LyricOffsetMenuPanelState extends ConsumerState<_LyricOffsetMenuPanel> {
  double _offsetMs = 0;
  Duration? _queuedOffset;
  bool _persistingOffset = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      final offset = await ref
          .read(lyricRepositoryProvider)
          .offsetForItem(widget.item.id);
      if (mounted) {
        setState(() {
          _offsetMs = offset.inMilliseconds.toDouble();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final strings = ref.watch(activeThemeStringsProvider);
    return SizedBox(
      width: RobyneDialogWidth.forContext(context, 280),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.tune, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.resolve(ThemeStringKey.playerLyricOffset),
                  style: TextStyle(
                    fontSize: tokens.typography.resolvedListPrimarySize,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${(_offsetMs / 1000).toStringAsFixed(2)}s',
                style: TextStyle(fontSize: 11, color: colors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            key: const Key('lyric-offset-slider'),
            min: -10000,
            max: 10000,
            divisions: 80,
            value: _offsetMs.clamp(-10000, 10000).toDouble(),
            onChanged: _applyOffset,
          ),
          Text(
            strings.resolve(ThemeStringKey.playerLyricOffsetHint),
            style: TextStyle(fontSize: 11, color: colors.textMuted),
          ),
        ],
      ),
    );
  }

  void _applyOffset(double value) {
    final offset = Duration(milliseconds: value.round());
    setState(() {
      _offsetMs = value;
    });
    ref
        .read(lyricLiveOffsetProvider(widget.item.id).notifier)
        .setOffset(offset);
    _queuedOffset = offset;
    if (!_persistingOffset) {
      unawaited(_drainOffsetWrites());
    }
  }

  Future<void> _drainOffsetWrites() async {
    _persistingOffset = true;
    try {
      while (mounted && _queuedOffset != null) {
        final offset = _queuedOffset!;
        _queuedOffset = null;
        await ref.read(lyricRepositoryProvider).setOffset(widget.item, offset);
        ref.invalidate(storedCurrentLyricsProvider);
      }
    } finally {
      _persistingOffset = false;
      if (mounted && _queuedOffset != null) {
        unawaited(_drainOffsetWrites());
      }
    }
  }
}

class _LyricSearchDialog extends ConsumerStatefulWidget {
  const _LyricSearchDialog({required this.item});

  final PlaybackItem item;

  @override
  ConsumerState<_LyricSearchDialog> createState() => _LyricSearchDialogState();
}

class _LyricSearchDialogState extends ConsumerState<_LyricSearchDialog> {
  late final TextEditingController _controller;
  bool _autoSearched = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.title);
    attachImeTextControllerTrace(_controller, 'lyrics.searchKeyword');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plugins =
        ref.watch(pluginControllerProvider).value ?? const <PluginDefinition>[];
    if (!_autoSearched && plugins.isNotEmpty) {
      _autoSearched = true;
      Future<void>.microtask(() {
        ref
            .read(lyricSearchControllerProvider.notifier)
            .search(_controller.text, plugins);
      });
    }
    final state =
        ref.watch(lyricSearchControllerProvider).value ??
        const LyricSearchState();
    final selected = state.selectedPluginResult;
    final strings = ref.watch(activeThemeStringsProvider);

    return AlertDialog(
      title: Text(strings.resolve(ThemeStringKey.playerSearchLyricsTitle)),
      content: SizedBox(
        width: RobyneDialogWidth.forContext(context, 720),
        height: RobyneDialogWidth.heightForContext(context, 520),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) {
                      if (state.isSearching) {
                        return;
                      }
                      unawaited(
                        ref
                            .read(lyricSearchControllerProvider.notifier)
                            .search(_controller.text, plugins),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SearchActionButton(
                  isSearching: state.isSearching,
                  searchLabelKey: ThemeStringKey.playerSearchLyricAction,
                  stopLabelKey: ThemeStringKey.playerSearchLyricStop,
                  onSearch: () => unawaited(
                    ref
                        .read(lyricSearchControllerProvider.notifier)
                        .search(_controller.text, plugins),
                  ),
                  onCancel: () =>
                      ref.read(lyricSearchControllerProvider.notifier).cancel(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: HorizontalWheelScroll(
                builder: (context, controller) => ListView.separated(
                  controller: controller,
                  scrollDirection: Axis.horizontal,
                  itemCount: state.pluginResults.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final result = state.pluginResults[index];
                    return ChoiceChip(
                      selected: result.pluginId == selected?.pluginId,
                      label: Text(
                        result.isSearching
                            ? '${result.platform} ...'
                            : result.error != null
                            ? '${result.platform} !'
                            : '${result.platform} ${result.items.length}',
                      ),
                      onSelected: (_) => ref
                          .read(lyricSearchControllerProvider.notifier)
                          .selectPlugin(result.pluginId),
                    );
                  },
                ),
              ),
            ),
            const Divider(height: 24),
            Expanded(
              child: selected == null
                  ? Center(
                      child: Text(
                        strings.resolve(ThemeStringKey.playerLyricPluginsEmpty),
                      ),
                    )
                  : selected.isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : selected.error != null && selected.items.isEmpty
                  ? Center(
                      child: Text(
                        '${selected.error!.code}: ${selected.error!.message}',
                        style: TextStyle(
                          color: RobyneTheme.of(context).tokens.color.danger,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: selected.items.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final candidate = selected.items[index];
                        return ListTile(
                          title: Text(candidate.title),
                          subtitle: Text(
                            <String?>[
                                  candidate.artist,
                                  candidate.album,
                                  candidate.platform,
                                ]
                                .whereType<String>()
                                .where((value) => value.isNotEmpty)
                                .join(' - '),
                          ),
                          onTap: () async {
                            final error = await ref
                                .read(lyricSearchControllerProvider.notifier)
                                .associateCandidate(
                                  item: widget.item,
                                  candidate: candidate,
                                  plugins: plugins,
                                );
                            if (error == null && context.mounted) {
                              Navigator.of(context).pop();
                            } else if (error != null && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${error.code}: ${error.message}',
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
