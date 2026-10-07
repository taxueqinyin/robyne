import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../core/database/legacy_storage_migration.dart';
import '../domain/search_history_entry.dart';

/// Remembers the keywords the user has searched.
///
/// Stored as one JSON list under a single settings key rather than a table of
/// its own: history is a short, ordered list read as a whole, so a row per
/// entry would add a table and a schema migration to buy nothing.
class SearchHistoryRepository {
  SearchHistoryRepository({
    required db.AppDatabase database,
    LegacyStorageMigration? legacyMigration,
  }) : _database = database,
       _legacyMigration = legacyMigration;

  static const _key = 'search.history';

  /// Cap on remembered keywords.
  ///
  /// The list is rendered in full under the search field, so an unbounded
  /// history would scroll forever and slow every read.
  static const maxEntries = 20;

  final db.AppDatabase _database;
  final LegacyStorageMigration? _legacyMigration;

  Future<List<SearchHistoryEntry>> load() async {
    await _legacyMigration?.ensureMigrated();
    final raw = await _readRaw();
    if (raw == null || raw.isEmpty) {
      return const <SearchHistoryEntry>[];
    }
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      // A corrupt entry costs the history, not the app: treat it as empty
      // rather than surfacing a parse error on every search page open.
      return const <SearchHistoryEntry>[];
    }
    if (decoded is! List) {
      return const <SearchHistoryEntry>[];
    }
    final entries = <SearchHistoryEntry>[
      for (final value in decoded)
        if (SearchHistoryEntry.fromJson(value) case final SearchHistoryEntry entry)
          entry,
    ];
    return _normalize(entries);
  }

  /// Records [keyword], or refreshes it when already present.
  Future<List<SearchHistoryEntry>> remember(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      return load();
    }
    final existing = await load();
    final next = <SearchHistoryEntry>[
      SearchHistoryEntry(keyword: trimmed, searchedAt: DateTime.now()),
      // Re-searching a word should move it to the top, not duplicate it.
      ...existing.where((entry) => entry.keyword != trimmed),
    ];
    return _save(_normalize(next));
  }

  Future<List<SearchHistoryEntry>> remove(String keyword) async {
    final existing = await load();
    final next = existing
        .where((entry) => entry.keyword != keyword)
        .toList(growable: false);
    return _save(next);
  }

  Future<List<SearchHistoryEntry>> clear() async {
    await _legacyMigration?.ensureMigrated();
    await (_database.delete(
      _database.appSettings,
    )..where((row) => row.key.equals(_key))).go();
    return const <SearchHistoryEntry>[];
  }

  Future<List<SearchHistoryEntry>> _save(
    List<SearchHistoryEntry> entries,
  ) async {
    await _legacyMigration?.ensureMigrated();
    final capped = entries.length <= maxEntries
        ? entries
        : entries.sublist(0, maxEntries);
    await _database.into(_database.appSettings).insert(
      db.AppSettingsCompanion(
        key: Value(_key),
        value: Value(jsonEncode(capped.map((e) => e.toJson()).toList())),
      ),
      mode: InsertMode.insertOrReplace,
    );
    return capped;
  }

  /// Drops duplicates and blanks, newest first — the order the UI renders.
  List<SearchHistoryEntry> _normalize(List<SearchHistoryEntry> entries) {
    final seen = <String>{};
    final unique = <SearchHistoryEntry>[
      for (final entry in entries)
        if (entry.keyword.trim().isNotEmpty && seen.add(entry.keyword.trim()))
          entry,
    ];
    unique.sort((left, right) {
      final recent = right.searchedAt.compareTo(left.searchedAt);
      return recent != 0
          ? recent
          : left.keyword.compareTo(right.keyword);
    });
    return unique;
  }

  Future<String?> _readRaw() async {
    final row = await (_database.select(
      _database.appSettings,
    )..where((row) => row.key.equals(_key))).getSingleOrNull();
    return row?.value;
  }
}
