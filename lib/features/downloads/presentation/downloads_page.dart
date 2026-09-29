import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/window_size_class.dart';
import '../../../core/theme/application/theme_providers.dart';
import '../../../core/theme/domain/theme_strings.dart';
import '../../../core/theme/infrastructure/token_resolver.dart';
import '../../player/application/player_providers.dart';
import '../../player/presentation/artwork_view.dart';
import '../application/download_providers.dart';
import '../domain/download_task.dart';

class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    final tokens = RobyneTheme.of(context).tokens;
    final metrics = ref.watch(activeThemeContentMetricsProvider);
    final compactWidth =
        WindowSizeClass.of(context).width != WindowWidthClass.expanded;
    final downloads = ref.watch(downloadControllerProvider);
    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          metrics.gutterFor(compact: compactWidth),
          20,
          metrics.gutterFor(compact: compactWidth),
          20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              strings.resolve(ThemeStringKey.downloadsTitle),
              style: TextStyle(
                fontSize: tokens.typography.resolvedPageTitleSize,
                fontWeight: FontWeight.w700,
                color: tokens.color.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            TabBar(
              tabs: <Widget>[
                Tab(text: strings.resolve(ThemeStringKey.downloadsTabActive)),
                Tab(
                  text: strings.resolve(ThemeStringKey.downloadsTabCompleted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: downloads.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: Text(
                    error.toString(),
                    style: TextStyle(color: tokens.color.danger),
                  ),
                ),
                data: (tasks) => TabBarView(
                  children: <Widget>[
                    _TaskList(
                      tasks: tasks
                          .where(
                            (task) => task.status != DownloadStatus.completed,
                          )
                          .toList(growable: false),
                      emptyLabel: strings.resolve(
                        ThemeStringKey.downloadsEmpty,
                      ),
                    ),
                    _TaskList(
                      tasks: tasks
                          .where(
                            (task) => task.status == DownloadStatus.completed,
                          )
                          .toList(growable: false),
                      emptyLabel: strings.resolve(
                        ThemeStringKey.downloadsEmpty,
                      ),
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
  const _TaskList({required this.tasks, required this.emptyLabel});

  final List<DownloadTask> tasks;

  /// Skin-declared empty copy, so the two tabs can differ if a skin wants.
  final String emptyLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    if (tasks.isEmpty) {
      return Center(
        child: Text(emptyLabel, style: TextStyle(color: colors.textMuted)),
      );
    }
    return ListView.separated(
      itemCount: tasks.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(tokens.radius.sm),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: ArtworkView(artworkUrl: task.item.artworkUrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      task.item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: tokens.typography.resolvedListPrimarySize,
                        fontWeight: FontWeight.w500,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _statusLabel(strings, task),
                      style: TextStyle(fontSize: 11, color: colors.textMuted),
                    ),
                    if (task.status == DownloadStatus.downloading) ...<Widget>[
                      const SizedBox(height: 6),
                      // Progress colours are the player bar's, not Material's:
                      // a download and a track are both "how far along".
                      ClipRRect(
                        borderRadius: BorderRadius.circular(tokens.radius.sm),
                        child: LinearProgressIndicator(
                          value: task.progress,
                          minHeight: 3,
                          backgroundColor:
                              tokens.components.playerBar.progressTrack,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            tokens.components.playerBar.progressActive,
                          ),
                        ),
                      ),
                    ],
                    if (task.errorMessage != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        task.errorMessage!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: colors.danger),
                      ),
                    ],
                  ],
                ),
              ),
              if (task.status == DownloadStatus.completed)
                _TaskAction(
                  icon: Icons.play_arrow,
                  tooltip: strings.resolve(ThemeStringKey.downloadsPlay),
                  onPressed: () => ref
                      .read(playerControllerProvider.notifier)
                      .playItem(task.item),
                ),
              if (task.status == DownloadStatus.failed)
                _TaskAction(
                  icon: Icons.refresh,
                  tooltip: strings.resolve(ThemeStringKey.downloadsRetry),
                  onPressed: () =>
                      ref.read(downloadControllerProvider.notifier).retry(task),
                ),
              _TaskAction(
                icon: Icons.delete_outline,
                tooltip: strings.resolve(ThemeStringKey.downloadsDelete),
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

  /// Status names come from the skin; the percentage is the one thing a skin
  /// cannot invent, so it is the only interpolated value.
  static String _statusLabel(ThemeStrings strings, DownloadTask task) {
    return switch (task.status) {
      DownloadStatus.queued => strings.resolve(
        ThemeStringKey.downloadsStatusQueued,
      ),
      DownloadStatus.downloading =>
        strings
            .resolve(ThemeStringKey.downloadsStatusDownloading)
            .replaceAll('{percent}', '${(task.progress * 100).round()}'),
      DownloadStatus.converting => strings.resolve(
        ThemeStringKey.downloadsStatusConverting,
      ),
      DownloadStatus.completed => strings.resolve(
        ThemeStringKey.downloadsStatusCompleted,
      ),
      DownloadStatus.failed => strings.resolve(
        ThemeStringKey.downloadsStatusFailed,
      ),
    };
  }
}

/// One download action: a 30dp hit target, dim, revealed by the row.
class _TaskAction extends StatelessWidget {
  const _TaskAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    return SizedBox(
      width: 30,
      height: 30,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 17,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: tokens.color.textSecondary),
      ),
    );
  }
}
