import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robyne/shared/providers/app_providers.dart';
import 'package:robyne/shared/models/track.dart';

class SearchDebugPage extends ConsumerStatefulWidget {
  const SearchDebugPage({super.key});
  @override
  ConsumerState<SearchDebugPage> createState() => _SearchDebugPageState();
}

class _SearchDebugPageState extends ConsumerState<SearchDebugPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Search Debug')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(hintText: 'Search keyword...'),
                    onSubmitted: (_) => _doSearch(),
                  ),
                ),
                ElevatedButton(
                  onPressed: _doSearch,
                  child: Text('Search'),
                ),
              ],
            ),
          ),
          Expanded(
            child: searchResults.when(
              data: (results) {
                if (results.isEmpty) return Center(child: Text('No results'));
                return ListView(
                  children: results.entries.expand((entry) {
                    return [
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          entry.key,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      ...() {
                        final tracks = entry.value;
                        return tracks.asMap().entries.map(
                          (indexed) => ListTile(
                            title: Text(indexed.value.title),
                            subtitle: Text(indexed.value.artist),
                            onTap: () => _playAll(tracks, indexed.key),
                          ),
                        );
                      }(),
                    ];
                  }).toList(),
                );
              },
              loading: () => Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  void _doSearch() {
    if (_searchController.text.isNotEmpty) {
      ref.read(searchResultsProvider.notifier).search(_searchController.text);
    }
  }

  void _playAll(List<RemoteTrack> tracks, int startIndex) async {
    final service = ref.read(playbackServiceProvider);
    // 设置播放队列
    final items = tracks.map((t) => QueueItem.fromTrack(t)).toList();
    service.setQueue(items, startIndex: startIndex);
  }
}
