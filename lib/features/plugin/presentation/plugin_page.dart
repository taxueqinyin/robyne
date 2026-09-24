import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import 'package:robyne/core/debug/ime_trace.dart';
import 'package:robyne/core/layout/window_size_class.dart';
import 'package:robyne/features/plugin/application/plugin_controller.dart';
import 'package:robyne/features/plugin/domain/plugin_definition.dart';
import 'package:robyne/features/plugin/domain/plugin_repository.dart';

class PluginPage extends ConsumerWidget {
  const PluginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pluginsValue = ref.watch(pluginControllerProvider);
    final importProgress = ref.watch(pluginImportProgressProvider);
    final isImporting = importProgress != null;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Plugins', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: isImporting
                    ? null
                    : () async {
                        final result = await FilePicker.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: <String>['js'],
                          allowMultiple: true,
                        );
                        final paths =
                            result?.files
                                .map((file) => file.path)
                                .whereType<String>()
                                .toList(growable: false) ??
                            const <String>[];
                        if (paths.isEmpty || !context.mounted) {
                          return;
                        }
                        _startPluginPathImport(context, ref, paths);
                      },
                icon: const Icon(Icons.file_open),
                label: const Text('Import files'),
              ),
              OutlinedButton.icon(
                onPressed: isImporting
                    ? null
                    : () async {
                        final path = await _pickPluginDirectory(context);
                        if (path == null || !context.mounted) {
                          return;
                        }
                        final paths = await _pluginFilesInDirectory(path);
                        if (!context.mounted) {
                          return;
                        }
                        if (paths.isEmpty) {
                          _showPluginError(
                            context,
                            'No JavaScript plugin files found.',
                          );
                          return;
                        }
                        _startPluginPathImport(context, ref, paths);
                      },
                icon: const Icon(Icons.folder_open),
                label: const Text('Import folder'),
              ),
              FilledButton.icon(
                onPressed: isImporting
                    ? null
                    : () async {
                        final url = await _showImportUrlDialog(context);
                        if (url == null || !context.mounted) {
                          return;
                        }
                        final error = await ref
                            .read(pluginControllerProvider.notifier)
                            .importFromUrl(url);
                        if (error != null && context.mounted) {
                          _showPluginError(context, error);
                        }
                      },
                icon: const Icon(Icons.link),
                label: const Text('Import from URL'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Import MusicFree-style JavaScript plugins from local files, folders, or URLs.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (importProgress != null) ...<Widget>[
            const SizedBox(height: 12),
            _PluginImportProgressView(progress: importProgress),
          ],
          const SizedBox(height: 24),
          Expanded(child: _PluginList(pluginsValue: pluginsValue)),
        ],
      ),
    );
  }
}

class _PluginList extends ConsumerWidget {
  const _PluginList({required this.pluginsValue});

  final AsyncValue<List<PluginDefinition>> pluginsValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plugins = pluginsValue.value;
    if (plugins == null) {
      return pluginsValue.when(
        data: (_) => const SizedBox.shrink(),
        error: (error, stackTrace) =>
            _PluginErrorPanel(message: error.toString()),
        loading: () => const Center(child: CircularProgressIndicator()),
      );
    }

    if (plugins.isEmpty) {
      return const Center(child: Text('No installed plugins yet.'));
    }

    return ListView.separated(
      itemCount: plugins.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
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
              if (plugin.userVariables.isNotEmpty)
                IconButton(
                  tooltip: 'Configure',
                  icon: const Icon(Icons.tune),
                  onPressed: () async {
                    final values = await _showUserVariablesDialog(
                      context,
                      plugin,
                    );
                    if (values == null || !context.mounted) {
                      return;
                    }
                    await ref
                        .read(pluginControllerProvider.notifier)
                        .updateUserVariableValues(plugin.id, values);
                  },
                ),
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
                  ref.read(pluginControllerProvider.notifier).delete(plugin.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<String?> _showImportUrlDialog(BuildContext context) async {
  return showDialog<String>(
    context: context,
    builder: (context) => const _ImportUrlDialog(),
  );
}

void _showPluginError(BuildContext context, Object error) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(error.toString())));
}

void _startPluginPathImport(
  BuildContext context,
  WidgetRef ref,
  List<String> paths,
) {
  unawaited(
    Future<void>(() async {
      final result = await ref
          .read(pluginControllerProvider.notifier)
          .importFromPaths(paths);
      if (context.mounted) {
        _showPluginImportResult(context, result);
      }
    }),
  );
}

void _showPluginImportResult(
  BuildContext context,
  PluginImportBatchResult result,
) {
  final summary =
      'Imported ${result.importedCount}, '
      'updated ${result.updatedCount}, '
      'skipped ${result.skippedCount}';
  final message = result.hasErrors
      ? '$summary; ${result.errors.length} failed. ${result.errors.first.code}: ${result.errors.first.message}'
      : '$summary.';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<String?> _pickPluginDirectory(BuildContext context) async {
  try {
    return await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose plugin folder',
    );
  } catch (error) {
    if (context.mounted) {
      _showPluginError(context, error);
    }
    return null;
  }
}

Future<List<String>> _pluginFilesInDirectory(String path) async {
  final directory = Directory(path);
  if (!await directory.exists()) {
    return const <String>[];
  }
  final paths = <String>[];
  await for (final entity in directory.list(recursive: true)) {
    if (entity is File && p.extension(entity.path).toLowerCase() == '.js') {
      paths.add(entity.path);
    }
  }
  paths.sort();
  return paths;
}

class _PluginImportProgressView extends StatelessWidget {
  const _PluginImportProgressView({required this.progress});

  final PluginImportProgress progress;

  @override
  Widget build(BuildContext context) {
    final current = progress.currentLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LinearProgressIndicator(value: progress.fraction),
        const SizedBox(height: 6),
        Text(
          current == null
              ? 'Preparing plugin import...'
              : 'Importing ${p.basename(current)} (${progress.completed}/${progress.total})',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

Future<Map<String, String>?> _showUserVariablesDialog(
  BuildContext context,
  PluginDefinition plugin,
) async {
  return showDialog<Map<String, String>>(
    context: context,
    builder: (context) => _UserVariablesDialog(plugin: plugin),
  );
}

class _ImportUrlDialog extends StatefulWidget {
  const _ImportUrlDialog();

  @override
  State<_ImportUrlDialog> createState() => _ImportUrlDialogState();
}

class _ImportUrlDialogState extends State<_ImportUrlDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    attachImeTextControllerTrace(_controller, 'plugins.importUrl');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import plugin from URL'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Plugin URL',
            hintText: 'https://example.com/plugin.js',
          ),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          validator: (value) {
            final raw = value?.trim() ?? '';
            final uri = Uri.tryParse(raw);
            if (uri == null ||
                !uri.hasAbsolutePath ||
                (uri.scheme != 'http' && uri.scheme != 'https')) {
              return 'Enter an http:// or https:// URL.';
            }
            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Import')),
      ],
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }
}

class _UserVariablesDialog extends StatefulWidget {
  const _UserVariablesDialog({required this.plugin});

  final PluginDefinition plugin;

  @override
  State<_UserVariablesDialog> createState() => _UserVariablesDialogState();
}

class _UserVariablesDialogState extends State<_UserVariablesDialog> {
  final _controllers = <String, TextEditingController>{};
  final _boolValues = <String, bool>{};

  @override
  void initState() {
    super.initState();
    for (final variable in widget.plugin.userVariables) {
      final key = variable['key']?.toString();
      if (key == null || key.isEmpty) {
        continue;
      }
      final value = widget.plugin.userVariableValues[key] ?? '';
      if (_isBooleanVariable(variable)) {
        _boolValues[key] = value.toLowerCase() == 'true' || value == '1';
      } else {
        final controller = TextEditingController(text: value);
        attachImeTextControllerTrace(controller, 'plugins.variable.$key');
        _controllers[key] = controller;
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plugin = widget.plugin;
    return AlertDialog(
      title: Text('Configure ${plugin.platform}'),
      content: SizedBox(
        width: RobyneDialogWidth.forContext(context, 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: plugin.userVariables
                .map((variable) {
                  final key = variable['key']?.toString() ?? '';
                  if (key.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  final name = variable['name']?.toString() ?? key;
                  final hint = variable['hint']?.toString();
                  if (_isBooleanVariable(variable)) {
                    return SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(name),
                      subtitle: hint == null || hint.isEmpty
                          ? null
                          : Text(hint),
                      value: _boolValues[key] ?? false,
                      onChanged: (value) {
                        setState(() {
                          _boolValues[key] = value;
                        });
                      },
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: _controllers[key],
                      decoration: InputDecoration(
                        labelText: name,
                        hintText: hint,
                        border: const OutlineInputBorder(),
                      ),
                      minLines: _isLongTextVariable(variable) ? 3 : 1,
                      maxLines: _isLongTextVariable(variable) ? 5 : 1,
                    ),
                  );
                })
                .toList(growable: false),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final values = <String, String>{
              for (final entry in _controllers.entries)
                entry.key: entry.value.text,
              for (final entry in _boolValues.entries)
                entry.key: entry.value.toString(),
            };
            Navigator.of(context).pop(values);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

bool _isBooleanVariable(Map<String, Object?> variable) {
  final type = variable['type']?.toString().toLowerCase();
  return type == 'boolean' || type == 'bool' || type == 'switch';
}

bool _isLongTextVariable(Map<String, Object?> variable) {
  final key = variable['key']?.toString().toLowerCase() ?? '';
  final name = variable['name']?.toString().toLowerCase() ?? '';
  return key.contains('cookie') ||
      key.contains('token') ||
      name.contains('cookie') ||
      name.contains('token');
}

class _PluginErrorPanel extends StatelessWidget {
  const _PluginErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 36),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
