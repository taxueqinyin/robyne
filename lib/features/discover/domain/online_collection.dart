import '../../search/domain/music_item.dart';

enum OnlineCollectionKind { topList, musicSheet }

class OnlineCollectionItem {
  const OnlineCollectionItem({
    required this.id,
    required this.pluginId,
    required this.platform,
    required this.kind,
    required this.title,
    required this.raw,
    this.description,
    this.artworkUrl,
  });

  final String id;
  final String pluginId;
  final String platform;
  final OnlineCollectionKind kind;
  final String title;
  final String? description;
  final String? artworkUrl;
  final Map<String, Object?> raw;

  String get uniqueKey => '$pluginId:${kind.name}:$id';

  OnlineCollectionItem copyWith({
    String? id,
    String? pluginId,
    String? platform,
    OnlineCollectionKind? kind,
    String? title,
    Object? description = _unset,
    Object? artworkUrl = _unset,
    Map<String, Object?>? raw,
  }) {
    return OnlineCollectionItem(
      id: id ?? this.id,
      pluginId: pluginId ?? this.pluginId,
      platform: platform ?? this.platform,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      description: identical(description, _unset)
          ? this.description
          : description as String?,
      artworkUrl: identical(artworkUrl, _unset)
          ? this.artworkUrl
          : artworkUrl as String?,
      raw: raw ?? this.raw,
    );
  }
}

class OnlineCollectionGroup {
  const OnlineCollectionGroup({required this.title, required this.items});

  final String title;
  final List<OnlineCollectionItem> items;
}

class OnlineSheetTag {
  const OnlineSheetTag({
    required this.id,
    required this.title,
    required this.raw,
  });

  final String id;
  final String title;
  final Map<String, Object?> raw;

  String get key => '$id:$title';

  static const OnlineSheetTag hot = OnlineSheetTag(
    id: 'hot',
    title: 'Hot',
    raw: <String, Object?>{},
  );
}

class OnlineSheetTagGroup {
  const OnlineSheetTagGroup({required this.title, required this.tags});

  final String title;
  final List<OnlineSheetTag> tags;
}

class OnlineSheetTagCatalog {
  const OnlineSheetTagCatalog({required this.groups, required this.pinned});

  final List<OnlineSheetTagGroup> groups;
  final List<OnlineSheetTag> pinned;
}

class OnlineCollectionPage {
  const OnlineCollectionPage({
    required this.items,
    required this.page,
    required this.isEnd,
  });

  final List<OnlineCollectionItem> items;
  final int page;
  final bool isEnd;
}

class OnlineCollectionDetail {
  const OnlineCollectionDetail({
    required this.collection,
    required this.items,
    required this.page,
    required this.isEnd,
  });

  final OnlineCollectionItem collection;
  final List<MusicItem> items;
  final int page;
  final bool isEnd;

  OnlineCollectionDetail copyWith({
    OnlineCollectionItem? collection,
    List<MusicItem>? items,
    int? page,
    bool? isEnd,
  }) {
    return OnlineCollectionDetail(
      collection: collection ?? this.collection,
      items: items ?? this.items,
      page: page ?? this.page,
      isEnd: isEnd ?? this.isEnd,
    );
  }
}

const _unset = Object();
