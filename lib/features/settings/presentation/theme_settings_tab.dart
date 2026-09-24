import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/application/theme_controller.dart';
import '../../../core/theme/application/theme_mode_providers.dart';
import '../../../core/theme/application/theme_providers.dart';
import '../../../core/theme/domain/theme_layout.dart';
import '../../../core/theme/domain/theme_package.dart';
import '../../../core/theme/domain/theme_tokens.dart';
import '../../../core/theme/infrastructure/token_resolver.dart';
import '../../../core/theme/presentation/theme_setting_control.dart';
import 'package:file_picker/file_picker.dart';

import '../application/settings_providers.dart';

/// Lets the user pick a skin, force light/dark, and see the knobs a skin
/// exposes. This doubles as the discovery surface for community skins.
class ThemeSettingsTab extends ConsumerWidget {
  const ThemeSettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeControllerProvider);
    final tokens = ref.watch(activeThemeTokensProvider);
    final textTheme = Theme.of(context).textTheme;

    return themeState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('皮肤加载失败！')),
      data: (state) {
        final available = state.available;
        final active = state.package;
        return ListView(
          children: <Widget>[
            if (state.lastError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _ThemeBanner(message: state.lastError!),
              ),
            Text('外观模式', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            const _ThemeModeSelector(),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Text('皮肤', style: textTheme.titleMedium),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '共 ${available.length} 个，内置即官方 UI 本身',
                    style: textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                for (final theme in available)
                  _ThemeCard(
                    theme: theme,
                    selected: theme.id == active.id,
                    onTap: () => ref
                        .read(themeControllerProvider.notifier)
                        .selectTheme(theme.id),
                  ),
              ],
            ),
            if (active.settings.isNotEmpty) ...<Widget>[
              const SizedBox(height: 24),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '「${active.name}」可调项',
                      style: textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('由皮肤作者声明，调整后立即生效', style: textTheme.bodySmall),
                  ),
                  TextButton.icon(
                    onPressed: () => _resetKnobs(ref, active),
                    icon: const Icon(Icons.restart_alt, size: 16),
                    label: const Text('恢复默认'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Consumer(
                builder: (context, ref, _) {
                  final values = ref.watch(activeThemeSettingValuesProvider);
                  return Column(
                    children: <Widget>[
                      for (final setting in active.settings)
                        ThemeSettingControl(
                          theme: active,
                          setting: setting,
                          value: values[setting.key] ?? setting.defaultValue,
                        ),
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Text('管理', style: textTheme.titleMedium),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => _importTheme(ref, context),
                  icon: const Icon(Icons.file_open_outlined, size: 16),
                  label: const Text('导入皮肤'),
                ),
                if (active.source == ThemeSource.user) ...<Widget>[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _deleteTheme(ref, context, active),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('删除'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            Text('布局', style: textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('皮肤声明的骨架参数；桌面与手机可分别指定。', style: textTheme.bodySmall),
            const SizedBox(height: 12),
            _LayoutSummary(layout: active.layout),
            const SizedBox(height: 24),
            Text('当前 Tokens', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            _TokenPreview(tokens: tokens),
          ],
        );
      },
    );
  }
}

class _ThemeBanner extends StatelessWidget {
  const _ThemeBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.maybeOf(context)?.tokens;
    final warning = tokens?.color.warning ?? Colors.amber;
    final radius = tokens?.radius.md ?? 8;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: warning),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.warning_amber_rounded, size: 18, color: warning),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _ThemeModeSelector extends ConsumerWidget {
  const _ThemeModeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final override = ref.watch(themeModeOverrideProvider);
    return SegmentedButton<ThemeMode>(
      segments: const <ButtonSegment<ThemeMode>>[
        ButtonSegment<ThemeMode>(
          value: ThemeMode.system,
          icon: Icon(Icons.brightness_auto_outlined),
          label: Text('跟随皮肤'),
        ),
        ButtonSegment<ThemeMode>(
          value: ThemeMode.light,
          icon: Icon(Icons.light_mode_outlined),
          label: Text('亮色'),
        ),
        ButtonSegment<ThemeMode>(
          value: ThemeMode.dark,
          icon: Icon(Icons.dark_mode_outlined),
          label: Text('暗色'),
        ),
      ],
      selected: <ThemeMode>{override},
      onSelectionChanged: (selection) {
        ref.read(themeModeOverrideProvider.notifier).set(selection.first);
      },
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final ThemePackage theme;
  final bool selected;
  final VoidCallback onTap;

  Color? _previewColor() {
    final preview = theme.preview;
    if (preview == null || !preview.startsWith('#')) {
      return null;
    }
    final hex = preview.substring(1);
    final buffer = StringBuffer();
    if (hex.length == 3) {
      buffer.write('FF');
      for (final unit in hex.split('')) {
        buffer.write(unit * 2);
      }
    } else if (hex.length == 6) {
      buffer.write('FF$hex');
    } else if (hex.length == 8) {
      buffer.write(hex);
    } else {
      return null;
    }
    final parsed = int.tryParse(buffer.toString(), radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = theme.tokens;
    final brand = tokens.color.brandBase;
    final background = tokens.color.backgroundBase;
    final previewColor = _previewColor() ?? background;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radius.md),
      child: LayoutBuilder(
        builder: (context, constraints) => AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          // The card was pinned to 168dp; two of those plus spacing overflow a
          // 400dp phone. Prefer the declared width, but never exceed the
          // available one. See ADR-001 decision D4.
          width: constraints.maxWidth.isFinite && constraints.maxWidth < 168
              ? constraints.maxWidth
              : 168,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tokens.color.surfaceBase,
            borderRadius: BorderRadius.circular(tokens.radius.md),
            border: Border.all(
              color: selected ? brand : tokens.color.borderDefault,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                height: 72,
                decoration: BoxDecoration(
                  color: previewColor,
                  borderRadius: BorderRadius.circular(tokens.radius.sm),
                  gradient: LinearGradient(
                    colors: <Color>[background, brand.withValues(alpha: 0.35)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: selected
                    ? Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.check_circle,
                            color: brand,
                            size: 18,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 10),
              Text(
                theme.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: tokens.color.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                theme.author.isEmpty ? '未知作者' : theme.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: tokens.color.textMuted),
              ),
              if (theme.source == ThemeSource.builtIn) ...<Widget>[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: brand.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(tokens.radius.sm),
                  ),
                  child: Text(
                    '内置',
                    style: TextStyle(fontSize: 10, color: brand),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

void _resetKnobs(WidgetRef ref, ThemePackage theme) {
  for (final setting in theme.settings) {
    ref
        .read(settingsControllerProvider.notifier)
        .setThemeSettingValue(theme.id, setting.key, null);
  }
}

Future<void> _importTheme(WidgetRef ref, BuildContext context) async {
  final path = await FilePicker.getDirectoryPath(dialogTitle: '选择皮肤文件夹');
  if (path == null) {
    return;
  }
  final error = await ref.read(themeImportControllerProvider).importFrom(path);
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? '导入成功')));
  }
}

Future<void> _deleteTheme(
  WidgetRef ref,
  BuildContext context,
  ThemePackage theme,
) async {
  // Deleting a skin removes its whole directory, so ask first: the action is
  // irreversible and there is no undo.
  final confirmed =
      await showAdaptiveDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog.adaptive(
            title: const Text('删除皮肤'),
            content: Text('「${theme.name}」将被永久删除，此操作无法撤销。'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('删除'),
              ),
            ],
          );
        },
      ) ??
      false;
  if (!confirmed) {
    return;
  }
  await ref.read(themeImportControllerProvider).delete(theme.id);
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已删除「${theme.name}」')));
  }
}

class _LayoutSummary extends StatelessWidget {
  const _LayoutSummary({required this.layout});

  final ThemeLayout layout;

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = layout.desktop;
    final m = layout.mobile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('桌面', style: Theme.of(context).textTheme.bodyMedium),
        _row('侧栏位置', d.sidebar.position.name),
        _row('侧栏宽度', d.sidebar.effectiveWidth.toStringAsFixed(0)),
        _row('标签显示', d.sidebar.labelMode.name),
        _row('播放条高度', d.playerBarHeight.toStringAsFixed(0)),
        const SizedBox(height: 8),
        Text('手机', style: Theme.of(context).textTheme.bodyMedium),
        _row('导航', m.navigation.name),
        _row('播放条高度', m.playerBarHeight.toStringAsFixed(0)),
        _row('紧凑模式', m.playerBarCompact ? '开' : '关'),
        const SizedBox(height: 8),
        Text('内容', style: Theme.of(context).textTheme.bodyMedium),
        _row('列表样式', layout.content.listStyle.name),
        _row('密度', layout.content.density.name),
      ],
    );
  }
}

class _TokenPreview extends StatelessWidget {
  const _TokenPreview({required this.tokens});

  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final swatches = <MapEntry<String, Color>>[
      MapEntry<String, Color>('backgroundBase', tokens.color.backgroundBase),
      MapEntry<String, Color>(
        'backgroundElevated',
        tokens.color.backgroundElevated,
      ),
      MapEntry<String, Color>('surfaceBase', tokens.color.surfaceBase),
      MapEntry<String, Color>('brandBase', tokens.color.brandBase),
      MapEntry<String, Color>('textPrimary', tokens.color.textPrimary),
      MapEntry<String, Color>('textSecondary', tokens.color.textSecondary),
      MapEntry<String, Color>('borderDefault', tokens.color.borderDefault),
      MapEntry<String, Color>('success', tokens.color.success),
      MapEntry<String, Color>('danger', tokens.color.danger),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        for (final swatch in swatches)
          SizedBox(
            width: 96,
            child: Column(
              children: <Widget>[
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: swatch.value,
                    borderRadius: BorderRadius.circular(tokens.radius.sm),
                    border: Border.all(color: tokens.color.borderSubtle),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  swatch.key,
                  style: const TextStyle(fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
