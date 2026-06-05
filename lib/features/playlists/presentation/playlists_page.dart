import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/debug/ime_trace.dart';
import '../../player/application/player_providers.dart';
import '../../player/presentation/artwork_view.dart';
import '../application/playlist_providers.dart';
import '../infrastructure/playlist_repository.dart';

class PlaylistsPage extends ConsumerWidget {
  const PlaylistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsValue = ref.watch(playlistControllerProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Playlists',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showCreateDialog(context, ref),
                icon: const Icon(Icons.playlist_add),
                label: const Text('New playlist'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: playlistsValue.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  Center(child: Text(error.toString())),
              data: (playlists) {
                if (playlists.isEmpty) {
                  return const Center(child: Text('No playlists.'));
                }
                return ListView.separated(
                  itemCount: playlists.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    return ExpansionTile(
                      leading: Icon(
                        playlist.isFavorites
                            ? Icons.favorite
                            : Icons.queue_music,
                      ),
                      title: Text(playlist.name),
                      subtitle: Text('${playlist.items.length} tracks'),
                      trailing: playlist.id == PlaylistRepository.favoritesId
                          ? null
                          : IconButton(
                              tooltip: 'Delete playlist',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final confirmed =
                                    await _confirmDestructiveAction(
                                      context,
                                      title: 'Delete playlist',
                                      message: 'Delete "${playlist.name}"?',
                                      actionLabel: 'Delete',
                                    );
                                if (confirmed) {
                                  await ref
                                      .read(playlistControllerProvider.notifier)
                                      .deletePlaylist(playlist.id);
                                }
                              },
                            ),
                      children: <Widget>[
                        if (playlist.items.isEmpty)
                          const ListTile(title: Text('No tracks.'))
                        else
                          for (final item in playlist.items)
                            ListTile(
                              leading: ArtworkView(artworkUrl: item.artworkUrl),
                              title: Text(item.title),
                              subtitle: Text(
                                item.artist ?? item.platform ?? '',
                              ),
                              onTap: () => ref
                                  .read(playerControllerProvider.notifier)
                                  .playItem(item),
                              trailing: IconButton(
                                tooltip: 'Remove',
                                icon: const Icon(Icons.close),
                                onPressed: () async {
                                  final confirmed = await _confirmDestructiveAction(
                                    context,
                                    title: 'Remove track',
                                    message:
                                        'Remove "${item.title}" from "${playlist.name}"?',
                                    actionLabel: 'Remove',
                                  );
                                  if (confirmed) {
                                    await ref
                                        .read(
                                          playlistControllerProvider.notifier,
                                        )
                                        .removeItem(playlist.id, item.id);
                                  }
                                },
                              ),
                            ),
                      ],
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

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (context) => const _CreatePlaylistDialog(),
    );
  }

  Future<bool> _confirmDestructiveAction(
    BuildContext context, {
    required String title,
    required String message,
    required String actionLabel,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.delete_outline),
                label: Text(actionLabel),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _CreatePlaylistDialog extends ConsumerStatefulWidget {
  const _CreatePlaylistDialog();

  @override
  ConsumerState<_CreatePlaylistDialog> createState() =>
      _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends ConsumerState<_CreatePlaylistDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    attachImeTextControllerTrace(_controller, 'playlists.createName');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New playlist'),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Name',
          ),
          onSubmitted: (_) => _create(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _create, child: const Text('Create')),
      ],
    );
  }

  Future<void> _create() async {
    final name = _controller.text;
    FocusManager.instance.primaryFocus?.unfocus();
    await ref.read(playlistControllerProvider.notifier).createPlaylist(name);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
