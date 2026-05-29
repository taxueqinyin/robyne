import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/player_providers.dart';
import '../domain/playback_item.dart';

const _tracePlayerBar = bool.fromEnvironment('ROBYNE_PLAYER_TRACE');

class PlayerBar extends ConsumerWidget {
  const PlayerBar({super.key});

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
    final preferredDuration =
        playerState?.currentItem?.duration ?? playerState?.lastDuration;
    final restoredDuration = preferredDuration ?? Duration.zero;
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

    return Material(
      elevation: 2,
      color: theme.colorScheme.surface,
      child: SizedBox(
        height: 112,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
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
              Row(
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
                      children: <Widget>[
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
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Previous',
                    icon: const Icon(Icons.skip_previous),
                    onPressed: playerState?.queue.isEmpty == false
                        ? () => ref
                              .read(playerControllerProvider.notifier)
                              .playPrevious()
                        : null,
                  ),
                  IconButton(
                    tooltip: snapshot?.playing == true ? 'Pause' : 'Play',
                    icon: Icon(
                      snapshot?.playing == true
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                    onPressed: snapshot?.playing == true
                        ? () => ref
                              .read(playerControllerProvider.notifier)
                              .pause()
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
                        ? () => ref
                              .read(playerControllerProvider.notifier)
                              .playNext()
                        : null,
                  ),
                  IconButton(
                    key: const Key('player-mode-button'),
                    tooltip: _modeLabel(
                      playerState?.playbackMode ?? PlaybackMode.sequence,
                    ),
                    icon: Icon(
                      _modeIcon(
                        playerState?.playbackMode ?? PlaybackMode.sequence,
                      ),
                    ),
                    onPressed: () => ref
                        .read(playerControllerProvider.notifier)
                        .setPlaybackMode(
                          _nextMode(
                            playerState?.playbackMode ?? PlaybackMode.sequence,
                          ),
                        ),
                  ),
                  IconButton(
                    tooltip: 'Stop',
                    icon: const Icon(Icons.stop),
                    onPressed: () =>
                        ref.read(playerControllerProvider.notifier).stop(),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.volume_up, size: 20),
                  SizedBox(
                    width: 120,
                    child: Slider(
                      key: const Key('player-volume-slider'),
                      value: (playerState?.volume ?? snapshot?.volume ?? 100)
                          .clamp(0, 100)
                          .toDouble(),
                      min: 0,
                      max: 100,
                      onChanged: (value) => ref
                          .read(playerControllerProvider.notifier)
                          .setVolume(value),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPosition(Duration position, Duration duration) {
    return '${_formatDuration(position)} / ${_formatDuration(duration)}';
  }

  Duration _stableDuration({
    required Duration snapshotDuration,
    required Duration savedDuration,
  }) {
    if (savedDuration <= Duration.zero || snapshotDuration <= Duration.zero) {
      return snapshotDuration;
    }
    final difference = (snapshotDuration - savedDuration).abs();
    if (difference <= const Duration(seconds: 1)) {
      return savedDuration;
    }
    return snapshotDuration;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
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
