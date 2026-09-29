import '../../../features/discover/domain/online_collection.dart';

/// An online collection the user has favourited, stored as a pointer plus a
/// display snapshot.
///
/// Unlike a local playlist, the tracks are not copied: opening a favourite
/// re-asks its plugin for the detail, so a ranking that refreshes daily stays
/// current.
///
/// Named `...Entry` because drift generates a `FavoriteCollection` row class
/// from the table, and two types with one name would silently shadow.
class FavoriteCollectionEntry {
  const FavoriteCollectionEntry({
    required this.collectionKey,
    required this.pluginId,
    required this.platform,
    required this.kind,
    required this.collectionId,
    required this.title,
    required this.raw,
    this.description,
    this.artworkUrl,
    this.addedAt,
  });

  final String collectionKey;
  final String pluginId;
  final String platform;
  final OnlineCollectionKind kind;
  final String collectionId;
  final String title;
  final String? description;
  final String? artworkUrl;
  final Map<String, Object?> raw;
  final DateTime? addedAt;

  /// Rebuilds the browse-time item so the favourite can be opened with the
  /// same code path as any other collection.
  OnlineCollectionItem toCollectionItem() {
    return OnlineCollectionItem(
      id: collectionId,
      pluginId: pluginId,
      platform: platform,
      kind: kind,
      title: title,
      description: description,
      artworkUrl: artworkUrl,
      raw: raw,
    );
  }
}
