import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/layout/window_size_class.dart';
import '../../../core/theme/infrastructure/token_resolver.dart';
import '../../downloads/application/download_providers.dart';
import '../../player/application/player_providers.dart';
import '../../player/domain/playback_item.dart';
import '../../player/presentation/artwork_view.dart';
import '../../plugin/application/plugin_controller.dart';
import '../../plugin/domain/plugin_definition.dart';
import '../../search/domain/music_item.dart';
import '../application/discover_controller.dart';
import '../domain/online_collection.dart';

class DiscoverPage extends ConsumerWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pluginsValue = ref.watch(pluginControllerProvider);
    final discoverState = ref.watch(discoverControllerProvider);
    final controller = ref.read(discoverControllerProvider.notifier);
    final enabledPlugins = _enabledPlugins(pluginsValue.value);
    final pluginSignature = discoverPluginSignature(enabledPlugins);

    if (discoverState.pluginSignature != pluginSignature) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(controller.syncPlugins(enabledPlugins));
      });
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Discover',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rankings and trending playlists from enabled plugins.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: enabledPlugins.isEmpty
                    ? null
                    : () => unawaited(controller.reloadCurrentSurface()),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (pluginsValue.hasError) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              pluginsValue.error.toString(),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          if (enabledPlugins.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'Enable a plugin to browse rankings and playlists.',
                ),
              ),
            )
          else
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // This is the Material list-detail pattern. On an expanded
                  // width both panes share the axis; at medium or compact they
                  // must not, because stacking them gave each pane ~80dp on a
                  // landscape phone. Instead the detail takes the full pane and
                  // offers a back affordance. See ADR-001 decision D6.
                  final splitPanes =
                      constraints.maxWidth >=
                      WindowSizeClass.expandedWidthBreakpoint;
                  final browse = _BrowsePanel(
                    plugins: enabledPlugins,
                    state: discoverState,
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
                    state: discoverState,
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

                  // Single pane: the detail replaces the browse list while a
                  // collection is open, so the user never has to read a list
                  // through a 80dp slot.
                  final showingDetail = discoverState.detail != null;
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: showingDetail ? detail : browse,
                  );
                },
              ),
            ),
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

class _BrowsePanel extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return _PanelShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Sources', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Wrap(
              spacing: 8,
              children: plugins
                  .map(
                    (plugin) => ChoiceChip(
                      selected: plugin.id == state.selectedPluginId,
                      label: Text(plugin.platform),
                      onSelected: (_) => onSelectPlugin(plugin.id),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<DiscoverSurface>(
            segments: const <ButtonSegment<DiscoverSurface>>[
              ButtonSegment<DiscoverSurface>(
                value: DiscoverSurface.rankings,
                icon: Icon(Icons.equalizer),
                label: Text('Rankings'),
              ),
              ButtonSegment<DiscoverSurface>(
                value: DiscoverSurface.hotPlaylists,
                icon: Icon(Icons.local_fire_department_outlined),
                label: Text('Hot playlists'),
              ),
            ],
            selected: <DiscoverSurface>{state.surface},
            onSelectionChanged: (selection) {
              onSelectSurface(selection.first);
            },
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

class _RankingsBrowser extends StatelessWidget {
  const _RankingsBrowser({
    required this.state,
    required this.onRetry,
    required this.onSelectCollection,
  });

  final DiscoverState state;
  final VoidCallback onRetry;
  final ValueChanged<OnlineCollectionItem> onSelectCollection;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingTopLists && state.topListGroups.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.topListsError != null && state.topListGroups.isEmpty) {
      return _ErrorState(error: state.topListsError!, onRetry: onRetry);
    }
    if (state.topListGroups.isEmpty) {
      return const Center(child: Text('No rankings.'));
    }
    return _GroupedCollectionList(
      groups: state.topListGroups,
      selectedCollectionKey: state.selectedCollectionKey,
      onSelectCollection: onSelectCollection,
    );
  }
}

class _HotPlaylistsBrowser extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
                ChoiceChip(
                  selected: tag.key == state.selectedSheetTag?.key,
                  label: Text(tag.title),
                  onSelected: (_) => onSelectTag(tag),
                ),
              if (state.sheetTagGroups.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _showTagSheet(context),
                  icon: const Icon(Icons.tune),
                  label: const Text('More tags'),
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
                return const Center(child: Text('No playlists.'));
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
                child: ListView.separated(
                  itemCount:
                      state.hotPlaylistItems.length + (showFooter ? 1 : 0),
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
                      selected: item.uniqueKey == state.selectedCollectionKey,
                      onTap: () => onSelectCollection(item),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showTagSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(
              'Playlist tags',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            for (final group in state.sheetTagGroups) ...<Widget>[
              Text(group.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: group.tags
                    .map(
                      (tag) => ChoiceChip(
                        selected: tag.key == state.selectedSheetTag?.key,
                        label: Text(tag.title),
                        onSelected: (_) {
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

class _DetailPanel extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
            return const Center(
              child: Text('Select a ranking or playlist to load tracks.'),
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
                      tooltip: 'Back to browse',
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      RobyneTheme.of(context).tokens.radius.sm,
                    ),
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
                          style: Theme.of(context).textTheme.titleLarge,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          detail.collection.description?.trim().isNotEmpty ==
                                  true
                              ? detail.collection.description!
                              : detail.collection.platform,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${detail.items.length} tracks',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Reload detail',
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
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
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ArtworkView(artworkUrl: item.artworkUrl),
                        title: Text(item.title),
                        subtitle: Text(
                          <String?>[item.artist, item.album, item.platform]
                              .whereType<String>()
                              .where((value) => value.isNotEmpty)
                              .join(' - '),
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: <Widget>[
                            IconButton(
                              tooltip: 'Play',
                              icon: const Icon(Icons.play_arrow),
                              onPressed: () => onPlay(item),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'More',
                              onSelected: (value) {
                                if (value == 'download') {
                                  onDownload(item);
                                }
                              },
                              itemBuilder: (context) =>
                                  const <PopupMenuEntry<String>>[
                                    PopupMenuItem<String>(
                                      value: 'download',
                                      child: ListTile(
                                        leading: Icon(Icons.download),
                                        title: Text('Download'),
                                      ),
                                    ),
                                  ],
                            ),
                          ],
                        ),
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

class _GroupedCollectionList extends StatelessWidget {
  const _GroupedCollectionList({
    required this.groups,
    required this.selectedCollectionKey,
    required this.onSelectCollection,
  });

  final List<OnlineCollectionGroup> groups;
  final String? selectedCollectionKey;
  final ValueChanged<OnlineCollectionItem> onSelectCollection;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return Padding(
          padding: EdgeInsets.only(bottom: index == groups.length - 1 ? 0 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(group.title, style: Theme.of(context).textTheme.titleMedium),
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

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final OnlineCollectionItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Card colours come from component tokens so a skin can restyle the
    // collection grid; the semantic layer has no "card" role to fall back on.
    final components = RobyneTheme.of(context).tokens.components;
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
                  width: 56,
                  height: 56,
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
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (item.description?.trim().isNotEmpty ==
                        true) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        item.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionFooter extends StatelessWidget {
  const _CollectionFooter({required this.isLoading, required this.error});

  final bool isLoading;
  final AppError? error;

  @override
  Widget build(BuildContext context) {
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
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final AppError error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '${error.code}: ${error.message}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _PanelShell extends StatelessWidget {
  const _PanelShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.components.card.surface,
        borderRadius: BorderRadius.circular(tokens.radius.sm),
        border: Border.all(color: tokens.color.borderSubtle),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}
