import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import 'package:robyne/features/plugin/application/plugin_controller.dart';
import 'package:robyne/features/plugin/domain/plugin_definition.dart';

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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: <Widget>[
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
                      final error = await ref
                          .read(pluginControllerProvider.notifier)
                          .importFromPath(path);
                      if (error != null && context.mounted) {
                        _showPluginError(context, error);
                      }
                    },
                    icon: const Icon(Icons.file_open),
                    label: const Text('Import from file'),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
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
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Import MusicFree-style JavaScript plugins from local files.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
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
        _controllers[key] = TextEditingController(text: value);
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
        width: 520,
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
