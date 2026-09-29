import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/window_size_class.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/theme/domain/theme_components.dart';
import '../../../core/theme/application/theme_providers.dart';
import '../../../core/theme/domain/theme_icons.dart';
import '../../../core/theme/domain/theme_strings.dart';
import '../../../core/theme/domain/theme_tokens.dart';
import '../../../core/theme/infrastructure/token_resolver.dart';
import '../../../core/theme/presentation/theme_icon.dart';
import '../../downloads/application/download_providers.dart';
import '../../playlists/application/playlist_providers.dart';
import '../../playlists/infrastructure/playlist_repository.dart';
import '../../settings/application/settings_providers.dart';
import '../application/player_providers.dart';
import '../domain/playback_item.dart';
import 'artwork_view.dart';
import 'progress_slider.dart';

const _tracePlayerBar = bool.fromEnvironment('ROBYNE_PLAYER_TRACE');

class PlayerBar extends ConsumerWidget {
  const PlayerBar({
    super.key,
    this.compactHeight = false,
    this.onOpenNowPlaying,
  });

  /// True when the window is short (landscape phone).
  ///
  /// The bar then collapses to a single-row mini bar: the progress slider and
  /// every secondary transport control go away, because a ~360dp tall window
  /// cannot carry both chrome and content. See ADR-001 decision D5.
  ///
  /// The shell passes this; when the bar is used standalone it derives it from
  /// the viewport, so the behaviour is identical either way.
  final bool compactHeight;

  /// Opens the immersive Now Playing surface.
  ///
  /// Kept as a callback so the bar does not need to know whether it is hosted
  /// by the shell, a test, or a future secondary window.
  final VoidCallback? onOpenNowPlaying;

  /// Icon buttons are 42dp so they are comfortably hittable at every size
  /// class. See `docs/design/UI_DESIGN_SPEC.md` §5.1.
  static const double actionSize = 42;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotValue = ref.watch(playerSnapshotsProvider);
    ref.watch(playbackCompletionListenerProvider);
    final snapshot = snapshotValue.value;
    final playerState = ref.watch(playerControllerProvider).value;
    final error = playerState?.error;
    final hasLoadedSource = snapshot?.currentSource != null;
    final hasRestoredItem = playerState?.currentItem != null;
    final restoreTarget = playerState?.restoreTargetPosition ?? Duration.zero;
    final useRestoredPlaybackState =
        !hasLoadedSource || restoreTarget > Duration.zero;
    final snapshotDuration = snapshot?.duration ?? Duration.zero;
    final restoredDuration = _restoredDuration(
      itemDuration: playerState?.currentItem?.duration,
      lastDuration: playerState?.lastDuration ?? Duration.zero,
    );
    final stableDuration = _stableDuration(
      snapshotDuration: snapshotDuration,
      savedDuration: restoredDuration,
    );
    final duration =
        useRestoredPlaybackState && restoredDuration > Duration.zero
        ? restoredDuration
        : hasLoadedSource && stableDuration > Duration.zero
        ? stableDuration
        : restoredDuration;
    final position = useRestoredPlaybackState
        ? playerState?.lastPosition ?? Duration.zero
        : snapshot?.position ?? Duration.zero;
    final maxPosition = duration.inMilliseconds <= 0
        ? 1.0
        : duration.inMilliseconds.toDouble();
    final currentPosition = position.inMilliseconds
        .clamp(0, maxPosition.toInt())
        .toDouble();
    if (_tracePlayerBar) {
      debugPrint(
        '[ROBYNE_PLAYER_TRACE] PlayerBar '
        'snapshot.position=${snapshot?.position.inMilliseconds} '
        'snapshot.duration=${snapshot?.duration.inMilliseconds} '
        'state.lastPosition=${playerState?.lastPosition.inMilliseconds} '
        'state.lastDuration=${playerState?.lastDuration.inMilliseconds} '
        'item.duration=${playerState?.currentItem?.duration?.inMilliseconds} '
        'state.restoreTarget=${playerState?.restoreTargetPosition.inMilliseconds} '
        'display.position=${position.inMilliseconds} '
        'display.duration=${duration.inMilliseconds} '
        'hasLoadedSource=$hasLoadedSource',
      );
    }

    // Compact *width* hides the desktop-only controls; compact *height*
    // additionally drops the progress row. They are independent axes: a
    // landscape phone can be medium-width and compact-height at once.
    final sizeClass = WindowSizeClass.of(context);
    final isCompactWidth = sizeClass.isCompactWidth;
    final isCompactHeight = compactHeight || sizeClass.isCompactHeight;
    final horizontalPadding = isCompactWidth ? 12.0 : 24.0;
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final comp = tokens.components.playerBar;
    final strings = ref.watch(activeThemeStringsProvider);
    final item = playerState?.currentItem;
    final title =
        item?.title ??
        snapshot?.currentSource?.url ??
        strings.resolve(ThemeStringKey.playerNothingPlaying);
    final canPlay = hasLoadedSource || hasRestoredItem;
    final playing = snapshot?.playing == true;
    final mode = playerState?.playbackMode ?? PlaybackMode.sequence;
    final queueLength = playerState?.queue.length ?? 0;

    final playIcon = playing ? Icons.pause : Icons.play_arrow;
    // `mobile-portrait.png` insets the transport card from the shell edges;
    // `desktop-discover.png` insets it on the sides only, with no bottom gap.
    final compactRadius = tokens.radius.lg;
    final compactMargin = EdgeInsets.fromLTRB(10, 0, 10, 8);
    final fullRadius = tokens.radius.lg;
    final fullMargin = EdgeInsets.fromLTRB(12, 0, 12, 12);
    final void Function()? playAction = playing
        ? () => ref.read(playerControllerProvider.notifier).pause()
        : canPlay
        ? () =>
              ref.read(playerControllerProvider.notifier).resumeOrPlayCurrent()
        : null;

    // Mini bar, straight from `mobile-portrait.png`: artwork, title and
    // artist, then like / more / play / queue. A 52dp row cannot carry a
    // progress line *and* five targets, and the design chose the targets; the
    // same row is also the honest answer for a window too narrow to hold the
    // desktop controls without crowding them.
    final miniBar = _PlayerSurface(
      colors: colors,
      gradient: comp.gradient,
      height: 52,
      radius: compactRadius,
      margin: compactMargin,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isCompactWidth ? 12 : 16),
        child: Row(
          children: <Widget>[
            Expanded(
              // The mockup's phone bar carries no previous/next buttons, so
              // the identity block is the way through to the full transport
              // on the Now Playing page — the controls are moved, not lost.
              child: InkWell(
                key: const Key('player-identity'),
                borderRadius: BorderRadius.all(
                  Radius.circular(tokens.radius.sm),
                ),
                onTap: item == null
                    ? null
                    : (onOpenNowPlaying ??
                          () => ref
                              .read(nowPlayingImmersiveProvider.notifier)
                              .open()),
                child: Row(
                  children: <Widget>[
                    ArtworkView(artworkUrl: item?.artworkUrl, size: 38),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize:
                                  tokens.typography.resolvedListPrimarySize,
                              fontWeight: FontWeight.w600,
                              color: tokens.color.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item?.artist?.trim().isNotEmpty == true
                                ? item!.artist!
                                : _formatPosition(position, duration),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: tokens.typography.resolvedLabelSize,
                              color: tokens.color.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            _LikeButton(item: item, colors: colors),
            _MoreMenu(item: item, colors: colors),
            _PlayerAction(
              icon: playIcon,
              tooltip: playing
                  ? strings.resolve(ThemeStringKey.playerPause)
                  : strings.resolve(ThemeStringKey.playerPlay),
              color: playing ? colors.brandBase : colors.textPrimary,
              onPressed: playAction,
            ),
            _QueueToggle(count: queueLength, colors: colors),
          ],
        ),
      ),
    );

    if (isCompactHeight || isCompactWidth) {
      return miniBar;
    }

    final modeButton = _PlayerAction(
      key: const Key('player-mode-button'),
      icon: _modeIcon(mode),
      tooltip: _modeLabel(strings, mode),
      color: colors.textSecondary,
      onPressed: () => ref
          .read(playerControllerProvider.notifier)
          .setPlaybackMode(_nextMode(mode)),
    );
    final qualityChip = _QualityChip(
      quality: snapshot?.currentSource?.quality,
      colors: colors,
    );

    // One elastic row, exactly the order `desktop-discover.png` draws: meta,
    // like, more, mode, transport, elapsed, track, total, quality, lyric,
    // queue, volume. Only the progress track flexes.
    //
    // The previous version split the row into two fixed-width halves plus a
    // 470dp-capped middle column. Once the window passed that cap every extra
    // pixel went to the identity block, so the transport drifted left of the
    // real centre while the track stayed 470dp wide on a 1936dp bar — the
    // "ugly when maximised" state. A single row has no such cliff: it is the
    // design's own layout at every width.
    //
    // Design spec §5.1 words its breakpoints as window widths, but the bar does
    // not always get the whole window: docking the queue beside it can hand it
    // 720dp inside a 1280dp window. Measuring the bar itself is the only way
    // the thresholds mean what they say, so the desktop-only controls drop out
    // exactly when the space for them disappears.
    final volume = (playerState?.volume ?? snapshot?.volume ?? 100)
        .clamp(0, 100)
        .toDouble();
    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth;
        // Design spec §5.1: below 960 the desktop lyric and volume controls
        // go; below 720 the mode badge goes too. The quality chip stays at
        // both, since it is the one control the spec never drops.
        // The spec's 720 boundary, kept exactly. The 3.6dp that used to
        // overflow here came from the time labels, not the badge, so the
        // labels give way instead of moving the breakpoint.
        final showModeBadge = barWidth >= 720;
        // Below 720 the spec keeps the bar down to "like, more, transport,
        // quality, queue". The skip buttons are what actually overflows at
        // 600dp, and the phone bar already teaches users that this size of
        // bar moves previous/next into the immersive surface.
        final showSkip = barWidth >= 720;
        final showDesktopOnly = barWidth >= 960;
        // The design keeps the meta a bounded column instead of a share that
        // grows with the window. Letting it flex was the other half of the
        // maximised-window bug: extra pixels piled up beside the track title
        // instead of stretching the progress line, which is why the transport
        // looked stranded at 1936dp.
        final identityWidth = (barWidth * 0.18).clamp(120.0, 260.0);
        return _PlayerSurface(
          colors: colors,
          gradient: comp.gradient,
          height: 92,
          radius: fullRadius,
          margin: fullMargin,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                // The design gives the meta a bounded column (~260dp at
                // 1360dp) rather than a share that grows with the window.
                // Letting it flex was the other half of the maximised-window
                // bug: every extra pixel went to empty space beside the track
                // title instead of to the progress line. `Flexible` keeps it
                // honest on narrow bars, where it may have to shrink.
                SizedBox(
                  width: identityWidth,
                  child: _PlayerIdentity(
                    item: item,
                    title: title,
                    error: error,
                    colors: colors,
                    radius: tokens.radius.sm,
                    onTap: item == null
                        ? null
                        : (onOpenNowPlaying ??
                              () => ref
                                  .read(nowPlayingImmersiveProvider.notifier)
                                  .open()),
                  ),
                ),
                _LikeButton(item: item, colors: colors),
                _MoreMenu(item: item, colors: colors),
                if (showModeBadge) ...<Widget>[
                  modeButton,
                  const SizedBox(width: 4),
                ],
                if (showSkip)
                  _PlayerAction(
                    icon: Icons.skip_previous,
                    slot: ThemeIconKey.skipPrevious,
                    tooltip: strings.resolve(ThemeStringKey.playerPrevious),
                    color: colors.textPrimary,
                    onPressed: queueLength == 0
                        ? null
                        : () => ref
                              .read(playerControllerProvider.notifier)
                              .playPrevious(),
                  ),
                _PlayerAction(
                  icon: playIcon,
                  slot: playing ? ThemeIconKey.pause : ThemeIconKey.play,
                  tooltip: playing
                      ? strings.resolve(ThemeStringKey.playerPause)
                      : strings.resolve(ThemeStringKey.playerPlay),
                  color: playing ? colors.brandBase : colors.textPrimary,
                  onPressed: playAction,
                ),
                if (showSkip)
                  _PlayerAction(
                    icon: Icons.skip_next,
                    slot: ThemeIconKey.skipNext,
                    tooltip: strings.resolve(ThemeStringKey.playerNext),
                    color: colors.textPrimary,
                    onPressed: queueLength == 0
                        ? null
                        : () => ref
                              .read(playerControllerProvider.notifier)
                              .playNext(),
                  ),
                const SizedBox(width: 8),
                // Elapsed / total are fixed-width so the thumb never makes
                // the neighbouring labels jitter.
                SizedBox(
                  width: 36,
                  child: Text(
                    _formatElapsed(position),
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 11, color: colors.textMuted),
                  ),
                ),
                const SizedBox(width: 8),
                // The track is the only element that grows. Everything else
                // is fixed or bounded, so a maximised window stretches the
                // progress line instead of leaving the transport stranded
                // left of centre.
                Expanded(
                  flex: 3,
                  // The bar's scrub line matches the full-window player: a
                  // flat line at rest, a thumb only under the pointer, and the
                  // seek committed on release instead of on every pixel.
                  child: ProgressSlider(
                    key: const Key('player-progress-slider'),
                    value: currentPosition,
                    max: maxPosition,
                    thumbRadius: 5,
                    overlayRadius: 10,
                    activeColor: comp.progressActive,
                    inactiveColor: comp.progressTrack,
                    onChangeEnd: canPlay
                        ? (value) => ref
                              .read(playerControllerProvider.notifier)
                              .seek(Duration(milliseconds: value.round()))
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  child: Text(
                    _formatTotalDuration(duration),
                    style: TextStyle(fontSize: 11, color: colors.textMuted),
                  ),
                ),
                const SizedBox(width: 8),
                qualityChip,
                if (showDesktopOnly) ...<Widget>[
                  _DesktopLyricToggle(ref: ref, colors: colors),
                  _QueueToggle(count: queueLength, colors: colors),
                  SizedBox(
                    width: 128,
                    child: _VolumeSlider(
                      value: volume,
                      colors: colors,
                      onChanged: (value) => ref
                          .read(playerControllerProvider.notifier)
                          .setVolume(value),
                    ),
                  ),
                ] else
                  _QueueToggle(count: queueLength, colors: colors),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatPosition(Duration position, Duration duration) {
    return '${_formatElapsed(position)} / ${_formatTotalDuration(duration)}';
  }

  Duration _restoredDuration({
    required Duration? itemDuration,
    required Duration lastDuration,
  }) {
    if (itemDuration == null || itemDuration <= Duration.zero) {
      return lastDuration;
    }
    if (lastDuration <= Duration.zero) {
      return itemDuration;
    }
    return _stableDuration(
      snapshotDuration: lastDuration,
      savedDuration: itemDuration,
    );
  }

  Duration _stableDuration({
    required Duration snapshotDuration,
    required Duration savedDuration,
  }) {
    if (savedDuration <= Duration.zero || snapshotDuration <= Duration.zero) {
      return snapshotDuration;
    }
    final difference = (snapshotDuration - savedDuration).abs();
    if (difference == Duration.zero) {
      return savedDuration;
    }
    if (difference <= const Duration(seconds: 2)) {
      if (snapshotDuration > savedDuration) {
        return savedDuration;
      }
      final adjusted = savedDuration - const Duration(seconds: 1);
      return adjusted > snapshotDuration ? adjusted : snapshotDuration;
    }
    return snapshotDuration;
  }

  String _formatElapsed(Duration duration) {
    return _formatSeconds(duration.inSeconds);
  }

  String _formatTotalDuration(Duration duration) {
    final totalSeconds = (duration.inMilliseconds / 1000).round();
    return _formatSeconds(totalSeconds);
  }

  String _formatSeconds(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60)
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  PlaybackMode _nextMode(PlaybackMode mode) {
    return switch (mode) {
      PlaybackMode.sequence => PlaybackMode.random,
      PlaybackMode.random => PlaybackMode.allLoop,
      PlaybackMode.allLoop => PlaybackMode.singleLoop,
      PlaybackMode.singleLoop => PlaybackMode.sequence,
    };
  }

  IconData _modeIcon(PlaybackMode mode) {
    return switch (mode) {
      PlaybackMode.sequence => Icons.format_list_numbered,
      PlaybackMode.random => Icons.shuffle,
      PlaybackMode.allLoop => Icons.repeat,
      PlaybackMode.singleLoop => Icons.repeat_one,
    };
  }

  String _modeLabel(ThemeStrings strings, PlaybackMode mode) {
    return switch (mode) {
      PlaybackMode.sequence => strings.resolve(ThemeStringKey.modeSequence),
      PlaybackMode.random => strings.resolve(ThemeStringKey.modeRandom),
      PlaybackMode.allLoop => strings.resolve(ThemeStringKey.modeAllLoop),
      PlaybackMode.singleLoop => strings.resolve(ThemeStringKey.modeSingleLoop),
    };
  }
}

/// The player bar surface, painted from `components.playerBar`.
///
/// A skin may give a flat colour or a multi-stop gradient; when it gives
/// neither the bar falls back to the semantic elevated background so an
/// unstyled skin still reads as chrome rather than as content.
///
/// The design floats the transport on a rounded card inset from the shell
/// edges (`desktop-discover.png`), so the region's slot height covers the card
/// *plus* its margin and the card itself is what gets painted.
class _PlayerSurface extends StatelessWidget {
  const _PlayerSurface({
    required this.colors,
    required this.gradient,
    required this.height,
    required this.child,
    this.radius = 0,
    this.margin = EdgeInsets.zero,
  });

  final ThemeColors colors;
  final ThemeGradient gradient;
  final double height;
  final Widget child;

  /// Corner radius of the painted card. Zero keeps a flush, full-bleed bar for
  /// skins that prefer one.
  final double radius;

  /// Space between the slot edges and the card.
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.all(Radius.circular(radius));
    final decoration = BoxDecoration(
      color: gradient.isEmpty ? colors.backgroundElevated : null,
      gradient: gradient.isEmpty
          ? null
          : LinearGradient(
              colors: <Color>[for (final stop in gradient.stops) stop.color],
              stops: <double>[for (final stop in gradient.stops) stop.offset],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
      borderRadius: borderRadius,
      border: radius > 0
          ? Border.all(color: colors.borderSubtle)
          : const Border.fromBorderSide(BorderSide.none),
    );
    // When the shell supplies a height from the skin's ratio, honour exactly
    // that; otherwise fall back to the intrinsic height. Reading the incoming
    // constraint rather than the window means the bar composes wherever it is
    // placed, including the standalone row used by tests.
    return LayoutBuilder(
      builder: (context, constraints) {
        final constrained = constraints.hasBoundedHeight
            ? constraints.maxHeight - margin.top - margin.bottom
            : height;
        return Padding(
          padding: margin,
          child: SizedBox(
            height: constrained < 0 ? 0 : constrained,
            width: constraints.hasBoundedWidth ? constraints.maxWidth : null,
            child: DecoratedBox(
              decoration: decoration,
              // The plan's height is exact, so rounding can leave a fraction
              // of a pixel over budget. Clipping is the honest fix: the card
              // decoration is what yields, the transport row must stay
              // visible.
              child: ClipRRect(borderRadius: borderRadius, child: child),
            ),
          ),
        );
      },
    );
  }
}

/// The identity block: cover, title, artist.
///
/// Kept separate from the transport row so the bar's single `Row` stays
/// readable. The title ellipsises rather than pushing the transport around,
/// which is what lets one elastic bar work at every width.
class _PlayerIdentity extends StatelessWidget {
  const _PlayerIdentity({
    required this.item,
    required this.title,
    required this.error,
    required this.colors,
    required this.radius,
    required this.onTap,
  });

  final PlaybackItem? item;
  final String title;
  final AppError? error;
  final ThemeColors colors;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('player-identity'),
      borderRadius: BorderRadius.all(Radius.circular(radius)),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          ArtworkView(artworkUrl: item?.artworkUrl, size: 46),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                if (error != null)
                  Text(
                    '${error!.code}: ${error!.message}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: colors.danger),
                  )
                else
                  Text(
                    item?.artist ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: colors.textMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single 42dp transport button.
///
/// The size is fixed rather than derived so every control stays hittable at
/// any size class, and so adding a control never reflows the bar.
class _PlayerAction extends StatelessWidget {
  const _PlayerAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
    this.slot,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onPressed;

  /// Which skin icon slot may replace [icon].
  ///
  /// Null for the menus and mode badges, whose glyphs change with state in a
  /// way a single slot cannot express; the transport row is where a skin's
  /// shapes most define its identity, so those are the ones exposed.
  final ThemeIconKey? slot;

  /// Whether the slot is in its selected state (a filled heart, say).
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: PlayerBar.actionSize,
      height: PlayerBar.actionSize,
      child: IconButton(
        tooltip: tooltip,
        icon: slot == null
            ? Icon(icon, size: 22, color: color)
            : ThemeIconView(
                slot: slot!,
                fallback: icon,
                size: 22,
                color: color,
                active: active,
              ),
        // A disabled control still has to be discoverable, so it dims rather
        // than vanishing.
        onPressed: onPressed,
      ),
    );
  }
}

/// The like toggle (design spec §6.2: `PlayerBarActions.like`).
///
/// Optimistic: the icon flips to a filled brand-coloured heart immediately
/// and the repository write happens after, because waiting a database round
/// trip to see feedback feels broken.
class _LikeButton extends ConsumerWidget {
  const _LikeButton({required this.item, required this.colors});

  final PlaybackItem? item;
  final ThemeColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistControllerProvider).value;
    final strings = ref.watch(activeThemeStringsProvider);
    final liked =
        playlists
            ?.where((playlist) => playlist.id == PlaylistRepository.favoritesId)
            .any(
              (playlist) => playlist.items.any((entry) => entry.id == item?.id),
            ) ??
        false;

    return _PlayerAction(
      icon: liked ? Icons.favorite : Icons.favorite_border,
      // One slot with an active variant, not two independent slots: a skin
      // that declares only `like` still gets its heart filled when liked,
      // instead of silently falling back to Material for the filled state.
      slot: ThemeIconKey.like,
      active: liked,
      tooltip: liked
          ? strings.resolve(ThemeStringKey.playerRemoveFromLikedShort)
          : strings.resolve(ThemeStringKey.playerAddToLikedShort),
      color: liked ? colors.brandBase : colors.textSecondary,
      onPressed: item == null
          ? null
          : () => ref
                .read(playlistControllerProvider.notifier)
                .toggleFavorite(item!),
    );
  }
}

/// The overflow menu (design spec §3.5 tier 3).
///
/// Everything here is deliberately *not* a transport control: the bar keeps
/// play/pause/next reachable on a phone and pushes the rest of the
/// long tail in here.
class _MoreMenu extends ConsumerWidget {
  const _MoreMenu({required this.item, required this.colors});

  final PlaybackItem? item;
  final ThemeColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    return SizedBox(
      width: PlayerBar.actionSize,
      height: PlayerBar.actionSize,
      child: PopupMenuButton<String>(
        tooltip: strings.resolve(ThemeStringKey.playerMore),
        icon: Icon(Icons.more_horiz, size: 22, color: colors.textSecondary),
        onSelected: (value) async {
          final current = item;
          if (current == null) {
            return;
          }
          switch (value) {
            case 'download':
              await ref
                  .read(downloadControllerProvider.notifier)
                  .startDownload(current);
            case 'stop':
              await ref.read(playerControllerProvider.notifier).stop();
          }
        },
        itemBuilder: (context) => <PopupMenuEntry<String>>[
          if (item != null)
            PopupMenuItem<String>(
              value: 'download',
              child: ListTile(
                leading: const Icon(Icons.download_outlined),
                title: Text(strings.resolve(ThemeStringKey.playerDownload)),
              ),
            ),
          PopupMenuItem<String>(
            value: 'stop',
            child: ListTile(
              leading: const Icon(Icons.stop_outlined),
              title: Text(strings.resolve(ThemeStringKey.playerStopPlayback)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The queue entry point, with a 1..999+ count badge (design spec §5.1).
class _QueueToggle extends ConsumerWidget {
  const _QueueToggle({required this.count, required this.colors});

  final int count;
  final ThemeColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final override = ref.watch(queuePanelVisibleProvider);
    final strings = ref.watch(activeThemeStringsProvider);
    final isDesktop =
        WindowSizeClass.of(context).width == WindowWidthClass.expanded;
    final docked = override ?? isDesktop;
    final label = count > 999 ? '999+' : '$count';
    return SizedBox(
      width: PlayerBar.actionSize,
      height: PlayerBar.actionSize,
      child: IconButton(
        key: const Key('player-queue-toggle'),
        tooltip: strings.resolve(ThemeStringKey.playerQueue),
        icon: Badge(
          isLabelVisible: count > 0,
          label: Text(label),
          backgroundColor: colors.brandBase,
          textColor: colors.onBrand,
          child: ThemeIconView(
            slot: ThemeIconKey.queue,
            fallback: docked ? Icons.queue_music : Icons.queue_music_outlined,
            size: 22,
            color: docked ? colors.brandBase : colors.textSecondary,
          ),
        ),
        onPressed: () =>
            ref.read(queuePanelVisibleProvider.notifier).setVisible(!docked),
      ),
    );
  }
}

/// The audio-quality chip (design spec §5.1 item 7).
///
/// Lossless reads with the accent colour and everything else reads as a
/// plain surface chip, so the accent always means "better than standard".
class _QualityChip extends ConsumerWidget {
  const _QualityChip({required this.quality, required this.colors});

  final String? quality;
  final ThemeColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RobyneTheme.of(context).tokens;
    final strings = ref.watch(activeThemeStringsProvider);
    final isLossless = _isLossless(quality);
    final label = isLossless
        ? strings.resolve(ThemeStringKey.qualityLossless)
        : strings.resolve(ThemeStringKey.qualityStandard);
    final background = isLossless
        ? colors.accentBase
        : tokens.components.card.surface;
    final foreground = isLossless ? colors.onAccent : colors.textSecondary;

    return Tooltip(
      message: _qualityMessage(strings, quality),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.all(Radius.circular(tokens.radius.full)),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: foreground,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// The chip's tooltip: the raw plugin string, when there is one.
  ///
  /// The plugin value stays as-is rather than being translated — it is data
  /// from the plugin, not chrome the skin authored.
  static String _qualityMessage(ThemeStrings strings, String? quality) {
    if (quality == null) {
      return strings.resolve(ThemeStringKey.qualityUnknown);
    }
    return strings
        .resolve(ThemeStringKey.qualityTooltip)
        .replaceAll('{quality}', quality);
  }

  /// Plugin quality strings are free-form (`sq`, `hq`, `flac`, `无损`...), so
  /// the classification is a substring match rather than an enum compare.
  static bool _isLossless(String? quality) {
    if (quality == null) {
      return false;
    }
    final normalized = quality.toLowerCase();
    return normalized.contains('lossless') ||
        normalized.contains('flac') ||
        normalized.contains('ape') ||
        normalized.contains('wav') ||
        normalized.contains('hi-res') ||
        normalized.contains('hires') ||
        normalized.contains('sq') ||
        normalized.contains('无损');
  }
}

/// The desktop lyric toggle (design spec §6.2: `PlayerBarActions.desktopLyric`).
class _DesktopLyricToggle extends ConsumerWidget {
  const _DesktopLyricToggle({required this.ref, required this.colors});

  final WidgetRef ref;
  final ThemeColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    final enabled =
        this.ref
            .watch(settingsControllerProvider)
            .value
            ?.lyricSettings
            .desktopLyricsEnabled ??
        false;
    return SizedBox(
      width: PlayerBar.actionSize,
      height: PlayerBar.actionSize,
      child: IconButton(
        tooltip: enabled
            ? strings.resolve(ThemeStringKey.playerHideDesktopLyric)
            : strings.resolve(ThemeStringKey.playerShowDesktopLyric),
        icon: ThemeIconView(
          slot: ThemeIconKey.lyric,
          fallback: Icons.lyrics_outlined,
          size: 22,
          color: enabled ? colors.accentBase : colors.textSecondary,
        ),
        onPressed: () => this.ref
            .read(settingsControllerProvider.notifier)
            .toggleDesktopLyricsEnabled(),
      ),
    );
  }
}

/// The volume slider (design spec §6.2: `PlayerBarActions.volume`).
class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({
    required this.value,
    required this.colors,
    required this.onChanged,
  });

  final double value;
  final ThemeColors colors;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ThemeIconView(
          slot: ThemeIconKey.volume,
          fallback: Icons.volume_up,
          size: 20,
          color: colors.textSecondary,
        ),
        // Flexible so a narrow bar narrows the slider instead of overflowing
        // its row: the volume control is the one part of the trailing group
        // that has width to give.
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 96),
            child: Slider(
              key: const Key('player-volume-slider'),
              value: value,
              min: 0,
              max: 100,
              activeColor: colors.brandBase,
              inactiveColor: colors.textMuted,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
