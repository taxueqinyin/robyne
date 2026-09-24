import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/window_size_class.dart';
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
    final sizeClass = WindowSizeClass.of(context);
    // Queue and history side by side need real horizontal room; below the
    // expanded breakpoint they become tabs rather than 50/50 slits.
    final splitPanes =
        sizeClass.width == WindowWidthClass.expanded &&
        !sizeClass.isCompactHeight;
    final padding = sizeClass.isCompactWidth ? 16.0 : 24.0;

    final queueList = _QueueList(state: state);
    final historyList = _HistoryList(state: state);

    final pane = splitPanes
        ? Row(
            children: <Widget>[
              Expanded(child: queueList),
              const VerticalDivider(width: 32),
              Expanded(child: historyList),
            ],
          )
        : DefaultTabController(
            length: 2,
            child: Column(
              children: <Widget>[
                TabBar(
                  tabs: const <Tab>[
                    Tab(text: 'Queue'),
                    Tab(text: 'History'),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(children: <Widget>[queueList, historyList]),
                ),
              ],
            ),
          );

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Title + mode dropdown + clear button do not fit one line on a
          // phone, so the controls wrap onto their own row instead of
          // overflowing.
          sizeClass.isCompactWidth
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Queue',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    _QueueControls(state: state),
                  ],
                )
              : Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Queue',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    // Flexible, not bare: a Row gives its non-flex children
                    // unbounded width, which the controls' own Expanded child
                    // cannot resolve.
                    const SizedBox(width: 16),
                    Flexible(child: _QueueControls(state: state)),
                  ],
                ),
          const SizedBox(height: 16),
          Expanded(child: pane),
        ],
      ),
    );
  }
}

/// Playback-mode picker and the clear action, shared by both header layouts.
class _QueueControls extends ConsumerWidget {
  const _QueueControls({required this.state});

  final PlayerControllerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: <Widget>[
        Expanded(
          child: DropdownButton<PlaybackMode>(
            isExpanded: true,
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
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: state.queue.isEmpty
              ? null
              : () => ref.read(playerControllerProvider.notifier).clearQueue(),
          icon: const Icon(Icons.clear_all),
          label: const Text('Clear'),
        ),
      ],
    );
  }

  static String _modeLabel(PlaybackMode mode) {
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
