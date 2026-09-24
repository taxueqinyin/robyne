import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../player/application/player_providers.dart';
import '../application/library_providers.dart';

/// Matches the shell breakpoint in [RobyneShell].
const double _compactWidthBreakpoint = 700;

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(localMusicLibraryProvider);
    final title = Text(
      'Library',
      style: Theme.of(context).textTheme.headlineMedium,
    );
    final actions = <Widget>[
      OutlinedButton.icon(
        onPressed: () async {
          final result = await FilePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: const <String>[
              'mp3',
              'flac',
              'wav',
              'm4a',
              'aac',
              'ogg',
              'opus',
              'wma',
            ],
            allowMultiple: true,
          );
          final paths = result?.files
              .map((file) => file.path)
              .whereType<String>()
              .toList(growable: false);
          if (paths == null || paths.isEmpty || !context.mounted) {
            return;
          }
          final error = await ref
              .read(localMusicLibraryProvider.notifier)
              .importFiles(paths);
          if (error != null && context.mounted) {
            _showError(context, error);
          }
        },
        icon: const Icon(Icons.file_open),
        label: const Text('Import files'),
      ),
      const SizedBox(width: 8, height: 8),
      FilledButton.icon(
        onPressed: () async {
          final path = await FilePicker.getDirectoryPath();
          if (path == null || !context.mounted) {
            return;
          }
          final error = await ref
              .read(localMusicLibraryProvider.notifier)
              .importFolder(path);
          if (error != null && context.mounted) {
            _showError(context, error);
          }
        },
        icon: const Icon(Icons.folder_open),
        label: const Text('Import folder'),
      ),
    ];

    // On phone widths the title and both buttons do not fit on one line,
    // so stack them vertically instead of overflowing.
    final header = MediaQuery.sizeOf(context).width < _compactWidthBreakpoint
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[title, const SizedBox(height: 12), ...actions],
          )
        : Row(
            children: <Widget>[
              Expanded(child: title),
              ...actions,
            ],
          );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          header,
          const SizedBox(height: 24),
          Expanded(
            child: library.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  Center(child: Text(error.toString())),
              data: (tracks) {
                if (tracks.isEmpty) {
                  return const Center(child: Text('No local music imported.'));
                }
                return ListView.separated(
                  itemCount: tracks.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = tracks[index];
                    return ListTile(
                      leading: const Icon(Icons.music_note),
                      title: Text(item.title),
                      subtitle: Text(item.localPath ?? ''),
                      trailing: Wrap(
                        spacing: 8,
                        children: <Widget>[
                          IconButton(
                            tooltip: 'Play',
                            icon: const Icon(Icons.play_arrow),
                            onPressed: () => ref
                                .read(playerControllerProvider.notifier)
                                .playItem(item),
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => ref
                                .read(localMusicLibraryProvider.notifier)
                                .remove(item.id),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showError(BuildContext context, Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }
}
