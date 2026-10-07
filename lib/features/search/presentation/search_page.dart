import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/debug/ime_trace.dart';
import '../../../core/layout/window_size_class.dart';
import '../../../core/theme/application/theme_providers.dart';
import '../../../core/theme/domain/theme_strings.dart';
import '../../../core/theme/infrastructure/token_resolver.dart';
import '../../../shared/widgets/search_action_button.dart';
import '../../../shared/widgets/horizontal_wheel_scroll.dart';
import '../../downloads/application/download_providers.dart';
import '../../player/application/player_providers.dart';
import '../../player/domain/playback_item.dart';
import '../../player/presentation/artwork_view.dart';
import '../../plugin/application/plugin_controller.dart';
import '../../plugin/domain/plugin_definition.dart';
import '../application/search_controller.dart' as search_state;
import '../domain/music_item.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final TextEditingController _keywordController;

  @override
  void initState() {
    super.initState();
    _keywordController = TextEditingController(
      text:
          ref.read(search_state.searchControllerProvider).value?.keyword ?? '',
    );
    attachImeTextControllerTrace(_keywordController, 'search.keyword');
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchValue = ref.watch(search_state.searchControllerProvider);
    // Searched in the order the plugin page arranged, so the first result tab
    // and the first source searched are the ones the user put first.
    final plugins = ref.watch(orderedPluginsProvider);
    final state = searchValue.value ?? const search_state.SearchState();
    final strings = ref.watch(activeThemeStringsProvider);
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final metrics = ref.watch(activeThemeContentMetricsProvider);
    final compactWidth =
        WindowSizeClass.of(context).width != WindowWidthClass.expanded;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        compactWidth ? metrics.gutterCompact : metrics.gutter,
        20,
        compactWidth ? metrics.gutterCompact : metrics.gutter,
        20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            strings.resolve(ThemeStringKey.searchPageTitle),
            style: TextStyle(
              fontSize: tokens.typography.resolvedPageTitleSize,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            strings.resolve(ThemeStringKey.searchPageSubtitle),
            style: TextStyle(fontSize: 12, color: colors.textMuted),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _keywordController,
                  style: TextStyle(fontSize: 13, color: colors.textPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: colors.surfaceBase,
                    hintText: strings.resolve(ThemeStringKey.searchHint),
                    hintStyle: TextStyle(fontSize: 13, color: colors.textMuted),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: colors.textMuted,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(tokens.radius.md),
                      ),
                      borderSide: BorderSide(color: colors.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(tokens.radius.md),
                      ),
                      borderSide: BorderSide(color: colors.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(tokens.radius.md),
                      ),
                      borderSide: BorderSide(
                        color: colors.borderFocus,
                        width: 2,
                      ),
                    ),
                  ),
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(plugins),
                ),
              ),
              const SizedBox(width: 12),
              SearchActionButton(
                isSearching: state.isSearching,
                onSearch: () => _search(plugins),
                onCancel: () => ref
                    .read(search_state.searchControllerProvider.notifier)
                    .cancel(),
              ),
            ],
          ),
          if (state.error != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              '${state.error!.code}: ${state.error!.message}',
              style: TextStyle(color: colors.danger),
            ),
          ],
          if (state.pluginResults.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            _PluginTabs(
              state: state,
              onSelected: ref
                  .read(search_state.searchControllerProvider.notifier)
                  .selectPlugin,
            ),
          ],
          const SizedBox(height: 14),
          Expanded(
            child: _SearchResults(
              state: state,
              onLoadMore: () {
                ref
                    .read(search_state.searchControllerProvider.notifier)
                    .loadMoreSelected(plugins);
              },
              onPlay: (item) {
                ref
                    .read(playerControllerProvider.notifier)
                    .playFromPlugin(item);
              },
              onDownload: (item) {
                ref
                    .read(downloadControllerProvider.notifier)
                    .startDownload(PlaybackItem.fromMusicItem(item));
              },
            ),
          ),
        ],
      ),
    );
  }

  void _search(List<PluginDefinition> plugins) {
    final controller = ref.read(search_state.searchControllerProvider.notifier);
    controller.updateKeyword(_keywordController.text);
    unawaited(controller.search(plugins));
  }
}

class _PluginTabs extends ConsumerWidget {
  const _PluginTabs({required this.state, required this.onSelected});

  final search_state.SearchState state;
  final void Function(String pluginId) onSelected;

  /// Result tabs in the plugin page's order, not in completion order.
  ///
  /// Searches finish whenever each plugin answers, so a fast-but-unimportant
  /// plugin would otherwise jump to the front of the strip mid-search. The
  /// user's own arrangement is the stable answer, and it is the same order the
  /// discover source row uses.
  List<search_state.PluginSearchState> _orderedResults(WidgetRef ref) {
    final results = state.pluginResults;
    final rank = <String, int>{
      for (var index = 0; index < results.length; index += 1)
        results[index].pluginId: index,
    };
    final ordered = ref
        .watch(orderedPluginsProvider)
        .map((plugin) => rank[plugin.id])
        .whereType<int>()
        .map((index) => results[index])
        .toList(growable: false);
    // A result whose plugin has since been removed still belongs on screen:
    // the user asked for it, and dropping it would hide its error.
    final seen = <String>{for (final result in ordered) result.pluginId};
    return <search_state.PluginSearchState>[
      ...ordered,
      ...results.where((result) => !seen.contains(result.pluginId)),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    final results = _orderedResults(ref);
    return SizedBox(
      height: 40,
      // With many plugins the strip overflows, and a bare wheel reported
      // nothing until the user discovered shift+wheel — which is why the
      // row looked truncated rather than scrollable.
      child: HorizontalWheelScroll(
        builder: (context, controller) => ListView.separated(
          controller: controller,
          scrollDirection: Axis.horizontal,
          itemCount: results.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final result = results[index];
            final selected =
                result.pluginId ==
                (state.selectedPluginId ?? results.first.pluginId);
            final loading = result.isSearching || result.isLoadingMore;
            final label = loading
                ? strings
                      .resolve(ThemeStringKey.searchResultLoadingSuffix)
                      .replaceAll('{platform}', result.platform)
                : result.error != null
                ? strings
                      .resolve(ThemeStringKey.searchResultErrorSuffix)
                      .replaceAll('{platform}', result.platform)
                : '${result.platform} ${result.resultCount}';
            return _SourcePill(
              label: label,
              selected: selected,
              trailing: loading
                  ? const SizedBox.square(
                      dimension: 13,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : result.error != null
                  ? Icon(
                      Icons.error_outline,
                      size: 15,
                      color: RobyneTheme.of(context).tokens.color.danger,
                    )
                  : null,
              onTap: () => onSelected(result.pluginId),
            );
          },
        ),
      ),
    );
  }
}

/// A bordered source pill: brand-tinted when selected, plain when not.
///
/// The design's source row is a strip of bordered pills, not Material chips;
/// the count belongs inside the label rather than in a chip avatar slot.
class _SourcePill extends StatelessWidget {
  const _SourcePill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final comp = tokens.components.navBar;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.all(Radius.circular(tokens.radius.full)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? comp.selectedIndicatorFill : colors.surfaceBase,
          borderRadius: BorderRadius.all(Radius.circular(tokens.radius.full)),
          border: Border.all(
            color: selected ? comp.selectedIndicator : colors.borderDefault,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? comp.selectedItem : colors.textSecondary,
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: 6),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({
    required this.state,
    required this.onLoadMore,
    required this.onPlay,
    required this.onDownload,
  });

  final search_state.SearchState state;
  final VoidCallback onLoadMore;
  final void Function(MusicItem item) onPlay;
  final void Function(MusicItem item) onDownload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final pluginResult = state.selectedPluginResult;
    if (pluginResult == null) {
      return Center(
        child: Text(
          strings.resolve(ThemeStringKey.searchEmpty),
          style: TextStyle(color: colors.textMuted),
        ),
      );
    }

    if (pluginResult.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (pluginResult.error != null && pluginResult.result == null) {
      return Center(
        child: Text(
          '${pluginResult.error!.code}: ${pluginResult.error!.message}',
          style: TextStyle(color: colors.danger),
        ),
      );
    }

    final result = pluginResult.result;
    if (result == null) {
      return Center(
        child: Text(
          strings.resolve(ThemeStringKey.searchEmpty),
          style: TextStyle(color: colors.textMuted),
        ),
      );
    }

    if (result.items.isEmpty) {
      return Center(
        child: Text(
          strings.resolve(ThemeStringKey.searchEmptyResults),
          style: TextStyle(color: colors.textMuted),
        ),
      );
    }

    final showFooter = pluginResult.isLoadingMore || pluginResult.error != null;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 600 &&
            !pluginResult.isLoadingMore &&
            pluginResult.error == null &&
            !result.isEnd) {
          onLoadMore();
        }
        return false;
      },
      child: ListView.separated(
        itemCount: result.items.length + (showFooter ? 1 : 0),
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index >= result.items.length) {
            return _SearchResultFooter(pluginResult: pluginResult);
          }

          final item = result.items[index];
          return GestureDetector(
            onSecondaryTapDown: (details) =>
                _showResultMenu(context, details.globalPosition, item),
            // The design's track row carries the source as a chip beside the
            // title and reveals play/download on the row, rather than parking
            // them in a `ListTile` trailing slot.
            child: _SearchResultRow(
              item: item,
              index: index,
              strings: strings,
              onPlay: () => onPlay(item),
              onDownload: () => onDownload(item),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showResultMenu(
    BuildContext context,
    Offset position,
    MusicItem item,
  ) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: const <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'download',
          child: ListTile(
            leading: Icon(Icons.download),
            title: Text('Download'),
          ),
        ),
      ],
    );
    if (selected == 'download') {
      onDownload(item);
    }
  }
}

/// One search hit, in the design's row shape.
///
/// The mockup's row is: artwork, title with a plugin chip beside it, then
/// artist · album underneath, and the row actions on the trailing edge. A
/// `ListTile` could not hold the chip inside the title line.
class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({
    required this.item,
    required this.index,
    required this.strings,
    required this.onPlay,
    required this.onDownload,
  });

  final MusicItem item;
  final int index;
  final ThemeStrings strings;
  final VoidCallback onPlay;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final subtitle = <String?>[
      item.artist,
      item.album,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 22,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 11,
                color: colors.textMuted,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radius.sm),
            child: SizedBox(
              width: 40,
              height: 40,
              child: ArtworkView(artworkUrl: item.artworkUrl),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: tokens.typography.resolvedListPrimarySize,
                          fontWeight: FontWeight.w500,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: colors.textPrimary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.all(
                          Radius.circular(tokens.radius.sm),
                        ),
                        border: Border.all(color: colors.borderSubtle),
                      ),
                      child: Text(
                        item.platform,
                        style: TextStyle(
                          fontSize: 10,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (subtitle.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: colors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 30,
            height: 30,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 17,
              tooltip: strings.resolve(ThemeStringKey.searchPlay),
              onPressed: onPlay,
              icon: Icon(Icons.play_arrow, color: colors.textSecondary),
            ),
          ),
          SizedBox(
            width: 30,
            height: 30,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 16,
              tooltip: strings.resolve(ThemeStringKey.searchDownload),
              onPressed: onDownload,
              icon: Icon(Icons.download_outlined, color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultFooter extends ConsumerWidget {
  const _SearchResultFooter({required this.pluginResult});

  final search_state.PluginSearchState pluginResult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (pluginResult.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final error = pluginResult.error;
    if (error == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        '${error.code}: ${error.message}',
        textAlign: TextAlign.center,
        style: TextStyle(color: RobyneTheme.of(context).tokens.color.danger),
      ),
    );
  }
}
