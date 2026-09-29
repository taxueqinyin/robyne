import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import '../storage/local_file_store.dart';

part 'app_database.g.dart';

class PlaybackItems extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get title => text()();
  TextColumn get platform => text().nullable()();
  TextColumn get musicId => text().nullable()();
  TextColumn get localPath => text().nullable()();
  TextColumn get artist => text().nullable()();
  TextColumn get album => text().nullable()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get artworkUrl => text().nullable()();
  TextColumn get rawJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class PlayerStateRows extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get currentItemId =>
      text().nullable().references(PlaybackItems, #id)();
  TextColumn get playbackMode =>
      text().withDefault(const Constant('sequence'))();
  RealColumn get volume => real().withDefault(const Constant(100))();
  IntColumn get lastPositionMs => integer().withDefault(const Constant(0))();
  IntColumn get lastDurationMs => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class QueueEntries extends Table {
  IntColumn get position => integer()();
  TextColumn get itemId => text().references(PlaybackItems, #id)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{itemId};
}

class PlaybackHistoryRows extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get itemId => text().references(PlaybackItems, #id)();
  DateTimeColumn get playedAt => dateTime()();
}

class LocalLibraryTracks extends Table {
  TextColumn get itemId => text().references(PlaybackItems, #id)();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{itemId};
}

class PluginDefinitionRows extends Table {
  TextColumn get id => text()();
  TextColumn get platform => text()();
  TextColumn get version => text().nullable()();
  TextColumn get author => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get sourcePath => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get installedAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get supportedSearchTypesJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get userVariablesJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get userVariableValuesJson =>
      text().withDefault(const Constant('{}'))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class AudioCacheEntries extends Table {
  TextColumn get itemId => text().references(PlaybackItems, #id)();
  TextColumn get sourceUrl => text()();
  TextColumn get path => text()();
  IntColumn get size => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastAccessedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{itemId};
}

class LyricPreferences extends Table {
  TextColumn get itemId => text().references(PlaybackItems, #id)();
  TextColumn get sourceType => text().nullable()();
  TextColumn get associatedPath => text().nullable()();
  TextColumn get pluginPlatform => text().nullable()();
  TextColumn get pluginItemRawJson => text().nullable()();
  TextColumn get rawLyric => text().nullable()();
  IntColumn get offsetMs => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{itemId};
}

class Playlists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  BoolColumn get isFavorites => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class PlaylistItems extends Table {
  TextColumn get playlistId => text().references(Playlists, #id)();
  TextColumn get itemId => text().references(PlaybackItems, #id)();
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{playlistId, itemId};
}

class DownloadTasks extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text().references(PlaybackItems, #id)();
  TextColumn get status => text()();
  RealColumn get progress => real().withDefault(const Constant(0))();
  TextColumn get sourceUrl => text().nullable()();
  TextColumn get filePath => text().nullable()();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}

/// Online collections (rankings, recommend sheets) the user has favourited.
///
/// A favourited collection is a *pointer to a plugin's catalogue entry*, not a
/// local playlist: the tracks are owned by the plugin and may change, so the
/// row stores the identity plus the display snapshot (title, artwork) and lets
/// the plugin re-resolve the track list on open. Copying every track into
/// `PlaylistItems` would freeze a live list and double the storage.
class FavoriteCollections extends Table {
  /// `OnlineCollectionItem.uniqueKey`: `<pluginId>:<kind>:<id>`.
  TextColumn get collectionKey => text()();
  TextColumn get pluginId => text()();
  TextColumn get platform => text()();
  /// `OnlineCollectionKind.name`, so a ranking and a sheet never collide.
  TextColumn get kind => text()();
  TextColumn get collectionId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get artworkUrl => text().nullable()();
  /// The plugin payload, kept verbatim so the detail can be re-fetched.
  TextColumn get rawJson => text()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{collectionKey};
}

@DriftDatabase(
  tables: <Type>[
    PlaybackItems,
    PlayerStateRows,
    QueueEntries,
    PlaybackHistoryRows,
    LocalLibraryTracks,
    PluginDefinitionRows,
    AudioCacheEntries,
    LyricPreferences,
    Playlists,
    PlaylistItems,
    DownloadTasks,
    AppSettings,
    FavoriteCollections,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  factory AppDatabase.open(LocalFileStore fileStore) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    return AppDatabase(_openConnection(fileStore));
  }

  factory AppDatabase.memory() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    return AppDatabase(NativeDatabase.memory());
  }

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // v2 added favourite online collections. Existing databases already have
      // every other table, so only the new one needs creating.
      if (from < 2) {
        await m.createTable(favoriteCollections);
      }
    },
  );
}

LazyDatabase _openConnection(LocalFileStore fileStore) {
  return LazyDatabase(() async {
    final directory = await fileStore.dataDirectory();
    final file = File(p.join(directory.path, 'robyne.sqlite'));
    return NativeDatabase(file);
  });
}
