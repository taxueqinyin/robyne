import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/window_size_class.dart';
import '../application/player_providers.dart';
import '../domain/playback_item.dart';

const _tracePlayerBar = bool.fromEnvironment('ROBYNE_PLAYER_TRACE');

class PlayerBar extends ConsumerWidget {
  const PlayerBar({super.key, this.compactHeight = false});

  /// True when the window is short (landscape phone).
  ///
  /// The bar then collapses to a single-row mini bar: the progress slider and
  /// every secondary transport control go away, because a ~360dp tall window
  /// cannot carry both chrome and content. See ADR-001 decision D5.
  ///
  /// The shell passes this; when the bar is used standalone it derives it from
  /// the viewport, so the behaviour is identical either way.
  final bool compactHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotValue = ref.watch(playerSnapshotsProvider);
    ref.watch(playbackCompletionListenerProvider);
    final snapshot = snapshotValue.value;
    final playerState = ref.watch(playerControllerProvider).value;
    final error = playerState?.error;
    final theme = Theme.of(context);
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

    // Compact *width* drops the volume slider; compact *height* additionally
    // drops the progress row. They are independent axes: a landscape phone can
    // be medium-width and compact-height at the same time.
    final sizeClass = WindowSizeClass.of(context);
    final isCompactWidth = sizeClass.isCompactWidth;
    final isCompactHeight = compactHeight || sizeClass.isCompactHeight;
    final horizontalPadding = isCompactWidth ? 12.0 : 24.0;
    final trackInfo = <Widget>[
      Text(
        playerState?.currentItem?.title ??
            snapshot?.currentSource?.url ??
            'Nothing playing',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium,
      ),
      if (error != null)
        Text(
          '${error.code}: ${error.message}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        )
      else
        Text(
          _formatPosition(position, duration),
          style: theme.textTheme.bodySmall,
        ),
    ];
    final transportControls = <Widget>[
      IconButton(
        tooltip: 'Previous',
        icon: const Icon(Icons.skip_previous),
        onPressed: playerState?.queue.isEmpty == false
            ? () => ref.read(playerControllerProvider.notifier).playPrevious()
            : null,
      ),
      IconButton(
        tooltip: snapshot?.playing == true ? 'Pause' : 'Play',
        icon: Icon(snapshot?.playing == true ? Icons.pause : Icons.play_arrow),
        onPressed: snapshot?.playing == true
            ? () => ref.read(playerControllerProvider.notifier).pause()
            : !hasLoadedSource && !hasRestoredItem
            ? null
            : () => ref
                  .read(playerControllerProvider.notifier)
                  .resumeOrPlayCurrent(),
      ),
      IconButton(
        tooltip: 'Next',
        icon: const Icon(Icons.skip_next),
        onPressed: playerState?.queue.isEmpty == false
            ? () => ref.read(playerControllerProvider.notifier).playNext()
            : null,
      ),
      IconButton(
        key: const Key('player-mode-button'),
        tooltip: _modeLabel(playerState?.playbackMode ?? PlaybackMode.sequence),
        icon: Icon(
          _modeIcon(playerState?.playbackMode ?? PlaybackMode.sequence),
        ),
        onPressed: () => ref
            .read(playerControllerProvider.notifier)
            .setPlaybackMode(
              _nextMode(playerState?.playbackMode ?? PlaybackMode.sequence),
            ),
      ),
      IconButton(
        tooltip: 'Stop',
        icon: const Icon(Icons.stop),
        onPressed: () => ref.read(playerControllerProvider.notifier).stop(),
      ),
    ];
    final volumeControl = <Widget>[
      const SizedBox(width: 8),
      const Icon(Icons.volume_up, size: 20),
      SizedBox(
        width: isCompactWidth ? 88.0 : 120.0,
        child: Slider(
          key: const Key('player-volume-slider'),
          value: (playerState?.volume ?? snapshot?.volume ?? 100)
              .clamp(0, 100)
              .toDouble(),
          min: 0,
          max: 100,
          onChanged: (value) =>
              ref.read(playerControllerProvider.notifier).setVolume(value),
        ),
      ),
    ];

    // Mini bar: only the play/pause and skip controls survive, because five
    // transport buttons plus a title column do not fit in a narrow window and
    // truncating the title to a few glyphs is worse than dropping the rest.
    final miniTransport = <Widget>[
      IconButton(
        tooltip: snapshot?.playing == true ? 'Pause' : 'Play',
        icon: Icon(snapshot?.playing == true ? Icons.pause : Icons.play_arrow),
        onPressed: snapshot?.playing == true
            ? () => ref.read(playerControllerProvider.notifier).pause()
            : !hasLoadedSource && !hasRestoredItem
            ? null
            : () => ref
                  .read(playerControllerProvider.notifier)
                  .resumeOrPlayCurrent(),
      ),
      IconButton(
        tooltip: 'Next',
        icon: const Icon(Icons.skip_next),
        onPressed: playerState?.queue.isEmpty == false
            ? () => ref.read(playerControllerProvider.notifier).playNext()
            : null,
      ),
    ];

    final controlsRow = isCompactHeight
        ? Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  playerState?.currentItem?.title ??
                      snapshot?.currentSource?.url ??
                      'Nothing playing',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              ...miniTransport,
            ],
          )
        : isCompactWidth
        ? Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: trackInfo,
                ),
              ),
              ...transportControls,
            ],
          )
        : Row(
            children: <Widget>[
              Icon(
                snapshot?.playing == true
                    ? Icons.equalizer
                    : Icons.music_note_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: trackInfo,
                ),
              ),
              ...transportControls,
              ...volumeControl,
            ],
          );

    return Material(
      elevation: 2,
      color: theme.colorScheme.surface,
      child: SizedBox(
        height: isCompactHeight
            ? 56
            : isCompactWidth
            ? 104
            : 112,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: isCompactHeight
              ? Center(child: controlsRow)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Slider(
                      key: const Key('player-progress-slider'),
                      value: currentPosition,
                      min: 0,
                      max: maxPosition,
                      onChanged: !hasLoadedSource && !hasRestoredItem
                          ? null
                          : (value) => ref
                                .read(playerControllerProvider.notifier)
                                .seek(Duration(milliseconds: value.round())),
                    ),
                    controlsRow,
                  ],
                ),
        ),
      ),
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

  String _modeLabel(PlaybackMode mode) {
    return switch (mode) {
      PlaybackMode.sequence => 'Sequence',
      PlaybackMode.random => 'Random',
      PlaybackMode.allLoop => 'Loop all',
      PlaybackMode.singleLoop => 'Loop one',
    };
  }
}
