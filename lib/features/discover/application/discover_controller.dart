import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/result/result.dart';
import '../../plugin/application/plugin_providers.dart';
import '../../plugin/domain/plugin_definition.dart';
import '../../plugin/domain/plugin_discovery_executor.dart';
import '../../search/domain/music_item.dart';
import '../domain/online_collection.dart';

final discoverControllerProvider =
    NotifierProvider<DiscoverController, DiscoverState>(DiscoverController.new);

enum DiscoverSurface { rankings, hotPlaylists }

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
    this.surface = DiscoverSurface.rankings,
    this.availableSurfaces = const <DiscoverSurface>[
      DiscoverSurface.rankings,
      DiscoverSurface.hotPlaylists,
    ],
    this.supportsRankingDetail = true,
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
  final DiscoverSurface surface;
  final List<DiscoverSurface> availableSurfaces;
  final bool supportsRankingDetail;
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

  String? get selectedCollectionKey => detail?.collection.uniqueKey;

  DiscoverState copyWith({
    String? pluginSignature,
    Object? selectedPluginId = _discoverUnset,
    DiscoverSurface? surface,
    List<DiscoverSurface>? availableSurfaces,
    bool? supportsRankingDetail,
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
      surface: surface ?? this.surface,
      availableSurfaces: availableSurfaces ?? this.availableSurfaces,
      supportsRankingDetail:
          supportsRankingDetail ?? this.supportsRankingDetail,
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
  int _topListsRequestId = 0;
  int _hotPlaylistsRequestId = 0;
  int _detailRequestId = 0;

  @override
  DiscoverState build() => const DiscoverState();

  Future<void> syncPlugins(List<PluginDefinition> plugins) async {
    final enabled = plugins
        .where((plugin) => plugin.enabled)
        .toList(growable: false);
    _pluginsById
      ..clear()
      ..addEntries(enabled.map((plugin) => MapEntry(plugin.id, plugin)));

    final signature = discoverPluginSignature(enabled);
    if (enabled.isEmpty) {
      _invalidateAllRequests();
      state = DiscoverState(pluginSignature: signature, surface: state.surface);
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
    state = _resetForPlugin(
      state.copyWith(
        pluginSignature: signature,
        selectedPluginId: selectedPluginId,
      ),
    );
    await _loadCurrentSurface(force: true);
  }

  Future<void> selectPlugin(String pluginId) async {
    if (pluginId == state.selectedPluginId ||
        !_pluginsById.containsKey(pluginId)) {
      return;
    }
    _invalidateAllRequests();
    state = _resetForPlugin(state.copyWith(selectedPluginId: pluginId));
    await _loadCurrentSurface(force: true);
  }

  Future<void> selectSurface(DiscoverSurface surface) async {
    if (surface == state.surface) {
      return;
    }
    state = state.copyWith(surface: surface);
    if (_needsLoadForSurface(surface)) {
      await _loadCurrentSurface(force: false);
    }
  }

  Future<void> reloadCurrentSurface() async {
    await _loadCurrentSurface(force: true);
  }

  Future<void> reloadDetail() async {
    final collection = state.detail?.collection;
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
    if (collection.kind == OnlineCollectionKind.topList) {
      await _loadTopListDetail(collection);
      return;
    }
    await _loadMusicSheetDetail(collection, page: 1, append: false);
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

  Future<void> _loadCurrentSurface({required bool force}) async {
    switch (state.surface) {
      case DiscoverSurface.rankings:
        await _loadTopLists(force: force);
        return;
      case DiscoverSurface.hotPlaylists:
        await _loadHotPlaylists(force: force, reloadCatalog: true);
        return;
    }
  }

  bool _needsLoadForSurface(DiscoverSurface surface) {
    return switch (surface) {
      DiscoverSurface.rankings =>
        state.topListGroups.isEmpty && !state.isLoadingTopLists,
      DiscoverSurface.hotPlaylists =>
        state.hotPlaylistItems.isEmpty && !state.isLoadingHotPlaylists,
    };
  }

  Future<void> _loadTopLists({required bool force}) async {
    final plugin = _selectedPlugin;
    if (plugin == null) {
      return;
    }

    final requestId = ++_topListsRequestId;
    state = state.copyWith(
      topListGroups: force
          ? const <OnlineCollectionGroup>[]
          : state.topListGroups,
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

    final requestId = ++_hotPlaylistsRequestId;
    state = state.copyWith(
      hotPlaylistItems: force
          ? const <OnlineCollectionItem>[]
          : state.hotPlaylistItems,
      hotPlaylistPage: force ? 0 : state.hotPlaylistPage,
      hotPlaylistsIsEnd: force ? false : state.hotPlaylistsIsEnd,
      isLoadingHotPlaylists: true,
      isLoadingMoreHotPlaylists: false,
      hotPlaylistsError: null,
    );

    List<OnlineSheetTagGroup> tagGroups = state.sheetTagGroups;
    List<OnlineSheetTag> pinnedTags = state.pinnedSheetTags;
    var selectedTag = requestedTag ?? state.selectedSheetTag;

    if (reloadCatalog || tagGroups.isEmpty) {
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

    final requestId = ++_detailRequestId;
    state = state.copyWith(
      detail: identical(state.selectedCollectionKey, collection.uniqueKey)
          ? state.detail
          : null,
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

    final requestId = ++_detailRequestId;
    state = state.copyWith(
      detail: append ? state.detail : null,
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
    if (message.contains('plugin method not found')) {
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
