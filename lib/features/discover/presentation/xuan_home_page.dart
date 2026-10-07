import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation.dart';
import '../../../core/layout/window_size_class.dart';
import '../../../core/theme/application/theme_providers.dart';
import '../../../core/theme/domain/theme_regions.dart';
import '../../../core/theme/domain/theme_icons.dart';
import '../../../core/theme/domain/theme_materials.dart';
import '../../../core/theme/domain/theme_tokens.dart';
import '../../../core/theme/domain/theme_strings.dart';
import '../../../core/theme/domain/theme_home.dart';
import '../../../core/theme/infrastructure/token_resolver.dart';
import '../../../core/theme/presentation/theme_icon.dart';
import '../../../core/theme/presentation/theme_asset_image.dart';
import '../../../core/theme/presentation/theme_material.dart';
import '../../player/presentation/artwork_view.dart';
import '../../library/application/library_providers.dart';
import '../../player/application/player_providers.dart';
import '../../player/domain/playback_item.dart';
import '../../../../shared/widgets/search_field_with_history.dart';
import '../../plugin/application/plugin_controller.dart';
import '../../playlists/application/playlist_providers.dart';
import '../../playlists/infrastructure/playlist_repository.dart';
import '../../search/application/search_controller.dart' as search_state;
import '../application/discover_controller.dart';
import '../domain/online_collection.dart';

/// The flagship《玄》home page.
///
/// The composition is data, not code: [ThemeHomeLayout.blocks] decides which
/// sections render and in what order. Each block binds to the same live
/// repositories the rest of the app uses; when a source has no data the block
/// shows the design's skeleton state instead of disappearing, so the shell
/// never collapses into a blank column.
class XuanHomePage extends ConsumerWidget {
  const XuanHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(activeThemePackageProvider).layout.home;
    final formFactor =
        WindowSizeClass.of(context).width == WindowWidthClass.expanded
        ? RobyneFormFactor.desktop
        : RobyneFormFactor.mobile;
    final blocks = home.resolve(formFactor);
    final plugins = ref.watch(orderedPluginsProvider);
    final discover = ref.watch(discoverControllerProvider);
    final library = ref.watch(localMusicLibraryProvider).value;

    return CustomScrollView(
      slivers: <Widget>[
        // Page identity is app chrome, not skin composition: whichever blocks
        // a skin asks for, the page still says what it is and how to search
        // it. `topBar` owns the search field on desktop, so the phone-shaped
        // header carries its own (design spec §2.2).
        const SliverToBoxAdapter(child: _HomeHeader()),
        for (final block in blocks)
          if (block == ThemeHomeBlock.quickActions)
            SliverToBoxAdapter(
              child: _QuickActionGrid(
                onOpenPlaylists: () => ref
                    .read(selectedTabProvider.notifier)
                    .select(RobyneTab.playlists),
                onOpenSearch: () => ref
                    .read(selectedTabProvider.notifier)
                    .select(RobyneTab.search),
              ),
            )
          else if (block == ThemeHomeBlock.categoryChips)
            SliverToBoxAdapter(
              child: _CategoryChips(
                onOpenSearch: () => ref
                    .read(selectedTabProvider.notifier)
                    .select(RobyneTab.search),
              ),
            )
          else if (block == ThemeHomeBlock.hero)
            SliverToBoxAdapter(
              child: _HeroBanner(
                latest: discover.hotPlaylistItems.firstOrNull,
                onOpen: () => _openDiscover(
                  ref,
                  context,
                  discover.hotPlaylistItems.firstOrNull,
                ),
              ),
            )
          else if (block == ThemeHomeBlock.recommendations)
            SliverToBoxAdapter(
              child: _RecommendationRail(
                items: discover.hotPlaylistItems
                    .take(8)
                    .toList(growable: false),
                onOpen: (item) => _openDiscover(ref, context, item),
              ),
            )
          else if (block == ThemeHomeBlock.recent)
            SliverToBoxAdapter(
              child: _RecentSection(
                tracks: (library ?? const <PlaybackItem>[])
                    .take(6)
                    .toList(growable: false),
              ),
            )
          else if (block == ThemeHomeBlock.favorites)
            SliverToBoxAdapter(
              child: _FavoriteSection(
                tracks:
                    ref
                        .watch(playlistControllerProvider)
                        .value
                        ?.where(
                          (playlist) =>
                              playlist.id == PlaylistRepository.favoritesId,
                        )
                        .expand((playlist) => playlist.items)
                        .take(6)
                        .toList(growable: false) ??
                    const <PlaybackItem>[],
              ),
            )
          else if (block == ThemeHomeBlock.queue)
            const SliverToBoxAdapter(child: SizedBox.shrink()),
        if (plugins.isEmpty)
          const SliverToBoxAdapter(child: _EnablePluginHint()),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  void _openDiscover(
    WidgetRef ref,
    BuildContext context,
    OnlineCollectionItem? item,
  ) {
    if (item == null) {
      return;
    }
    // Loading the detail is only half the job: the home page and the browser
    // are two views of one destination, so the shelf's play / open actions
    // must also raise the browser. Without this the detail loaded invisibly
    // and every hero and card button read as "clicked but nothing happened".
    ref.read(discoverBrowserProvider.notifier).open();
    unawaited(
      ref.read(discoverControllerProvider.notifier).openCollection(item),
    );
  }
}

/// The phone design's four-tile shortcut grid.
/// Clicking the search field switches to the search destination and submits
/// whatever the user typed.
class _HomeHeader extends ConsumerStatefulWidget {
  const _HomeHeader();

  @override
  ConsumerState<_HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends ConsumerState<_HomeHeader> {
  late final TextEditingController _keyword;
  late final FocusNode _keywordFocus;

  @override
  void initState() {
    super.initState();
    _keyword = TextEditingController(
      text:
          ref.read(search_state.searchControllerProvider).value?.keyword ?? '',
    );
    _keywordFocus = FocusNode();
  }

  @override
  void dispose() {
    _keywordFocus.dispose();
    _keyword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The home page consumes the same plugin-scoped discovery state as the
    // browser. Syncing here means the recommendation rail paints real plugin
    // data on the first visit instead of waiting for the user to find the
    // 插件榜单 entry — the TTL cache in [DiscoverController] makes the follow-up
    // browser open free.
    final discoverState = ref.watch(discoverControllerProvider);
    // The user's own source order, so the home shelf starts from whichever
    // plugin they put first rather than whichever was installed first.
    final enabledPlugins = ref.watch(orderedEnabledPluginsProvider);
    final pluginSignature = discoverPluginSignature(enabledPlugins);
    if (discoverState.pluginSignature != pluginSignature) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final controller = ref.read(discoverControllerProvider.notifier);
        // Sync first (it fills the plugin table synchronously), then let the
        // controller pick whichever enabled plugin can actually serve the
        // shelf. The home rail reads `hotPlaylistItems`, so this is the
        // hot-playlist flow regardless of the surface the browser kept.
        unawaited(() async {
          await controller.syncPlugins(enabledPlugins);
          await controller.seedHomeShelf();
        }());
      });
    }
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final sizeClass = WindowSizeClass.of(context);
    final isPhone = sizeClass.width != WindowWidthClass.expanded;
    // The landscape board (`mobile-landscape.png`) is a single 44dp strip:
    // title, inline search, brand mark. Stacking the portrait header there
    // eats the entire 360dp-tall window.
    final isStrip = isPhone && sizeClass.isCompactHeight;
    final assets = ref.watch(activeThemePackageProvider).assets;
    if (isStrip) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Row(
          children: <Widget>[
            Text(
              '发现',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _HomeSearchField(
                compact: true,
                controller: _keyword,
                focusNode: _keywordFocus,
                onSubmit: _search,
              ),
            ),
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radius.sm),
              child: SizedBox(
                width: 28,
                height: 28,
                child: ThemeAssetImage(
                  asset: assets.logo,
                  fallback: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.brandBase,
                    ),
                    child: Icon(
                      Icons.graphic_eq,
                      size: 15,
                      color: colors.onBrand,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(isPhone ? 16 : 28, 20, isPhone ? 16 : 28, 0),
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
                      '发现',
                      style: TextStyle(
                        fontSize: isPhone ? 21 : 26,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '根据本地曲库推荐',
                      style: TextStyle(fontSize: 12, color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              if (isPhone)
                ClipRRect(
                  borderRadius: BorderRadius.circular(tokens.radius.sm),
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: ThemeAssetImage(
                      asset: assets.logo,
                      fallback: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.brandBase,
                        ),
                        child: Icon(
                          Icons.graphic_eq,
                          size: 18,
                          color: colors.onBrand,
                        ),
                      ),
                    ),
                  ),
                ),
              if (!isPhone) ...<Widget>[
                const SizedBox(width: 12),
                _PluginBrowserButton(),
              ],
            ],
          ),
          if (isPhone) ...<Widget>[
            const SizedBox(height: 14),
            _HomeSearchField(
              controller: _keyword,
              focusNode: _keywordFocus,
              onSubmit: _search,
            ),
          ],
        ],
      ),
    );
  }

  void _search() {
    final keyword = _keyword.text.trim();
    ref.read(selectedTabProvider.notifier).select(RobyneTab.search);
    if (keyword.isEmpty) {
      return;
    }
    ref
        .read(search_state.searchControllerProvider.notifier)
        .updateKeyword(keyword);
    unawaited(
      ref
          .read(search_state.searchControllerProvider.notifier)
          .search(
            ref.read(orderedPluginsProvider),
          ),
    );
  }
}

class _HomeSearchField extends ConsumerWidget {
  const _HomeSearchField({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    this.compact = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  /// True inside the landscape strip, where the field shares a 44dp row.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    // The same dropdown the desktop top bar gets: the phone layout hides the
    // top bar's field, so this one is the only search box on screen and it has
    // to carry the remembered keywords too.
    return SearchFieldWithHistory(
      controller: controller,
      focusNode: focusNode,
      onSubmit: (_) => onSubmit(),
      textStyle: TextStyle(fontSize: 13, color: colors.textPrimary),
      fillColor: colors.surfaceBase,
      borderRadius: BorderRadius.all(Radius.circular(tokens.radius.md)),
      contentPadding: EdgeInsets.symmetric(vertical: compact ? 8 : 11),
      hintText: strings.resolve(ThemeStringKey.searchHint),
      hintStyle: TextStyle(fontSize: 12.5, color: colors.textMuted),
      prefix: Padding(
        padding: const EdgeInsets.only(left: 12, right: 8),
        child: ThemeIconView(
          slot: ThemeIconKey.search,
          fallback: Icons.search,
          size: compact ? 16 : 18,
          color: colors.textMuted,
        ),
      ),
    );
  }
}

/// The desktop affordance into the plugin browser.
///
/// The design puts page-level actions on the header row beside the identity
/// block, not floating over the content; a FAB there covered the first shelf.
class _PluginBrowserButton extends ConsumerWidget {
  const _PluginBrowserButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    // The design draws a labelled pill (`pillbtn`) on the header row, not a
    // bare `IconButton`: a pill has a visible boundary and a padding-driven
    // hit target, where an IconButton's sparse 48x48 tap target over a wide
    // Row read as "clicked but nothing happened" whenever the pointer landed
    // between the icon and the label.
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    return Tooltip(
      message: strings.resolve(ThemeStringKey.discoverMore),
      child: InkWell(
        onTap: () => ref.read(discoverBrowserProvider.notifier).open(),
        borderRadius: BorderRadius.all(Radius.circular(tokens.radius.full)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: colors.textPrimary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.all(Radius.circular(tokens.radius.full)),
            border: Border.all(color: colors.borderDefault),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ThemeIconView(
                slot: ThemeIconKey.plugins,
                fallback: Icons.extension_outlined,
                size: 16,
                color: colors.textSecondary,
              ),
              const SizedBox(width: 7),
              Text(
                strings.resolve(ThemeStringKey.discoverRankingEntry),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The phone design's four-tile shortcut grid.
///
/// A desktop column already repeats these destinations in the rail, so the
/// grid only renders on phone-shaped widths; the block still exists in the
/// skin's `layout.home.blocks`, which keeps one composition for both shapes.
class _QuickActionGrid extends ConsumerWidget {
  const _QuickActionGrid({
    required this.onOpenPlaylists,
    required this.onOpenSearch,
  });

  final VoidCallback onOpenPlaylists;
  final VoidCallback onOpenSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sizeClass = WindowSizeClass.of(context);
    // The grid is a portrait affordance: on a 360dp-tall landscape window the
    // design replaces it with a chip row inside the content, so keeping four
    // 42dp tiles would cost a third of the page.
    if (sizeClass.width == WindowWidthClass.expanded ||
        sizeClass.isCompactHeight) {
      return const SizedBox.shrink();
    }
    final tokens = RobyneTheme.of(context).tokens;
    final entries = <_QuickAction>[
      _QuickAction(
        label: '每日电台',
        icon: Icons.auto_awesome_outlined,
        tint: tokens.components.navBar.selectedItem,
        onTap: onOpenSearch,
      ),
      _QuickAction(
        label: '排行榜',
        icon: Icons.emoji_events_outlined,
        tint: tokens.color.accentBase,
        onTap: onOpenSearch,
      ),
      _QuickAction(
        label: '分类歌单',
        icon: Icons.grid_view_outlined,
        tint: tokens.components.navBar.selectedItem,
        onTap: onOpenSearch,
      ),
      _QuickAction(
        label: '我喜欢',
        icon: Icons.favorite_border,
        tint: tokens.color.accentBase,
        onTap: onOpenPlaylists,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
      child: Row(
        children: <Widget>[
          for (final entry in entries) Expanded(child: _QuickActionTile(entry)),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatefulWidget {
  const _CategoryChips({required this.onOpenSearch});

  final VoidCallback onOpenSearch;

  @override
  State<_CategoryChips> createState() => _CategoryChipsState();
}

class _CategoryChipsState extends State<_CategoryChips> {
  static const _labels = <String>['推荐', '电台', '歌单', '排行', '本地'];
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    // Only the landscape board uses these; a portrait phone or a desktop
    // column has the full-width shelves instead.
    if (!WindowSizeClass.of(context).isCompactHeight) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: <Widget>[
          for (var index = 0; index < _labels.length; index += 1) ...<Widget>[
            if (index > 0) const SizedBox(width: 8),
            _CategoryChip(
              label: _labels[index],
              selected: index == _selected,
              tokens: tokens,
              onTap: () {
                setState(() => _selected = index);
                widget.onOpenSearch();
              },
            ),
          ],
          const Spacer(),
          Text('全部', style: TextStyle(fontSize: 11, color: colors.textMuted)),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.tokens,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = tokens.color;
    final comp = tokens.components.navBar;
    return Material(
      color: selected ? comp.selectedIndicatorFill : colors.surfaceBase,
      borderRadius: BorderRadius.all(Radius.circular(tokens.radius.full)),
      child: InkWell(
        borderRadius: BorderRadius.all(Radius.circular(tokens.radius.full)),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? colors.onBrand : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.tint,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile(this.entry);

  final _QuickAction entry;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    return InkWell(
      onTap: entry.onTap,
      borderRadius: BorderRadius.circular(tokens.radius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.surfaceBase,
                borderRadius: BorderRadius.circular(tokens.radius.md),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Icon(entry.icon, size: 20, color: entry.tint),
            ),
            const SizedBox(height: 7),
            Text(
              entry.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// The gradient hero from the design.
class _HeroBanner extends ConsumerWidget {
  const _HeroBanner({required this.latest, required this.onOpen});

  final OnlineCollectionItem? latest;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final hero = ref.watch(activeThemePackageProvider).assets.hero;
    // The landscape board (`mobile-landscape.png`) has no banner: its leading
    // element is the 为你推荐 shelf, and a 96dp strip above that shelf would
    // push the cards out of a 360dp window. The block therefore yields rather
    // than shrinking, and `recommendations` — which renders as a grid at this
    // size — carries the same content.
    final sizeClass = WindowSizeClass.of(context);
    if (sizeClass.isCompactHeight) {
      return const SizedBox.shrink();
    }
    // A narrow desktop window keeps the side rail, which leaves the hero
    // less room than the wide board. Reflowing the copy beside the cover
    // avoids the copy column overflowing the fixed 176dp banner.
    final compactHero = sizeClass.width != WindowWidthClass.expanded;
    final heroMaterial = tokens.materials.hero;
    final heroRadius = BorderRadius.circular(tokens.radius.lg);
    final effectiveHero = heroMaterial.isTransparent
        ? heroMaterial.copyWith(
            gradient: ThemeGradient(
              stops: <ThemeGradientStop>[
                ThemeGradientStop(color: colors.brandBase, offset: 0),
                ThemeGradientStop(
                  color: colors.brandBase.withValues(alpha: 0.72),
                  offset: 0.5,
                ),
                ThemeGradientStop(color: colors.surfaceSelected, offset: 1),
              ],
              begin: ThemePoint.centerLeft,
              end: ThemePoint.centerRight,
            ),
            radius: tokens.radius.lg,
          )
        : heroMaterial.copyWith(radius: heroMaterial.radius ?? tokens.radius.lg);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MaterialSurface(
            material: effectiveHero,
            tokens: tokens,
            borderRadius: heroRadius,
            child: SizedBox(
              height: 176,
              child: compactHero
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                      child: _heroCopy(latest, colors, tokens),
                    )
                  : Row(
                      children: <Widget>[
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 18, 12, 18),
                            child: _heroCopy(latest, colors, tokens),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            right: 18,
                            top: 18,
                            bottom: 18,
                          ),
                          child: _heroCover(hero, latest, colors, tokens),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroCopy(
    OnlineCollectionItem? latest,
    ThemeColors colors,
    ThemeTokens tokens,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colors.onBrand.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(tokens.radius.sm),
          ),
          child: Text(
            '每日电台',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.onBrand,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          latest?.title ?? '深夜通勤电台',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: colors.onBrand,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          latest?.description?.trim().isNotEmpty == true
              ? latest!.description!
              : '基于你喜欢和最近播放生成',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: colors.onBrand.withValues(alpha: 0.82),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: <Widget>[
            FilledButton.icon(
              onPressed: onOpen,
              style: FilledButton.styleFrom(
                backgroundColor: colors.onBrand,
                foregroundColor: colors.brandBase,
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('立即播放'),
            ),
            OutlinedButton.icon(
              onPressed: onOpen,
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.onBrand,
                side: BorderSide(
                  color: colors.onBrand.withValues(alpha: 0.55),
                ),
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('收藏'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _heroCover(
    String? hero,
    OnlineCollectionItem? latest,
    ThemeColors colors,
    ThemeTokens tokens,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radius.md),
      child: SizedBox(
        width: 132,
        child: latest?.artworkUrl != null
            ? ArtworkView(
                artworkUrl: latest!.artworkUrl,
                fit: BoxFit.cover,
                expand: true,
              )
            : ThemeAssetImage(
                asset: hero,
                fallback: Container(
                  color: colors.onBrand.withValues(alpha: 0.14),
                  child: Icon(
                    Icons.nightlight_round,
                    size: 56,
                    color: colors.onBrand.withValues(alpha: 0.85),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Horizontally scrolling recommendation cards.
class _RecommendationRail extends StatelessWidget {
  const _RecommendationRail({required this.items, required this.onOpen});

  final List<OnlineCollectionItem> items;
  final ValueChanged<OnlineCollectionItem> onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    // The design always shows a populated rail. When a plugin has not
    // returned data yet, render the same card geometry with the brand palette
    // so the page keeps its shape instead of jumping when data arrives.
    final cards = items.isEmpty
        ? const <OnlineCollectionItem?>[null, null, null, null, null]
        : items.map<OnlineCollectionItem?>((item) => item).toList();
    // The landscape board lays the same shelf out as an evenly divided grid:
    // five columns fit across 800dp where a horizontal rail would have to
    // scroll past the fold (design spec §4.5, "banner 横向滚动，不压缩为两列").
    final sizeClass = WindowSizeClass.of(context);
    final grid = sizeClass.isCompactHeight;
    // The portrait board leads with the liked-songs list instead, so the rail
    // would arrive below the fold on a phone and only add a scroll region.
    if (!grid && sizeClass.width == WindowWidthClass.compact) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.only(top: grid ? 10 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: grid ? 16 : 28),
            child: Row(
              children: <Widget>[
                Text(
                  '为你推荐',
                  style: TextStyle(
                    fontSize: grid ? 12.5 : 17,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  items.isEmpty ? '等待插件数据' : '${items.length} 张更新',
                  style: TextStyle(
                    fontSize: grid ? 10.5 : 11,
                    color: colors.textMuted,
                  ),
                ),
                const Spacer(),
                Text(
                  '全部 ›',
                  style: TextStyle(
                    fontSize: grid ? 10.5 : 11,
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: grid ? 8 : 12),
          if (grid)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (
                    var index = 0;
                    index < cards.length;
                    index += 1
                  ) ...<Widget>[
                    if (index > 0) const SizedBox(width: 10),
                    Expanded(
                      child: _RecommendationCard(
                        item: cards[index],
                        accent: _cardAccent(index),
                        fluid: true,
                        onTap: cards[index] == null
                            ? null
                            : () => onOpen(cards[index]!),
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            SizedBox(
              height: 176,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                scrollDirection: Axis.horizontal,
                itemCount: cards.length,
                separatorBuilder: (context, index) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final item = cards[index];
                  return _RecommendationCard(
                    item: item,
                    accent: _cardAccent(index),
                    onTap: item == null ? null : () => onOpen(item),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  static Color _cardAccent(int index) {
    const palette = <Color>[
      Color(0xFF63D8C3),
      Color(0xFF6FA8FF),
      Color(0xFFB78CFF),
      Color(0xFFE7B35A),
      Color(0xFFF07178),
      Color(0xFF9CBF76),
    ];
    return palette[index % palette.length];
  }
}

class _RecommendationCard extends ConsumerWidget {
  const _RecommendationCard({
    required this.item,
    required this.accent,
    required this.onTap,
    this.fluid = false,
  });

  final OnlineCollectionItem? item;
  final Color accent;
  final VoidCallback? onTap;

  /// True inside the landscape grid, where the surrounding [Expanded] owns the
  /// width and an inner fixed width would leave a gap.
  final bool fluid;

  /// True in the landscape grid, which uses the design's 100dp cover and
  /// 11dp captions instead of the portrait rail's 108dp/13dp.
  bool get _compact => fluid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final card = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radius.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: _compact ? 100 : 108,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  accent,
                  Color.alphaBlend(
                    colors.backgroundBase.withValues(alpha: 0.55),
                    accent,
                  ),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(tokens.radius.md),
            ),
            // The gradient stays as the bed the cover is painted on: it shows
            // through while a cover loads, and stands in when a plugin
            // returns no artwork at all. `ArtworkView` owns the single shared
            // disk cache, so a cover already fetched by the queue or the
            // detail panel costs nothing here.
            child: ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radius.md),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (item?.artworkUrl != null)
                    ArtworkView(
                      artworkUrl: item!.artworkUrl,
                      fit: BoxFit.cover,
                      expand: true,
                    ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.backgroundBase.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(tokens.radius.sm),
                      ),
                      child: Text(
                        item?.platform ?? 'Robyne',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    // A real hit target rather than a decorative glyph: the
                    // overlapping card `InkWell` used to be the only thing that
                    // made this play affordance work, so any change to the
                    // Stack's hit testing silently killed the button the user
                    // sees. It now owns its own tap, with a tooltip to match.
                    child: Tooltip(
                      message: strings.resolve(ThemeStringKey.discoverPlay),
                      child: Material(
                        color: colors.backgroundBase.withValues(alpha: 0.6),
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: onTap,
                          child: SizedBox(
                            width: 30,
                            height: 30,
                            child: Icon(
                              Icons.play_arrow,
                              size: 18,
                              color: colors.brandBase,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item?.title ?? '等待推荐数据',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: _compact ? 11 : 13,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item?.description?.trim().isNotEmpty == true
                ? item!.description!
                : '启用插件后自动更新',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: _compact ? 9.5 : 10,
              color: colors.textMuted,
            ),
          ),
        ],
      ),
    );
    if (fluid) {
      return card;
    }
    return SizedBox(width: 154, child: card);
  }
}

/// The phone board's liked-songs list (`mobile-portrait.png`).
///
/// Rows are taller on a phone (the design's touch target rule, spec §4.4) and
/// each row carries its own like affordance, so the list reads as the place
/// the songs live rather than as a read-only preview.
class _FavoriteSection extends ConsumerWidget {
  const _FavoriteSection({required this.tracks});

  final List<PlaybackItem> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    // The landscape board leads with the recommendation shelf instead; a
    // four-row list of 54dp rows would consume most of a 360dp window.
    if (WindowSizeClass.of(context).isCompactHeight) {
      return const SizedBox.shrink();
    }
    final items = tracks.isEmpty
        ? const <PlaybackItem?>[null, null, null, null]
        : tracks.map<PlaybackItem?>((item) => item).toList(growable: false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                '红心歌曲',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                tracks.isEmpty ? '本机曲库' : '${tracks.length} 首',
                style: TextStyle(fontSize: 11, color: colors.textMuted),
              ),
              const Spacer(),
              Text(
                '全部 ›',
                style: TextStyle(fontSize: 11, color: colors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in items)
            _FavoriteRow(
              item: item,
              colors: colors,
              selected: item != null && item.id == tracks.firstOrNull?.id,
            ),
        ],
      ),
    );
  }
}

class _FavoriteRow extends ConsumerWidget {
  const _FavoriteRow({
    required this.item,
    required this.colors,
    required this.selected,
  });

  final PlaybackItem? item;
  final ThemeColors colors;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RobyneTheme.of(context).tokens;
    return Material(
      color: selected ? colors.surfaceSelected : const Color(0x00000000),
      borderRadius: BorderRadius.all(Radius.circular(tokens.radius.md)),
      child: InkWell(
        borderRadius: BorderRadius.all(Radius.circular(tokens.radius.md)),
        onTap: item == null
            ? null
            : () => ref.read(playerControllerProvider.notifier).playItem(item!),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.surfaceBase,
                  borderRadius: BorderRadius.circular(tokens.radius.sm),
                ),
                child: Icon(
                  Icons.music_note,
                  size: 18,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item?.title ?? '还没有红心歌曲',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: selected ? colors.brandBase : colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item?.artist ?? '在任意歌曲上点喜欢即可收藏',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              if (item != null)
                IconButton(
                  tooltip: '取消喜欢',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.favorite, size: 18, color: colors.brandBase),
                  onPressed: () => ref
                      .read(playlistControllerProvider.notifier)
                      .toggleFavorite(item!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Recently added local tracks.
class _RecentSection extends ConsumerWidget {
  const _RecentSection({required this.tracks});

  final List<PlaybackItem> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final items = tracks.isEmpty
        ? const <PlaybackItem?>[null, null, null, null]
        : tracks.map<PlaybackItem?>((item) => item).toList(growable: false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                '最近入库',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                tracks.isEmpty ? '本机曲库' : '本机 · ${tracks.length} 首',
                style: TextStyle(fontSize: 11, color: colors.textMuted),
              ),
              const Spacer(),
              Text(
                '全部 ›',
                style: TextStyle(fontSize: 11, color: colors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in items)
            InkWell(
              onTap: item == null
                  ? null
                  : () => ref
                        .read(playerControllerProvider.notifier)
                        .playItem(item),
              borderRadius: BorderRadius.circular(tokens.radius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.surfaceBase,
                        borderRadius: BorderRadius.circular(tokens.radius.sm),
                      ),
                      child: Icon(
                        Icons.music_note,
                        size: 18,
                        color: colors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item?.title ?? '导入本地音乐后显示',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item?.artist ??
                                item?.localPath ??
                                '支持 MP3 / FLAC / WAV / M4A',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (item?.duration != null)
                      Text(
                        _formatDuration(item!.duration!),
                        style: TextStyle(fontSize: 11, color: colors.textMuted),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _EnablePluginHint extends StatelessWidget {
  const _EnablePluginHint();

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tokens.components.card.surface,
          borderRadius: BorderRadius.circular(tokens.radius.md),
          border: Border.all(color: tokens.color.borderSubtle),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.extension_outlined,
              size: 18,
              color: tokens.color.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '启用音乐插件后，推荐与榜单会自动出现在这里。',
                style: TextStyle(
                  fontSize: 12,
                  color: tokens.color.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
