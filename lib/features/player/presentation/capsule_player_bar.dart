import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/theme/application/theme_providers.dart';
import '../../../core/theme/domain/theme_icons.dart';
import '../../../core/theme/domain/theme_strings.dart';
import '../../../core/theme/infrastructure/token_resolver.dart';
import '../../../core/theme/presentation/theme_icon.dart';
import '../../playlists/application/playlist_providers.dart';
import '../../playlists/infrastructure/playlist_repository.dart';
import '../application/capsule_window.dart';
import '../application/player_providers.dart';
import '../domain/playback_item.dart';
import 'artwork_view.dart';

/// The capsule "mini layout" the title bar's capsule entry collapses into.
///
/// A compact pill: a circular cover protruding past the surface, song info at
/// rest and transport controls on hover, and a close button tucked into the
/// trailing edge. Every pixel that is not a button drags the window — the
/// cover included, which the previous build left dead.
class CapsulePlayerBar extends ConsumerStatefulWidget {
  const CapsulePlayerBar({super.key});

  @override
  ConsumerState<CapsulePlayerBar> createState() => _CapsulePlayerBarState();
}

class _CapsulePlayerBarState extends ConsumerState<CapsulePlayerBar> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final strings = ref.watch(activeThemeStringsProvider);
    final state =
        ref.watch(playerControllerProvider).value ??
        const PlayerControllerState();
    final item = state.currentItem;
    final playing = ref.watch(playerSnapshotsProvider).value?.playing == true;
    final queue = state.queue;
    const w = CapsuleWindow.barWidth;
    const h = CapsuleWindow.barHeight;
    const art = CapsuleWindow.artworkSize;
    const artworkTop = CapsuleWindow.artworkTop;

    final info = Column(
      key: const Key('capsule-info'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          item?.title ?? strings.resolve(ThemeStringKey.playerNothingPlaying),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _subtitle(item),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10.5, color: colors.textMuted),
        ),
      ],
    );

    final controls = Row(
      key: const Key('capsule-controls'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _LikeButton(item: item),
        _SkipButton(
          direction: -1,
          tooltip: strings.resolve(ThemeStringKey.playerPrevious),
          onPressed: queue.isEmpty
              ? null
              : () =>
                    ref.read(playerControllerProvider.notifier).playPrevious(),
        ),
        _PlayButton(
          playing: playing,
          canPlay: item != null,
          playTooltip: strings.resolve(ThemeStringKey.playerPlay),
          pauseTooltip: strings.resolve(ThemeStringKey.playerPause),
        ),
        _SkipButton(
          direction: 1,
          tooltip: strings.resolve(ThemeStringKey.playerNext),
          onPressed: queue.isEmpty
              ? null
              : () => ref.read(playerControllerProvider.notifier).playNext(),
        ),
        _QueueButton(
          tooltip: strings.resolve(ThemeStringKey.playerCapsuleQueue),
        ),
      ],
    );

    // One drag layer under the whole capsule, and one above the cover. The
    // cover is painted as a sibling that overlaps the surface, so a gesture
    // recogniser inside the surface never sees pointers over it — without
    // this second layer the cover was the one part of the bar you could not
    // move the window by.
    Widget dragLayer(Key key) => Positioned.fill(
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => windowManager.startDragging(),
      ),
    );

    // The bar is opaque, not frosted. The capsule floats over the desktop, so
    // a backdrop filter here would blur the desktop into a coloured haze
    // instead of letting it show through around the bar — and the skin's
    // blur token is what made the capsule look like a smeared panel.
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.backgroundElevated,
        borderRadius: BorderRadius.all(Radius.circular(tokens.radius.lg)),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            dragLayer(const Key('capsule-drag-region')),
            Positioned(
              top: 0,
              bottom: 0,
              left:
                  CapsuleWindow.artworkInset +
                  art +
                  CapsuleWindow.artworkGap,
              right: CapsuleWindow.closeButtonSize +
                  CapsuleWindow.closeButtonGap,
              child: Center(
                child: AnimatedSwitcher(
                  key: const ValueKey('capsule-middle'),
                  duration: tokens.components.motion.short,
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: _hovering ? controls : info,
                ),
              ),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              right: CapsuleWindow.closeButtonGap,
              width: CapsuleWindow.closeButtonSize,
              child: Center(
                // The close affordance follows the same hover rule as the
                // transport controls: the capsule shows song info at rest,
                // so a permanently visible close button would clutter the
                // resting state it is meant to leave clean.
                child: AnimatedOpacity(
                  opacity: _hovering ? 1 : 0,
                  duration: tokens.components.motion.short,
                  child: IgnorePointer(
                    ignoring: !_hovering,
                    child: _CloseButton(
                      tooltip: strings.resolve(
                        ThemeStringKey.playerCapsuleExit,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: SizedBox(
        width: w,
        height: CapsuleWindow.stackHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              top: CapsuleWindow.barTop,
              left: 0,
              width: w,
              height: h,
              child: surface,
            ),
            // The circular cover is tangent to the bar's bottom edge and
            // protrudes only above it, and carries its own drag layer so it
            // moves the window too.
            Positioned(
              key: const Key('capsule-artwork'),
              top: artworkTop,
              left: CapsuleWindow.artworkInset,
              width: art,
              height: art,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ClipOval(
                    child: ArtworkView(
                      artworkUrl: item?.artworkUrl,
                      size: art,
                    ),
                  ),
                  dragLayer(const Key('capsule-artwork-drag')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(PlaybackItem? item) {
    final artist = item?.artist?.trim();
    if (artist != null && artist.isNotEmpty) {
      return artist;
    }
    return item?.platform?.trim() ?? '';
  }
}

class _LikeButton extends ConsumerWidget {
  const _LikeButton({required this.item});

  final PlaybackItem? item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = RobyneTheme.of(context).tokens.color;
    final strings = ref.watch(activeThemeStringsProvider);
    final playlists = ref.watch(playlistControllerProvider).value;
    final liked =
        playlists
            ?.where((playlist) => playlist.id == PlaylistRepository.favoritesId)
            .any(
              (playlist) => playlist.items.any((entry) => entry.id == item?.id),
            ) ??
        false;

    return _CapsuleIconButton(
      key: const Key('capsule-like'),
      size: CapsuleWindow.sideButtonSize,
      tooltip: liked
          ? strings.resolve(ThemeStringKey.playerRemoveFromLikedShort)
          : strings.resolve(ThemeStringKey.playerAddToLikedShort),
      icon: ThemeIconView(
        slot: ThemeIconKey.like,
        fallback: liked ? Icons.favorite : Icons.favorite_border,
        size: 18,
        color: liked ? colors.brandBase : colors.textSecondary,
        active: liked,
      ),
      onPressed: item == null
          ? null
          : () => ref
                .read(playlistControllerProvider.notifier)
                .toggleFavorite(item!),
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({
    required this.direction,
    required this.tooltip,
    required this.onPressed,
  });

  final int direction;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = RobyneTheme.of(context).tokens.color;
    return _CapsuleIconButton(
      size: CapsuleWindow.sideButtonSize,
      tooltip: tooltip,
      icon: ThemeIconView(
        slot: direction < 0
            ? ThemeIconKey.skipPrevious
            : ThemeIconKey.skipNext,
        fallback: direction < 0
            ? Icons.skip_previous_rounded
            : Icons.skip_next_rounded,
        size: 20,
        color: colors.textPrimary,
      ),
      onPressed: onPressed,
    );
  }
}

class _PlayButton extends ConsumerWidget {
  const _PlayButton({
    required this.playing,
    required this.canPlay,
    required this.playTooltip,
    required this.pauseTooltip,
  });

  final bool playing;
  final bool canPlay;
  final String playTooltip;
  final String pauseTooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    return _CapsuleIconButton(
      size: CapsuleWindow.playButtonSize,
      tooltip: playing ? pauseTooltip : playTooltip,
      filled: true,
      icon: ThemeIconView(
        slot: playing ? ThemeIconKey.pause : ThemeIconKey.play,
        fallback: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
        size: 24,
        color: colors.onBrand,
      ),
      onPressed: !canPlay
          ? null
          : () {
              final notifier = ref.read(playerControllerProvider.notifier);
              if (playing) {
                notifier.pause();
              } else {
                notifier.resumeOrPlayCurrent();
              }
            },
    );
  }
}

class _QueueButton extends ConsumerWidget {
  const _QueueButton({required this.tooltip});

  final String tooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = RobyneTheme.of(context).tokens.color;
    return _CapsuleIconButton(
      key: const Key('capsule-queue-toggle'),
      size: CapsuleWindow.sideButtonSize,
      tooltip: tooltip,
      icon: ThemeIconView(
        slot: ThemeIconKey.queue,
        fallback: Icons.format_list_bulleted,
        size: 18,
        color: colors.textSecondary,
      ),
      onPressed: () => ref.read(capsuleQueueOpenProvider.notifier).toggle(),
    );
  }
}

class _CloseButton extends ConsumerWidget {
  const _CloseButton({required this.tooltip});

  final String tooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = RobyneTheme.of(context).tokens.color;
    return _CapsuleIconButton(
      key: const Key('capsule-close'),
      size: CapsuleWindow.closeButtonSize,
      tooltip: tooltip,
      icon: Icon(Icons.close, size: 16, color: colors.textSecondary),
      onPressed: () => ref.read(capsuleModeProvider.notifier).exit(),
    );
  }
}

/// One compact capsule control.
///
/// The buttons are smaller than the shell's 42dp transport row because the
/// capsule is a mini surface; the icon is still comfortably hittable inside a
/// fixed box, and hover uses the same accent the shell's controls use.
class _CapsuleIconButton extends StatelessWidget {
  const _CapsuleIconButton({
    super.key,
    required this.size,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final double size;
  final String tooltip;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        radius: size * 0.55,
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: filled ? colors.brandBase : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Center(child: icon),
        ),
      ),
    );
  }
}

/// Whether the capsule's playlist panel is unfolded beneath the bar.
///
/// Riverpod has no widget-local provider, and the shell needs to compose the
/// capsule surface, so this lives next to the bar rather than inside it.
final capsuleQueueOpenProvider =
    NotifierProvider<CapsuleQueueOpenNotifier, bool>(
      CapsuleQueueOpenNotifier.new,
    );

class CapsuleQueueOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;

  void close() => state = false;
}
