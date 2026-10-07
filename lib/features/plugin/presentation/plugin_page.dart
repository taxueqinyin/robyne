import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import 'package:robyne/core/debug/ime_trace.dart';
import 'package:robyne/core/layout/window_size_class.dart';
import 'package:robyne/core/theme/application/theme_providers.dart';
import 'package:robyne/core/theme/domain/theme_strings.dart';
import 'package:robyne/core/theme/infrastructure/token_resolver.dart';
import 'package:robyne/shared/widgets/plugin_sort_picker.dart';
import 'package:robyne/shared/widgets/reorderable_handle.dart';
import 'package:robyne/features/plugin/application/plugin_controller.dart';
import 'package:robyne/features/plugin/domain/plugin_definition.dart';
import 'package:robyne/features/plugin/domain/plugin_repository.dart';
import 'package:robyne/features/plugin/domain/plugin_sort.dart';

class PluginPage extends ConsumerWidget {
  const PluginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final metrics = ref.watch(activeThemeContentMetricsProvider);
    final compactWidth =
        WindowSizeClass.of(context).width != WindowWidthClass.expanded;
    final pluginsValue = ref.watch(pluginControllerProvider);
    final importProgress = ref.watch(pluginImportProgressProvider);
    final isImporting = importProgress != null;
    final buttonStyle = OutlinedButton.styleFrom(
      foregroundColor: colors.textSecondary,
      side: BorderSide(color: colors.borderDefault),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.gutterFor(compact: compactWidth),
        20,
        metrics.gutterFor(compact: compactWidth),
        20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            strings.resolve(ThemeStringKey.pluginsTitle),
            style: TextStyle(
              fontSize: tokens.typography.resolvedPageTitleSize,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
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
                        _startPluginPathImport(context, ref, paths, strings);
                      },
                icon: const Icon(Icons.file_open),
                label: Text(strings.resolve(ThemeStringKey.pluginsImportFiles)),
                style: buttonStyle,
              ),
              OutlinedButton.icon(
                onPressed: isImporting
                    ? null
                    : () async {
                        final path = await _pickPluginDirectory(
                          context,
                          strings,
                        );
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
                            strings.resolve(ThemeStringKey.pluginsNoJsFiles),
                          );
                          return;
                        }
                        _startPluginPathImport(context, ref, paths, strings);
                      },
                icon: const Icon(Icons.folder_open),
                label: Text(
                  strings.resolve(ThemeStringKey.pluginsImportFolder),
                ),
                style: buttonStyle,
              ),
              FilledButton.icon(
                onPressed: isImporting
                    ? null
                    : () async {
                        final url = await _showImportUrlDialog(context);
                        if (url == null || !context.mounted) {
                          return;
                        }
                        final result = await ref
                            .read(pluginControllerProvider.notifier)
                            .importFromUrlBatch(url);
                        if (context.mounted) {
                          _showPluginImportResult(context, result, strings);
                        }
                      },
                icon: const Icon(Icons.link),
                label: Text(strings.resolve(ThemeStringKey.pluginsImportUrl)),
              ),
              PluginSortPicker(
                strings: strings,
                order: ref.watch(pluginSortOrderProvider),
                onChanged: (order) =>
                    ref.read(pluginSortOrderProvider.notifier).set(order),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            strings.resolve(ThemeStringKey.pluginsSubtitle),
            style: TextStyle(fontSize: 12, color: colors.textMuted),
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
    final strings = ref.watch(activeThemeStringsProvider);
    final colors = RobyneTheme.of(context).tokens.color;
    final sortOrder = ref.watch(pluginSortOrderProvider);
    final plugins = pluginsValue.value;
    if (plugins == null) {
      return pluginsValue.when(
        data: (_) => const SizedBox.shrink(),
        error: (error, stackTrace) =>
            _PluginErrorPanel(message: error.toString()),
        loading: () => const Center(child: CircularProgressIndicator()),
      );
    }

    final visible = sortPlugins(plugins, sortOrder);

    if (visible.isEmpty) {
      return Center(
        child: Text(
          strings.resolve(ThemeStringKey.pluginsEmpty),
          style: TextStyle(color: colors.textMuted),
        ),
      );
    }

    // Dragging is only offered in the manual order, because the manual order
    // is the only one the rows actually store: dragging while sorted by name
    // would have to either silently switch the mode or throw the drag away,
    // and both are worse than showing why the handle is missing.
    final canReorder = sortOrder == PluginSortOrder.manual;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (canReorder && visible.length > 1) ...<Widget>[
          Text(
            strings.resolve(ThemeStringKey.pluginsSortDragHint),
            style: TextStyle(fontSize: 11.5, color: colors.textMuted),
          ),
          const SizedBox(height: 8),
        ],
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: visible.length,
            onReorder: canReorder
                ? (oldIndex, newIndex) {
                    final next = List<PluginDefinition>.of(visible);
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final moved = next.removeAt(oldIndex);
                    next.insert(newIndex, moved);
                    unawaited(
                      ref
                          .read(pluginControllerProvider.notifier)
                          .reorderPlugins(
                            next
                                .map((plugin) => plugin.id)
                                .toList(growable: false),
                          ),
                    );
                  }
                // Not draggable in a computed order: the row renders without
                // a handle, so a reorder is never requested from this mode.
                : (int from, int to) {},
            itemBuilder: (context, index) {
              final plugin = visible[index];
              return _PluginRow(
                key: ValueKey<String>(plugin.id),
                plugin: plugin,
                index: index,
                strings: strings,
                draggable: canReorder,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// One plugin row, with its own drag handle when the order is draggable.
///
/// A keyed widget rather than an inline `ListTile`: reordering rebuilds rows
/// by key, and the switch and button callbacks need the row's own plugin, not
/// an index that is already stale by the time the drag settles.
class _PluginRow extends ConsumerWidget {
  const _PluginRow({
    super.key,
    required this.plugin,
    required this.index,
    required this.strings,
    required this.draggable,
  });

  final PluginDefinition plugin;
  final int index;
  final ThemeStrings strings;
  final bool draggable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    return Container(
      // The row carries its own divider: `ReorderableListView` has no
      // separator builder, and the design's rows are separated lines.
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.borderSubtle, width: 1),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.only(right: 8),
        leading: draggable
            ? ReorderableHandle(
                index: index,
                tooltip: strings.resolve(ThemeStringKey.pluginsDragHandle),
              )
            : const Icon(Icons.extension),
        title: Text(plugin.platform),
        subtitle: Text(
          <String?>[
            plugin.version,
            plugin.author,
            plugin.supportedSearchTypes.join(', '),
          ].whereType<String>().where((value) => value.isNotEmpty).join(' - '),
        ),
        trailing: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            if (plugin.userVariables.isNotEmpty)
              IconButton(
                tooltip: strings.resolve(
                  ThemeStringKey.pluginsConfigureTooltip,
                ),
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
              tooltip: strings.resolve(ThemeStringKey.pluginsDelete),
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                ref.read(pluginControllerProvider.notifier).delete(plugin.id);
              },
            ),
          ],
        ),
      ),
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
  ThemeStrings strings,
) {
  unawaited(
    Future<void>(() async {
      final result = await ref
          .read(pluginControllerProvider.notifier)
          .importFromPaths(paths);
      if (context.mounted) {
        _showPluginImportResult(context, result, strings);
      }
    }),
  );
}

void _showPluginImportResult(
  BuildContext context,
  PluginImportBatchResult result,
  ThemeStrings strings,
) {
  // Counts and codes are data, but the sentence around them is chrome, so the
  // skin writes the template and the app fills the numbers.
  final summary = strings
      .resolve(ThemeStringKey.pluginsImportSummary)
      .replaceAll('{imported}', '${result.importedCount}')
      .replaceAll('{updated}', '${result.updatedCount}')
      .replaceAll('{skipped}', '${result.skippedCount}');
  final message = result.hasErrors
      ? '$summary ${strings.resolve(ThemeStringKey.pluginsImportFailed).replaceAll('{count}', '${result.errors.length}').replaceAll('{code}', result.errors.first.code).replaceAll('{message}', result.errors.first.message)}'
      : summary;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<String?> _pickPluginDirectory(
  BuildContext context,
  ThemeStrings strings,
) async {
  try {
    return await FilePicker.getDirectoryPath(
      dialogTitle: strings.resolve(ThemeStringKey.pluginsChooseFolder),
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

class _PluginImportProgressView extends ConsumerWidget {
  const _PluginImportProgressView({required this.progress});

  final PluginImportProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    final colors = RobyneTheme.of(context).tokens.color;
    final current = progress.currentLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LinearProgressIndicator(
          value: progress.fraction,
          backgroundColor: RobyneTheme.of(
            context,
          ).tokens.components.playerBar.progressTrack,
          valueColor: AlwaysStoppedAnimation<Color>(
            RobyneTheme.of(context).tokens.components.playerBar.progressActive,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          current == null
              ? strings.resolve(ThemeStringKey.pluginsImportPreparing)
              : strings
                    .resolve(ThemeStringKey.pluginsImportProgress)
                    .replaceAll('{file}', p.basename(current))
                    .replaceAll('{done}', '${progress.completed}')
                    .replaceAll('{total}', '${progress.total}'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: colors.textMuted),
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

class _ImportUrlDialog extends ConsumerStatefulWidget {
  const _ImportUrlDialog();

  @override
  ConsumerState<_ImportUrlDialog> createState() => _ImportUrlDialogState();
}

class _ImportUrlDialogState extends ConsumerState<_ImportUrlDialog> {
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
    final strings = ref.watch(activeThemeStringsProvider);
    return AlertDialog(
      title: Text(strings.resolve(ThemeStringKey.pluginsImportUrlTitle)),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: strings.resolve(ThemeStringKey.pluginsUrlField),
            hintText: strings.resolve(ThemeStringKey.pluginsUrlHint),
          ),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          validator: (value) {
            final raw = value?.trim() ?? '';
            final uri = Uri.tryParse(raw);
            if (uri == null ||
                !uri.hasAbsolutePath ||
                (uri.scheme != 'http' && uri.scheme != 'https')) {
              return strings.resolve(ThemeStringKey.pluginsUrlInvalid);
            }
            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.resolve(ThemeStringKey.actionCancel)),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(strings.resolve(ThemeStringKey.pluginsImport)),
        ),
      ],
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }
}

class _UserVariablesDialog extends ConsumerStatefulWidget {
  const _UserVariablesDialog({required this.plugin});

  final PluginDefinition plugin;

  @override
  ConsumerState<_UserVariablesDialog> createState() =>
      _UserVariablesDialogState();
}

class _UserVariablesDialogState extends ConsumerState<_UserVariablesDialog> {
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
    final strings = ref.watch(activeThemeStringsProvider);
    return AlertDialog(
      title: Text(
        strings
            .resolve(ThemeStringKey.pluginsConfigure)
            .replaceAll('{platform}', plugin.platform),
      ),
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
          child: Text(strings.resolve(ThemeStringKey.actionCancel)),
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
          child: Text(strings.resolve(ThemeStringKey.pluginsSave)),
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
              style: TextStyle(
                fontSize: RobyneTheme.of(
                  context,
                ).tokens.typography.resolvedListPrimarySize,
                color: RobyneTheme.of(context).tokens.color.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
