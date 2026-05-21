import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robyne/core/audio/audio_player_service.dart';
import 'package:robyne/core/audio/playback_queue.dart';

final playerVisibleProvider = StateProvider<bool>((ref) => true);

class PlayerControls extends ConsumerWidget {
  const PlayerControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerServiceProvider);
    final isVisible = ref.watch(playerVisibleProvider);

    if (playerState.currentSong == null || !isVisible) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Song info with close button
          ListTile(
            leading: playerState.currentSong!.coverUrl != null
                ? Image.network(
                    playerState.currentSong!.coverUrl!,
                    width: 48,
                    height: 48,
                    errorBuilder: (_, __, ___) => const Icon(Icons.music_note),
                  )
                : const Icon(Icons.music_note),
            title: Text(
              playerState.currentSong!.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              playerState.currentSong!.artist ?? 'Unknown Artist',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                ref.read(playerVisibleProvider.notifier).state = false;
              },
            ),
          ),
          // Progress bar
          Slider(
            value: playerState.position.inMilliseconds.toDouble(),
            max: playerState.duration.inMilliseconds.toDouble() > 0
                ? playerState.duration.inMilliseconds.toDouble()
                : 1.0,
            onChanged: (value) {
              ref.read(audioPlayerServiceProvider.notifier).seek(
                    Duration(milliseconds: value.toInt()),
                  );
            },
          ),
          // Controls row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(_getPlaybackModeIcon(playerState.playbackMode)),
                onPressed: () {
                  final modes = PlaybackMode.values;
                  final currentIndex =
                      modes.indexOf(playerState.playbackMode);
                  final nextIndex = (currentIndex + 1) % modes.length;
                  ref
                      .read(audioPlayerServiceProvider.notifier)
                      .setPlaybackMode(modes[nextIndex]);
                },
              ),
              IconButton(
                icon: const Icon(Icons.skip_previous),
                onPressed: () {
                  ref.read(audioPlayerServiceProvider.notifier).skipToPrevious();
                },
              ),
              IconButton(
                icon: Icon(
                  playerState.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  size: 48,
                ),
                onPressed: () {
                  if (playerState.isPlaying) {
                    ref.read(audioPlayerServiceProvider.notifier).pause();
                  } else {
                    ref.read(audioPlayerServiceProvider.notifier).play();
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.skip_next),
                onPressed: () {
                  ref.read(audioPlayerServiceProvider.notifier).skipToNext();
                },
              ),
              IconButton(
                icon: const Icon(Icons.stop),
                onPressed: () {
                  ref.read(audioPlayerServiceProvider.notifier).stop();
                },
              ),
            ],
          ),
          // Volume control
          Row(
            children: [
              IconButton(
                icon: Icon(
                  playerState.volume > 0
                      ? Icons.volume_up
                      : Icons.volume_off,
                ),
                onPressed: () {
                  final newVolume = playerState.volume > 0 ? 0.0 : 1.0;
                  ref.read(audioPlayerServiceProvider.notifier).setVolume(newVolume);
                },
              ),
              Expanded(
                child: Slider(
                  value: playerState.volume,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (value) {
                    ref.read(audioPlayerServiceProvider.notifier).setVolume(value);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getPlaybackModeIcon(PlaybackMode mode) {
    switch (mode) {
      case PlaybackMode.sequential:
        return Icons.repeat;
      case PlaybackMode.shuffle:
        return Icons.shuffle;
      case PlaybackMode.singleLoop:
        return Icons.repeat_one;
      case PlaybackMode.listLoop:
        return Icons.repeat;
    }
  }
}
