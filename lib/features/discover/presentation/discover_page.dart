import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/layout/window_size_class.dart';
import '../../../core/theme/application/theme_providers.dart';
import '../../../core/theme/domain/theme_layout.dart';
import '../../../core/theme/domain/theme_strings.dart';
import '../../../core/theme/infrastructure/token_resolver.dart';
import '../../../core/theme/domain/theme_materials.dart';
import '../../../core/theme/domain/theme_tokens.dart';
import '../../../core/theme/presentation/theme_material.dart';
import '../../../shared/widgets/horizontal_wheel_scroll.dart';
import '../../../shared/widgets/song_actions_menu.dart';
import '../../downloads/application/download_providers.dart';
import '../../player/application/player_providers.dart';
import '../../player/domain/playback_item.dart';
import '../../player/presentation/artwork_view.dart';
import '../../plugin/application/plugin_controller.dart';
import '../../plugin/domain/plugin_definition.dart';
import '../../search/domain/music_item.dart';
import '../application/discover_controller.dart';
import '../domain/online_collection.dart';
import 'collection_actions.dart';

/// The first-level discovery surface: sources, rankings and hot playlists.
///
/// The two catalogue sections are peers, not tabs. A previous revision hid
/// them behind a two-way switch inside a second-level browser, which meant the
/// user had to pick a surface before they could see either; the design spec
/// (§4.2) describes them as sections of the page itself. Both therefore load
/// together for the selected source and both are on screen at once — side by
/// side where the content column is wide enough, stacked and sharing one
/// scroll view otherwise.
class DiscoverPage extends ConsumerWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pluginsValue = ref.watch(pluginControllerProvider);
    // Ordered the way the plugin page arranged it, so a drag there reorders
    // this strip too.
    final enabledPlugins = ref.watch(orderedEnabledPluginsProvider);
    final state = ref.watch(discoverControllerProvider);
    final controller = ref.read(discoverControllerProvider.notifier);
    final strings = ref.watch(activeThemeStringsProvider);
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final metrics = ref.watch(activeThemeContentMetricsProvider);
    final sizeClass = WindowSizeClass.of(context);
    final compactWidth = sizeClass.width != WindowWidthClass.expanded;
    final compactHeight = sizeClass.isCompactHeight;
    final signature = discoverPluginSignature(enabledPlugins);

    if (state.pluginSignature != signature) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(controller.syncPlugins(enabledPlugins));
      });
    }

    final horizontalGutter = compactWidth
        ? metrics.gutterCompact
        : metrics.gutter;
    final detail = state.selectedCollection != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalGutter,
        compactHeight ? 10 : 20,
        horizontalGutter,
        compactHeight ? 10 : 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // The detail surface owns the whole page: its header carries the
          // back affordance, and the source strip would only compete with it.
          if (!detail) ...<Widget>[
            _DiscoverHeader(
              compactHeight: compactHeight,
              strings: strings,
              tokens: tokens,
              onRefresh: enabledPlugins.isEmpty
                  ? null
                  : () => unawaited(controller.refreshAll()),
            ),
            SizedBox(height: compactHeight ? 8 : 14),
            _SourceStrip(
              plugins: enabledPlugins,
              state: state,
              onSelect: (pluginId) =>
                  unawaited(controller.selectPlugin(pluginId)),
            ),
            SizedBox(height: compactHeight ? 10 : 18),
            if (pluginsValue.hasError) ...<Widget>[
              Text(
                pluginsValue.error.toString(),
                style: TextStyle(fontSize: 12, color: colors.danger),
              ),
              const SizedBox(height: 10),
            ],
          ],
          Expanded(
            child: detail
                ? _DetailPanel(
                    state: state,
                    strings: strings,
                    onRetry: () => unawaited(controller.reloadDetail()),
                    onLoadMore: () => unawaited(controller.loadMoreDetail()),
                    onPlay: (item) => unawaited(
                      ref
                          .read(playerControllerProvider.notifier)
                          .playFromPlugin(item),
                    ),
                    onDownload: (item) => unawaited(
                      ref
                          .read(downloadControllerProvider.notifier)
                          .startDownload(PlaybackItem.fromMusicItem(item)),
                    ),
                  )
                : _BrowseSurface(
                    state: state,
                    strings: strings,
                    compactHeight: compactHeight,
                    showPluginHint: enabledPlugins.isEmpty,
                    onSelectCollection: (collection) =>
                        unawaited(controller.openCollection(collection)),
                    onRetryRankings: () =>
                        unawaited(controller.reloadRankings()),
                    onRetryHotPlaylists: () =>
                        unawaited(controller.reloadHotPlaylists()),
                    onSelectTag: (tag) =>
                        unawaited(controller.selectHotPlaylistTag(tag)),
                    onLoadMoreHotPlaylists: () =>
                        unawaited(controller.loadMoreHotPlaylists()),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Page identity and the one page-level action.
///
/// A short window (landscape phone) compresses the title and the source strip
/// into a single row: at 360dp tall the stacked header plus section headings
/// left almost no room for the catalogue itself.
class _DiscoverHeader extends StatelessWidget {
  const _DiscoverHeader({
    required this.compactHeight,
    required this.strings,
    required this.tokens,
    required this.onRefresh,
  });

  final bool compactHeight;
  final ThemeStrings strings;
  final ThemeTokens tokens;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = tokens.color;
    final title = Text(
      strings.resolve(ThemeStringKey.discoverPageTitle),
      style: TextStyle(
        fontSize: tokens.typography.resolvedPageTitleSize,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
      ),
    );
    if (compactHeight) {
      return Row(
        children: <Widget>[
          Text(
            strings.resolve(ThemeStringKey.discoverPageTitle),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const Spacer(),
          _PillButton(
            icon: Icons.refresh,
            label: strings.resolve(ThemeStringKey.discoverRefresh),
            onTap: onRefresh,
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              title,
              const SizedBox(height: 4),
              Text(
                strings.resolve(ThemeStringKey.discoverPageSubtitle),
                style: TextStyle(fontSize: 12, color: colors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _PillButton(
          icon: Icons.refresh,
          label: strings.resolve(ThemeStringKey.discoverRefresh),
          onTap: onRefresh,
        ),
      ],
    );
  }
}

/// The source strip, shaped like the search page's result tabs.
///
/// One source owns both sections at a time, so this is a selector rather than
/// a filter: the selected pill is the plugin whose rankings and playlists are
/// on screen. The trailing affordance only speaks for the selected source —
/// the other pills have no state to report until they are chosen.
class _SourceStrip extends ConsumerWidget {
  const _SourceStrip({
    required this.plugins,
    required this.state,
    required this.onSelect,
  });

  final List<PluginDefinition> plugins;
  final DiscoverState state;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (plugins.isEmpty) {
      return const SizedBox.shrink();
    }
    final loading = state.isLoadingTopLists || state.isLoadingHotPlaylists;
    final failed =
        state.topListsError != null && state.hotPlaylistsError != null;
    return SizedBox(
      height: 40,
      // With several plugins the strip overflows; the wheel adapter keeps a
      // plain mouse wheel usable instead of requiring shift+wheel.
      child: HorizontalWheelScroll(
        builder: (context, controller) => ListView.separated(
          controller: controller,
          scrollDirection: Axis.horizontal,
          itemCount: plugins.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final plugin = plugins[index];
            final selected = plugin.id == state.selectedPluginId;
            return _SourcePill(
              label: plugin.platform,
              selected: selected,
              trailing: selected && loading
                  ? const SizedBox.square(
                      dimension: 13,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : selected && failed
                  ? Icon(
                      Icons.error_outline,
                      size: 15,
                      color: RobyneTheme.of(context).tokens.color.danger,
                    )
                  : null,
              onTap: () => onSelect(plugin.id),
            );
          },
        ),
      ),
    );
  }
}

/// A bordered source pill — the same shape the search page's result tabs use.
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

/// The two catalogue sections, arranged for the available content width.
class _BrowseSurface extends ConsumerWidget {
  const _BrowseSurface({
    required this.state,
    required this.strings,
    required this.compactHeight,
    required this.showPluginHint,
    required this.onSelectCollection,
    required this.onRetryRankings,
    required this.onRetryHotPlaylists,
    required this.onSelectTag,
    required this.onLoadMoreHotPlaylists,
  });

  final DiscoverState state;
  final ThemeStrings strings;
  final bool compactHeight;
  final bool showPluginHint;
  final ValueChanged<OnlineCollectionItem> onSelectCollection;
  final VoidCallback onRetryRankings;
  final VoidCallback onRetryHotPlaylists;
  final ValueChanged<OnlineSheetTag> onSelectTag;
  final VoidCallback onLoadMoreHotPlaylists;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The skin decides how a collection flow presents (grid of covers or rows
    // of tiles). Both sections read the same declaration so they cannot
    // disagree about what "discover" looks like.
    final style = ref.watch(
      contentStyleForProvider(ThemeContentSurface.discover),
    );
    final rankings = _RankingsSection(
      state: state,
      strings: strings,
      style: style,
      onSelect: onSelectCollection,
      onRetry: onRetryRankings,
    );
    final hotPlaylists = _HotPlaylistsSection(
      state: state,
      strings: strings,
      style: style,
      onSelect: onSelectCollection,
      onRetry: onRetryHotPlaylists,
      onSelectTag: onSelectTag,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showPluginHint) ...<Widget>[
          _EnablePluginHint(strings: strings, compact: compactHeight),
          SizedBox(height: compactHeight ? 10 : 16),
        ],
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Two panes need room for a readable cover grid each. Below this
              // the stacked reading order is better than two 140dp columns.
              final twoColumns = !compactHeight && constraints.maxWidth >= 620;
              if (twoColumns) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: _SectionScroll(
                        storageKey: 'discover-rankings',
                        child: rankings,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _SectionScroll(
                        storageKey: 'discover-hot-playlists',
                        onLoadMore: onLoadMoreHotPlaylists,
                        child: hotPlaylists,
                      ),
                    ),
                  ],
                );
              }
              return _SectionScroll(
                storageKey: 'discover-stack',
                onLoadMore: onLoadMoreHotPlaylists,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    rankings,
                    const SizedBox(height: 24),
                    hotPlaylists,
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// One scrollable column, with the hot-playlist pagination trigger attached.
///
/// Pagination hangs off the scroll view rather than a "load more" button: the
/// catalogue is a wall of covers, and a button at the bottom of a short list is
/// a button the user has to hunt for. A post-frame check covers the case the
/// scroll listener cannot see — content shorter than the viewport, where no
/// scroll event ever fires but the next page is still wanted.
class _SectionScroll extends StatefulWidget {
  const _SectionScroll({
    required this.storageKey,
    required this.child,
    this.onLoadMore,
  });

  final String storageKey;
  final Widget child;
  final VoidCallback? onLoadMore;

  @override
  State<_SectionScroll> createState() => _SectionScrollState();
}

class _SectionScrollState extends State<_SectionScroll> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _scheduleLoadMore();
  }

  @override
  void didUpdateWidget(_SectionScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleLoadMore();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scheduleLoadMore() {
    if (widget.onLoadMore == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMoreIfClose());
  }

  void _loadMoreIfClose() {
    final onLoadMore = widget.onLoadMore;
    if (!mounted || onLoadMore == null || !_controller.hasClients) {
      return;
    }
    if (_controller.position.extentAfter < 500) {
      onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scrollView = SingleChildScrollView(
      controller: _controller,
      // Opening a collection and coming back should land where the user left,
      // not at the top of the page.
      key: PageStorageKey<String>(widget.storageKey),
      padding: const EdgeInsets.only(bottom: 8),
      child: widget.child,
    );
    if (widget.onLoadMore == null) {
      return scrollView;
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 500) {
          widget.onLoadMore!();
        }
        return false;
      },
      child: scrollView,
    );
  }
}

class _RankingsSection extends StatelessWidget {
  const _RankingsSection({
    required this.state,
    required this.strings,
    required this.style,
    required this.onSelect,
    required this.onRetry,
  });

  final DiscoverState state;
  final ThemeStrings strings;
  final ThemeListStyle style;
  final ValueChanged<OnlineCollectionItem> onSelect;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final heading = strings.resolve(ThemeStringKey.discoverRankings);
    final groups = state.topListGroups;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionHeading(label: heading),
        const SizedBox(height: 10),
        if (state.isLoadingTopLists && groups.isEmpty)
          const _SectionLoading()
        else if (state.topListsError != null && groups.isEmpty)
          _SectionError(error: state.topListsError!, onRetry: onRetry)
        else if (groups.isEmpty)
          _SectionEmpty(
            label: strings.resolve(ThemeStringKey.discoverEmptyRankings),
          )
        else ...<Widget>[
          for (final group in groups) ...<Widget>[
            // A plugin often names its first group after the section itself
            // ("排行榜 → 排行榜"); printing it twice only adds noise.
            if (group.title.trim().isNotEmpty && group.title.trim() != heading)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  group.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: RobyneTheme.of(context).tokens.color.textSecondary,
                  ),
                ),
              ),
            _CollectionFlow(
              items: group.items,
              style: style,
              onSelect: onSelect,
            ),
            const SizedBox(height: 16),
          ],
          if (state.topListsError != null)
            _InlineError(error: state.topListsError!, onRetry: onRetry),
        ],
      ],
    );
  }
}

class _HotPlaylistsSection extends ConsumerWidget {
  const _HotPlaylistsSection({
    required this.state,
    required this.strings,
    required this.style,
    required this.onSelect,
    required this.onRetry,
    required this.onSelectTag,
  });

  final DiscoverState state;
  final ThemeStrings strings;
  final ThemeListStyle style;
  final ValueChanged<OnlineCollectionItem> onSelect;
  final VoidCallback onRetry;
  final ValueChanged<OnlineSheetTag> onSelectTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heading = strings.resolve(ThemeStringKey.discoverHotPlaylists);
    final quickTags = state.pinnedSheetTags.isNotEmpty
        ? state.pinnedSheetTags
        : state.sheetTagGroups
              .expand((group) => group.tags)
              .take(6)
              .toList(growable: false);
    final hasTags = quickTags.isNotEmpty || state.sheetTagGroups.isNotEmpty;
    final showFooter = state.isLoadingMoreHotPlaylists;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionHeading(label: heading),
        if (hasTags) ...<Widget>[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final tag in quickTags)
                _TagChip(
                  label: tag.title,
                  selected: tag.key == state.selectedSheetTag?.key,
                  onTap: () => onSelectTag(tag),
                ),
              if (state.sheetTagGroups.isNotEmpty)
                _PillButton(
                  icon: Icons.tune,
                  label: strings.resolve(ThemeStringKey.discoverMoreTags),
                  onTap: () => _showTagSheet(context, ref),
                ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        if (state.isLoadingHotPlaylists && state.hotPlaylistItems.isEmpty)
          const _SectionLoading()
        else if (state.hotPlaylistsError != null &&
            state.hotPlaylistItems.isEmpty)
          _SectionError(error: state.hotPlaylistsError!, onRetry: onRetry)
        else if (state.hotPlaylistItems.isEmpty)
          _SectionEmpty(
            label: strings.resolve(ThemeStringKey.discoverEmptyPlaylists),
          )
        else ...<Widget>[
          _CollectionFlow(
            items: state.hotPlaylistItems,
            style: style,
            onSelect: onSelect,
          ),
          if (state.hotPlaylistsError != null)
            _InlineError(error: state.hotPlaylistsError!, onRetry: onRetry),
          if (showFooter) const _CollectionFooter(isLoading: true, error: null),
        ],
      ],
    );
  }

  Future<void> _showTagSheet(BuildContext context, WidgetRef ref) async {
    final strings = ref.read(activeThemeStringsProvider);
    final tokens = RobyneTheme.of(context).tokens;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(
              strings.resolve(ThemeStringKey.discoverTagSheetTitle),
              style: TextStyle(
                fontSize: tokens.typography.resolvedSectionTitleSize,
                fontWeight: FontWeight.w700,
                color: tokens.color.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            for (final group in state.sheetTagGroups) ...<Widget>[
              Text(
                group.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tokens.color.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: group.tags
                    .map(
                      (tag) => _TagChip(
                        label: tag.title,
                        selected: tag.key == state.selectedSheetTag?.key,
                        onTap: () {
                          Navigator.of(context).pop();
                          onSelectTag(tag);
                        },
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

/// One collection list in either the skin's grid or list presentation.
class _CollectionFlow extends StatelessWidget {
  const _CollectionFlow({
    required this.items,
    required this.style,
    required this.onSelect,
  });

  final List<OnlineCollectionItem> items;
  final ThemeListStyle style;
  final ValueChanged<OnlineCollectionItem> onSelect;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    // The grids are nested inside the page's scroll view, so they must not
    // scroll or expand unboundedly themselves.
    if (style == ThemeListStyle.grid) {
      // The caption block is measured, not assumed: a fixed 55dp was arithmetic
      // about Latin line boxes and overflowed by 3–6dp as soon as a CJK font or
      // a text scale made the lines taller.
      final metrics = _CollectionCardMetrics.resolve(
        RobyneTheme.of(context).tokens,
        MediaQuery.textScalerOf(context),
      );
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 190,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: _CollectionCardMetrics.cover + metrics.caption,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _CollectionCard(
            item: item,
            metrics: metrics,
            onTap: () => onSelect(item),
          );
        },
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return _CollectionTile(item: item, onTap: () => onSelect(item));
      },
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    return Text(
      label,
      style: TextStyle(
        fontSize: tokens.typography.resolvedSectionTitleSize,
        fontWeight: FontWeight.w700,
        color: tokens.color.textPrimary,
      ),
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: RobyneTheme.of(context).tokens.color.textMuted,
        ),
      ),
    );
  }
}

class _SectionError extends ConsumerWidget {
  const _SectionError({required this.error, required this.onRetry});

  final AppError error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${error.code}: ${error.message}',
            style: TextStyle(
              fontSize: 12,
              color: RobyneTheme.of(context).tokens.color.danger,
            ),
          ),
          const SizedBox(height: 10),
          _PillButton(
            icon: Icons.refresh,
            label: strings.resolve(ThemeStringKey.discoverRetry),
            onTap: onRetry,
          ),
        ],
      ),
    );
  }
}

class _InlineError extends ConsumerWidget {
  const _InlineError({required this.error, required this.onRetry});

  final AppError error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RobyneTheme.of(context).tokens;
    final strings = ref.watch(activeThemeStringsProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(Icons.error_outline, size: 14, color: tokens.color.danger),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '${error.code}: ${error.message}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: tokens.color.danger),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(
            foregroundColor: tokens.color.textSecondary,
            visualDensity: VisualDensity.compact,
            minimumSize: const Size(0, 28),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: Text(
            strings.resolve(ThemeStringKey.discoverRetry),
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _DetailPanel extends ConsumerWidget {
  const _DetailPanel({
    required this.state,
    required this.strings,
    required this.onRetry,
    required this.onLoadMore,
    required this.onPlay,
    required this.onDownload,
  });

  final DiscoverState state;
  final ThemeStrings strings;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;
  final ValueChanged<MusicItem> onPlay;
  final ValueChanged<MusicItem> onDownload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final detail = state.detail;
    // The header is built from whichever record the state holds: a click puts
    // the collection into `selectedCollection` before the first request goes
    // out, so the way back exists from the first frame. Building it inside
    // the "detail loaded" branch is how a slow or failing source used to trap
    // the user in a drill-down with nothing to press.
    final collection = detail?.collection ?? state.selectedCollection;

    Widget body;
    if (state.isLoadingDetail && detail == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (state.detailError != null && detail == null) {
      body = _SectionError(error: state.detailError!, onRetry: onRetry);
    } else if (detail == null) {
      body = Center(
        child: Text(
          strings.resolve(ThemeStringKey.discoverChooseCollection),
          style: TextStyle(color: colors.textMuted),
        ),
      );
    } else {
      final showFooter = state.isLoadingMoreDetail || state.detailError != null;
      body = NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 500 &&
              !state.isLoadingDetail &&
              !state.isLoadingMoreDetail &&
              !detail.isEnd &&
              detail.collection.kind == OnlineCollectionKind.musicSheet) {
            onLoadMore();
          }
          return false;
        },
        child: ListView.separated(
          itemCount: detail.items.length + (showFooter ? 1 : 0),
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            if (index >= detail.items.length) {
              return _CollectionFooter(
                isLoading: state.isLoadingMoreDetail,
                error: state.detailError,
              );
            }
            final item = detail.items[index];
            // The design draws the track row's actions inline (`rowacts`),
            // revealed on the row rather than parked in a `ListTile` trailing
            // slot.
            return SongContextMenuRegion(
              item: PlaybackItem.fromMusicItem(item),
              child: _DetailTrackRow(
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

    return _PanelShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (collection != null) ...<Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(tokens.radius.sm),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: ArtworkView(artworkUrl: collection.artworkUrl),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _DetailHeaderText(
                    collection: collection,
                    itemCount: detail?.items.length,
                    strings: strings,
                  ),
                ),
              ] else
                const Spacer(),
              IconButton(
                tooltip: strings.resolve(ThemeStringKey.discoverRefresh),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Collection-level actions: the panel header is the only place that
          // knows the whole collection, so this is where "play it" and
          // "favourite it" belong — the rows below are per-track.
          if (collection != null && detail != null) ...<Widget>[
            CollectionActions(collection: collection),
            const SizedBox(height: 16),
          ],
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Title, subtitle and track count for the detail header.
///
/// Split out so the header can render before the track list exists: the count
/// line is the only part that needs the loaded detail.
class _DetailHeaderText extends StatelessWidget {
  const _DetailHeaderText({
    required this.collection,
    required this.itemCount,
    required this.strings,
  });

  final OnlineCollectionItem collection;
  final int? itemCount;
  final ThemeStrings strings;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final description = collection.description?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          collection.title,
          style: TextStyle(
            fontSize: tokens.typography.resolvedSectionTitleSize,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          description.isNotEmpty ? description : collection.platform,
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (itemCount != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            strings
                .resolve(ThemeStringKey.discoverTrackCount)
                .replaceAll('{count}', '$itemCount'),
            style: TextStyle(fontSize: 11, color: colors.textMuted),
          ),
        ],
      ],
    );
  }
}

/// One track in the detail pane, in the design's row shape.
class _DetailTrackRow extends StatelessWidget {
  const _DetailTrackRow({
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
              width: 38,
              height: 38,
              child: ArtworkView(artworkUrl: item.artworkUrl),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: tokens.typography.resolvedListPrimarySize,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  <String?>[item.artist, item.album, item.platform]
                      .whereType<String>()
                      .where((value) => value.isNotEmpty)
                      .join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: colors.textMuted),
                ),
              ],
            ),
          ),
          _RowAction(
            icon: Icons.play_arrow,
            tooltip: strings.resolve(ThemeStringKey.discoverPlay),
            onTap: onPlay,
          ),
          _RowAction(
            icon: Icons.download_outlined,
            tooltip: strings.resolve(ThemeStringKey.discoverDownload),
            onTap: onDownload,
          ),
        ],
      ),
    );
  }
}

/// The design's inline row action: a 30dp hit target that stays dim until the
/// row is engaged, rather than a full Material icon button.
class _RowAction extends StatelessWidget {
  const _RowAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    return SizedBox(
      width: 30,
      height: 30,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 17,
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, color: colors.textSecondary),
      ),
    );
  }
}

/// The caption block under a collection cover, measured rather than guessed.
///
/// It used to be a single `55` standing in for "two title lines + one
/// description line". That arithmetic was about Latin line boxes: with a CJK
/// font (taller line box) or any text scale the block ran 3–6dp past the card
/// and Flutter painted the yellow overflow stripes. Every line box is now
/// pinned to the same multiplier the measurement assumes, so the two cannot
/// disagree.
class _CollectionCardMetrics {
  const _CollectionCardMetrics({
    required this.titleFontSize,
    required this.descriptionFontSize,
    required this.titleLineHeight,
    required this.descriptionLineHeight,
  });

  static const double cover = 96;
  static const double titleLines = 2;
  static const double titleHeightFactor = 1.3;
  static const double descriptionHeightFactor = 1.3;
  static const double gap = 4;
  static const double inset = 8;

  factory _CollectionCardMetrics.resolve(
    ThemeTokens tokens,
    TextScaler scaler,
  ) {
    final titleFontSize = tokens.typography.resolvedListPrimarySize;
    const descriptionFontSize = 11.0;
    return _CollectionCardMetrics(
      titleFontSize: titleFontSize,
      descriptionFontSize: descriptionFontSize,
      titleLineHeight: scaler.scale(titleFontSize) * titleHeightFactor,
      descriptionLineHeight:
          scaler.scale(descriptionFontSize) * descriptionHeightFactor,
    );
  }

  final double titleFontSize;
  final double descriptionFontSize;
  final double titleLineHeight;
  final double descriptionLineHeight;

  double get titleBlock => titleLineHeight * titleLines;

  /// Everything below the cover: inset, the title block, the gap and one
  /// description line. The half-dp of slack absorbs fractional rounding.
  double get caption => inset + titleBlock + gap + descriptionLineHeight + 0.5;
}

/// One card in the collection grid.
///
/// The design's card is a square cover with the caption *below* it (not
/// inside it) — this is the `covergrid` block in `docs/design/mockups`:
///   cov(96dp) → ct(≤2 lines) → cs(one line)
class _CollectionCard extends ConsumerWidget {
  const _CollectionCard({
    required this.item,
    required this.metrics,
    required this.onTap,
  });

  final OnlineCollectionItem item;
  final _CollectionCardMetrics metrics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final comp = tokens.components;
    final radius = tokens.radius.md;
    final description = item.description?.trim() ?? '';
    return Material(
      color: comp.card.surface,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 96dp cover, top-aligned. A fixed extent from the grid delegate
            // guarantees the caption below never fights the cover for room.
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
              child: SizedBox(
                width: double.infinity,
                height: _CollectionCardMetrics.cover,
                child: ArtworkView(artworkUrl: item.artworkUrl),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                10,
                _CollectionCardMetrics.inset,
                10,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Each text gets exactly its measured box, so a third line
                  // or a taller glyph run is clipped by the box instead of
                  // overflowing the card.
                  SizedBox(
                    height: metrics.titleBlock,
                    child: Text(
                      item.title,
                      maxLines: _CollectionCardMetrics.titleLines.round(),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: metrics.titleFontSize,
                        height: _CollectionCardMetrics.titleHeightFactor,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  if (description.isNotEmpty) ...<Widget>[
                    const SizedBox(height: _CollectionCardMetrics.gap),
                    SizedBox(
                      height: metrics.descriptionLineHeight,
                      child: Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: metrics.descriptionFontSize,
                          height:
                              _CollectionCardMetrics.descriptionHeightFactor,
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionTile extends ConsumerWidget {
  const _CollectionTile({required this.item, required this.onTap});

  final OnlineCollectionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Card colours come from component tokens so a skin can restyle the
    // collection grid; the semantic layer has no "card" role to fall back on.
    final components = RobyneTheme.of(context).tokens.components;
    final tokens = RobyneTheme.of(context).tokens;
    final radius = RobyneTheme.of(context).tokens.radius.sm;
    return Material(
      color: components.card.surface,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: ArtworkView(artworkUrl: item.artworkUrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: tokens.typography.resolvedListPrimarySize,
                        fontWeight: FontWeight.w600,
                        color: tokens.color.textPrimary,
                      ),
                    ),
                    if (item.description?.trim().isNotEmpty ==
                        true) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        item.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: tokens.color.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: tokens.color.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionFooter extends ConsumerWidget {
  const _CollectionFooter({required this.isLoading, required this.error});

  final bool isLoading;
  final AppError? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isLoading) {
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
    if (error == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        '${error!.code}: ${error!.message}',
        textAlign: TextAlign.center,
        style: TextStyle(color: RobyneTheme.of(context).tokens.color.danger),
      ),
    );
  }
}

/// The design's bordered pill, used for page actions and tag overflow.
class _PillButton extends ConsumerWidget {
  const _PillButton({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.all(Radius.circular(tokens.radius.full)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: colors.surfaceBase,
          borderRadius: BorderRadius.all(Radius.circular(tokens.radius.full)),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 15,
              color: enabled ? colors.textSecondary : colors.textDisabled,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: enabled ? colors.textSecondary : colors.textDisabled,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One playlist tag in the hot-playlist section.
class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final comp = tokens.components.navBar;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.all(Radius.circular(tokens.radius.full)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? comp.selectedIndicatorFill : colors.surfaceBase,
          borderRadius: BorderRadius.all(Radius.circular(tokens.radius.full)),
          border: Border.all(
            color: selected ? comp.selectedIndicator : colors.borderDefault,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? comp.selectedItem : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _EnablePluginHint extends StatelessWidget {
  const _EnablePluginHint({required this.strings, required this.compact});

  final ThemeStrings strings;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 8 : 12),
      decoration: BoxDecoration(
        color: tokens.components.card.surface,
        borderRadius: BorderRadius.circular(tokens.radius.md),
        border: Border.all(color: tokens.color.borderSubtle),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.extension_outlined,
            size: 16,
            color: tokens.color.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              strings.resolve(ThemeStringKey.discoverEnablePlugin),
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: tokens.color.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelShell extends ConsumerWidget {
  const _PanelShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RobyneTheme.of(context).tokens;
    final radius = BorderRadius.circular(tokens.radius.sm);
    final card = tokens.materials.card;
    final material = card.isTransparent
        ? card.copyWith(
            color: tokens.components.card.surface,
            radius: tokens.radius.sm,
            border: ThemeMaterialBorder(color: tokens.color.borderSubtle),
          )
        : card.copyWith(
            radius: card.radius ?? tokens.radius.sm,
            border:
                card.border ??
                ThemeMaterialBorder(color: tokens.color.borderSubtle),
          );
    return MaterialSurface(
      material: material,
      tokens: tokens,
      borderRadius: radius,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}
