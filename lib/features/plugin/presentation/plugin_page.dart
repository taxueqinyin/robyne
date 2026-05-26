import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import 'package:robyne/features/plugin/application/plugin_controller.dart';

class PluginPage extends ConsumerWidget {
  const PluginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pluginsValue = ref.watch(pluginControllerProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Plugins',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final result = await FilePicker.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: <String>['js'],
                    allowMultiple: false,
                  );
                  final path = result?.files.single.path;
                  if (path == null || !context.mounted) {
                    return;
                  }
                  await ref
                      .read(pluginControllerProvider.notifier)
                      .importFromPath(path);
                },
                icon: const Icon(Icons.file_open),
                label: const Text('Import from file'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Import MusicFree-style JavaScript plugins from local files.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: pluginsValue.when(
              data: (plugins) {
                if (plugins.isEmpty) {
                  return const Center(child: Text('No installed plugins yet.'));
                }
                return ListView.separated(
                  itemCount: plugins.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final plugin = plugins[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.extension),
                      title: Text(plugin.platform),
                      subtitle: Text(
                        <String?>[
                              plugin.version,
                              plugin.author,
                              plugin.supportedSearchTypes.join(', '),
                            ]
                            .whereType<String>()
                            .where((value) => value.isNotEmpty)
                            .join(' - '),
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: <Widget>[
                          Switch(
                            value: plugin.enabled,
                            onChanged: (enabled) {
                              ref
                                  .read(pluginControllerProvider.notifier)
                                  .setEnabled(plugin.id, enabled);
                            },
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              ref
                                  .read(pluginControllerProvider.notifier)
                                  .delete(plugin.id);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              error: (error, stackTrace) =>
                  Center(child: Text(error.toString())),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }
}
