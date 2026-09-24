import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/debug/ime_trace.dart';
import '../../../core/layout/window_size_class.dart';
import '../../../shared/widgets/search_action_button.dart';
import '../../lyrics/application/lyrics_providers.dart';
import '../../playlists/application/playlist_providers.dart';
import '../../playlists/infrastructure/playlist_repository.dart';
import '../../plugin/application/plugin_controller.dart';
import '../../plugin/domain/plugin_definition.dart';
import '../application/player_providers.dart';
import '../domain/playback_item.dart';
import 'artwork_view.dart';

const _lyricsSystemEnabled = true;

class NowPlayingPage extends ConsumerWidget {
  const NowPlayingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(
      playerControllerProvider.select((value) => value.value?.currentItem),
    );
    if (item == null) {
      return const Center(child: Text('Nothing playing.'));
    }

    final playlists = ref.watch(playlistControllerProvider).value;
    final favorite =
        playlists
            ?.where((playlist) => playlist.id == PlaylistRepository.favoritesId)
            .any(
              (playlist) => playlist.items.any(
                (playlistItem) => playlistItem.id == item.id,
              ),
            ) ??
        false;

    final sizeClass = WindowSizeClass.of(context);
    final padding = sizeClass.isCompactWidth ? 16.0 : 32.0;

    // The 340dp art column was fixed: on a 400dp-wide phone the content area
    // is ~336dp, so art + divider + lyrics overflowed and the lyrics pane was
    // pushed off-screen entirely. Every extent is now derived from the
    // viewport. See ADR-001 decision D4.
    final artSize = sizeClass.clampDimension(300, maxRatio: 0.62);
    final metadata = _NowPlayingMetadata(
      item: item,
      favorite: favorite,
      artworkSize: artSize,
    );

    if (sizeClass.isCompactWidth) {
      // Compact width: the two panes cannot share the axis, so they become
      // tabs. This is the Material list-detail pattern; stacking them would
      // give each pane ~80dp of height on a landscape phone.
      return DefaultTabController(
        length: 2,
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            children: <Widget>[
              TabBar(
                tabs: const <Tab>[
                  Tab(icon: Icon(Icons.album_outlined), text: 'Now'),
                  Tab(icon: Icon(Icons.lyrics_outlined), text: 'Lyrics'),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: <Widget>[
                    SingleChildScrollView(child: metadata),
                    _lyricsSystemEnabled
                        ? _LyricsPane(item: item)
                        : const _LyricsDisabledPane(),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Compact *height* with a non-compact width (landscape phone): keep both
    // panes side by side but shrink the art so the lyrics keep usable height.
    final artColumnWidth = artSize + (sizeClass.isCompactHeight ? 16 : 40);

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: artColumnWidth,
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(child: metadata),
            ),
          ),
          const VerticalDivider(width: 48),
          Expanded(
            child: _lyricsSystemEnabled
                ? _LyricsPane(item: item)
                : const _LyricsDisabledPane(),
          ),
        ],
      ),
    );
  }
}

/// Cover art plus title/artist/actions, shared by every layout variant.
class _NowPlayingMetadata extends StatelessWidget {
  const _NowPlayingMetadata({
    required this.item,
    required this.favorite,
    required this.artworkSize,
  });

  final PlaybackItem item;
  final bool favorite;
  final double artworkSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ArtworkView(artworkUrl: item.artworkUrl, size: artworkSize),
        const SizedBox(height: 16),
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          <String?>[
            item.artist,
            item.album,
            item.platform,
          ].whereType<String>().where((value) => value.isNotEmpty).join(' - '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 16),
        _NowPlayingActions(item: item, favorite: favorite),
      ],
    );
  }
}

class _NowPlayingActions extends ConsumerWidget {
  const _NowPlayingActions({required this.item, required this.favorite});

  final PlaybackItem item;
  final bool favorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: <Widget>[
        IconButton.filledTonal(
          tooltip: favorite ? 'Remove from liked' : 'Add to liked',
          icon: Icon(favorite ? Icons.favorite : Icons.favorite_border),
          onPressed: () => ref
              .read(playlistControllerProvider.notifier)
              .toggleFavorite(item),
        ),
        const SizedBox(width: 8),
        _NowPlayingMenu(item: item),
      ],
    );
  }
}

class _NowPlayingMenu extends ConsumerWidget {
  const _NowPlayingMenu({required this.item});

  final PlaybackItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: const Icon(Icons.more_horiz),
      onSelected: (value) async {
        switch (value) {
          case 'search':
            await showDialog<void>(
              context: context,
              builder: (context) => _LyricSearchDialog(item: item),
            );
          case 'local':
            final path = await FilePicker.pickFiles(
              type: FileType.custom,
              allowedExtensions: const <String>['lrc', 'txt'],
            );
            final filePath = path?.files.single.path;
            if (filePath != null) {
              await ref
                  .read(lyricRepositoryProvider)
                  .associateLocalFile(item, filePath);
              ref.invalidate(storedCurrentLyricsProvider);
            }
          case 'playlist':
            await showDialog<void>(
              context: context,
              builder: (context) => _AddToPlaylistDialog(item: item),
            );
          case 'clear':
            await ref.read(lyricRepositoryProvider).clearAssociation(item);
            ref.read(lyricLiveOffsetProvider(item.id).notifier).setOffset(null);
            ref.invalidate(storedCurrentLyricsProvider);
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        if (_lyricsSystemEnabled) ...<PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            value: 'search',
            child: ListTile(
              leading: Icon(Icons.manage_search),
              title: Text('Search and link lyric'),
            ),
          ),
          PopupMenuItem<String>(
            value: 'local',
            child: ListTile(
              leading: Icon(Icons.file_open),
              title: Text('Link local lyric file'),
            ),
          ),
          PopupMenuItem<String>(
            value: 'offset',
            enabled: false,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            height: 124,
            child: _LyricOffsetMenuPanel(item: item),
          ),
        ],
        PopupMenuItem<String>(
          value: 'playlist',
          child: ListTile(
            leading: Icon(Icons.playlist_add),
            title: Text('Add to playlist'),
          ),
        ),
        if (_lyricsSystemEnabled)
          const PopupMenuItem<String>(
            value: 'clear',
            child: ListTile(
              leading: Icon(Icons.link_off),
              title: Text('Clear lyric link'),
            ),
          ),
      ],
    );
  }
}

class _LyricsDisabledPane extends StatelessWidget {
  const _LyricsDisabledPane();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Lyrics temporarily disabled.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}

class _AddToPlaylistDialog extends ConsumerWidget {
  const _AddToPlaylistDialog({required this.item});

  final PlaybackItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistControllerProvider);
    return AlertDialog(
      title: const Text('Add to playlist'),
      // A 420dp dialog on a 400dp screen overflows by 400dp. The width is a
      // preference, not a requirement. See ADR-001 decision D4.
      content: SizedBox(
        width: RobyneDialogWidth.forContext(context, 420),
        child: playlists.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Text(error.toString()),
          data: (playlists) {
            final normalPlaylists = playlists
                .where((playlist) => !playlist.isFavorites)
                .toList(growable: false);
            if (normalPlaylists.isEmpty) {
              return const Text('Create a playlist first.');
            }
            return ListView(
              shrinkWrap: true,
              children: <Widget>[
                for (final playlist in normalPlaylists)
                  ListTile(
                    leading: const Icon(Icons.queue_music),
                    title: Text(playlist.name),
                    onTap: () async {
                      await ref
                          .read(playlistControllerProvider.notifier)
                          .addItem(playlist.id, item);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LyricsPane extends ConsumerStatefulWidget {
  const _LyricsPane({required this.item});

  final PlaybackItem item;

  @override
  ConsumerState<_LyricsPane> createState() => _LyricsPaneState();
}

class _LyricsPaneState extends ConsumerState<_LyricsPane> {
  static const _lyricLineExtent = 56.0;

  final _scrollController = ScrollController();
  int _lastActiveIndex = -1;
  Duration? _lastDocumentOffset;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshotPosition = ref.watch(
      playerSnapshotsProvider.select((value) {
        final snapshot = value.value;
        return (
          hasSource: snapshot?.currentSource != null,
          seconds: snapshot?.position.inSeconds ?? 0,
        );
      }),
    );
    final position = snapshotPosition.hasSource
        ? Duration(seconds: snapshotPosition.seconds)
        : ref.watch(
            playerControllerProvider.select(
              (value) => value.value?.lastPosition ?? Duration.zero,
            ),
          );
    final lyrics = ref.watch(currentLyricsProvider);
    return lyrics.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text(error.toString())),
      data: (document) {
        if (document == null || document.lines.isEmpty) {
          return const Center(child: Text('No lyrics linked.'));
        }
        if (document.offset != _lastDocumentOffset) {
          _lastDocumentOffset = document.offset;
          _lastActiveIndex = -1;
        }
        final activeIndex = document.activeIndex(position);
        if (activeIndex != _lastActiveIndex && activeIndex >= 0) {
          _lastActiveIndex = activeIndex;
          _scrollActiveLineIntoView(activeIndex);
        }
        return ExcludeSemantics(
          child: ListView.builder(
            controller: _scrollController,
            itemExtent: _lyricLineExtent,
            itemCount: document.lines.length,
            itemBuilder: (context, index) {
              final line = document.lines[index];
              final active = index == activeIndex;
              return DefaultTextStyle(
                style:
                    (active
                            ? Theme.of(context).textTheme.titleLarge
                            : Theme.of(context).textTheme.bodyLarge)
                        ?.copyWith(
                          color: active
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ) ??
                    const TextStyle(),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    line.text.isEmpty ? '...' : line.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _scrollActiveLineIntoView(int activeIndex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final position = _scrollController.position;
      final target =
          activeIndex * _lyricLineExtent -
          (position.viewportDimension - _lyricLineExtent) / 2;
      _scrollController.jumpTo(
        target.clamp(0, position.maxScrollExtent).toDouble(),
      );
    });
  }
}

class _LyricOffsetMenuPanel extends ConsumerStatefulWidget {
  const _LyricOffsetMenuPanel({required this.item});

  final PlaybackItem item;

  @override
  ConsumerState<_LyricOffsetMenuPanel> createState() =>
      _LyricOffsetMenuPanelState();
}

class _LyricOffsetMenuPanelState extends ConsumerState<_LyricOffsetMenuPanel> {
  double _offsetMs = 0;
  Duration? _queuedOffset;
  bool _persistingOffset = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      final offset = await ref
          .read(lyricRepositoryProvider)
          .offsetForItem(widget.item.id);
      if (mounted) {
        setState(() {
          _offsetMs = offset.inMilliseconds.toDouble();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: RobyneDialogWidth.forContext(context, 280),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.tune, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Lyric offset',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                '${(_offsetMs / 1000).toStringAsFixed(2)}s',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            key: const Key('lyric-offset-slider'),
            min: -10000,
            max: 10000,
            divisions: 80,
            value: _offsetMs.clamp(-10000, 10000).toDouble(),
            onChanged: _applyOffset,
          ),
          Text(
            'Drag to shift lyric timing in real time.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  void _applyOffset(double value) {
    final offset = Duration(milliseconds: value.round());
    setState(() {
      _offsetMs = value;
    });
    ref
        .read(lyricLiveOffsetProvider(widget.item.id).notifier)
        .setOffset(offset);
    _queuedOffset = offset;
    if (!_persistingOffset) {
      unawaited(_drainOffsetWrites());
    }
  }

  Future<void> _drainOffsetWrites() async {
    _persistingOffset = true;
    try {
      while (mounted && _queuedOffset != null) {
        final offset = _queuedOffset!;
        _queuedOffset = null;
        await ref.read(lyricRepositoryProvider).setOffset(widget.item, offset);
        ref.invalidate(storedCurrentLyricsProvider);
      }
    } finally {
      _persistingOffset = false;
      if (mounted && _queuedOffset != null) {
        unawaited(_drainOffsetWrites());
      }
    }
  }
}

class _LyricSearchDialog extends ConsumerStatefulWidget {
  const _LyricSearchDialog({required this.item});

  final PlaybackItem item;

  @override
  ConsumerState<_LyricSearchDialog> createState() => _LyricSearchDialogState();
}

class _LyricSearchDialogState extends ConsumerState<_LyricSearchDialog> {
  late final TextEditingController _controller;
  bool _autoSearched = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.title);
    attachImeTextControllerTrace(_controller, 'lyrics.searchKeyword');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plugins =
        ref.watch(pluginControllerProvider).value ?? const <PluginDefinition>[];
    if (!_autoSearched && plugins.isNotEmpty) {
      _autoSearched = true;
      Future<void>.microtask(() {
        ref
            .read(lyricSearchControllerProvider.notifier)
            .search(_controller.text, plugins);
      });
    }
    final state =
        ref.watch(lyricSearchControllerProvider).value ??
        const LyricSearchState();
    final selected = state.selectedPluginResult;

    return AlertDialog(
      title: const Text('Search lyrics'),
      content: SizedBox(
        width: RobyneDialogWidth.forContext(context, 720),
        height: RobyneDialogWidth.heightForContext(context, 520),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) {
                      if (state.isSearching) {
                        return;
                      }
                      unawaited(
                        ref
                            .read(lyricSearchControllerProvider.notifier)
                            .search(_controller.text, plugins),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SearchActionButton(
                  isSearching: state.isSearching,
                  onSearch: () => unawaited(
                    ref
                        .read(lyricSearchControllerProvider.notifier)
                        .search(_controller.text, plugins),
                  ),
                  onCancel: () =>
                      ref.read(lyricSearchControllerProvider.notifier).cancel(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: state.pluginResults.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final result = state.pluginResults[index];
                  return ChoiceChip(
                    selected: result.pluginId == selected?.pluginId,
                    label: Text(
                      result.isSearching
                          ? '${result.platform} ...'
                          : result.error != null
                          ? '${result.platform} !'
                          : '${result.platform} ${result.items.length}',
                    ),
                    onSelected: (_) => ref
                        .read(lyricSearchControllerProvider.notifier)
                        .selectPlugin(result.pluginId),
                  );
                },
              ),
            ),
            const Divider(height: 24),
            Expanded(
              child: selected == null
                  ? const Center(child: Text('No lyric plugins.'))
                  : selected.isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : selected.error != null && selected.items.isEmpty
                  ? Center(
                      child: Text(
                        '${selected.error!.code}: ${selected.error!.message}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: selected.items.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final candidate = selected.items[index];
                        return ListTile(
                          title: Text(candidate.title),
                          subtitle: Text(
                            <String?>[
                                  candidate.artist,
                                  candidate.album,
                                  candidate.platform,
                                ]
                                .whereType<String>()
                                .where((value) => value.isNotEmpty)
                                .join(' - '),
                          ),
                          onTap: () async {
                            final error = await ref
                                .read(lyricSearchControllerProvider.notifier)
                                .associateCandidate(
                                  item: widget.item,
                                  candidate: candidate,
                                  plugins: plugins,
                                );
                            if (error == null && context.mounted) {
                              Navigator.of(context).pop();
                            } else if (error != null && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${error.code}: ${error.message}',
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
