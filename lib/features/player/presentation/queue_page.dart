import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/player_providers.dart';
import '../domain/playback_item.dart';
import 'artwork_view.dart';

class QueuePage extends ConsumerWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state =
        ref.watch(playerControllerProvider).value ??
        const PlayerControllerState();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Queue',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              DropdownButton<PlaybackMode>(
                value: state.playbackMode,
                onChanged: (mode) {
                  if (mode != null) {
                    ref
                        .read(playerControllerProvider.notifier)
                        .setPlaybackMode(mode);
                  }
                },
                items: PlaybackMode.values
                    .map(
                      (mode) => DropdownMenuItem<PlaybackMode>(
                        value: mode,
                        child: Text(_modeLabel(mode)),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: state.queue.isEmpty
                    ? null
                    : () => ref
                          .read(playerControllerProvider.notifier)
                          .clearQueue(),
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: <Widget>[
                Expanded(child: _QueueList(state: state)),
                const VerticalDivider(width: 32),
                Expanded(child: _HistoryList(state: state)),
              ],
            ),
          ),
        ],
      ),
    );
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

class _QueueList extends ConsumerWidget {
  const _QueueList({required this.state});

  final PlayerControllerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.queue.isEmpty) {
      return const Center(child: Text('Queue is empty.'));
    }
    return ListView.separated(
      itemCount: state.queue.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = state.queue[index];
        final selected = item.id == state.currentItem?.id;
        return ListTile(
          leading: selected
              ? const Icon(Icons.equalizer)
              : ArtworkView(artworkUrl: item.artworkUrl),
          title: Text(item.title),
          subtitle: Text(item.platform ?? item.localPath ?? ''),
          onTap: () =>
              ref.read(playerControllerProvider.notifier).playItem(item),
          trailing: IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => ref
                .read(playerControllerProvider.notifier)
                .removeFromQueue(item.id),
          ),
        );
      },
    );
  }
}

class _HistoryList extends ConsumerWidget {
  const _HistoryList({required this.state});

  final PlayerControllerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.history.isEmpty) {
      return const Center(child: Text('History is empty.'));
    }
    return Column(
      children: <Widget>[
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            key: const Key('clear-history-button'),
            onPressed: () =>
                ref.read(playerControllerProvider.notifier).clearHistory(),
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Clear history'),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: state.history.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = state.history[state.history.length - index - 1];
              return ListTile(
                leading: ArtworkView(artworkUrl: entry.item.artworkUrl),
                title: Text(entry.item.title),
                subtitle: Text(entry.playedAt.toLocal().toString()),
              );
            },
          ),
        ),
      ],
    );
  }
}
