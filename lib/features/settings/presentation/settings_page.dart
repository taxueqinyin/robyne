import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/debug/ime_trace.dart';
import '../../downloads/domain/download_audio_format.dart';
import '../../../core/layout/window_size_class.dart';
import '../../../core/theme/infrastructure/token_resolver.dart';
import '../application/settings_providers.dart';
import '../application/shortcut_runtime.dart';
import '../domain/lyric_settings.dart';
import '../domain/shortcut_action.dart';
import '../domain/shortcut_binding.dart';
import '../domain/shortcut_settings.dart';
import '../domain/user_settings.dart';
import 'theme_settings_tab.dart';

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
          return DefaultTabController(
            length: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('设置', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 24),
                // The tab bar was pinned to 420dp; on a 400dp phone it
                // overflowed and pushed the whole settings surface off-screen.
                SizedBox(
                  width: WindowSizeClass.of(
                    context,
                  ).clampDimension(420, maxRatio: 0.92),
                  child: TabBar(
                    dividerColor: Colors.transparent,
                    tabs: const <Tab>[
                      Tab(text: '常规'),
                      Tab(text: '外观'),
                      Tab(text: '快捷键'),
                      Tab(text: '歌词'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: TabBarView(
                    children: <Widget>[
                      _GeneralSettingsTab(settings: settings),
                      const ThemeSettingsTab(),
                      _ShortcutSettingsTab(settings: settings),
                      _LyricsSettingsTab(settings: settings),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

const _lyricFontOptions = <MapEntry<String, String?>>[
  MapEntry<String, String?>('默认', null),
  MapEntry<String, String?>('微软雅黑', 'Microsoft YaHei'),
  MapEntry<String, String?>('宋体', 'SimSun'),
  MapEntry<String, String?>('黑体', 'SimHei'),
  MapEntry<String, String?>('等线', 'DengXian'),
  MapEntry<String, String?>('楷体', 'KaiTi'),
];

const _lyricColorPalette = <int>[
  0xFFFFFFFF,
  0xFF3DD6A3,
  0xFF9A7CFF,
  0xFFE767AF,
  0xFF5C9DFF,
  0xFFFFC82E,
  0xFFFF7A1A,
  0xB3000000,
];

class _GeneralSettingsTab extends ConsumerWidget {
  const _GeneralSettingsTab({required this.settings});

  final UserSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      children: <Widget>[
        ListTile(
          leading: const Icon(Icons.storage),
          title: const Text('缓存大小'),
          subtitle: Text(_formatBytes(settings.cacheSizeBytes)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showCacheSizeDialog(context, ref, settings),
        ),
        ListTile(
          leading: const Icon(Icons.folder_outlined),
          title: const Text('缓存位置'),
          subtitle: Text(settings.cacheDirectoryPath),
          trailing: const Icon(Icons.folder_open),
          onTap: () => _pickCacheDirectory(context, ref, settings),
        ),
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: const Text('下载位置'),
          subtitle: Text(settings.downloadsDirectoryPath),
          trailing: const Icon(Icons.folder_open),
          onTap: () => _pickDownloadsDirectory(context, ref, settings),
        ),
        ListTile(
          leading: const Icon(Icons.audio_file_outlined),
          title: const Text('下载格式'),
          subtitle: Text(settings.downloadAudioFormat.label),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showDownloadFormatDialog(context, ref, settings),
        ),
      ],
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
        title: const Text('缓存大小'),
        content: SizedBox(
          width: RobyneDialogWidth.forContext(context, 320),
          child: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: '大小',
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
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(int.tryParse(controller.text)),
            child: const Text('保存'),
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
      dialogTitle: '选择缓存位置',
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
      dialogTitle: '选择下载位置',
      initialDirectory: settings.downloadsDirectoryPath,
    );
    if (path != null) {
      await ref
          .read(settingsControllerProvider.notifier)
          .setDownloadsDirectory(path);
    }
  }

  Future<void> _showDownloadFormatDialog(
    BuildContext context,
    WidgetRef ref,
    UserSettings settings,
  ) async {
    final value = await showDialog<DownloadAudioFormat>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('下载格式'),
        children: <Widget>[
          for (final format in DownloadAudioFormat.values)
            ListTile(
              title: Text(format.label),
              trailing: settings.downloadAudioFormat == format
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(context).pop(format),
            ),
        ],
      ),
    );
    if (value == null) {
      return;
    }
    await ref
        .read(settingsControllerProvider.notifier)
        .setDownloadAudioFormat(value);
  }
}

class _LyricsSettingsTab extends ConsumerWidget {
  const _LyricsSettingsTab({required this.settings});

  final UserSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyricSettings = settings.lyricSettings;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      children: <Widget>[
        _LyricsSwitchRow(
          title: '显示桌面歌词',
          subtitle: '支持桌面与播放器同步',
          value: lyricSettings.desktopLyricsEnabled,
          onChanged: (value) => ref
              .read(settingsControllerProvider.notifier)
              .setDesktopLyricsEnabled(value),
        ),
        _LyricsSwitchRow(
          title: '桌面歌词置顶',
          subtitle: '歌词窗口始终位于最前方',
          value: lyricSettings.desktopLyricsAlwaysOnTop,
          onChanged: (value) => ref
              .read(settingsControllerProvider.notifier)
              .setDesktopLyricsAlwaysOnTop(value),
        ),
        _LyricsSwitchRow(
          title: '锁定桌面歌词',
          subtitle: '锁定后歌词窗口不可拖动',
          value: lyricSettings.desktopLyricsLocked,
          onChanged: (value) => ref
              .read(settingsControllerProvider.notifier)
              .setDesktopLyricsLocked(value),
        ),
        _LyricsSwitchRow(
          title: '双排模式',
          subtitle: '显示当前句与下一句的左右对齐双排歌词',
          value: lyricSettings.desktopLyricsDoubleLine,
          onChanged: (value) => ref
              .read(settingsControllerProvider.notifier)
              .setDesktopLyricsDoubleLine(value),
          showDivider: false,
        ),
        const SizedBox(height: 16),
        _LyricsSettingRow(
          title: '歌词字体',
          subtitle: '桌面歌词使用的字体',
          control: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 200, maxWidth: 260),
            child: DropdownButtonFormField<String?>(
              initialValue: lyricSettings.desktopLyricFontFamily,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              items: _lyricFontOptions
                  .map(
                    (option) => DropdownMenuItem<String?>(
                      value: option.value,
                      child: Text(option.key),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => ref
                  .read(settingsControllerProvider.notifier)
                  .setDesktopLyricFontFamily(value),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _LyricsSettingRow(
          title: '歌词字体大小',
          subtitle:
              '桌面歌词字号 (${LyricSettings.minFontSize}-${LyricSettings.maxFontSize})',
          control: _FontSizeStepper(
            value: lyricSettings.desktopLyricFontSize,
            onDecrease: () => ref
                .read(settingsControllerProvider.notifier)
                .adjustDesktopLyricFontSize(-LyricSettings.fontSizeStep),
            onIncrease: () => ref
                .read(settingsControllerProvider.notifier)
                .adjustDesktopLyricFontSize(LyricSettings.fontSizeStep),
          ),
        ),
        const SizedBox(height: 20),
        _LyricsSettingRow(
          title: '歌词颜色',
          subtitle: '当前歌词填充颜色',
          control: _ColorPalettePicker(
            selectedColorValue: lyricSettings.desktopLyricTextColorValue,
            onSelected: (colorValue) => ref
                .read(settingsControllerProvider.notifier)
                .setDesktopLyricTextColorValue(colorValue),
          ),
        ),
        const SizedBox(height: 20),
        _LyricsSettingRow(
          title: '歌词描边颜色',
          subtitle: '歌词文字描边颜色',
          control: _ColorPalettePicker(
            selectedColorValue: lyricSettings.desktopLyricStrokeColorValue,
            noneLabel: '不描边',
            noneValue: LyricSettings.noStrokeColorValue,
            onSelected: (colorValue) => ref
                .read(settingsControllerProvider.notifier)
                .setDesktopLyricStrokeColorValue(colorValue),
          ),
        ),
      ],
    );
  }
}

class _ShortcutSettingsTab extends ConsumerWidget {
  const _ShortcutSettingsTab({required this.settings});

  final UserSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      itemCount: ShortcutAction.values.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final action = ShortcutAction.values[index];
        final binding = settings.shortcuts[action];
        return _ShortcutRow(
          action: action,
          binding: binding,
          onEdit: () => _editShortcut(context, ref, action),
          onClear: binding == null ? null : () => _clearShortcut(ref, action),
        );
      },
    );
  }

  Future<void> _editShortcut(
    BuildContext context,
    WidgetRef ref,
    ShortcutAction action,
  ) async {
    ref.read(shortcutCaptureActiveProvider.notifier).setActive(true);
    final result =
        await showDialog<ShortcutBinding>(
          context: context,
          builder: (context) => _ShortcutCaptureDialog(
            action: action,
            settings: settings.shortcuts,
            initialBinding: settings.shortcuts[action],
          ),
        ).whenComplete(() {
          ref.read(shortcutCaptureActiveProvider.notifier).setActive(false);
        });
    if (result == null) {
      return;
    }
    final conflict = settings.shortcuts.conflictingAction(action, result);
    if (conflict != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('与“${conflict.label}”冲突，未保存。')));
      return;
    }
    await ref
        .read(settingsControllerProvider.notifier)
        .setShortcutBinding(action, result);
  }

  Future<void> _clearShortcut(WidgetRef ref, ShortcutAction action) async {
    await ref
        .read(settingsControllerProvider.notifier)
        .setShortcutBinding(action, null);
  }
}

class _LyricsSettingRow extends StatelessWidget {
  const _LyricsSettingRow({
    required this.title,
    required this.subtitle,
    required this.control,
  });

  final String title;
  final String subtitle;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Flexible(
          child: Align(alignment: Alignment.centerRight, child: control),
        ),
      ],
    );
  }
}

class _LyricsSwitchRow extends StatelessWidget {
  const _LyricsSwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
      ],
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.action,
    required this.binding,
    required this.onEdit,
    required this.onClear,
  });

  final ShortcutAction action;
  final ShortcutBinding? binding;
  final VoidCallback onEdit;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(action.label, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      action.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '软件内',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      binding?.displayLabel ?? '未设置',
                      style: theme.textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              TextButton(onPressed: onClear, child: const Text('清除')),
            ],
          ),
        ),
      ),
    );
  }
}

class _FontSizeStepper extends StatelessWidget {
  const _FontSizeStepper({
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int value;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canDecrease = value > LyricSettings.minFontSize;
    final canIncrease = value < LyricSettings.maxFontSize;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          RobyneTheme.of(context).tokens.radius.md,
        ),
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            onPressed: canDecrease ? onDecrease : null,
            icon: const Icon(Icons.remove),
            tooltip: '减小字号',
          ),
          SizedBox(
            width: 56,
            child: Center(
              child: Text('$value', style: theme.textTheme.titleMedium),
            ),
          ),
          IconButton(
            onPressed: canIncrease ? onIncrease : null,
            icon: const Icon(Icons.add),
            tooltip: '增大字号',
          ),
        ],
      ),
    );
  }
}

class _ColorPalettePicker extends StatelessWidget {
  const _ColorPalettePicker({
    required this.selectedColorValue,
    required this.onSelected,
    this.noneLabel,
    this.noneValue,
  });

  final int selectedColorValue;
  final ValueChanged<int> onSelected;
  final String? noneLabel;
  final int? noneValue;

  @override
  Widget build(BuildContext context) {
    // Swatches are circular whatever the skin says, so they use the `full`
    // radius token rather than a literal 18 (half of the 32dp box).
    final fullRadius = RobyneTheme.of(context).tokens.radius.full;
    final children = <Widget>[
      if (noneLabel != null && noneValue != null)
        _NoColorOption(
          label: noneLabel!,
          selected: selectedColorValue == noneValue,
          onTap: () => onSelected(noneValue!),
        ),
    ];
    children.addAll(
      _lyricColorPalette.map((colorValue) {
        final color = Color(colorValue);
        final selected = colorValue == selectedColorValue;
        return Tooltip(
          message:
              '#${colorValue.toRadixString(16).padLeft(8, '0').toUpperCase()}',
          child: InkWell(
            borderRadius: BorderRadius.circular(fullRadius),
            onTap: () => onSelected(colorValue),
            child: Ink(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                  width: selected ? 3 : 1,
                ),
              ),
            ),
          ),
        );
      }),
    );
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.end,
      children: children,
    );
  }
}

class _NoColorOption extends StatelessWidget {
  const _NoColorOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A pill: fully rounded on the 32dp-tall chip.
    final pillRadius = RobyneTheme.of(context).tokens.radius.full;
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(pillRadius),
        onTap: onTap,
        child: Ink(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(pillRadius),
            color: theme.colorScheme.surfaceContainerHighest,
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.block_rounded,
                size: 16,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortcutCaptureDialog extends ConsumerStatefulWidget {
  const _ShortcutCaptureDialog({
    required this.action,
    required this.settings,
    required this.initialBinding,
  });

  final ShortcutAction action;
  final ShortcutSettings settings;
  final ShortcutBinding? initialBinding;

  @override
  ConsumerState<_ShortcutCaptureDialog> createState() =>
      _ShortcutCaptureDialogState();
}

class _ShortcutCaptureDialogState
    extends ConsumerState<_ShortcutCaptureDialog> {
  late final FocusNode _focusNode;
  ShortcutBinding? _binding;
  late int _tapCount;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'shortcut-capture');
    _binding = widget.initialBinding;
    _tapCount = widget.initialBinding?.tapCount ?? 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final conflict = _binding == null
        ? null
        : widget.settings.conflictingAction(widget.action, _binding);
    return AlertDialog(
      title: Text('设置 ${widget.action.label}'),
      content: SizedBox(
        width: RobyneDialogWidth.forContext(context, 460),
        child: Focus(
          focusNode: _focusNode,
          onKeyEvent: (node, event) {
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.of(context).pop();
              return KeyEventResult.handled;
            }
            final binding = shortcutBindingFromKeyEvent(
              event,
              tapCount: _tapCount,
            );
            if (binding == null) {
              return KeyEventResult.ignored;
            }
            setState(() {
              _binding = binding;
            });
            return KeyEventResult.handled;
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('点击下方区域后，按下要绑定的按键或组合键。'),
              const SizedBox(height: 16),
              SegmentedButton<int>(
                segments: const <ButtonSegment<int>>[
                  ButtonSegment<int>(value: 1, label: Text('单击')),
                  ButtonSegment<int>(value: 2, label: Text('双击')),
                ],
                selected: <int>{_tapCount},
                onSelectionChanged: (selection) {
                  final tapCount = selection.first;
                  setState(() {
                    _tapCount = tapCount;
                    if (_binding != null) {
                      _binding = _binding!.copyWith(tapCount: tapCount);
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _focusNode.requestFocus,
                child: Ink(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      RobyneTheme.of(context).tokens.radius.md,
                    ),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _binding?.displayLabel ?? '按下快捷键',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _focusNode.hasFocus ? '正在监听键盘输入' : '点击此区域开始录制',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (conflict != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  '与“${conflict.label}”冲突，请更换按键。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _binding == null || conflict != null
              ? null
              : () => Navigator.of(context).pop(_binding),
          child: const Text('保存'),
        ),
      ],
    );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法打开目录选择器：$error')));
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
        width: RobyneDialogWidth.forContext(context, 520),
        child: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: '文件夹路径',
          ),
          onSubmitted: (_) => Navigator.of(context).pop(controller.text.trim()),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: const Text('保存'),
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
