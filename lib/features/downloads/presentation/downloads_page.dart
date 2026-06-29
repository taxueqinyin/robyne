import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../player/application/player_providers.dart';
import '../../player/presentation/artwork_view.dart';
import '../application/download_providers.dart';
import '../domain/download_task.dart';

class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadControllerProvider);
    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Downloads',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const TabBar(
              tabs: <Widget>[
                Tab(text: 'Downloading'),
                Tab(text: 'Completed'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: downloads.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) =>
                    Center(child: Text(error.toString())),
                data: (tasks) => TabBarView(
                  children: <Widget>[
                    _TaskList(
                      tasks: tasks
                          .where(
                            (task) => task.status != DownloadStatus.completed,
                          )
                          .toList(growable: false),
                    ),
                    _TaskList(
                      tasks: tasks
                          .where(
                            (task) => task.status == DownloadStatus.completed,
                          )
                          .toList(growable: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskList extends ConsumerWidget {
  const _TaskList({required this.tasks});

  final List<DownloadTask> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tasks.isEmpty) {
      return const Center(child: Text('No downloads.'));
    }
    return ListView.separated(
      itemCount: tasks.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final task = tasks[index];
        return ListTile(
          leading: ArtworkView(artworkUrl: task.item.artworkUrl),
          title: Text(task.item.title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(_statusLabel(task)),
              if (task.status == DownloadStatus.downloading)
                LinearProgressIndicator(value: task.progress),
              if (task.errorMessage != null)
                Text(
                  task.errorMessage!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
          trailing: Wrap(
            spacing: 4,
            children: <Widget>[
              if (task.status == DownloadStatus.completed)
                IconButton(
                  tooltip: 'Play',
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () => ref
                      .read(playerControllerProvider.notifier)
                      .playItem(task.item),
                ),
              if (task.status == DownloadStatus.failed)
                IconButton(
                  tooltip: 'Retry',
                  icon: const Icon(Icons.refresh),
                  onPressed: () =>
                      ref.read(downloadControllerProvider.notifier).retry(task),
                ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => ref
                    .read(downloadControllerProvider.notifier)
                    .deleteTask(task),
              ),
            ],
          ),
        );
      },
    );
  }

  String _statusLabel(DownloadTask task) {
    return switch (task.status) {
      DownloadStatus.queued => 'Queued',
      DownloadStatus.downloading =>
        'Downloading ${(task.progress * 100).round()}%',
      DownloadStatus.converting => 'Converting',
      DownloadStatus.completed => 'Completed',
      DownloadStatus.failed => 'Failed',
    };
  }
}
