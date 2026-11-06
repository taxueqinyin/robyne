import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/result/result.dart';
import '../../plugin/application/plugin_providers.dart';
import '../../plugin/domain/plugin_definition.dart';
import '../../plugin/domain/plugin_discovery_executor.dart';
import '../../search/domain/music_item.dart';
import '../domain/online_collection.dart';
import '../infrastructure/discover_cache_store.dart';

final discoverControllerProvider =
    NotifierProvider<DiscoverController, DiscoverState>(DiscoverController.new);

/// How long a discovery response stays valid before another request hits the
/// plugin again.
///
/// Rankings, hot-playlist tags and playlist pages are plugin-scoped catalogue
/// data, not live playback state. Re-fetching them on every tab or source
/// switch was the exact UX complaint from review: the user watches a spinner
/// for data that was on screen five seconds ago. One hour matches "catalogue
/// that changes daily at most" — and the refresh button still bypasses the
/// cache, so staleness is a choice, not a limit.
const Duration discoverCacheTtl = Duration(hours: 1);

/// Timestamps use `dart:ui`'s clock abstraction so tests can drive time
/// through `TestWidgetsFlutterBinding`.
DateTime _now() => DateTime.now();

/// A cache entry and the moment it was filled.
class _CacheEntry<T> {
  const _CacheEntry({
    required this.value,
    required this.filledAt,
    required this.pluginSignature,
  });

  final T value;
  final DateTime filledAt;
  final String pluginSignature;

  bool get isFresh => _now().difference(filledAt) < discoverCacheTtl;
}

/// Cache keys for every plugin-scoped discovery request.
///
/// Keys include the plugin id (and for sheets, the tag), because the same
/// key must never leak data between plugins or between two different tag
/// pages.
String _rankingsCacheKey(String pluginId) => 'rankings:$pluginId';

String _sheetTagsCacheKey(String pluginId) => 'sheets:$pluginId:';

String _sheetPageCacheKey(String pluginId, Object? tag) =>
    'sheets:$pluginId:${tag?.toString() ?? ''}';

String discoverPluginSignature(List<PluginDefinition> plugins) {
  final enabled = plugins
      .where((plugin) => plugin.enabled)
      .toList(growable: false);
  return enabled
      .map((plugin) {
        final variables = plugin.userVariableValues.entries.toList(
          growable: false,
        )..sort((left, right) => left.key.compareTo(right.key));
        final values = variables
            .map((entry) => '${entry.key}=${entry.value}')
            .join('&');
        return '${plugin.id}:${plugin.updatedAt.microsecondsSinceEpoch}:$values';
      })
      .join('|');
}

class DiscoverState {
  const DiscoverState({
    this.pluginSignature = '',
    this.selectedPluginId,
    this.selectedCollection,
    this.topListGroups = const <OnlineCollectionGroup>[],
    this.isLoadingTopLists = false,
    this.topListsError,
    this.sheetTagGroups = const <OnlineSheetTagGroup>[],
    this.pinnedSheetTags = const <OnlineSheetTag>[],
    this.selectedSheetTag,
    this.hotPlaylistItems = const <OnlineCollectionItem>[],
    this.hotPlaylistPage = 0,
    this.hotPlaylistsIsEnd = false,
    this.isLoadingHotPlaylists = false,
    this.isLoadingMoreHotPlaylists = false,
    this.hotPlaylistsError,
    this.detail,
    this.isLoadingDetail = false,
    this.isLoadingMoreDetail = false,
    this.detailError,
  });

  final String pluginSignature;
  final String? selectedPluginId;

  /// The collection the user drilled into, if any.
  ///
  /// This is what tells the page to show the detail surface: [detail] is only
  /// the loaded result, and it is still null while the first page is in
  /// flight, so keying the view off it would leave a click with no feedback.
  final OnlineCollectionItem? selectedCollection;
  final List<OnlineCollectionGroup> topListGroups;
  final bool isLoadingTopLists;
  final AppError? topListsError;
  final List<OnlineSheetTagGroup> sheetTagGroups;
  final List<OnlineSheetTag> pinnedSheetTags;
  final OnlineSheetTag? selectedSheetTag;
  final List<OnlineCollectionItem> hotPlaylistItems;
  final int hotPlaylistPage;
  final bool hotPlaylistsIsEnd;
  final bool isLoadingHotPlaylists;
  final bool isLoadingMoreHotPlaylists;
  final AppError? hotPlaylistsError;
  final OnlineCollectionDetail? detail;
  final bool isLoadingDetail;
  final bool isLoadingMoreDetail;
  final AppError? detailError;

  String? get selectedCollectionKey =>
      selectedCollection?.uniqueKey ?? detail?.collection.uniqueKey;

  DiscoverState copyWith({
    String? pluginSignature,
    Object? selectedPluginId = _discoverUnset,
    Object? selectedCollection = _discoverUnset,
    List<OnlineCollectionGroup>? topListGroups,
    bool? isLoadingTopLists,
    Object? topListsError = _discoverUnset,
    List<OnlineSheetTagGroup>? sheetTagGroups,
    List<OnlineSheetTag>? pinnedSheetTags,
    Object? selectedSheetTag = _discoverUnset,
    List<OnlineCollectionItem>? hotPlaylistItems,
    int? hotPlaylistPage,
    bool? hotPlaylistsIsEnd,
    bool? isLoadingHotPlaylists,
    bool? isLoadingMoreHotPlaylists,
    Object? hotPlaylistsError = _discoverUnset,
    Object? detail = _discoverUnset,
    bool? isLoadingDetail,
    bool? isLoadingMoreDetail,
    Object? detailError = _discoverUnset,
  }) {
    return DiscoverState(
      pluginSignature: pluginSignature ?? this.pluginSignature,
      selectedPluginId: identical(selectedPluginId, _discoverUnset)
          ? this.selectedPluginId
          : selectedPluginId as String?,
      selectedCollection: identical(selectedCollection, _discoverUnset)
          ? this.selectedCollection
          : selectedCollection as OnlineCollectionItem?,
      topListGroups: topListGroups ?? this.topListGroups,
      isLoadingTopLists: isLoadingTopLists ?? this.isLoadingTopLists,
      topListsError: identical(topListsError, _discoverUnset)
          ? this.topListsError
          : topListsError as AppError?,
      sheetTagGroups: sheetTagGroups ?? this.sheetTagGroups,
      pinnedSheetTags: pinnedSheetTags ?? this.pinnedSheetTags,
      selectedSheetTag: identical(selectedSheetTag, _discoverUnset)
          ? this.selectedSheetTag
          : selectedSheetTag as OnlineSheetTag?,
      hotPlaylistItems: hotPlaylistItems ?? this.hotPlaylistItems,
      hotPlaylistPage: hotPlaylistPage ?? this.hotPlaylistPage,
      hotPlaylistsIsEnd: hotPlaylistsIsEnd ?? this.hotPlaylistsIsEnd,
      isLoadingHotPlaylists:
          isLoadingHotPlaylists ?? this.isLoadingHotPlaylists,
      isLoadingMoreHotPlaylists:
          isLoadingMoreHotPlaylists ?? this.isLoadingMoreHotPlaylists,
      hotPlaylistsError: identical(hotPlaylistsError, _discoverUnset)
          ? this.hotPlaylistsError
          : hotPlaylistsError as AppError?,
      detail: identical(detail, _discoverUnset)
          ? this.detail
          : detail as OnlineCollectionDetail?,
      isLoadingDetail: isLoadingDetail ?? this.isLoadingDetail,
      isLoadingMoreDetail: isLoadingMoreDetail ?? this.isLoadingMoreDetail,
      detailError: identical(detailError, _discoverUnset)
          ? this.detailError
          : detailError as AppError?,
    );
  }
}

class DiscoverController extends Notifier<DiscoverState> {
  final Map<String, PluginDefinition> _pluginsById =
      <String, PluginDefinition>{};
  final Map<String, DiscoverCacheRecord> _diskRecords =
      <String, DiscoverCacheRecord>{};
  int _topListsRequestId = 0;
  int _hotPlaylistsRequestId = 0;
  int _detailRequestId = 0;
  bool _hydrated = false;
  Future<void>? _hydration;
  String _pluginSignature = '';
  // Cache is instance state so hot-reloading the skin, switching tabs, or
  // navigating away and back all read the same data without a refetch.
  final Map<String, _CacheEntry<List<OnlineCollectionGroup>>> _topListsCache =
      {};
  final Map<String, _CacheEntry<OnlineSheetTagCatalog>> _sheetTagCache = {};
  final Map<String, _CacheEntry<OnlineCollectionPage>> _sheetPageCache = {};
  final Map<String, _CacheEntry<OnlineCollectionDetail>> _detailCache = {};

  @override
  DiscoverState build() => const DiscoverState();

  Future<void> syncPlugins(List<PluginDefinition> plugins) async {
    await _ensureHydrated();
    final enabled = plugins
        .where((plugin) => plugin.enabled)
        .toList(growable: false);
    _pluginsById
      ..clear()
      ..addEntries(enabled.map((plugin) => MapEntry(plugin.id, plugin)));

    final signature = discoverPluginSignature(enabled);
    if (enabled.isEmpty) {
      _invalidateAllRequests();
      state = DiscoverState(pluginSignature: signature);
      return;
    }

    final selectedPluginId =
        enabled.any((plugin) => plugin.id == state.selectedPluginId)
        ? state.selectedPluginId
        : enabled.first.id;
    final pluginChanged = selectedPluginId != state.selectedPluginId;
    final signatureChanged = signature != state.pluginSignature;

    if (!pluginChanged && !signatureChanged) {
      return;
    }

    _invalidateAllRequests();
    if (signatureChanged) {
      _clearCaches();
      _adoptDiskRecords(signature);
    }
    _pluginSignature = signature;
    state = _resetForPlugin(
      state.copyWith(
        pluginSignature: signature,
        selectedPluginId: selectedPluginId,
      ),
    );
    await _loadAll(force: false);
  }

  Future<void> selectPlugin(String pluginId) async {
    if (pluginId == state.selectedPluginId ||
        !_pluginsById.containsKey(pluginId)) {
      return;
    }
    _invalidateAllRequests();
    state = _resetForPlugin(state.copyWith(selectedPluginId: pluginId));
    await _loadAll(force: false);
  }

  /// Reloads both sections for the selected source.
  ///
  /// The page paints rankings and hot playlists at the same time, so the
  /// header's refresh is one action over the pair. The per-section retry
  /// buttons call [reloadRankings] / [reloadHotPlaylists] instead, so one
  /// broken section does not discard the other one's data.
  Future<void> refreshAll() async {
    await _loadAll(force: true);
  }

  Future<void> reloadRankings() async {
    await _loadTopLists(force: true);
  }

  Future<void> reloadHotPlaylists() async {
    await _loadHotPlaylists(force: true, reloadCatalog: true);
  }

  Future<void> reloadDetail() async {
    final collection = state.selectedCollection ?? state.detail?.collection;
    if (collection == null) {
      return;
    }
    await openCollection(collection);
  }

  Future<void> selectHotPlaylistTag(OnlineSheetTag tag) async {
    if (tag.key == state.selectedSheetTag?.key) {
      return;
    }
    state = state.copyWith(selectedSheetTag: tag);
    await _loadHotPlaylists(
      force: true,
      reloadCatalog: false,
      requestedTag: tag,
    );
  }

  Future<void> loadMoreHotPlaylists() async {
    final plugin = _selectedPlugin;
    final tag = state.selectedSheetTag;
    if (plugin == null ||
        tag == null ||
        state.isLoadingHotPlaylists ||
        state.isLoadingMoreHotPlaylists ||
        state.hotPlaylistsIsEnd) {
      return;
    }

    final requestId = ++_hotPlaylistsRequestId;
    state = state.copyWith(
      isLoadingMoreHotPlaylists: true,
      hotPlaylistsError: null,
    );
    final result = await _invokeDiscovery(
      plugin,
      (executor, source) => executor.getRecommendSheetsByTag(
        plugin: plugin,
        source: source,
        tag: tag.raw,
        page: state.hotPlaylistPage + 1,
      ),
    );
    if (!ref.mounted || requestId != _hotPlaylistsRequestId) {
      return;
    }

    switch (result) {
      case Ok<Object?>(:final value):
        final adapted = ref
            .read(musicFreeCompatAdapterProvider)
            .musicSheetPageFromPluginValue(
              value,
              pluginId: plugin.id,
              platform: plugin.platform,
              page: state.hotPlaylistPage + 1,
            );
        switch (adapted) {
          case Ok<OnlineCollectionPage>(:final value):
            state = state.copyWith(
              hotPlaylistItems: <OnlineCollectionItem>[
                ...state.hotPlaylistItems,
                ...value.items,
              ],
              hotPlaylistPage: value.page,
              hotPlaylistsIsEnd: value.isEnd,
              isLoadingMoreHotPlaylists: false,
              hotPlaylistsError: null,
            );
          case Failure<OnlineCollectionPage>(:final error):
            state = state.copyWith(
              isLoadingMoreHotPlaylists: false,
              hotPlaylistsError: error,
            );
        }
      case Failure<Object?>(:final error):
        state = state.copyWith(
          isLoadingMoreHotPlaylists: false,
          hotPlaylistsError: _discoveryError(
            error,
            plugin,
            method: 'getRecommendSheetsByTag',
            label: 'hot playlists',
          ),
        );
    }
  }

  Future<void> openCollection(OnlineCollectionItem collection) async {
    // The page keys its detail surface off this, not off `detail`: the
    // request has not answered yet, and a click that changes nothing reads as
    // broken.
    state = state.copyWith(selectedCollection: collection, detailError: null);
    if (collection.kind == OnlineCollectionKind.topList) {
      await _loadTopListDetail(collection);
      return;
    }
    await _loadMusicSheetDetail(collection, page: 1, append: false);
  }

  /// Leaves the detail surface and returns to rankings + hot playlists.
  void closeDetail() {
    if (state.detail == null && state.selectedCollection == null) {
      return;
    }
    // Any in-flight detail load is invalidated first, otherwise a late
    // response would re-open the view the user just dismissed.
    _invalidateAllRequests();
    state = state.copyWith(
      selectedCollection: null,
      detail: null,
      detailError: null,
      isLoadingDetail: false,
      isLoadingMoreDetail: false,
    );
  }

  /// Puts a collection back on screen from the key the shell recorded.
  ///
  /// The navigation history only stores the opaque
  /// [OnlineCollectionItem.uniqueKey], so the item is looked up among the ones
  /// already loaded for the selected source. A key that is gone — the source
  /// was switched, or the cache moved on — falls back to the catalogue rather
  /// than parking the user on an empty drill-down.
  Future<void> restoreCollection(String key) async {
    if (state.selectedCollectionKey == key) {
      return;
    }
    final item = _findCollection(key);
    if (item == null) {
      closeDetail();
      return;
    }
    await openCollection(item);
  }

  OnlineCollectionItem? _findCollection(String key) {
    for (final group in state.topListGroups) {
      for (final item in group.items) {
        if (item.uniqueKey == key) {
          return item;
        }
      }
    }
    for (final item in state.hotPlaylistItems) {
      if (item.uniqueKey == key) {
        return item;
      }
    }
    final selected = state.selectedCollection;
    if (selected != null && selected.uniqueKey == key) {
      return selected;
    }
    final open = state.detail?.collection;
    return open != null && open.uniqueKey == key ? open : null;
  }

  Future<void> loadMoreDetail() async {
    final detail = state.detail;
    final plugin = _selectedPlugin;
    if (detail == null ||
        plugin == null ||
        detail.collection.kind != OnlineCollectionKind.musicSheet ||
        state.isLoadingDetail ||
        state.isLoadingMoreDetail ||
        detail.isEnd) {
      return;
    }
    await _loadMusicSheetDetail(
      detail.collection,
      page: detail.page + 1,
      append: true,
    );
  }

  /// Fetches both sections for the selected source.
  ///
  /// The first-level page shows rankings and hot playlists together, so a
  /// source switch has to fill both. Each loader has its own request id and
  /// its own cache entry, so they can run concurrently without trampling one
  /// another's state.
  Future<void> _loadAll({required bool force}) async {
    await Future.wait<void>(<Future<void>>[
      _loadTopLists(force: force),
      _loadHotPlaylists(force: force, reloadCatalog: true),
    ]);
  }

  Future<void> _loadTopLists({required bool force}) async {
    final plugin = _selectedPlugin;
    if (plugin == null) {
      return;
    }
    final key = _rankingsCacheKey(plugin.id);
    // A cache hit is a complete answer: paint it and stop, so switching
    // between plugins and tabs is instant and does not touch the plugin
    // runtime at all.
    final cached = _topListsCache[key];
    if (!force && cached != null && cached.isFresh) {
      _topListsRequestId += 1;
      state = state.copyWith(
        topListGroups: cached.value,
        isLoadingTopLists: false,
        topListsError: null,
      );
      return;
    }

    final requestId = ++_topListsRequestId;
    state = state.copyWith(
      topListGroups: force
          ? const <OnlineCollectionGroup>[]
          : cached?.value ?? state.topListGroups,
      isLoadingTopLists: true,
      topListsError: null,
    );
    final result = await _invokeDiscovery(
      plugin,
      (executor, source) =>
          executor.getTopLists(plugin: plugin, source: source),
    );
    if (!ref.mounted || requestId != _topListsRequestId) {
      return;
    }

    switch (result) {
      case Ok<Object?>(:final value):
        final adapted = ref
            .read(musicFreeCompatAdapterProvider)
            .topListGroupsFromPluginValue(
              value,
              pluginId: plugin.id,
              platform: plugin.platform,
            );
        switch (adapted) {
          case Ok<List<OnlineCollectionGroup>>(:final value):
            _topListsCache[key] = _CacheEntry(
              value: value,
              filledAt: _now(),
              pluginSignature: _pluginSignature,
            );
            await _persistCaches();
            state = state.copyWith(
              topListGroups: value,
              isLoadingTopLists: false,
              topListsError: null,
            );
          case Failure<List<OnlineCollectionGroup>>(:final error):
            state = state.copyWith(
              isLoadingTopLists: false,
              topListsError: error,
            );
        }
      case Failure<Object?>(:final error):
        state = state.copyWith(
          isLoadingTopLists: false,
          topListsError: _discoveryError(
            error,
            plugin,
            method: 'getTopLists',
            label: 'rankings',
          ),
        );
    }
  }

  Future<void> _loadHotPlaylists({
    required bool force,
    required bool reloadCatalog,
    OnlineSheetTag? requestedTag,
  }) async {
    final plugin = _selectedPlugin;
    if (plugin == null) {
      return;
    }

    // Tag catalogues change even less often than the playlists themselves, so
    // they are cached by plugin rather than by tag — one request for the
    // catalog serves every tab switch within the TTL.
    final tagKey = _sheetTagsCacheKey(plugin.id);
    final cachedTags = _sheetTagCache[tagKey];
    final useCachedTags = !force && cachedTags != null && cachedTags.isFresh;

    final requestId = ++_hotPlaylistsRequestId;
    // Seeding from the cache before the request starts is what makes the tab
    // switch paint instantly: the spinner never appears, and the only network
    // call left is the page itself.
    final cachedCatalog = useCachedTags ? cachedTags.value : null;
    state = state.copyWith(
      hotPlaylistItems: force
          ? const <OnlineCollectionItem>[]
          : state.hotPlaylistItems,
      hotPlaylistPage: force ? 0 : state.hotPlaylistPage,
      hotPlaylistsIsEnd: force ? false : state.hotPlaylistsIsEnd,
      // A cached catalog means the tags are already here, so only the page is
      // still outstanding.
      sheetTagGroups: cachedCatalog?.groups ?? state.sheetTagGroups,
      pinnedSheetTags: cachedCatalog?.pinned ?? state.pinnedSheetTags,
      isLoadingHotPlaylists: true,
      isLoadingMoreHotPlaylists: false,
      hotPlaylistsError: null,
    );

    List<OnlineSheetTagGroup> tagGroups =
        cachedCatalog?.groups ?? state.sheetTagGroups;
    List<OnlineSheetTag> pinnedTags =
        cachedCatalog?.pinned ?? state.pinnedSheetTags;
    var selectedTag = requestedTag ?? state.selectedSheetTag;

    if (!useCachedTags && (reloadCatalog || tagGroups.isEmpty)) {
      final tagResult = await _invokeDiscovery(
        plugin,
        (executor, source) =>
            executor.getRecommendSheetTags(plugin: plugin, source: source),
      );
      if (!ref.mounted || requestId != _hotPlaylistsRequestId) {
        return;
      }
      switch (tagResult) {
        case Ok<Object?>(:final value):
          final adapted = ref
              .read(musicFreeCompatAdapterProvider)
              .recommendSheetTagsFromPluginValue(value);
          switch (adapted) {
            case Ok<OnlineSheetTagCatalog>(:final value):
              _sheetTagCache[tagKey] = _CacheEntry(
                value: value,
                filledAt: _now(),
                pluginSignature: _pluginSignature,
              );
              await _persistCaches();
              tagGroups = value.groups;
              pinnedTags = value.pinned;
              selectedTag = _resolveTagSelection(
                requestedTag: requestedTag,
                currentTag: state.selectedSheetTag,
                groups: tagGroups,
                pinned: pinnedTags,
              );
            case Failure<OnlineSheetTagCatalog>(:final error):
              state = state.copyWith(
                isLoadingHotPlaylists: false,
                hotPlaylistsError: error,
              );
              return;
          }
        case Failure<Object?>(:final error):
          state = state.copyWith(
            isLoadingHotPlaylists: false,
            hotPlaylistsError: _discoveryError(
              error,
              plugin,
              method: 'getRecommendSheetTags',
              label: 'hot playlist tags',
            ),
          );
          return;
      }
    }

    selectedTag ??= _resolveTagSelection(
      requestedTag: requestedTag,
      currentTag: state.selectedSheetTag,
      groups: tagGroups,
      pinned: pinnedTags,
    );

    // The page itself is cached by (plugin, tag) so switching tabs and coming
    // back does not re-request what the user was just looking at.
    final pageKey = _sheetPageCacheKey(plugin.id, selectedTag.key);
    final cachedPage = _sheetPageCache[pageKey];
    if (!force && cachedPage != null && cachedPage.isFresh) {
      state = state.copyWith(
        sheetTagGroups: tagGroups,
        pinnedSheetTags: pinnedTags,
        selectedSheetTag: selectedTag,
        hotPlaylistItems: cachedPage.value.items,
        hotPlaylistPage: cachedPage.value.page,
        hotPlaylistsIsEnd: cachedPage.value.isEnd,
        isLoadingHotPlaylists: false,
        isLoadingMoreHotPlaylists: false,
        hotPlaylistsError: null,
      );
      return;
    }

    if (!force && cachedPage != null) {
      state = state.copyWith(
        sheetTagGroups: tagGroups,
        pinnedSheetTags: pinnedTags,
        selectedSheetTag: selectedTag,
        hotPlaylistItems: cachedPage.value.items,
        hotPlaylistPage: cachedPage.value.page,
        hotPlaylistsIsEnd: cachedPage.value.isEnd,
      );
    }

    final pageResult = await _invokeDiscovery(
      plugin,
      (executor, source) => executor.getRecommendSheetsByTag(
        plugin: plugin,
        source: source,
        tag: selectedTag!.raw,
        page: 1,
      ),
    );
    if (!ref.mounted || requestId != _hotPlaylistsRequestId) {
      return;
    }

    switch (pageResult) {
      case Ok<Object?>(:final value):
        final adapted = ref
            .read(musicFreeCompatAdapterProvider)
            .musicSheetPageFromPluginValue(
              value,
              pluginId: plugin.id,
              platform: plugin.platform,
              page: 1,
            );
        switch (adapted) {
          case Ok<OnlineCollectionPage>(:final value):
            _sheetPageCache[pageKey] = _CacheEntry(
              value: value,
              filledAt: _now(),
              pluginSignature: _pluginSignature,
            );
            await _persistCaches();
            state = state.copyWith(
              sheetTagGroups: tagGroups,
              pinnedSheetTags: pinnedTags,
              selectedSheetTag: selectedTag,
              hotPlaylistItems: value.items,
              hotPlaylistPage: value.page,
              hotPlaylistsIsEnd: value.isEnd,
              isLoadingHotPlaylists: false,
              hotPlaylistsError: null,
            );
          case Failure<OnlineCollectionPage>(:final error):
            state = state.copyWith(
              sheetTagGroups: tagGroups,
              pinnedSheetTags: pinnedTags,
              selectedSheetTag: selectedTag,
              isLoadingHotPlaylists: false,
              hotPlaylistsError: error,
            );
        }
      case Failure<Object?>(:final error):
        state = state.copyWith(
          sheetTagGroups: tagGroups,
          pinnedSheetTags: pinnedTags,
          selectedSheetTag: selectedTag,
          isLoadingHotPlaylists: false,
          hotPlaylistsError: _discoveryError(
            error,
            plugin,
            method: 'getRecommendSheetsByTag',
            label: 'hot playlists',
          ),
        );
    }
  }

  Future<void> _loadTopListDetail(OnlineCollectionItem collection) async {
    final plugin = _pluginsById[collection.pluginId];
    if (plugin == null) {
      return;
    }

    final cached = _detailCache[collection.uniqueKey];
    if (cached != null) {
      state = state.copyWith(
        detail: cached.value,
        isLoadingDetail: false,
        isLoadingMoreDetail: false,
        detailError: null,
      );
      if (cached.isFresh) {
        return;
      }
    }

    final requestId = ++_detailRequestId;
    state = state.copyWith(
      detail:
          cached?.value ??
          (identical(state.selectedCollectionKey, collection.uniqueKey)
              ? state.detail
              : null),
      isLoadingDetail: true,
      isLoadingMoreDetail: false,
      detailError: null,
    );
    final result = await _invokeDiscovery(
      plugin,
      (executor, source) => executor.getTopListDetail(
        plugin: plugin,
        source: source,
        topList: collection.raw,
      ),
    );
    if (!ref.mounted || requestId != _detailRequestId) {
      return;
    }

    switch (result) {
      case Ok<Object?>(:final value):
        final adapted = ref
            .read(musicFreeCompatAdapterProvider)
            .collectionDetailFromPluginValue(
              value,
              collection: collection,
              page: 1,
              assumeComplete: true,
            );
        switch (adapted) {
          case Ok<OnlineCollectionDetail>(:final value):
            _rememberDetail(value);
            await _persistCaches();
            state = state.copyWith(
              detail: value,
              isLoadingDetail: false,
              detailError: null,
            );
          case Failure<OnlineCollectionDetail>(:final error):
            state = state.copyWith(isLoadingDetail: false, detailError: error);
        }
      case Failure<Object?>(:final error):
        state = state.copyWith(
          isLoadingDetail: false,
          detailError: _discoveryError(
            error,
            plugin,
            method: 'getTopListDetail',
            label: 'ranking detail',
          ),
        );
    }
  }

  Future<void> _loadMusicSheetDetail(
    OnlineCollectionItem collection, {
    required int page,
    required bool append,
  }) async {
    final plugin = _pluginsById[collection.pluginId];
    if (plugin == null) {
      return;
    }

    if (!append) {
      final cached = _detailCache[collection.uniqueKey];
      if (cached != null) {
        state = state.copyWith(
          detail: cached.value,
          isLoadingDetail: false,
          isLoadingMoreDetail: false,
          detailError: null,
        );
        if (cached.isFresh) {
          return;
        }
      }
    }

    final requestId = ++_detailRequestId;
    final cachedDetail = !append ? _detailCache[collection.uniqueKey] : null;
    state = state.copyWith(
      detail: append ? state.detail : cachedDetail?.value,
      isLoadingDetail: !append,
      isLoadingMoreDetail: append,
      detailError: null,
    );
    final result = await _invokeDiscovery(
      plugin,
      (executor, source) => executor.getMusicSheetInfo(
        plugin: plugin,
        source: source,
        sheetItem: collection.raw,
        page: page,
      ),
    );
    if (!ref.mounted || requestId != _detailRequestId) {
      return;
    }

    switch (result) {
      case Ok<Object?>(:final value):
        final adapted = ref
            .read(musicFreeCompatAdapterProvider)
            .collectionDetailFromPluginValue(
              value,
              collection: collection,
              page: page,
            );
        switch (adapted) {
          case Ok<OnlineCollectionDetail>(:final value):
            _rememberDetail(value);
            await _persistCaches();
            if (append && state.detail != null) {
              state = state.copyWith(
                detail: state.detail!.copyWith(
                  collection: value.collection,
                  items: <MusicItem>[...state.detail!.items, ...value.items],
                  page: value.page,
                  isEnd: value.isEnd,
                ),
                isLoadingDetail: false,
                isLoadingMoreDetail: false,
                detailError: null,
              );
            } else {
              state = state.copyWith(
                detail: value,
                isLoadingDetail: false,
                isLoadingMoreDetail: false,
                detailError: null,
              );
            }
          case Failure<OnlineCollectionDetail>(:final error):
            state = state.copyWith(
              isLoadingDetail: false,
              isLoadingMoreDetail: false,
              detailError: error,
            );
        }
      case Failure<Object?>(:final error):
        state = state.copyWith(
          isLoadingDetail: false,
          isLoadingMoreDetail: false,
          detailError: _discoveryError(
            error,
            plugin,
            method: 'getMusicSheetInfo',
            label: 'playlist detail',
          ),
        );
    }
  }

  Future<Result<Object?>> _invokeDiscovery(
    PluginDefinition plugin,
    Future<Result<Object?>> Function(
      PluginDiscoveryExecutor executor,
      String source,
    )
    call,
  ) async {
    try {
      final source = await File(plugin.sourcePath).readAsString();
      if (!ref.mounted) {
        return const Failure(
          AppError(
            code: 'discover.disposed',
            message: 'Discover controller has already been disposed.',
          ),
        );
      }
      return call(ref.read(pluginDiscoveryExecutorProvider), source);
    } catch (error, stackTrace) {
      return Failure(
        AppError(
          code: 'discover.load_failed',
          message: 'Failed to read plugin source for ${plugin.platform}.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  void _rememberDetail(OnlineCollectionDetail detail) {
    _detailCache[detail.collection.uniqueKey] = _CacheEntry(
      value: detail,
      filledAt: _now(),
      pluginSignature: _pluginSignature,
    );
  }

  Future<void> _ensureHydrated() {
    if (_hydrated) {
      return Future<void>.value();
    }
    return _hydration ??= _hydrate();
  }

  Future<void> _hydrate() async {
    try {
      final records = await ref.read(discoverCacheStoreProvider).load();
      _diskRecords
        ..clear()
        ..addEntries(records.map((record) => MapEntry(record.key, record)));
    } catch (_) {
      _diskRecords.clear();
    } finally {
      _hydrated = true;
    }
  }

  void _adoptDiskRecords(String signature) {
    for (final record in _diskRecords.values) {
      if (record.pluginSignature != signature) {
        continue;
      }
      switch (record.kind) {
        case DiscoverCacheKind.topLists:
          _topListsCache[record.key] = _CacheEntry(
            value: record.value as List<OnlineCollectionGroup>,
            filledAt: record.filledAt,
            pluginSignature: record.pluginSignature,
          );
        case DiscoverCacheKind.sheetTags:
          _sheetTagCache[record.key] = _CacheEntry(
            value: record.value as OnlineSheetTagCatalog,
            filledAt: record.filledAt,
            pluginSignature: record.pluginSignature,
          );
        case DiscoverCacheKind.sheetPage:
          _sheetPageCache[record.key] = _CacheEntry(
            value: record.value as OnlineCollectionPage,
            filledAt: record.filledAt,
            pluginSignature: record.pluginSignature,
          );
        case DiscoverCacheKind.detail:
          _detailCache[record.key] = _CacheEntry(
            value: record.value as OnlineCollectionDetail,
            filledAt: record.filledAt,
            pluginSignature: record.pluginSignature,
          );
      }
    }
  }

  Future<void> _persistCaches() async {
    final records = <DiscoverCacheRecord>[
      for (final entry in _topListsCache.entries)
        DiscoverCacheRecord(
          key: entry.key,
          kind: DiscoverCacheKind.topLists,
          value: entry.value.value,
          filledAt: entry.value.filledAt,
          pluginSignature: entry.value.pluginSignature,
        ),
      for (final entry in _sheetTagCache.entries)
        DiscoverCacheRecord(
          key: entry.key,
          kind: DiscoverCacheKind.sheetTags,
          value: entry.value.value,
          filledAt: entry.value.filledAt,
          pluginSignature: entry.value.pluginSignature,
        ),
      for (final entry in _sheetPageCache.entries)
        DiscoverCacheRecord(
          key: entry.key,
          kind: DiscoverCacheKind.sheetPage,
          value: entry.value.value,
          filledAt: entry.value.filledAt,
          pluginSignature: entry.value.pluginSignature,
        ),
      for (final entry in _detailCache.entries)
        DiscoverCacheRecord(
          key: entry.key,
          kind: DiscoverCacheKind.detail,
          value: entry.value.value,
          filledAt: entry.value.filledAt,
          pluginSignature: entry.value.pluginSignature,
        ),
    ];
    await ref.read(discoverCacheStoreProvider).save(records);
  }

  void _clearCaches() {
    _topListsCache.clear();
    _sheetTagCache.clear();
    _sheetPageCache.clear();
    _detailCache.clear();
  }

  OnlineSheetTag _resolveTagSelection({
    required OnlineSheetTag? requestedTag,
    required OnlineSheetTag? currentTag,
    required List<OnlineSheetTagGroup> groups,
    required List<OnlineSheetTag> pinned,
  }) {
    final available = <OnlineSheetTag>[
      ...pinned,
      for (final group in groups) ...group.tags,
    ];
    for (final candidate in <OnlineSheetTag?>[requestedTag, currentTag]) {
      if (candidate == null) {
        continue;
      }
      for (final tag in available) {
        if (tag.key == candidate.key) {
          return tag;
        }
      }
    }
    if (pinned.isNotEmpty) {
      return pinned.first;
    }
    if (available.isNotEmpty) {
      return available.first;
    }
    return OnlineSheetTag.hot;
  }

  AppError _discoveryError(
    AppError error,
    PluginDefinition plugin, {
    required String method,
    required String label,
  }) {
    final message = error.message.toLowerCase();
    // Codes come from the runtime's failure envelope, so matching on them is
    // stable across languages; the message check stays for older surfaces
    // that only carried text.
    final unsupported =
        error.code == 'plugin.method_not_found' ||
        error.code == 'plugin.method_unsupported' ||
        message.contains('plugin method not found') ||
        message.contains('method not found');
    if (unsupported) {
      return AppError(
        code: 'plugin.method_unsupported',
        message:
            '${plugin.platform} plugin does not expose $method, so $label is '
            'unavailable. Check whether the plugin is outdated.',
        cause: error.cause,
        stackTrace: error.stackTrace,
      );
    }
    if (error.code == 'plugin.method_timeout') {
      return AppError(
        code: error.code,
        message: '${plugin.platform} $label request timed out.',
        cause: error.cause,
        stackTrace: error.stackTrace,
      );
    }
    return AppError(
      code: error.code,
      message:
          '${plugin.platform} plugin failed while calling $method. '
          'Check whether the plugin is outdated or broken and still supports '
          '$label. Original error: ${error.message}',
      cause: error.cause,
      stackTrace: error.stackTrace,
    );
  }

  DiscoverState _resetForPlugin(DiscoverState current) {
    return current.copyWith(
      selectedCollection: null,
      topListGroups: const <OnlineCollectionGroup>[],
      isLoadingTopLists: false,
      topListsError: null,
      sheetTagGroups: const <OnlineSheetTagGroup>[],
      pinnedSheetTags: const <OnlineSheetTag>[],
      selectedSheetTag: null,
      hotPlaylistItems: const <OnlineCollectionItem>[],
      hotPlaylistPage: 0,
      hotPlaylistsIsEnd: false,
      isLoadingHotPlaylists: false,
      isLoadingMoreHotPlaylists: false,
      hotPlaylistsError: null,
      detail: null,
      isLoadingDetail: false,
      isLoadingMoreDetail: false,
      detailError: null,
    );
  }

  void _invalidateAllRequests() {
    _topListsRequestId += 1;
    _hotPlaylistsRequestId += 1;
    _detailRequestId += 1;
  }

  PluginDefinition? get _selectedPlugin {
    final selectedPluginId = state.selectedPluginId;
    if (selectedPluginId == null) {
      return null;
    }
    return _pluginsById[selectedPluginId];
  }
}

const _discoverUnset = Object();
