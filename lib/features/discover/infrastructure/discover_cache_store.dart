import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/storage/local_file_store.dart';
import '../../search/domain/music_item.dart';
import '../domain/online_collection.dart';

/// The kinds of discovery data that survive an app restart.
enum DiscoverCacheKind { topLists, sheetTags, sheetPage, detail }

class DiscoverCacheRecord {
  const DiscoverCacheRecord({
    required this.key,
    required this.kind,
    required this.value,
    required this.filledAt,
    required this.pluginSignature,
  });

  final String key;
  final DiscoverCacheKind kind;
  final Object value;
  final DateTime filledAt;
  final String pluginSignature;
}

abstract interface class DiscoverCacheStore {
  Future<List<DiscoverCacheRecord>> load();

  Future<void> save(List<DiscoverCacheRecord> records);
}

final discoverCacheStoreProvider = Provider<DiscoverCacheStore>((ref) {
  // Widget tests frequently run in parallel and use repeated plugin ids. The
  // process environment keeps those tests isolated while a real desktop or
  // mobile session gets the durable file-backed store.
  if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) {
    return InMemoryDiscoverCacheStore();
  }
  return FileDiscoverCacheStore(LocalFileStore());
});

class InMemoryDiscoverCacheStore implements DiscoverCacheStore {
  List<DiscoverCacheRecord> _records = const <DiscoverCacheRecord>[];

  @override
  Future<List<DiscoverCacheRecord>> load() async {
    return List<DiscoverCacheRecord>.unmodifiable(_records);
  }

  @override
  Future<void> save(List<DiscoverCacheRecord> records) async {
    _records = List<DiscoverCacheRecord>.unmodifiable(records);
  }
}

class FileDiscoverCacheStore implements DiscoverCacheStore {
  FileDiscoverCacheStore(this._fileStore);

  final LocalFileStore _fileStore;
  Future<void> _writeTail = Future<void>.value();

  @override
  Future<List<DiscoverCacheRecord>> load() async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) {
        return const <DiscoverCacheRecord>[];
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        return const <DiscoverCacheRecord>[];
      }
      final records = decoded['records'];
      if (records is! List) {
        return const <DiscoverCacheRecord>[];
      }
      return <DiscoverCacheRecord>[
        for (final raw in records) ?_decodeRecord(raw),
      ];
    } catch (_) {
      // A corrupt cache is disposable. Returning empty makes the next network
      // request rebuild it rather than taking the feature down.
      return const <DiscoverCacheRecord>[];
    }
  }

  @override
  Future<void> save(List<DiscoverCacheRecord> records) {
    final payload = jsonEncode(<String, Object?>{
      'version': 1,
      'records': <Object?>[for (final record in records) _encodeRecord(record)],
    });
    final next = _enqueueWrite(payload);
    _writeTail = next;
    return next;
  }

  Future<void> _enqueueWrite(String payload) async {
    try {
      await _writeTail;
    } catch (_) {
      // A previous write failing must not permanently poison this queue.
    }
    try {
      final file = await _cacheFile();
      await file.writeAsString(payload, flush: true);
    } catch (_) {
      // Discovery remains usable in memory when the disk is unavailable.
    }
  }

  Future<File> _cacheFile() async {
    final directory = await _fileStore.cacheDirectory();
    return File(p.join(directory.path, 'discover-cache.json'));
  }
}

Object? _encodeRecord(DiscoverCacheRecord record) {
  return <String, Object?>{
    'key': record.key,
    'kind': record.kind.name,
    'filledAt': record.filledAt.millisecondsSinceEpoch,
    'pluginSignature': record.pluginSignature,
    'value': switch (record.kind) {
      DiscoverCacheKind.topLists => _encodeTopLists(
        record.value as List<OnlineCollectionGroup>,
      ),
      DiscoverCacheKind.sheetTags => _encodeTagCatalog(
        record.value as OnlineSheetTagCatalog,
      ),
      DiscoverCacheKind.sheetPage => _encodeSheetPage(
        record.value as OnlineCollectionPage,
      ),
      DiscoverCacheKind.detail => _encodeDetail(
        record.value as OnlineCollectionDetail,
      ),
    },
  };
}

DiscoverCacheRecord? _decodeRecord(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  final map = raw.cast<String, Object?>();
  final key = map['key'];
  final kindName = map['kind'];
  final filledAt = map['filledAt'];
  final pluginSignature = map['pluginSignature'];
  if (key is! String ||
      kindName is! String ||
      filledAt is! int ||
      pluginSignature is! String) {
    return null;
  }
  final kind = DiscoverCacheKind.values
      .where((candidate) => candidate.name == kindName)
      .firstOrNull;
  if (kind == null) {
    return null;
  }
  final value = switch (kind) {
    DiscoverCacheKind.topLists => _decodeTopLists(map['value']),
    DiscoverCacheKind.sheetTags => _decodeTagCatalog(map['value']),
    DiscoverCacheKind.sheetPage => _decodeSheetPage(map['value']),
    DiscoverCacheKind.detail => _decodeDetail(map['value']),
  };
  if (value == null) {
    return null;
  }
  return DiscoverCacheRecord(
    key: key,
    kind: kind,
    value: value,
    filledAt: DateTime.fromMillisecondsSinceEpoch(filledAt),
    pluginSignature: pluginSignature,
  );
}

Object? _encodeTopLists(List<OnlineCollectionGroup> groups) {
  return <Object?>[
    for (final group in groups)
      <String, Object?>{
        'title': group.title,
        'items': <Object?>[
          for (final item in group.items) _encodeCollectionItem(item),
        ],
      },
  ];
}

List<OnlineCollectionGroup>? _decodeTopLists(Object? raw) {
  if (raw is! List) {
    return null;
  }
  final groups = <OnlineCollectionGroup>[];
  for (final rawGroup in raw) {
    if (rawGroup is! Map) {
      return null;
    }
    final group = rawGroup.cast<String, Object?>();
    final title = group['title'];
    final rawItems = group['items'];
    if (title is! String || rawItems is! List) {
      return null;
    }
    final items = <OnlineCollectionItem>[];
    for (final rawItem in rawItems) {
      final item = _decodeCollectionItem(rawItem);
      if (item == null) {
        return null;
      }
      items.add(item);
    }
    groups.add(OnlineCollectionGroup(title: title, items: items));
  }
  return groups;
}

Object? _encodeTagCatalog(OnlineSheetTagCatalog catalog) {
  return <String, Object?>{
    'groups': <Object?>[
      for (final group in catalog.groups)
        <String, Object?>{
          'title': group.title,
          'tags': <Object?>[for (final tag in group.tags) _encodeTag(tag)],
        },
    ],
    'pinned': <Object?>[for (final tag in catalog.pinned) _encodeTag(tag)],
  };
}

OnlineSheetTagCatalog? _decodeTagCatalog(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  final map = raw.cast<String, Object?>();
  final rawGroups = map['groups'];
  final rawPinned = map['pinned'];
  if (rawGroups is! List || rawPinned is! List) {
    return null;
  }
  final groups = <OnlineSheetTagGroup>[];
  for (final rawGroup in rawGroups) {
    if (rawGroup is! Map) {
      return null;
    }
    final group = rawGroup.cast<String, Object?>();
    final title = group['title'];
    final rawTags = group['tags'];
    if (title is! String || rawTags is! List) {
      return null;
    }
    final tags = <OnlineSheetTag>[];
    for (final rawTag in rawTags) {
      final tag = _decodeTag(rawTag);
      if (tag == null) {
        return null;
      }
      tags.add(tag);
    }
    groups.add(OnlineSheetTagGroup(title: title, tags: tags));
  }
  final pinned = <OnlineSheetTag>[];
  for (final rawTag in rawPinned) {
    final tag = _decodeTag(rawTag);
    if (tag == null) {
      return null;
    }
    pinned.add(tag);
  }
  return OnlineSheetTagCatalog(groups: groups, pinned: pinned);
}

Object? _encodeSheetPage(OnlineCollectionPage page) {
  return <String, Object?>{
    'items': <Object?>[
      for (final item in page.items) _encodeCollectionItem(item),
    ],
    'page': page.page,
    'isEnd': page.isEnd,
  };
}

OnlineCollectionPage? _decodeSheetPage(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  final map = raw.cast<String, Object?>();
  final rawItems = map['items'];
  final page = map['page'];
  final isEnd = map['isEnd'];
  if (rawItems is! List || page is! int || isEnd is! bool) {
    return null;
  }
  final items = <OnlineCollectionItem>[];
  for (final rawItem in rawItems) {
    final item = _decodeCollectionItem(rawItem);
    if (item == null) {
      return null;
    }
    items.add(item);
  }
  return OnlineCollectionPage(items: items, page: page, isEnd: isEnd);
}

Object? _encodeDetail(OnlineCollectionDetail detail) {
  return <String, Object?>{
    'collection': _encodeCollectionItem(detail.collection),
    'items': <Object?>[for (final item in detail.items) _encodeMusicItem(item)],
    'page': detail.page,
    'isEnd': detail.isEnd,
  };
}

OnlineCollectionDetail? _decodeDetail(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  final map = raw.cast<String, Object?>();
  final collection = _decodeCollectionItem(map['collection']);
  final rawItems = map['items'];
  final page = map['page'];
  final isEnd = map['isEnd'];
  if (collection == null ||
      rawItems is! List ||
      page is! int ||
      isEnd is! bool) {
    return null;
  }
  final items = <MusicItem>[];
  for (final rawItem in rawItems) {
    final item = _decodeMusicItem(rawItem);
    if (item == null) {
      return null;
    }
    items.add(item);
  }
  return OnlineCollectionDetail(
    collection: collection,
    items: items,
    page: page,
    isEnd: isEnd,
  );
}

Object? _encodeCollectionItem(OnlineCollectionItem item) {
  return <String, Object?>{
    'id': item.id,
    'pluginId': item.pluginId,
    'platform': item.platform,
    'kind': item.kind.name,
    'title': item.title,
    'description': item.description,
    'artworkUrl': item.artworkUrl,
    'raw': _jsonValue(item.raw),
  };
}

OnlineCollectionItem? _decodeCollectionItem(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  final map = raw.cast<String, Object?>();
  final id = map['id'];
  final pluginId = map['pluginId'];
  final platform = map['platform'];
  final kindName = map['kind'];
  final title = map['title'];
  if (id is! String ||
      pluginId is! String ||
      platform is! String ||
      kindName is! String ||
      title is! String) {
    return null;
  }
  final kind = OnlineCollectionKind.values
      .where((candidate) => candidate.name == kindName)
      .firstOrNull;
  if (kind == null) {
    return null;
  }
  return OnlineCollectionItem(
    id: id,
    pluginId: pluginId,
    platform: platform,
    kind: kind,
    title: title,
    description: map['description'] as String?,
    artworkUrl: map['artworkUrl'] as String?,
    raw: _jsonMap(map['raw']),
  );
}

Object? _encodeMusicItem(MusicItem item) {
  return <String, Object?>{
    'id': item.id,
    'pluginId': item.pluginId,
    'platform': item.platform,
    'title': item.title,
    'artist': item.artist,
    'album': item.album,
    'durationMs': item.duration?.inMilliseconds,
    'artworkUrl': item.artworkUrl,
    'raw': _jsonValue(item.raw),
  };
}

MusicItem? _decodeMusicItem(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  final map = raw.cast<String, Object?>();
  final id = map['id'];
  final platform = map['platform'];
  final title = map['title'];
  if (id is! String || platform is! String || title is! String) {
    return null;
  }
  final durationMs = map['durationMs'];
  return MusicItem(
    id: id,
    pluginId: map['pluginId'] as String?,
    platform: platform,
    title: title,
    artist: map['artist'] as String?,
    album: map['album'] as String?,
    duration: durationMs is int ? Duration(milliseconds: durationMs) : null,
    artworkUrl: map['artworkUrl'] as String?,
    raw: _jsonMap(map['raw']),
  );
}

Object? _encodeTag(OnlineSheetTag tag) {
  return <String, Object?>{
    'id': tag.id,
    'title': tag.title,
    'raw': _jsonValue(tag.raw),
  };
}

OnlineSheetTag? _decodeTag(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  final map = raw.cast<String, Object?>();
  final id = map['id'];
  final title = map['title'];
  if (id is! String || title is! String) {
    return null;
  }
  return OnlineSheetTag(id: id, title: title, raw: _jsonMap(map['raw']));
}

Object? _jsonValue(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is List) {
    return <Object?>[for (final entry in value) _jsonValue(entry)];
  }
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries)
        entry.key.toString(): _jsonValue(entry.value),
    };
  }
  return value.toString();
}

Map<String, Object?> _jsonMap(Object? raw) {
  if (raw is! Map) {
    return const <String, Object?>{};
  }
  return <String, Object?>{
    for (final entry in raw.entries) entry.key.toString(): entry.value,
  };
}
