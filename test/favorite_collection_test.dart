import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/database/app_database.dart';
import 'package:robyne/features/discover/domain/online_collection.dart';
import 'package:robyne/features/discover/infrastructure/favorite_collection_repository.dart';

/// Guards the collection-favourite store: a favourite is a pointer plus a
/// display snapshot, so it must round-trip the plugin payload and never leak
/// between collections.
void main() {
  late AppDatabase database;
  late FavoriteCollectionRepository repository;

  setUp(() {
    database = AppDatabase.memory();
    repository = FavoriteCollectionRepository(database);
    addTearDown(database.close);
  });

  OnlineCollectionItem collection(String id) {
    return OnlineCollectionItem(
      id: id,
      pluginId: 'plugin-a',
      platform: '元力QQ',
      kind: OnlineCollectionKind.musicSheet,
      title: 'Sheet $id',
      description: 'desc $id',
      artworkUrl: 'https://example.com/$id.jpg',
      raw: <String, Object?>{'id': id, 'title': 'Sheet $id'},
    );
  }

  test('toggle stores, reports and removes a favourite', () async {
    final item = collection('one');
    expect(await repository.isFavorite(item.uniqueKey), isFalse);

    await repository.toggle(item);
    expect(await repository.isFavorite(item.uniqueKey), isTrue);

    final stored = (await repository.listFavorites()).single;
    expect(stored.title, 'Sheet one');
    expect(stored.artworkUrl, 'https://example.com/one.jpg');
    // The plugin payload must survive, otherwise re-opening the favourite
    // could not re-fetch its tracks.
    expect(stored.raw['id'], 'one');

    await repository.toggle(item);
    expect(await repository.isFavorite(item.uniqueKey), isFalse);
    expect(await repository.listFavorites(), isEmpty);
  });

  test('two collections keep separate favourite keys', () async {
    await repository.add(collection('one'));
    await repository.add(collection('two'));

    expect(await repository.listFavorites(), hasLength(2));
    await repository.remove(collection('one').uniqueKey);

    final remaining = await repository.listFavorites();
    expect(remaining, hasLength(1));
    expect(remaining.single.title, 'Sheet two');
  });
}
