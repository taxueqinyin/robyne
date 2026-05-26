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
                flex: 3,
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
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedPluginId(
                    state.selectedPluginId,
                    plugins,
                  ),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Plugin',
                  ),
                  items: plugins
                      .where((plugin) => plugin.enabled)
                      .map(
                        (plugin) => DropdownMenuItem<String>(
                          value: plugin.id,
                          child: Text(plugin.platform),
                        ),
                      )
                      .toList(),
                  onChanged: ref
                      .read(search_state.searchControllerProvider.notifier)
                      .selectPlugin,
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
          const SizedBox(height: 16),
          Expanded(
            child: _SearchResults(
              state: state,
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

  String? _selectedPluginId(
    String? selectedPluginId,
    List<PluginDefinition> plugins,
  ) {
    final enabled = plugins.where((plugin) => plugin.enabled).toList();
    if (enabled.isEmpty) {
      return null;
    }
    if (enabled.any((plugin) => plugin.id == selectedPluginId)) {
      return selectedPluginId;
    }
    return enabled.first.id;
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.state, required this.onPlay});

  final search_state.SearchState state;
  final void Function(MusicItem item) onPlay;

  @override
  Widget build(BuildContext context) {
    final result = state.result;
    if (result == null) {
      return const Center(child: Text('Import a plugin, then search music.'));
    }

    if (result.items.isEmpty) {
      return const Center(child: Text('No results.'));
    }

    return ListView.separated(
      itemCount: result.items.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
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
    );
  }
}
