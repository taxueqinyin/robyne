import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/debug/ime_trace.dart';
import '../../../core/theme/application/theme_providers.dart';
import '../../../core/theme/domain/theme_strings.dart';
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
    final strings = ref.watch(activeThemeStringsProvider);
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final metrics = ref.watch(activeThemeContentMetricsProvider);
    final compactWidth =
        WindowSizeClass.of(context).width != WindowWidthClass.expanded;
    final settings = ref.watch(settingsControllerProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.gutterFor(compact: compactWidth),
        20,
        metrics.gutterFor(compact: compactWidth),
        20,
      ),
      child: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(error.toString(), style: TextStyle(color: colors.danger)),
        ),
        data: (settings) {
          return DefaultTabController(
            length: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  strings.resolve(ThemeStringKey.settingsTitle),
                  style: TextStyle(
                    fontSize: tokens.typography.resolvedPageTitleSize,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 18),
                // The tab bar was pinned to 420dp; on a 400dp phone it
                // overflowed and pushed the whole settings surface off-screen.
                SizedBox(
                  width: WindowSizeClass.of(
                    context,
                  ).clampDimension(420, maxRatio: 0.92),
                  child: TabBar(
                    dividerColor: Colors.transparent,
                    tabs: <Tab>[
                      Tab(
                        text: strings.resolve(
                          ThemeStringKey.settingsTabGeneral,
                        ),
                      ),
                      Tab(
                        text: strings.resolve(
                          ThemeStringKey.settingsTabAppearance,
                        ),
                      ),
                      Tab(
                        text: strings.resolve(
                          ThemeStringKey.settingsTabShortcuts,
                        ),
                      ),
                      Tab(
                        text: strings.resolve(ThemeStringKey.settingsTabLyrics),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
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

/// One settings row: icon, title/subtitle, then a trailing affordance.
///
/// The mockup's settings rows sit on the card surface with a 34dp icon tile
/// and a dim affordance glyph. `ListTile` was the wrong tool because its
/// leading/trailing slots carry Material's own geometry and its selected tile
/// colour is not a skin token.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final IconData trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final comp = tokens.components;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: comp.card.surface,
        borderRadius: BorderRadius.all(Radius.circular(tokens.radius.md)),
        child: InkWell(
          borderRadius: BorderRadius.all(Radius.circular(tokens.radius.md)),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: colors.textPrimary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.all(
                      Radius.circular(tokens.radius.sm),
                    ),
                  ),
                  child: Icon(icon, size: 18, color: colors.textSecondary),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: tokens.typography.resolvedListPrimarySize,
                          fontWeight: FontWeight.w500,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
                Icon(trailing, size: 18, color: colors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GeneralSettingsTab extends ConsumerWidget {
  const _GeneralSettingsTab({required this.settings});

  final UserSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    return ListView(
      children: <Widget>[
        // The design's settings row is icon | title/subtitle | affordance, on
        // the skin's card surface — a `ListTile` carries Material's own
        // spacing and selected-tile colours that a skin cannot reach.
        _SettingsRow(
          icon: Icons.storage,
          title: strings.resolve(ThemeStringKey.settingsCacheSize),
          subtitle: _formatBytes(settings.cacheSizeBytes),
          trailing: Icons.chevron_right,
          onTap: () => _showCacheSizeDialog(context, ref, settings),
        ),
        _SettingsRow(
          icon: Icons.folder_outlined,
          title: strings.resolve(ThemeStringKey.settingsCacheLocation),
          subtitle: settings.cacheDirectoryPath,
          trailing: Icons.folder_open,
          onTap: () => _pickCacheDirectory(context, ref, settings),
        ),
        _SettingsRow(
          icon: Icons.download_outlined,
          title: strings.resolve(ThemeStringKey.settingsDownloadLocation),
          subtitle: settings.downloadsDirectoryPath,
          trailing: Icons.folder_open,
          onTap: () => _pickDownloadsDirectory(context, ref, settings),
        ),
        _SettingsRow(
          icon: Icons.audio_file_outlined,
          title: strings.resolve(ThemeStringKey.settingsDownloadFormat),
          subtitle: settings.downloadAudioFormat.label,
          trailing: Icons.chevron_right,
          onTap: () => _showDownloadFormatDialog(context, ref, settings),
        ),
        _SettingsRow(
          icon: Icons.queue_music_outlined,
          title: strings.resolve(ThemeStringKey.settingsPlaylistAction),
          subtitle: _playlistActionLabel(settings.playlistOpenAction, strings),
          trailing: Icons.chevron_right,
          onTap: () => _showPlaylistActionDialog(context, ref, settings),
        ),
        _SettingsRow(
          icon: Icons.close,
          title: strings.resolve(ThemeStringKey.settingsTrayCloseAction),
          subtitle: _trayCloseActionLabel(settings.trayCloseAction, strings),
          trailing: Icons.chevron_right,
          onTap: () => _showTrayCloseActionDialog(context, ref, settings),
        ),
      ],
    );
  }

  String _playlistActionLabel(PlaylistOpenAction action, ThemeStrings strings) {
    return switch (action) {
      PlaylistOpenAction.alwaysAsk => strings.resolve(
        ThemeStringKey.settingsPlaylistActionAsk,
      ),
      PlaylistOpenAction.append => strings.resolve(
        ThemeStringKey.settingsPlaylistActionAppend,
      ),
      PlaylistOpenAction.replace => strings.resolve(
        ThemeStringKey.settingsPlaylistActionReplace,
      ),
    };
  }

  Future<void> _showPlaylistActionDialog(
    BuildContext context,
    WidgetRef ref,
    UserSettings settings,
  ) async {
    final strings = ref.read(activeThemeStringsProvider);
    final action = await showDialog<PlaylistOpenAction>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(strings.resolve(ThemeStringKey.settingsPlaylistAction)),
        children: <Widget>[
          for (final action in PlaylistOpenAction.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(action),
              child: Row(
                children: <Widget>[
                  if (action == settings.playlistOpenAction)
                    Icon(
                      Icons.check,
                      size: 18,
                      color: RobyneTheme.of(context).tokens.color.brandBase,
                    )
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(_playlistActionLabel(action, strings)),
                ],
              ),
            ),
        ],
      ),
    );
    if (action == null || action == settings.playlistOpenAction) {
      return;
    }
    await ref
        .read(settingsControllerProvider.notifier)
        .setPlaylistOpenAction(action);
  }

  String _trayCloseActionLabel(TrayCloseAction action, ThemeStrings strings) {
    return switch (action) {
      TrayCloseAction.ask => strings.resolve(
        ThemeStringKey.settingsTrayCloseAsk,
      ),
      TrayCloseAction.minimizeToTray => strings.resolve(
        ThemeStringKey.settingsTrayCloseMinimize,
      ),
      TrayCloseAction.exit => strings.resolve(
        ThemeStringKey.settingsTrayCloseExit,
      ),
    };
  }

  Future<void> _showTrayCloseActionDialog(
    BuildContext context,
    WidgetRef ref,
    UserSettings settings,
  ) async {
    final strings = ref.read(activeThemeStringsProvider);
    final action = await showDialog<TrayCloseAction>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(strings.resolve(ThemeStringKey.settingsTrayCloseAction)),
        children: <Widget>[
          for (final action in TrayCloseAction.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(action),
              child: Row(
                children: <Widget>[
                  if (action == settings.trayCloseAction)
                    Icon(
                      Icons.check,
                      size: 18,
                      color: RobyneTheme.of(context).tokens.color.brandBase,
                    )
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(_trayCloseActionLabel(action, strings)),
                ],
              ),
            ),
        ],
      ),
    );
    if (action == null || action == settings.trayCloseAction) {
      return;
    }
    await ref
        .read(settingsControllerProvider.notifier)
        .setTrayCloseAction(action);
  }

  Future<void> _showCacheSizeDialog(
    BuildContext context,
    WidgetRef ref,
    UserSettings settings,
  ) async {
    final strings = ref.read(activeThemeStringsProvider);
    final controller = TextEditingController(
      text: (settings.cacheSizeBytes / (1024 * 1024)).round().toString(),
    );
    attachImeTextControllerTrace(controller, 'settings.cacheSize');
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.resolve(ThemeStringKey.settingsCacheSizeDialog)),
        content: SizedBox(
          width: RobyneDialogWidth.forContext(context, 320),
          child: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: strings.resolve(ThemeStringKey.settingsSizeField),
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
            child: Text(strings.resolve(ThemeStringKey.actionCancel)),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(int.tryParse(controller.text)),
            child: Text(strings.resolve(ThemeStringKey.pluginsSave)),
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
      dialogTitle: ref
          .read(activeThemeStringsProvider)
          .resolve(ThemeStringKey.settingsChooseCacheLocation),
      initialDirectory: settings.cacheDirectoryPath,
      strings: ref.read(activeThemeStringsProvider),
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
      dialogTitle: ref
          .read(activeThemeStringsProvider)
          .resolve(ThemeStringKey.settingsChooseDownloadLocation),
      initialDirectory: settings.downloadsDirectoryPath,
      strings: ref.read(activeThemeStringsProvider),
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
    final strings = ref.read(activeThemeStringsProvider);
    final value = await showDialog<DownloadAudioFormat>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(strings.resolve(ThemeStringKey.settingsDownloadFormat)),
        children: <Widget>[
          for (final format in DownloadAudioFormat.values)
            ListTile(
              title: Text(format.label),
              trailing: settings.downloadAudioFormat == format
                  ? Icon(
                      Icons.check,
                      color: RobyneTheme.of(
                        context,
                      ).tokens.components.navBar.selectedItem,
                    )
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
    final strings = ref.watch(activeThemeStringsProvider);
    final lyricSettings = settings.lyricSettings;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      children: <Widget>[
        _LyricsSwitchRow(
          title: strings.resolve(ThemeStringKey.settingsLyricsShowDesktop),
          subtitle: strings.resolve(
            ThemeStringKey.settingsLyricsShowDesktopSub,
          ),
          value: lyricSettings.desktopLyricsEnabled,
          onChanged: (value) => ref
              .read(settingsControllerProvider.notifier)
              .setDesktopLyricsEnabled(value),
        ),
        _LyricsSwitchRow(
          title: strings.resolve(ThemeStringKey.settingsLyricsAlwaysOnTop),
          subtitle: strings.resolve(
            ThemeStringKey.settingsLyricsAlwaysOnTopSub,
          ),
          value: lyricSettings.desktopLyricsAlwaysOnTop,
          onChanged: (value) => ref
              .read(settingsControllerProvider.notifier)
              .setDesktopLyricsAlwaysOnTop(value),
        ),
        _LyricsSwitchRow(
          title: strings.resolve(ThemeStringKey.settingsLyricsLocked),
          subtitle: strings.resolve(ThemeStringKey.settingsLyricsLockedSub),
          value: lyricSettings.desktopLyricsLocked,
          onChanged: (value) => ref
              .read(settingsControllerProvider.notifier)
              .setDesktopLyricsLocked(value),
        ),
        _LyricsSwitchRow(
          title: strings.resolve(ThemeStringKey.settingsLyricsDoubleLine),
          subtitle: strings.resolve(ThemeStringKey.settingsLyricsDoubleLineSub),
          value: lyricSettings.desktopLyricsDoubleLine,
          onChanged: (value) => ref
              .read(settingsControllerProvider.notifier)
              .setDesktopLyricsDoubleLine(value),
          showDivider: false,
        ),
        const SizedBox(height: 16),
        _LyricsSettingRow(
          title: strings.resolve(ThemeStringKey.settingsLyricsFont),
          subtitle: strings.resolve(ThemeStringKey.settingsLyricsFontSub),
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
          title: strings.resolve(ThemeStringKey.settingsLyricsFontSize),
          subtitle: strings
              .resolve(ThemeStringKey.settingsLyricsFontSizeSub)
              .replaceAll('{min}', '${LyricSettings.minFontSize}')
              .replaceAll('{max}', '${LyricSettings.maxFontSize}'),
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
          title: strings.resolve(ThemeStringKey.settingsLyricsColor),
          subtitle: strings.resolve(ThemeStringKey.settingsLyricsColorSub),
          control: _ColorPalettePicker(
            selectedColorValue: lyricSettings.desktopLyricTextColorValue,
            onSelected: (colorValue) => ref
                .read(settingsControllerProvider.notifier)
                .setDesktopLyricTextColorValue(colorValue),
          ),
        ),
        const SizedBox(height: 20),
        _LyricsSettingRow(
          title: strings.resolve(ThemeStringKey.settingsLyricsStroke),
          subtitle: strings.resolve(ThemeStringKey.settingsLyricsStrokeSub),
          control: _ColorPalettePicker(
            selectedColorValue: lyricSettings.desktopLyricStrokeColorValue,
            noneLabel: strings.resolve(ThemeStringKey.settingsLyricsNoStroke),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref
                .read(activeThemeStringsProvider)
                .resolve(ThemeStringKey.settingsShortcutConflictSaved)
                .replaceAll('{action}', conflict.label),
          ),
        ),
      );
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
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  fontSize: tokens.typography.resolvedListPrimarySize,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: colors.textMuted),
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
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
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
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: tokens.typography.resolvedListPrimarySize,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // The switch's track and thumb are the design's brand-tinted
              // toggle, not Material's primary-filled one.
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: colors.brandBase,
                inactiveThumbColor: colors.textDisabled,
                inactiveTrackColor: colors.surfaceActive,
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, color: colors.borderSubtle),
      ],
    );
  }
}

class _ShortcutRow extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final strings = ref.watch(activeThemeStringsProvider);
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
                    Text(
                      action.label,
                      style: TextStyle(
                        fontSize: tokens.typography.resolvedListPrimarySize,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      action.description,
                      style: TextStyle(fontSize: 11, color: colors.textMuted),
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
                      strings.resolve(ThemeStringKey.settingsShortcutScope),
                      style: TextStyle(fontSize: 10, color: colors.textMuted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      binding?.displayLabel ??
                          strings.resolve(ThemeStringKey.settingsShortcutUnset),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: onClear,
                child: Text(
                  strings.resolve(ThemeStringKey.settingsShortcutClear),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FontSizeStepper extends ConsumerWidget {
  const _FontSizeStepper({
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int value;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final strings = ref.watch(activeThemeStringsProvider);
    final canDecrease = value > LyricSettings.minFontSize;
    final canIncrease = value < LyricSettings.maxFontSize;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          RobyneTheme.of(context).tokens.radius.md,
        ),
        color: colors.surfaceBase,
        border: Border.all(color: colors.borderDefault),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            onPressed: canDecrease ? onDecrease : null,
            icon: const Icon(Icons.remove),
            tooltip: strings.resolve(ThemeStringKey.settingsLyricsDecreaseFont),
          ),
          SizedBox(
            width: 56,
            child: Center(
              child: Text(
                '$value',
                style: TextStyle(
                  fontSize: tokens.typography.resolvedListPrimarySize,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: canIncrease ? onIncrease : null,
            icon: const Icon(Icons.add),
            tooltip: strings.resolve(ThemeStringKey.settingsLyricsIncreaseFont),
          ),
        ],
      ),
    );
  }
}

class _ColorPalettePicker extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    // Swatches are circular whatever the skin says, so they use the `full`
    // radius token rather than a literal 18 (half of the 32dp box).
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final fullRadius = tokens.radius.full;
    // The selected ring is the nav bar's indicator colour, so a skin's accent
    // shows up on the swatch picker instead of Material's primary.
    final accent = tokens.components.navBar.selectedIndicator;
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
                  color: selected ? accent : colors.borderDefault,
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

class _NoColorOption extends ConsumerWidget {
  const _NoColorOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    // A pill: fully rounded on the 32dp-tall chip.
    final pillRadius = tokens.radius.full;
    final accent = tokens.components.navBar.selectedIndicator;
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
            color: colors.surfaceBase,
            border: Border.all(
              color: selected ? accent : colors.borderDefault,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.block_rounded,
                size: 16,
                color: selected ? accent : colors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: colors.textSecondary),
              ),
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
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final strings = ref.watch(activeThemeStringsProvider);
    final conflict = _binding == null
        ? null
        : widget.settings.conflictingAction(widget.action, _binding);
    return AlertDialog(
      title: Text(
        strings
            .resolve(ThemeStringKey.settingsShortcutEditTitle)
            .replaceAll('{action}', widget.action.label),
      ),
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
              Text(strings.resolve(ThemeStringKey.settingsShortcutHint)),
              const SizedBox(height: 16),
              SegmentedButton<int>(
                segments: <ButtonSegment<int>>[
                  ButtonSegment<int>(
                    value: 1,
                    label: Text(
                      strings.resolve(ThemeStringKey.settingsShortcutSingle),
                    ),
                  ),
                  ButtonSegment<int>(
                    value: 2,
                    label: Text(
                      strings.resolve(ThemeStringKey.settingsShortcutDouble),
                    ),
                  ),
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
                    border: Border.all(color: colors.borderDefault),
                    color: colors.surfaceBase,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _binding?.displayLabel ??
                            strings.resolve(
                              ThemeStringKey.settingsShortcutPress,
                            ),
                        style: TextStyle(
                          fontSize: tokens.typography.resolvedListPrimarySize,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _focusNode.hasFocus
                            ? strings.resolve(
                                ThemeStringKey.settingsShortcutListening,
                              )
                            : strings.resolve(
                                ThemeStringKey.settingsShortcutStartRecording,
                              ),
                        style: TextStyle(fontSize: 11, color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
              if (conflict != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  strings
                      .resolve(ThemeStringKey.settingsShortcutConflict)
                      .replaceAll('{action}', conflict.label),
                  style: TextStyle(fontSize: 11, color: colors.danger),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.resolve(ThemeStringKey.actionCancel)),
        ),
        FilledButton(
          onPressed: _binding == null || conflict != null
              ? null
              : () => Navigator.of(context).pop(_binding),
          child: Text(strings.resolve(ThemeStringKey.pluginsSave)),
        ),
      ],
    );
  }
}

Future<String?> _pickDirectory(
  BuildContext context, {
  required String dialogTitle,
  required String initialDirectory,
  required ThemeStrings strings,
}) async {
  try {
    return await FilePicker.getDirectoryPath(dialogTitle: dialogTitle);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings
                .resolve(ThemeStringKey.settingsDirectoryPickerFailed)
                .replaceAll('{error}', '$error'),
          ),
        ),
      );
      return _showManualDirectoryDialog(
        context,
        dialogTitle: dialogTitle,
        initialDirectory: initialDirectory,
        strings: strings,
      );
    }
    return null;
  }
}

Future<String?> _showManualDirectoryDialog(
  BuildContext context, {
  required String dialogTitle,
  required String initialDirectory,
  required ThemeStrings strings,
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
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: strings.resolve(ThemeStringKey.settingsDirectoryField),
          ),
          onSubmitted: (_) => Navigator.of(context).pop(controller.text.trim()),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.resolve(ThemeStringKey.actionCancel)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: Text(strings.resolve(ThemeStringKey.pluginsSave)),
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
