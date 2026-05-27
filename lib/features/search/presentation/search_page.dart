import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../player/application/player_providers.dart';
import '../../plugin/application/plugin_controller.dart';
import '../../plugin/domain/plugin_definition.dart';
import '../application/search_controller.dart' as search_state;
import '../domain/music_item.dart';

class SearchPage extends ConsumerWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pluginsValue = ref.watch(pluginControllerProvider);
    final searchValue = ref.watch(search_state.searchControllerProvider);
    final plugins = pluginsValue.value ?? const <PluginDefinition>[];
    final state = searchValue.value ?? const search_state.SearchState();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Robyne', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'MusicFree plugin runtime spike',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Keyword',
                  ),
                  onChanged: ref
                      .read(search_state.searchControllerProvider.notifier)
                      .updateKeyword,
                  onSubmitted: (_) => ref
                      .read(search_state.searchControllerProvider.notifier)
                      .search(plugins),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: state.isSearching
                    ? null
                    : () => ref
                          .read(search_state.searchControllerProvider.notifier)
                          .search(plugins),
                icon: state.isSearching
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: const Text('Search'),
              ),
            ],
          ),
          if (state.error != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              '${state.error!.code}: ${state.error!.message}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (state.pluginResults.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            _PluginTabs(
              state: state,
              onSelected: ref
                  .read(search_state.searchControllerProvider.notifier)
                  .selectPlugin,
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: _SearchResults(
              state: state,
              onLoadMore: () {
                ref
                    .read(search_state.searchControllerProvider.notifier)
                    .loadMoreSelected(plugins);
              },
              onPlay: (item) {
                ref
                    .read(playerControllerProvider.notifier)
                    .playFromPlugin(item);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PluginTabs extends StatelessWidget {
  const _PluginTabs({required this.state, required this.onSelected});

  final search_state.SearchState state;
  final void Function(String pluginId) onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: state.pluginResults.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final result = state.pluginResults[index];
          final selected =
              result.pluginId ==
              (state.selectedPluginId ?? state.pluginResults.first.pluginId);
          final loading = result.isSearching || result.isLoadingMore;
          final label = loading
              ? '${result.platform} ...'
              : result.error != null
              ? '${result.platform} !'
              : '${result.platform} ${result.resultCount}';
          return ChoiceChip(
            selected: selected,
            avatar: loading
                ? const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : result.error != null
                ? const Icon(Icons.error_outline, size: 18)
                : null,
            label: Text(label),
            onSelected: (_) => onSelected(result.pluginId),
          );
        },
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.state,
    required this.onLoadMore,
    required this.onPlay,
  });

  final search_state.SearchState state;
  final VoidCallback onLoadMore;
  final void Function(MusicItem item) onPlay;

  @override
  Widget build(BuildContext context) {
    final pluginResult = state.selectedPluginResult;
    if (pluginResult == null) {
      return const Center(child: Text('Import a plugin, then search music.'));
    }

    if (pluginResult.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (pluginResult.error != null && pluginResult.result == null) {
      return Center(
        child: Text(
          '${pluginResult.error!.code}: ${pluginResult.error!.message}',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    final result = pluginResult.result;
    if (result == null) {
      return const Center(child: Text('Import a plugin, then search music.'));
    }

    if (result.items.isEmpty) {
      return const Center(child: Text('No results.'));
    }

    final showFooter = pluginResult.isLoadingMore || pluginResult.error != null;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 600 &&
            !pluginResult.isLoadingMore &&
            pluginResult.error == null &&
            !result.isEnd) {
          onLoadMore();
        }
        return false;
      },
      child: ListView.separated(
        itemCount: result.items.length + (showFooter ? 1 : 0),
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index >= result.items.length) {
            return _SearchResultFooter(pluginResult: pluginResult);
          }

          final item = result.items[index];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.music_note),
            title: Text(item.title),
            subtitle: Text(
              <String?>[item.artist, item.album, item.platform]
                  .whereType<String>()
                  .where((value) => value.isNotEmpty)
                  .join(' - '),
            ),
            trailing: IconButton(
              tooltip: 'Play',
              icon: const Icon(Icons.play_arrow),
              onPressed: () => onPlay(item),
            ),
          );
        },
      ),
    );
  }
}

class _SearchResultFooter extends StatelessWidget {
  const _SearchResultFooter({required this.pluginResult});

  final search_state.PluginSearchState pluginResult;

  @override
  Widget build(BuildContext context) {
    if (pluginResult.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final error = pluginResult.error;
    if (error == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        '${error.code}: ${error.message}',
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
