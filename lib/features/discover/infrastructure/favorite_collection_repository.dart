import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../features/plugin/application/plugin_providers.dart'
    show appDatabaseProvider;
import '../domain/favorite_collection.dart';
import '../domain/online_collection.dart';

final favoriteCollectionRepositoryProvider =
    Provider<FavoriteCollectionRepository>((ref) {
      return FavoriteCollectionRepository(ref.watch(appDatabaseProvider));
    });

/// Whether one collection is favourited.
///
/// Per-key rather than one whole-list stream so toggling one card does not
/// rebuild every other card's subscription.
final favoriteCollectionKeysProvider = StreamProvider.family<bool, String>((
  ref,
  collectionKey,
) {
  return ref
      .watch(favoriteCollectionRepositoryProvider)
      .watchIsFavorite(collectionKey);
});

/// Every favourited collection, newest first.
final favoriteCollectionsProvider =
    StreamProvider<List<FavoriteCollectionEntry>>((ref) {
      return ref.watch(favoriteCollectionRepositoryProvider).watchFavorites();
    });

/// Rail-friendly snapshot of the favourited collections.
///
/// The live stream stays the source for surfaces that need database-driven
/// refresh. The shell uses a one-shot snapshot instead, because a long-lived
/// drift stream in chrome keeps a query subscription alive for the whole app
/// session and makes widget tests leave pending timers behind.
final favoriteCollectionsSnapshotProvider =
    FutureProvider<List<FavoriteCollectionEntry>>((ref) {
      return ref.watch(favoriteCollectionRepositoryProvider).listFavorites();
    });

/// Stores which online collections the user has favourited.
///
/// Deliberately thin: it holds the identity needed to re-open a collection and
/// the snapshot needed to render it, and nothing else. Track lists belong to
/// the plugin.
class FavoriteCollectionRepository {
  const FavoriteCollectionRepository(this._database);

  final AppDatabase _database;

  Future<List<FavoriteCollectionEntry>> listFavorites() async {
    final rows =
        await (_database.select(_database.favoriteCollections)
              ..orderBy(<OrderingTerm Function($FavoriteCollectionsTable)>[
                (table) => OrderingTerm.desc(table.addedAt),
              ]))
            .get();
    return rows.map(_fromRow).toList(growable: false);
  }

  Stream<List<FavoriteCollectionEntry>> watchFavorites() {
    return (_database.select(_database.favoriteCollections)
          ..orderBy(<OrderingTerm Function($FavoriteCollectionsTable)>[
            (table) => OrderingTerm.desc(table.addedAt),
          ]))
        .watch()
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  Future<bool> isFavorite(String collectionKey) async {
    final row =
        await (_database.select(_database.favoriteCollections)
              ..where((table) => table.collectionKey.equals(collectionKey)))
            .getSingleOrNull();
    return row != null;
  }

  Stream<bool> watchIsFavorite(String collectionKey) {
    return (_database.select(_database.favoriteCollections)
          ..where((table) => table.collectionKey.equals(collectionKey)))
        .watch()
        .map((rows) => rows.isNotEmpty);
  }

  Future<void> add(OnlineCollectionItem item) async {
    await _database
        .into(_database.favoriteCollections)
        .insert(_companion(item), mode: InsertMode.insertOrReplace);
  }

  Future<void> remove(String collectionKey) async {
    await (_database.delete(
      _database.favoriteCollections,
    )..where((table) => table.collectionKey.equals(collectionKey))).go();
  }

  Future<void> toggle(OnlineCollectionItem item) async {
    if (await isFavorite(item.uniqueKey)) {
      await remove(item.uniqueKey);
      return;
    }
    await add(item);
  }

  static FavoriteCollectionsCompanion _companion(OnlineCollectionItem item) {
    return FavoriteCollectionsCompanion.insert(
      collectionKey: item.uniqueKey,
      pluginId: item.pluginId,
      platform: item.platform,
      kind: item.kind.name,
      collectionId: item.id,
      title: item.title,
      description: Value(item.description),
      artworkUrl: Value(item.artworkUrl),
      rawJson: jsonEncode(item.raw),
    );
  }

  static FavoriteCollectionEntry _fromRow(FavoriteCollection row) {
    return FavoriteCollectionEntry(
      collectionKey: row.collectionKey,
      pluginId: row.pluginId,
      platform: row.platform,
      kind: OnlineCollectionKind.values.firstWhere(
        (kind) => kind.name == row.kind,
        orElse: () => OnlineCollectionKind.musicSheet,
      ),
      collectionId: row.collectionId,
      title: row.title,
      description: row.description,
      artworkUrl: row.artworkUrl,
      raw: _decodeRaw(row.rawJson),
      addedAt: row.addedAt,
    );
  }

  /// A corrupt payload must not take the whole favourites list down with it.
  static Map<String, Object?> _decodeRaw(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map<String, Object?>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.cast<String, Object?>();
      }
    } catch (_) {
      // fall through to the empty payload below
    }
    return const <String, Object?>{};
  }
}
