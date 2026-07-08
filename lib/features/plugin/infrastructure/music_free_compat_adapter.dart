import '../../../core/errors/app_error.dart';
import '../../../core/result/result.dart';
import '../../discover/domain/online_collection.dart';
import '../../player/domain/media_source.dart';
import '../../search/domain/music_item.dart';
import '../../search/domain/search_result.dart';
import '../domain/plugin_definition.dart';

class MusicFreeCompatAdapter {
  Result<PluginDefinition> definitionFromRuntimeMetadata({
    required String sourcePath,
    required Map<String, Object?> metadata,
    bool enabled = true,
    DateTime? installedAt,
  }) {
    final platform = _stringValue(metadata['platform']);
    if (platform == null || platform.isEmpty) {
      return const Failure(
        AppError(
          code: 'plugin.invalid_exports',
          message: 'Plugin export is missing a non-empty platform.',
        ),
      );
    }

    final now = DateTime.now();
    return Ok(
      PluginDefinition(
        id: _pluginId(platform, sourcePath),
        platform: platform,
        version: _stringValue(metadata['version']),
        author: _stringValue(metadata['author']),
        description: _stringValue(metadata['description']),
        sourcePath: sourcePath,
        enabled: enabled,
        installedAt: installedAt ?? now,
        updatedAt: now,
        supportedSearchTypes: _stringList(metadata['supportedSearchType']),
        userVariables: _mapList(metadata['userVariables']),
      ),
    );
  }

  Result<SearchResult> searchResultFromPluginValue(
    Object? value, {
    required String pluginId,
    required String platform,
    required int page,
  }) {
    if (value is! Map) {
      return const Failure(
        AppError(
          code: 'search.failed',
          message: 'Plugin search returned a non-object result.',
        ),
      );
    }

    final raw = _objectMap(value);
    final rawItems = _listValue(raw['data']) ?? _listValue(raw['list']);
    if (rawItems == null) {
      return const Failure(
        AppError(
          code: 'search.failed',
          message: 'Plugin search result does not contain data or list.',
        ),
      );
    }

    final items = <MusicItem>[];
    for (final item in rawItems) {
      if (item is Map) {
        final rawItem = _objectMap(item);
        final musicItem = musicItemFromRaw(
          rawItem,
          pluginId: pluginId,
          platform: platform,
        );
        if (musicItem != null) {
          items.add(musicItem);
        }
      }
    }

    return Ok(
      SearchResult(
        items: items,
        page: _intValue(raw['page']) ?? page,
        isEnd: _boolValue(raw['isEnd']) ?? _isEndFromTotal(raw, page, items),
        raw: raw,
      ),
    );
  }

  MusicItem? musicItemFromRaw(
    Map<String, Object?> raw, {
    required String pluginId,
    required String platform,
  }) {
    final id =
        _stringValue(raw['id']) ??
        _stringValue(raw['mid']) ??
        _stringValue(raw['aid']) ??
        _stringValue(raw['bvid']);
    final title = _stringValue(raw['title']) ?? _stringValue(raw['name']);

    if (id == null || id.isEmpty || title == null || title.isEmpty) {
      return null;
    }

    return MusicItem(
      id: id,
      pluginId: pluginId,
      platform: platform,
      title: title,
      artist: _stringValue(raw['artist']) ?? _stringValue(raw['author']),
      album: _stringValue(raw['album']),
      duration: _durationValue(raw['duration']),
      artworkUrl:
          _stringValue(raw['artwork']) ??
          _stringValue(raw['artworkUrl']) ??
          _stringValue(raw['cover']) ??
          _stringValue(raw['pic']) ??
          _stringValue(raw['coverImg']),
      raw: raw,
    );
  }

  Result<MediaSource> mediaSourceFromPluginValue(Object? value) {
    if (value == null || value == false) {
      return const Failure(
        AppError(
          code: 'player.media_source_empty',
          message: 'Plugin did not return a playable media source.',
        ),
      );
    }

    if (value is String && value.isNotEmpty) {
      return Ok(MediaSource(url: value));
    }

    if (value is! Map) {
      return const Failure(
        AppError(
          code: 'player.unsupported_source',
          message: 'Plugin media source result has an unsupported shape.',
        ),
      );
    }

    final raw = _objectMap(value);
    final url = _stringValue(raw['url']) ?? _stringValue(raw['src']);
    if (url == null || url.isEmpty) {
      return const Failure(
        AppError(
          code: 'player.media_source_empty',
          message: 'Plugin media source result is missing url.',
        ),
      );
    }

    return Ok(
      MediaSource(
        url: url,
        headers: _stringMap(raw['headers']),
        quality: _stringValue(raw['quality']),
        mimeType: _stringValue(raw['mimeType']),
        raw: raw,
      ),
    );
  }

  Result<String> lyricFromPluginValue(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return Ok(value);
    }
    if (value is! Map) {
      return const Failure(
        AppError(
          code: 'lyric.empty',
          message: 'Plugin did not return lyric text.',
        ),
      );
    }

    final raw = _objectMap(value);
    final lyric =
        _stringValue(raw['rawLrc']) ??
        _stringValue(raw['lrc']) ??
        _stringValue(raw['lyric']) ??
        _stringValue(raw['lyrics']) ??
        _stringValue(raw['text']);
    if (lyric == null || lyric.trim().isEmpty) {
      return const Failure(
        AppError(code: 'lyric.empty', message: 'Plugin lyric result is empty.'),
      );
    }
    return Ok(lyric);
  }

  Result<List<OnlineCollectionGroup>> topListGroupsFromPluginValue(
    Object? value, {
    required String pluginId,
    required String platform,
  }) {
    final groups = _collectionGroupsFromValue(
      value,
      pluginId: pluginId,
      platform: platform,
      kind: OnlineCollectionKind.topList,
    );
    if (groups == null) {
      return const Failure(
        AppError(
          code: 'discover.top_lists_failed',
          message: 'Plugin top lists result has an unsupported shape.',
        ),
      );
    }
    return Ok(groups);
  }

  Result<OnlineSheetTagCatalog> recommendSheetTagsFromPluginValue(
    Object? value,
  ) {
    if (value is List) {
      final groups = _sheetTagGroupsFromList(value.cast<Object?>());
      return Ok(OnlineSheetTagCatalog(groups: groups, pinned: const []));
    }
    if (value is! Map) {
      return const Failure(
        AppError(
          code: 'discover.sheet_tags_failed',
          message: 'Plugin sheet tag result has an unsupported shape.',
        ),
      );
    }

    final raw = _objectMap(value);
    return Ok(
      OnlineSheetTagCatalog(
        groups: _sheetTagGroupsFromList(_listValue(raw['data']) ?? const []),
        pinned: _sheetTagsFromList(_listValue(raw['pinned']) ?? const []),
      ),
    );
  }

  Result<OnlineCollectionPage> musicSheetPageFromPluginValue(
    Object? value, {
    required String pluginId,
    required String platform,
    required int page,
  }) {
    if (value is! Map) {
      return const Failure(
        AppError(
          code: 'discover.music_sheets_failed',
          message: 'Plugin music sheet result has an unsupported shape.',
        ),
      );
    }

    final raw = _objectMap(value);
    final rawItems = _listValue(raw['data']) ?? _listValue(raw['list']);
    if (rawItems == null) {
      return const Failure(
        AppError(
          code: 'discover.music_sheets_failed',
          message: 'Plugin music sheet result does not contain data or list.',
        ),
      );
    }

    final items = <OnlineCollectionItem>[];
    for (var index = 0; index < rawItems.length; index += 1) {
      final rawItem = rawItems[index];
      if (rawItem is! Map) {
        continue;
      }
      final item = _collectionItemFromRaw(
        _objectMap(rawItem),
        pluginId: pluginId,
        platform: platform,
        kind: OnlineCollectionKind.musicSheet,
        fallbackId: 'sheet-$page-$index',
      );
      if (item != null) {
        items.add(item);
      }
    }

    return Ok(
      OnlineCollectionPage(
        items: items,
        page: _intValue(raw['page']) ?? page,
        isEnd:
            _boolValue(raw['isEnd']) ??
            _isEndFromTotalCount(raw, page, items.length),
      ),
    );
  }

  Result<OnlineCollectionDetail> collectionDetailFromPluginValue(
    Object? value, {
    required OnlineCollectionItem collection,
    required int page,
    bool assumeComplete = false,
  }) {
    List<Object?>? rawItems;
    Map<String, Object?> raw = const <String, Object?>{};
    if (value is List) {
      rawItems = value.cast<Object?>();
    } else if (value is Map) {
      raw = _objectMap(value);
      rawItems =
          _listValue(raw['musicList']) ??
          _listValue(raw['data']) ??
          _listValue(raw['list']);
    }
    if (rawItems == null) {
      return const Failure(
        AppError(
          code: 'discover.collection_detail_failed',
          message: 'Plugin collection detail result is missing a music list.',
        ),
      );
    }

    final items = <MusicItem>[];
    for (final rawItem in rawItems) {
      if (rawItem is! Map) {
        continue;
      }
      final item = musicItemFromRaw(
        _objectMap(rawItem),
        pluginId: collection.pluginId,
        platform: collection.platform,
      );
      if (item != null) {
        items.add(item);
      }
    }

    final metadata = switch (raw['topListItem']) {
      Map<dynamic, dynamic> value => _objectMap(value),
      _ => switch (raw['sheetItem']) {
        Map<dynamic, dynamic> value => _objectMap(value),
        _ => null,
      },
    };

    return Ok(
      OnlineCollectionDetail(
        collection: metadata == null
            ? collection
            : _collectionItemFromRaw(
                    metadata,
                    pluginId: collection.pluginId,
                    platform: collection.platform,
                    kind: collection.kind,
                    fallbackId: collection.id,
                  ) ??
                  collection,
        items: items,
        page: _intValue(raw['page']) ?? page,
        isEnd:
            _boolValue(raw['isEnd']) ??
            (assumeComplete
                ? true
                : _isEndFromTotalCount(raw, page, items.length)),
      ),
    );
  }

  static String _pluginId(String platform, String sourcePath) {
    final normalized = sourcePath.replaceAll(r'\', '/');
    return '$platform@$normalized';
  }

  static String? _stringValue(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value;
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    return null;
  }

  static int? _intValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static bool? _boolValue(Object? value) {
    if (value is bool) {
      return value;
    }
    return null;
  }

  static Duration? _durationValue(Object? value) {
    final numeric = _intValue(value);
    if (numeric == null) {
      return null;
    }
    if (numeric > 100000) {
      return Duration(milliseconds: numeric);
    }
    return Duration(seconds: numeric);
  }

  static List<Object?>? _listValue(Object? value) {
    if (value is List) {
      return value.cast<Object?>();
    }
    return null;
  }

  static List<String> _stringList(Object? value) {
    return (_listValue(value) ?? const <Object?>[])
        .map(_stringValue)
        .whereType<String>()
        .toList(growable: false);
  }

  static List<Map<String, Object?>> _mapList(Object? value) {
    return (_listValue(value) ?? const <Object?>[])
        .whereType<Map>()
        .map(_objectMap)
        .toList(growable: false);
  }

  static Map<String, String> _stringMap(Object? value) {
    if (value is! Map) {
      return const <String, String>{};
    }
    return value.map(
      (key, dynamic mapValue) =>
          MapEntry(key.toString(), _stringValue(mapValue) ?? ''),
    );
  }

  static Map<String, Object?> _objectMap(Map<dynamic, dynamic> value) {
    return value.map(
      (key, dynamic mapValue) => MapEntry(key.toString(), mapValue as Object?),
    );
  }

  static List<OnlineCollectionGroup>? _collectionGroupsFromValue(
    Object? value, {
    required String pluginId,
    required String platform,
    required OnlineCollectionKind kind,
  }) {
    final rawGroups = _listValue(value);
    if (rawGroups == null) {
      return null;
    }

    final groups = <OnlineCollectionGroup>[];
    for (var groupIndex = 0; groupIndex < rawGroups.length; groupIndex += 1) {
      final rawGroup = rawGroups[groupIndex];
      if (rawGroup is! Map) {
        continue;
      }
      final group = _objectMap(rawGroup);
      final rawItems = _listValue(group['data']) ?? _listValue(group['list']);
      if (rawItems == null || rawItems.isEmpty) {
        continue;
      }
      final items = <OnlineCollectionItem>[];
      for (var itemIndex = 0; itemIndex < rawItems.length; itemIndex += 1) {
        final rawItem = rawItems[itemIndex];
        if (rawItem is! Map) {
          continue;
        }
        final item = _collectionItemFromRaw(
          _objectMap(rawItem),
          pluginId: pluginId,
          platform: platform,
          kind: kind,
          fallbackId: '$groupIndex-$itemIndex',
        );
        if (item != null) {
          items.add(item);
        }
      }
      if (items.isEmpty) {
        continue;
      }
      groups.add(
        OnlineCollectionGroup(
          title:
              _stringValue(group['title']) ??
              _stringValue(group['name']) ??
              'Untitled',
          items: items,
        ),
      );
    }
    return groups;
  }

  static OnlineCollectionItem? _collectionItemFromRaw(
    Map<String, Object?> raw, {
    required String pluginId,
    required String platform,
    required OnlineCollectionKind kind,
    required String fallbackId,
  }) {
    final id =
        _stringValue(raw['id']) ??
        _stringValue(raw['rid']) ??
        _stringValue(raw['sourceid']) ??
        fallbackId;
    final title =
        _stringValue(raw['title']) ??
        _stringValue(raw['name']) ??
        _stringValue(raw['subject']) ??
        id;
    if (title.isEmpty) {
      return null;
    }

    return OnlineCollectionItem(
      id: id,
      pluginId: pluginId,
      platform: platform,
      kind: kind,
      title: title,
      description:
          _stringValue(raw['description']) ??
          _stringValue(raw['intro']) ??
          _stringValue(raw['artist']) ??
          _stringValue(raw['uname']),
      artworkUrl:
          _stringValue(raw['artwork']) ??
          _stringValue(raw['artworkUrl']) ??
          _stringValue(raw['cover']) ??
          _stringValue(raw['coverImg']) ??
          _stringValue(raw['pic']) ??
          _stringValue(raw['img']),
      raw: raw,
    );
  }

  static List<OnlineSheetTagGroup> _sheetTagGroupsFromList(
    List<Object?> value,
  ) {
    final groups = <OnlineSheetTagGroup>[];
    for (final rawGroup in value) {
      if (rawGroup is! Map) {
        continue;
      }
      final group = _objectMap(rawGroup);
      final tags = _sheetTagsFromList(_listValue(group['data']) ?? const []);
      if (tags.isEmpty) {
        continue;
      }
      groups.add(
        OnlineSheetTagGroup(
          title:
              _stringValue(group['title']) ??
              _stringValue(group['name']) ??
              'Untitled',
          tags: tags,
        ),
      );
    }
    return groups;
  }

  static List<OnlineSheetTag> _sheetTagsFromList(List<Object?> value) {
    final tags = <OnlineSheetTag>[];
    for (final rawTag in value) {
      if (rawTag is! Map) {
        continue;
      }
      final tag = _objectMap(rawTag);
      final title =
          _stringValue(tag['title']) ??
          _stringValue(tag['name']) ??
          _stringValue(tag['digest']);
      if (title == null || title.isEmpty) {
        continue;
      }
      tags.add(
        OnlineSheetTag(
          id: _stringValue(tag['id']) ?? title,
          title: title,
          raw: tag,
        ),
      );
    }
    return tags;
  }

  static bool _isEndFromTotal(
    Map<String, Object?> raw,
    int page,
    List<MusicItem> items,
  ) {
    return _isEndFromTotalCount(raw, page, items.length);
  }

  static bool _isEndFromTotalCount(
    Map<String, Object?> raw,
    int page,
    int count,
  ) {
    final total =
        _intValue(raw['total']) ??
        _intValue(raw['totalCount']) ??
        _intValue(raw['numResults']);
    if (total == null || count == 0) {
      return true;
    }
    return total <= page * count;
  }
}
