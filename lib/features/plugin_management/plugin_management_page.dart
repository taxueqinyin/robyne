import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robyne/core/plugin/plugin_manager.dart';

class PluginManagementPage extends ConsumerWidget {
  const PluginManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pluginState = ref.watch(pluginManagerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plugin Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _importPlugin(context, ref),
          ),
        ],
      ),
      body: pluginState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : pluginState.installedPlugins.isEmpty
              ? const Center(child: Text('No plugins installed'))
              : ListView.builder(
                  itemCount: pluginState.installedPlugins.length,
                  itemBuilder: (context, index) {
                    final plugin = pluginState.installedPlugins[index];
                    return ListTile(
                      title: Text(plugin.name),
                      subtitle: Text('${plugin.author} v${plugin.version}'),
                      trailing: Switch(
                        value: plugin.isEnabled,
                        onChanged: (value) {
                          if (value) {
                            ref
                                .read(pluginManagerProvider.notifier)
                                .enablePlugin(plugin.id);
                          } else {
                            ref
                                .read(pluginManagerProvider.notifier)
                                .disablePlugin(plugin.id);
                          }
                        },
                      ),
                      onLongPress: () =>
                          _showDeleteDialog(context, ref, plugin.id),
                    );
                  },
                ),
    );
  }

  Future<void> _importPlugin(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['js'],
      );

      if (result != null && result.files.single.path != null) {
        await ref
            .read(pluginManagerProvider.notifier)
            .installPlugin(result.files.single.path!);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Plugin installed successfully')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to install plugin: $e')),
        );
      }
    }
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, int pluginId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Uninstall Plugin'),
        content: const Text('Are you sure you want to uninstall this plugin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(pluginManagerProvider.notifier).uninstallPlugin(pluginId);
              Navigator.pop(context);
            },
            child: const Text('Uninstall'),
          ),
        ],
      ),
    );
  }
}
