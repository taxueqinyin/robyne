import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/database/app_database.dart';
import 'package:robyne/features/search/domain/search_history_entry.dart';
import 'package:robyne/features/search/infrastructure/search_history_repository.dart';

void main() {
  late AppDatabase database;
  late SearchHistoryRepository repository;

  setUp(() {
    database = AppDatabase.memory();
    repository = SearchHistoryRepository(database: database);
    addTearDown(database.close);
  });

  test('history starts empty', () async {
    expect(await repository.load(), isEmpty);
  });

  test('remember stores a keyword and returns it newest first', () async {
    final afterFirst = await repository.remember('moonhalo');
    expect(afterFirst.map((e) => e.keyword), <String>['moonhalo']);

    final afterSecond = await repository.remember('jay chou');
    expect(
      afterSecond.map((e) => e.keyword),
      <String>['jay chou', 'moonhalo'],
    );
  });

  test('re-searching a keyword moves it to the top without duplicating', () async {
    await repository.remember('moonhalo');
    await repository.remember('jay chou');

    final result = await repository.remember('moonhalo');

    expect(result.length, 2);
    expect(result.first.keyword, 'moonhalo');
  });

  test('blank keywords are ignored', () async {
    final result = await repository.remember('   ');
    expect(result, isEmpty);
  });

  test('remove drops only the named keyword', () async {
    await repository.remember('moonhalo');
    await repository.remember('jay chou');

    final result = await repository.remove('moonhalo');

    expect(result.map((e) => e.keyword), <String>['jay chou']);
  });

  test('clear removes everything', () async {
    await repository.remember('moonhalo');
    await repository.remember('jay chou');

    expect(await repository.clear(), isEmpty);
    // And it stays gone — the row is deleted, not just hidden.
    expect(await repository.load(), isEmpty);
  });

  test('history is capped at the configured maximum', () async {
    for (var i = 0; i < SearchHistoryRepository.maxEntries + 5; i += 1) {
      await repository.remember('keyword-$i');
    }

    final result = await repository.load();
    expect(result.length, SearchHistoryRepository.maxEntries);
    // The newest survives; the oldest is dropped.
    expect(result.first.keyword, 'keyword-${SearchHistoryRepository.maxEntries + 4}');
  });

  test('history round-trips through a fresh repository instance', () async {
    await repository.remember('moonhalo');

    // A new instance reads the same database, which is what happens across
    // app launches.
    final reloaded = SearchHistoryRepository(database: database);
    expect((await reloaded.load()).map((e) => e.keyword), <String>['moonhalo']);
  });

  test('corrupt stored JSON degrades to empty rather than throwing', () async {
    await database
        .into(database.appSettings)
        .insert(
          AppSettingsCompanion(key: const Value('search.history'), value: const Value('{not json')),
        );

    expect(await repository.load(), isEmpty);
  });

  test('entries keep the time they were searched', () async {
    final before = DateTime.now();
    final result = await repository.remember('moonhalo');

    final entry = result.single;
    expect(
      entry.searchedAt.isBefore(before.add(const Duration(seconds: 5))),
      isTrue,
    );
    expect(entry.searchedAt.isAfter(before.subtract(const Duration(seconds: 5))), isTrue);
  });

  test('entry equality is by keyword and time', () {
    final at = DateTime(2026);
    expect(
      SearchHistoryEntry(keyword: 'a', searchedAt: at),
      SearchHistoryEntry(keyword: 'a', searchedAt: at),
    );
    expect(
      SearchHistoryEntry(keyword: 'a', searchedAt: at),
      isNot(SearchHistoryEntry(keyword: 'b', searchedAt: at)),
    );
  });
}
