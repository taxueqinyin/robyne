import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/layout/window_size_class.dart';
import '../../../core/theme/application/theme_providers.dart';
import '../../../core/theme/domain/theme_layout.dart';
import '../../../core/theme/domain/theme_materials.dart';
import '../../../core/theme/domain/theme_strings.dart';
import '../../../core/theme/infrastructure/token_resolver.dart';
import '../../../core/theme/presentation/theme_material.dart';
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

class DiscoverPage extends ConsumerWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pluginsValue = ref.watch(pluginControllerProvider);
    final discoverState = ref.watch(discoverControllerProvider);
    final controller = ref.read(discoverControllerProvider.notifier);
    final enabledPlugins = _enabledPlugins(pluginsValue.value);
    final pluginSignature = discoverPluginSignature(enabledPlugins);
    final strings = ref.watch(activeThemeStringsProvider);
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final metrics = ref.watch(activeThemeContentMetricsProvider);
    final compactWidth =
        WindowSizeClass.of(context).width != WindowWidthClass.expanded;
    // The discover destination is wrapped in a back button when the browser
    // is open (see `_DiscoverSurface`). Reserving a leading slot for it keeps
    // the page heading on the same left axis as every other surface instead
    // of sliding under the floating control.
    final leadingInset = ref.watch(discoverBrowserProvider) ? 44.0 : 0.0;

    if (discoverState.pluginSignature != pluginSignature) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(controller.syncPlugins(enabledPlugins));
      });
    }

    // The design's secondary browser leads with a header row of its own
    // ("插件榜单" + 刷新), sitting on the same gutter as the home page so the
    // two read as one surface and not as a dialog dropped on top of it.
    final header = Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                strings.resolve(ThemeStringKey.discoverRankingEntry),
                style: TextStyle(
                  fontSize: tokens.typography.resolvedPageTitleSize,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                strings.resolve(ThemeStringKey.discoverEnablePlugin),
                style: TextStyle(fontSize: 12, color: colors.textMuted),
              ),
            ],
          ),
        ),
        _PillButton(
          icon: Icons.refresh,
          label: strings.resolve(ThemeStringKey.discoverRefresh),
          onTap: enabledPlugins.isEmpty
              ? null
              : () => unawaited(controller.reloadCurrentSurface()),
        ),
      ],
    );

    final body = enabledPlugins.isEmpty
        ? Center(
            child: Text(
              strings.resolve(ThemeStringKey.discoverEnablePlugin),
              style: TextStyle(color: colors.textSecondary),
            ),
          )
        : _BrowserBody(state: discoverState, controller: controller);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        (compactWidth ? metrics.gutterCompact : metrics.gutter) + leadingInset,
        20,
        compactWidth ? metrics.gutterCompact : metrics.gutter,
        20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          header,
          if (pluginsValue.hasError) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              pluginsValue.error.toString(),
              style: TextStyle(color: colors.danger),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(child: body),
        ],
      ),
    );
  }

  static List<PluginDefinition> _enabledPlugins(
    List<PluginDefinition>? plugins,
  ) {
    return (plugins ?? const <PluginDefinition>[])
        .where((plugin) => plugin.enabled)
        .toList(growable: false);
  }
}

/// The design's compact header button: a bordered pill, not a raised button.
///
/// The mockup's secondary surfaces use one control shape throughout
/// (`pillbtn`), so the browser's actions are drawn from the same widget the
/// home page uses rather than from Material's button styles.
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

/// One plugin source in the browser's source row.
///
/// The mockup draws these as bordered pills that turn brand-tinted when
/// selected, rather than Material's `ChoiceChip`, whose selected state is a
/// solid brand fill — too loud inside a panel that is already a card.
class _SourceChip extends StatelessWidget {
  const _SourceChip({
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

/// The design's two-way switch between rankings and hot playlists.
///
/// A track with two pills (`segbar` in the mockup). Material's
/// `SegmentedButton` was the wrong shape here: inside a 5/11-wide pane it
/// wrapped its own labels, and its selected fill is a solid primary swatch
/// rather than the design's translucent brand wash.
class _SurfaceSwitch extends ConsumerWidget {
  const _SurfaceSwitch({required this.surface, required this.onSelectSurface});

  final DiscoverSurface surface;
  final ValueChanged<DiscoverSurface> onSelectSurface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final comp = tokens.components.navBar;
    final strings = ref.watch(activeThemeStringsProvider);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.textPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.all(Radius.circular(tokens.radius.md)),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final entry in <(DiscoverSurface, ThemeStringKey, IconData)>[
            (
              DiscoverSurface.rankings,
              ThemeStringKey.discoverRankings,
              Icons.emoji_events_outlined,
            ),
            (
              DiscoverSurface.hotPlaylists,
              ThemeStringKey.discoverHotPlaylists,
              Icons.grid_view_outlined,
            ),
          ]) ...<Widget>[
            _SurfacePill(
              icon: entry.$3,
              label: strings.resolve(entry.$2),
              selected: surface == entry.$1,
              accent: comp.selectedItem,
              fill: comp.selectedIndicatorFill,
              onTap: () => onSelectSurface(entry.$1),
            ),
          ],
        ],
      ),
    );
  }
}

class _SurfacePill extends StatelessWidget {
  const _SurfacePill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accent,
    required this.fill,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color accent;
  final Color fill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.all(Radius.circular(tokens.radius.sm)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? fill : const Color(0x00000000),
          borderRadius: BorderRadius.all(Radius.circular(tokens.radius.sm)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 15, color: selected ? accent : colors.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? accent : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders the browse/detail split when at least one plugin is enabled.
///
/// Split out of [DiscoverPage] so the enabled-plugin gate above reads as one
/// decision ("is there data at all?") instead of being tangled with the
/// two-pane layout question.
class _BrowserBody extends ConsumerWidget {
  const _BrowserBody({required this.state, required this.controller});

  final DiscoverState state;
  final DiscoverController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Consumer(
      builder: (context, ref, _) {
        ref.watch(discoverControllerProvider);
        final enabledPlugins = DiscoverPage._enabledPlugins(
          ref.watch(pluginControllerProvider).value,
        );
        return LayoutBuilder(
          builder: (context, constraints) {
            // The design draws the browser as two panes (来源 | 榜单歌曲).
            // The pane needs enough width to carry both a source list and the
            // detail rows, so the split is a content question, not a shell
            // breakpoint: a 1280 window minus the queue and rail has ~800dp
            // here and should split, while a 360dp-tall landscape phone must
            // keep the detail full-pane with a back affordance. See ADR-001
            // decision D6.
            final splitPanes = constraints.maxWidth >= 560;
            final browse = _BrowsePanel(
              plugins: enabledPlugins,
              state: ref.watch(discoverControllerProvider),
              onSelectPlugin: (pluginId) =>
                  unawaited(controller.selectPlugin(pluginId)),
              onSelectSurface: (surface) =>
                  unawaited(controller.selectSurface(surface)),
              onRetry: () => unawaited(controller.reloadCurrentSurface()),
              onSelectCollection: (collection) =>
                  unawaited(controller.openCollection(collection)),
              onSelectTag: (tag) =>
                  unawaited(controller.selectHotPlaylistTag(tag)),
              onLoadMoreHotPlaylists: () =>
                  unawaited(controller.loadMoreHotPlaylists()),
            );
            final detail = _DetailPanel(
              state: ref.watch(discoverControllerProvider),
              onRetry: () => unawaited(controller.reloadDetail()),
              onLoadMore: () => unawaited(controller.loadMoreDetail()),
              onBack: splitPanes ? null : () => controller.closeDetail(),
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
            );

            if (splitPanes) {
              return Row(
                children: <Widget>[
                  Expanded(flex: 5, child: browse),
                  const SizedBox(width: 16),
                  Expanded(flex: 6, child: detail),
                ],
              );
            }

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: ref.watch(discoverControllerProvider).detail != null
                  ? detail
                  : browse,
            );
          },
        );
      },
    );
  }
}

class _BrowsePanel extends ConsumerWidget {
  const _BrowsePanel({
    required this.plugins,
    required this.state,
    required this.onSelectPlugin,
    required this.onSelectSurface,
    required this.onRetry,
    required this.onSelectCollection,
    required this.onSelectTag,
    required this.onLoadMoreHotPlaylists,
  });

  final List<PluginDefinition> plugins;
  final DiscoverState state;
  final ValueChanged<String> onSelectPlugin;
  final ValueChanged<DiscoverSurface> onSelectSurface;
  final VoidCallback onRetry;
  final ValueChanged<OnlineCollectionItem> onSelectCollection;
  final ValueChanged<OnlineSheetTag> onSelectTag;
  final VoidCallback onLoadMoreHotPlaylists;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final strings = ref.watch(activeThemeStringsProvider);
    return _PanelShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            strings.resolve(ThemeStringKey.discoverSources),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          // A `Wrap` inside a horizontal scroll view is handed unbounded
          // width, so every chip lands on one line and the row overflows the
          // pane instead of wrapping. Scrollable axis wants a `Row`: chips
          // keep their intrinsic width and the row scrolls when the pane is
          // narrower than the source list (seen at 400dp phone width).
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 8,
              children: plugins
                  .map(
                    (plugin) => _SourceChip(
                      label: plugin.platform,
                      selected: plugin.id == state.selectedPluginId,
                      onTap: () => onSelectPlugin(plugin.id),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: 16),
          // The design's segmented control is a track with two brand-tinted
          // pills, not Material's outline-button group: at 300dp of pane
          // width the Material version wraps its own labels.
          _SurfaceSwitch(
            surface: state.surface,
            onSelectSurface: onSelectSurface,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: switch (state.surface) {
              DiscoverSurface.rankings => _RankingsBrowser(
                state: state,
                onRetry: onRetry,
                onSelectCollection: onSelectCollection,
              ),
              DiscoverSurface.hotPlaylists => _HotPlaylistsBrowser(
                state: state,
                onRetry: onRetry,
                onSelectTag: onSelectTag,
                onSelectCollection: onSelectCollection,
                onLoadMore: onLoadMoreHotPlaylists,
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _RankingsBrowser extends ConsumerWidget {
  const _RankingsBrowser({
    required this.state,
    required this.onRetry,
    required this.onSelectCollection,
  });

  final DiscoverState state;
  final VoidCallback onRetry;
  final ValueChanged<OnlineCollectionItem> onSelectCollection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    final colors = RobyneTheme.of(context).tokens.color;
    if (state.isLoadingTopLists && state.topListGroups.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.topListsError != null && state.topListGroups.isEmpty) {
      return _ErrorState(error: state.topListsError!, onRetry: onRetry);
    }
    if (state.topListGroups.isEmpty) {
      return Center(
        child: Text(
          strings.resolve(ThemeStringKey.discoverEmptyRankings),
          style: TextStyle(color: colors.textMuted),
        ),
      );
    }
    return _GroupedCollectionList(
      groups: state.topListGroups,
      selectedCollectionKey: state.selectedCollectionKey,
      onSelectCollection: onSelectCollection,
    );
  }
}

class _HotPlaylistsBrowser extends ConsumerWidget {
  const _HotPlaylistsBrowser({
    required this.state,
    required this.onRetry,
    required this.onSelectTag,
    required this.onSelectCollection,
    required this.onLoadMore,
  });

  final DiscoverState state;
  final VoidCallback onRetry;
  final ValueChanged<OnlineSheetTag> onSelectTag;
  final ValueChanged<OnlineCollectionItem> onSelectCollection;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    final colors = RobyneTheme.of(context).tokens.color;
    final quickTags = state.pinnedSheetTags.isNotEmpty
        ? state.pinnedSheetTags
        : state.sheetTagGroups
              .expand((group) => group.tags)
              .take(6)
              .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (quickTags.isNotEmpty || state.sheetTagGroups.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final tag in quickTags)
                _SourceChip(
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
        if (quickTags.isNotEmpty || state.sheetTagGroups.isNotEmpty)
          const SizedBox(height: 16),
        Expanded(
          child: Builder(
            builder: (context) {
              if (state.isLoadingHotPlaylists &&
                  state.hotPlaylistItems.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.hotPlaylistsError != null &&
                  state.hotPlaylistItems.isEmpty) {
                return _ErrorState(
                  error: state.hotPlaylistsError!,
                  onRetry: onRetry,
                );
              }
              if (state.hotPlaylistItems.isEmpty) {
                return Center(
                  child: Text(
                    strings.resolve(ThemeStringKey.discoverEmptyPlaylists),
                    style: TextStyle(color: colors.textMuted),
                  ),
                );
              }

              final showFooter =
                  state.isLoadingMoreHotPlaylists ||
                  state.hotPlaylistsError != null;
              return NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.extentAfter < 500 &&
                      !state.isLoadingMoreHotPlaylists &&
                      !state.isLoadingHotPlaylists &&
                      !state.hotPlaylistsIsEnd) {
                    onLoadMore();
                  }
                  return false;
                },
                child: Consumer(
                  builder: (context, ref, _) {
                    // The skin decides how `content.style` presents a
                    // collection flow (design spec §2.5). `grid` reads as a
                    // compact tiled grid; every other value keeps the row
                    // list, which is also the degradation fallback.
                    final style = ref.watch(
                      contentStyleForProvider(ThemeContentSurface.discover),
                    );
                    final child = style == ThemeListStyle.grid
                        ? GridView.builder(
                            padding: const EdgeInsets.only(bottom: 8),
                            gridDelegate:
                                SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 190,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  // The card is 96dp of cover plus a fixed
                                  // caption block. An aspect ratio cannot
                                  // express that: when the tile narrows (two
                                  // columns in an 800dp pane) a 0.78 ratio
                                  // left the cover insisting on its share and
                                  // clipped the title to one truncated line.
                                  mainAxisExtent: 96 + _collectionCardCaption,
                                ),
                            itemCount:
                                state.hotPlaylistItems.length +
                                (showFooter ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= state.hotPlaylistItems.length) {
                                return _CollectionFooter(
                                  isLoading: state.isLoadingMoreHotPlaylists,
                                  error: state.hotPlaylistsError,
                                );
                              }
                              final item = state.hotPlaylistItems[index];
                              return _CollectionCard(
                                item: item,
                                selected:
                                    item.uniqueKey ==
                                    state.selectedCollectionKey,
                                onTap: () => onSelectCollection(item),
                              );
                            },
                          )
                        : ListView.separated(
                            itemCount:
                                state.hotPlaylistItems.length +
                                (showFooter ? 1 : 0),
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              if (index >= state.hotPlaylistItems.length) {
                                return _CollectionFooter(
                                  isLoading: state.isLoadingMoreHotPlaylists,
                                  error: state.hotPlaylistsError,
                                );
                              }
                              final item = state.hotPlaylistItems[index];
                              return _CollectionTile(
                                item: item,
                                selected:
                                    item.uniqueKey ==
                                    state.selectedCollectionKey,
                                onTap: () => onSelectCollection(item),
                              );
                            },
                          );
                    return child;
                  },
                ),
              );
            },
          ),
        ),
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
                      (tag) => _SourceChip(
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

class _DetailPanel extends ConsumerWidget {
  const _DetailPanel({
    required this.state,
    required this.onRetry,
    required this.onLoadMore,
    required this.onPlay,
    required this.onDownload,
    this.onBack,
  });

  final DiscoverState state;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;
  final ValueChanged<MusicItem> onPlay;
  final ValueChanged<MusicItem> onDownload;

  /// Non-null only when the detail owns the whole pane; pops back to browse.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final strings = ref.watch(activeThemeStringsProvider);
    final detail = state.detail;
    return _PanelShell(
      child: Builder(
        builder: (context) {
          if (state.isLoadingDetail && detail == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.detailError != null && detail == null) {
            return _ErrorState(error: state.detailError!, onRetry: onRetry);
          }
          if (detail == null) {
            return Center(
              child: Text(
                strings.resolve(ThemeStringKey.discoverChooseCollection),
                style: TextStyle(color: colors.textMuted),
              ),
            );
          }

          final showFooter =
              state.isLoadingMoreDetail || state.detailError != null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  if (onBack != null)
                    IconButton(
                      tooltip: strings.resolve(
                        ThemeStringKey.discoverBackToBrowse,
                      ),
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(tokens.radius.sm),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: ArtworkView(
                        artworkUrl: detail.collection.artworkUrl,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          detail.collection.title,
                          style: TextStyle(
                            fontSize:
                                tokens.typography.resolvedSectionTitleSize,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          detail.collection.description?.trim().isNotEmpty ==
                                  true
                              ? detail.collection.description!
                              : detail.collection.platform,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          strings
                              .resolve(ThemeStringKey.discoverTrackCount)
                              .replaceAll('{count}', '${detail.items.length}'),
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: strings.resolve(ThemeStringKey.discoverRefresh),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Collection-level actions: the panel header is the only place
              // that knows the whole collection, so this is where "play it"
              // and "favourite it" belong — the rows below are per-track.
              CollectionActions(collection: detail.collection),
              const SizedBox(height: 16),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.extentAfter < 500 &&
                        !state.isLoadingDetail &&
                        !state.isLoadingMoreDetail &&
                        !detail.isEnd &&
                        detail.collection.kind ==
                            OnlineCollectionKind.musicSheet) {
                      onLoadMore();
                    }
                    return false;
                  },
                  child: ListView.separated(
                    itemCount: detail.items.length + (showFooter ? 1 : 0),
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index >= detail.items.length) {
                        return _CollectionFooter(
                          isLoading: state.isLoadingMoreDetail,
                          error: state.detailError,
                        );
                      }
                      final item = detail.items[index];
                      // The design draws the track row's actions inline
                      // (`rowacts`), revealed on the row rather than parked in
                      // a `ListTile` trailing slot that a two-pane detail
                      // cannot afford.
                      return _DetailTrackRow(
                        item: item,
                        index: index,
                        strings: strings,
                        onPlay: () => onPlay(item),
                        onDownload: () => onDownload(item),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One track in the detail pane, in the design's row shape.
///
/// The mockup's track row carries its index, a 38dp cover, title/artist and a
/// pair of actions that appear on the row. `ListTile` was the wrong tool: its
/// fixed 72dp height and trailing slot pushed the actions off a 5/11 pane.
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

/// The design's inline row action: a 28dp hit target that stays dim until the
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

class _GroupedCollectionList extends ConsumerWidget {
  const _GroupedCollectionList({
    required this.groups,
    required this.selectedCollectionKey,
    required this.onSelectCollection,
  });

  final List<OnlineCollectionGroup> groups;
  final String? selectedCollectionKey;
  final ValueChanged<OnlineCollectionItem> onSelectCollection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RobyneTheme.of(context).tokens;
    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return Padding(
          padding: EdgeInsets.only(bottom: index == groups.length - 1 ? 0 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                group.title,
                style: TextStyle(
                  fontSize: tokens.typography.resolvedSectionTitleSize,
                  fontWeight: FontWeight.w700,
                  color: tokens.color.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              for (final item in group.items) ...<Widget>[
                _CollectionTile(
                  item: item,
                  selected: item.uniqueKey == selectedCollectionKey,
                  onTap: () => onSelectCollection(item),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Fixed caption height for [_CollectionCard]: two title lines (18 + 18), 4dp
/// gap, then one description line (15).
const double _collectionCardCaption = 55;

/// One card in the hot-playlist flow.
///
/// The design's card is a square cover with the caption *below* it (not
/// inside it) — this is the `covergrid` block in `docs/design/mockups`:
///   cov(96dp) → ct(≤2 lines, 18dp each) → cs(one line)
/// A `Row`-shaped tile with the title beside the artwork was the wrong shape
/// for a 190dp-wide card: the title column was too narrow, so every title
/// wrapped into a tall blob over the cover and the row height fought back.
class _CollectionCard extends ConsumerWidget {
  const _CollectionCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final OnlineCollectionItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final comp = tokens.components;
    final radius = tokens.radius.md;
    return Material(
      color: selected ? comp.card.selected : comp.card.surface,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 96dp square cover, top-aligned. A fixed extent from the grid
            // delegate guarantees the caption block below never has to fight
            // the cover for vertical room.
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
              child: SizedBox(
                width: double.infinity,
                height: 96,
                child: ArtworkView(artworkUrl: item.artworkUrl),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: tokens.typography.resolvedListPrimarySize,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      height: 1.0,
                    ),
                  ),
                  if (item.description?.trim().isNotEmpty == true) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      item.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: colors.textMuted),
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
  const _CollectionTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final OnlineCollectionItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Card colours come from component tokens so a skin can restyle the
    // collection grid; the semantic layer has no "card" role to fall back on.
    final components = RobyneTheme.of(context).tokens.components;
    final tokens = RobyneTheme.of(context).tokens;
    final radius = RobyneTheme.of(context).tokens.radius.sm;
    final fill = selected ? components.card.selected : components.card.surface;
    return Material(
      color: fill,
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

class _ErrorState extends ConsumerWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final AppError error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '${error.code}: ${error.message}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: RobyneTheme.of(context).tokens.color.danger,
            ),
          ),
          const SizedBox(height: 12),
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
