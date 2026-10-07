import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/features/search/application/search_history_controller.dart';
import 'package:robyne/features/search/application/search_history_providers.dart';
import 'package:robyne/features/search/domain/search_history_entry.dart';
import 'package:robyne/features/search/infrastructure/search_history_repository.dart';

void main() {
  test('a write finishing after disposal does not throw', () async {
    final container = ProviderContainer(
      overrides: [
        searchHistoryRepositoryProvider.overrideWithValue(
          _SlowSearchHistoryRepository(),
        ),
      ],
    );

    // Start a write, then dispose the container before it resolves — exactly
    // what happens when the user leaves the search page mid-search.
    // Reading the provider starts `build()`, whose async load is in flight.
    container.read(searchHistoryControllerProvider);
    final future = container
        .read(searchHistoryControllerProvider.notifier)
        .remember('moonhalo');
    // Let the write reach its await, so disposal genuinely happens mid-flight
    // rather than before the work starts.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    container.dispose();
    await future;

    // Reaching this line is the assertion: assigning to `state` after
    // disposal used to throw "Cannot use the Ref ... after it has been
    // disposed", which failed every search that outlived the page.
  });

  test('a completed write publishes the new history', () async {
    final container = ProviderContainer(
      overrides: [
        searchHistoryRepositoryProvider.overrideWithValue(
          _InMemorySearchHistoryRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(searchHistoryControllerProvider.notifier)
        .remember('moonhalo');

    expect(
      container
          .read(searchHistoryControllerProvider)
          .value
          ?.map((e) => e.keyword),
      <String>['moonhalo'],
    );
  });
}

class _SlowSearchHistoryRepository implements SearchHistoryRepository {
  @override
  Future<List<SearchHistoryEntry>> load() async => const <SearchHistoryEntry>[];

  @override
  Future<List<SearchHistoryEntry>> remember(String keyword) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return <SearchHistoryEntry>[
      SearchHistoryEntry(keyword: keyword, searchedAt: DateTime(2026)),
    ];
  }

  @override
  Future<List<SearchHistoryEntry>> remove(String keyword) async =>
      const <SearchHistoryEntry>[];

  @override
  Future<List<SearchHistoryEntry>> clear() async =>
      const <SearchHistoryEntry>[];
}

class _InMemorySearchHistoryRepository implements SearchHistoryRepository {
  final List<SearchHistoryEntry> _entries = <SearchHistoryEntry>[];

  @override
  Future<List<SearchHistoryEntry>> load() async => _entries;

  @override
  Future<List<SearchHistoryEntry>> remember(String keyword) async {
    _entries.insert(
      0,
      SearchHistoryEntry(keyword: keyword, searchedAt: DateTime(2026)),
    );
    return _entries;
  }

  @override
  Future<List<SearchHistoryEntry>> remove(String keyword) async {
    _entries.removeWhere((entry) => entry.keyword == keyword);
    return _entries;
  }

  @override
  Future<List<SearchHistoryEntry>> clear() async {
    _entries.clear();
    return _entries;
  }
}
