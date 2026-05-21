import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robyne/core/audio/audio_player_service.dart';
import 'package:robyne/core/plugin/plugin_manager.dart';
import 'package:robyne/core/plugin/plugin_models.dart';
import 'package:robyne/shared/models/song_model.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _searchController = TextEditingController();
  List<SearchResult> _searchResults = [];
  bool _isSearching = false;
  int? _selectedPluginId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pluginState = ref.watch(pluginManagerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search songs...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _performSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _performSearch,
                  child: const Text('Search'),
                ),
              ],
            ),
          ),
          if (pluginState.installedPlugins.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: DropdownButtonFormField<int>(
                value: _selectedPluginId,
                decoration: const InputDecoration(
                  labelText: 'Select Plugin',
                  border: OutlineInputBorder(),
                ),
                items: pluginState.installedPlugins
                    .where((p) => p.isEnabled)
                    .map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPluginId = value;
                  });
                },
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? const Center(child: Text('No results'))
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final result = _searchResults[index];
                          return ListTile(
                            leading: result.cover != null
                                ? Image.network(
                                    result.cover!,
                                    width: 48,
                                    height: 48,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.music_note),
                                  )
                                : const Icon(Icons.music_note),
                            title: Text(result.title),
                            subtitle: Text(result.artist ?? 'Unknown Artist'),
                            onTap: () => _playSong(result),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _performSearch() async {
    if (_searchController.text.isEmpty) return;
    if (_selectedPluginId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a plugin')),
      );
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await ref.read(pluginManagerProvider.notifier).search(
            _selectedPluginId!,
            _searchController.text,
          );
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _playSong(SearchResult result) async {
    if (_selectedPluginId == null) return;

    try {
      final mediaSource = await ref
          .read(pluginManagerProvider.notifier)
          .getMediaSource(_selectedPluginId!, {
        'id': result.id,
        'title': result.title,
        'artist': result.artist,
        'album': result.album,
        'cover': result.cover,
      });

      if (mediaSource != null) {
        final song = SongModel(
          id: 0,
          sourceId: result.id,
          title: result.title,
          artist: result.artist,
          album: result.album,
          coverUrl: result.cover,
          audioUrl: mediaSource.url,
          durationMs: result.duration,
          pluginId: _selectedPluginId,
        );

        ref.read(audioPlayerServiceProvider.notifier).playSong(song);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play: $e')),
        );
      }
    }
  }
}
