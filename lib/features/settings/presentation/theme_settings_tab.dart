import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/application/theme_controller.dart';
import '../../../core/theme/application/theme_mode_providers.dart';
import '../../../core/theme/application/theme_providers.dart';
import '../../../core/theme/domain/theme_package.dart';
import '../../../core/theme/domain/theme_strings.dart';
import '../../../core/theme/domain/theme_tokens.dart';
import '../../../core/theme/infrastructure/token_resolver.dart';

/// Read-only appearance panel.
///
/// The flagship UI ships as the single built-in skin `xuan`. Skin authoring
/// happens in `theme.json`; the client deliberately does not expose colour,
/// radius or layout editors. A future editor can return as a separate
/// authoring surface without leaking authoring controls into daily use.
class ThemeSettingsTab extends ConsumerWidget {
  const ThemeSettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeControllerProvider);
    final fallbackNotice = ref.watch(themeFallbackNoticeProvider);
    final tokens = ref.watch(activeThemeTokensProvider);
    final strings = ref.watch(activeThemeStringsProvider);
    final resolved = RobyneTheme.of(context).tokens;
    final colors = resolved.color;

    return themeState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          strings.resolve(ThemeStringKey.settingsAppearanceLoadFailed),
          style: TextStyle(color: colors.danger),
        ),
      ),
      data: (state) {
        final active = state.package;
        return ListView(
          children: <Widget>[
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: fallbackNotice != null
                  ? Padding(
                      key: ValueKey<String>(fallbackNotice),
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _ThemeBanner(message: fallbackNotice),
                    )
                  : const SizedBox.shrink(key: ValueKey<String>('no-banner')),
            ),
            Text(
              strings.resolve(ThemeStringKey.settingsAppearanceMode),
              style: TextStyle(
                fontSize: resolved.typography.resolvedSectionTitleSize,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const _ThemeModeSelector(),
            const SizedBox(height: 24),
            Text(
              strings.resolve(ThemeStringKey.settingsAppearanceActive),
              style: TextStyle(
                fontSize: resolved.typography.resolvedSectionTitleSize,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _ActiveThemeCard(
              name: active.name,
              description: active.description,
              author: active.author,
              version: active.version,
              tokens: active.tokens,
            ),
            const SizedBox(height: 24),
            Text(
              strings.resolve(ThemeStringKey.settingsAppearanceSpec),
              style: TextStyle(
                fontSize: resolved.typography.resolvedSectionTitleSize,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              strings.resolve(ThemeStringKey.settingsAppearanceSpecBody),
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
            const SizedBox(height: 12),
            const _AuthoringHint(),
            const SizedBox(height: 24),
            Text(
              strings.resolve(ThemeStringKey.settingsAppearanceTokens),
              style: TextStyle(
                fontSize: resolved.typography.resolvedSectionTitleSize,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _TokenPreview(tokens: tokens),
          ],
        );
      },
    );
  }
}

/// Read-only pointer to the skin file a creator edits.
///
/// This is deliberately not a control: the flagship client has no colour,
/// radius or layout editor. It answers the one question a creator has —
/// "where is the file?" — and nothing else. The path is copied, never opened,
/// so the panel cannot become a file browser by accident.
class _AuthoringHint extends ConsumerWidget {
  const _AuthoringHint();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This panel renders inside the app shell, which always publishes the
    // resolved skin, so the tokens are read directly instead of through a
    // hard-coded Material fallback that skins could not restyle.
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final strings = ref.watch(activeThemeStringsProvider);
    final path = ref.watch(userThemesDirectoryPathProvider);
    final directory = path.value;
    final activeId = ref.watch(activeThemePackageProvider).id;
    final line = directory == null
        ? strings.resolve(ThemeStringKey.settingsAppearanceDirectoryUnavailable)
        : <String>[
            directory,
            activeId,
            'theme.json',
          ].join(Platform.pathSeparator);
    final copyable = directory == null ? null : line;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceBase,
        borderRadius: BorderRadius.circular(tokens.radius.md),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.edit_note_outlined, size: 18, color: colors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '保存即生效',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  line,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textMuted,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  ref.watch(activeThemePackageProvider).source ==
                          ThemeSource.builtIn
                      ? '内置皮肤打包进 App，先复制到皮肤目录再编辑。'
                      : '编辑 theme.json 或随包资源，客户端会自动重载。',
                  style: TextStyle(fontSize: 11, color: colors.textMuted),
                ),
              ],
            ),
          ),
          if (directory != null)
            if (copyable != null)
              IconButton(
                key: const Key('theme-authoring-copy-path'),
                tooltip: '复制路径',
                icon: const Icon(Icons.content_copy, size: 16),
                color: colors.textMuted,
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: copyable)),
              ),
        ],
      ),
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
      key: const Key('theme-fallback-banner'),
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
    final activeSkin = ref.watch(activeThemePackageProvider);
    final supportsLight = activeSkin.mode.supports(ThemeMode.light);
    final supportsDark = activeSkin.mode.supports(ThemeMode.dark);
    final selectedMode = activeSkin.mode.supports(override)
        ? override
        : ThemeMode.system;
    final strings = ref.watch(activeThemeStringsProvider);
    return SegmentedButton<ThemeMode>(
      segments: <ButtonSegment<ThemeMode>>[
        ButtonSegment<ThemeMode>(
          value: ThemeMode.system,
          icon: const Icon(Icons.brightness_auto_outlined),
          label: Text(strings.resolve(ThemeStringKey.appearanceModeSystem)),
        ),
        ButtonSegment<ThemeMode>(
          value: ThemeMode.light,
          icon: const Icon(Icons.light_mode_outlined),
          label: Text(strings.resolve(ThemeStringKey.appearanceModeLight)),
          enabled: supportsLight,
        ),
        ButtonSegment<ThemeMode>(
          value: ThemeMode.dark,
          icon: const Icon(Icons.dark_mode_outlined),
          label: Text(strings.resolve(ThemeStringKey.appearanceModeDark)),
          enabled: supportsDark,
        ),
      ],
      selected: <ThemeMode>{selectedMode},
      onSelectionChanged: (selection) {
        final mode = selection.first;
        // The segment is disabled in the UI, but keep the guard here as well:
        // programmatic selection must not force an unsupported brightness.
        if (!activeSkin.mode.supports(mode)) {
          ref.read(themeModeOverrideProvider.notifier).set(ThemeMode.system);
          return;
        }
        ref.read(themeModeOverrideProvider.notifier).set(mode);
      },
    );
  }
}

class _ActiveThemeCard extends StatelessWidget {
  const _ActiveThemeCard({
    required this.name,
    required this.description,
    required this.author,
    required this.version,
    required this.tokens,
  });

  final String name;
  final String description;
  final String author;
  final String version;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final colors = tokens.color;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            colors.backgroundElevated,
            colors.brandBase.withValues(alpha: 0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(tokens.radius.lg),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colors.brandBase,
              borderRadius: BorderRadius.circular(tokens.radius.md),
            ),
            child: Icon(Icons.graphic_eq, color: colors.onBrand, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
                const SizedBox(height: 6),
                Text(
                  '$author · v$version',
                  style: TextStyle(fontSize: 11, color: colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
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
      MapEntry<String, Color>('accentBase', tokens.color.accentBase),
      MapEntry<String, Color>('textPrimary', tokens.color.textPrimary),
      MapEntry<String, Color>('borderSubtle', tokens.color.borderSubtle),
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
