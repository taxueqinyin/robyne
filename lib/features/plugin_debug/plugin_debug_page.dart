import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:robyne/shared/providers/app_providers.dart';
import 'package:robyne/core/plugin/plugin_registry.dart';

class PluginDebugPage extends ConsumerWidget {
  const PluginDebugPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plugins = ref.watch(pluginListProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Plugin Debug')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['js'],
              );
              if (result != null && result.files.single.path != null) {
                final file = File(result.files.single.path!);
                final sourceCode = await file.readAsString();
                final sourcePath = result.files.single.name;
                try {
                  await ref
                      .read(pluginListProvider.notifier)
                      .loadPlugin(sourceCode, sourcePath);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Load failed: $e')),
                    );
                  }
                }
              }
            },
            child: Text('Import Plugin (.js)'),
          ),
          Expanded(
            child: plugins.isEmpty
                ? Center(child: Text('No plugins loaded'))
                : ListView.builder(
                    itemCount: plugins.length,
                    itemBuilder: (context, index) {
                      final plugin = plugins[index];
                      final holder = plugin is PluginInstanceHolder
                          ? plugin
                          : null;
                      return ListTile(
                        title: Text(plugin.meta.name),
                        subtitle: Text(
                          'id: ${plugin.meta.id} v${plugin.meta.version}'
                          '${holder != null ? ' [${holder.status.name}]' : ''}',
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () async {
                            try {
                              await ref
                                  .read(pluginListProvider.notifier)
                                  .unloadPlugin(plugin.meta.id);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Unload failed: $e')),
                                );
                              }
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
