import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/player_providers.dart';
import '../domain/audio_player_service.dart';

class PlayerBar extends ConsumerWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotValue = ref.watch(playerSnapshotsProvider);
    final snapshot = snapshotValue.value;
    final error = ref.watch(playerControllerProvider).value;
    final theme = Theme.of(context);

    return Material(
      elevation: 2,
      color: theme.colorScheme.surface,
      child: SizedBox(
        height: 76,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
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
                      snapshot?.currentSource?.url ?? 'Nothing playing',
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
                        _formatPosition(snapshot),
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: snapshot?.playing == true ? 'Pause' : 'Play',
                icon: Icon(
                  snapshot?.playing == true ? Icons.pause : Icons.play_arrow,
                ),
                onPressed: snapshot?.playing == true
                    ? () => ref.read(playerControllerProvider.notifier).pause()
                    : snapshot?.currentSource == null
                    ? null
                    : () =>
                          ref.read(playerControllerProvider.notifier).resume(),
              ),
              IconButton(
                tooltip: 'Stop',
                icon: const Icon(Icons.stop),
                onPressed: () =>
                    ref.read(playerControllerProvider.notifier).stop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPosition(PlayerSnapshot? snapshot) {
    if (snapshot == null) {
      return '00:00 / 00:00';
    }
    return '${_formatDuration(snapshot.position)} / ${_formatDuration(snapshot.duration)}';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
