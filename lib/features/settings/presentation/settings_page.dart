import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/debug/ime_trace.dart';
import '../application/settings_providers.dart';
import '../domain/user_settings.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(error.toString())),
        data: (settings) {
          return ListView(
            children: <Widget>[
              Text(
                'Settings',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.storage),
                title: const Text('Cache size'),
                subtitle: Text(_formatBytes(settings.cacheSizeBytes)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showCacheSizeDialog(context, ref, settings),
              ),
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('Cache location'),
                subtitle: Text(settings.cacheDirectoryPath),
                trailing: const Icon(Icons.folder_open),
                onTap: () => _pickCacheDirectory(context, ref, settings),
              ),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Download location'),
                subtitle: Text(settings.downloadsDirectoryPath),
                trailing: const Icon(Icons.folder_open),
                onTap: () => _pickDownloadsDirectory(context, ref, settings),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showCacheSizeDialog(
    BuildContext context,
    WidgetRef ref,
    UserSettings settings,
  ) async {
    final controller = TextEditingController(
      text: (settings.cacheSizeBytes / (1024 * 1024)).round().toString(),
    );
    attachImeTextControllerTrace(controller, 'settings.cacheSize');
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cache size'),
        content: SizedBox(
          width: 320,
          child: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Size',
              suffixText: 'MB',
            ),
            onSubmitted: (_) {
              Navigator.of(context).pop(int.tryParse(controller.text));
            },
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(int.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) {
      return;
    }
    await ref
        .read(settingsControllerProvider.notifier)
        .setCacheSizeBytes(value * 1024 * 1024);
  }

  Future<void> _pickCacheDirectory(
    BuildContext context,
    WidgetRef ref,
    UserSettings settings,
  ) async {
    final path = await _pickDirectory(
      context,
      dialogTitle: 'Choose cache location',
      initialDirectory: settings.cacheDirectoryPath,
    );
    if (path != null) {
      await ref
          .read(settingsControllerProvider.notifier)
          .setCacheDirectory(path);
    }
  }

  Future<void> _pickDownloadsDirectory(
    BuildContext context,
    WidgetRef ref,
    UserSettings settings,
  ) async {
    final path = await _pickDirectory(
      context,
      dialogTitle: 'Choose download location',
      initialDirectory: settings.downloadsDirectoryPath,
    );
    if (path != null) {
      await ref
          .read(settingsControllerProvider.notifier)
          .setDownloadsDirectory(path);
    }
  }

  Future<String?> _pickDirectory(
    BuildContext context, {
    required String dialogTitle,
    required String initialDirectory,
  }) async {
    try {
      return await FilePicker.getDirectoryPath(dialogTitle: dialogTitle);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open folder picker: $error')),
        );
        return _showManualDirectoryDialog(
          context,
          dialogTitle: dialogTitle,
          initialDirectory: initialDirectory,
        );
      }
      return null;
    }
  }

  Future<String?> _showManualDirectoryDialog(
    BuildContext context, {
    required String dialogTitle,
    required String initialDirectory,
  }) async {
    final controller = TextEditingController(text: initialDirectory);
    attachImeTextControllerTrace(controller, 'settings.manualDirectory');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(dialogTitle),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Folder path',
            ),
            onSubmitted: (_) =>
                Navigator.of(context).pop(controller.text.trim()),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value?.trim().isEmpty == true ? null : value;
  }

  String _formatBytes(int bytes) {
    final mb = bytes / (1024 * 1024);
    if (mb >= 1024) {
      final gb = mb / 1024;
      return '${gb.toStringAsFixed(gb.truncateToDouble() == gb ? 0 : 1)} GB';
    }
    return '${mb.round()} MB';
  }
}
