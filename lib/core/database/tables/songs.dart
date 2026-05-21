import 'package:drift/drift.dart';

class Songs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sourceId => text().nullable()();
  TextColumn get title => text().withLength(min: 1, max: 500)();
  TextColumn get artist => text().nullable()();
  TextColumn get album => text().nullable()();
  TextColumn get coverUrl => text().nullable()();
  TextColumn get coverLocal => text().nullable()();
  TextColumn get audioUrl => text().nullable()();
  IntColumn get durationMs => integer().nullable()();
  BoolColumn get isLocal => boolean().withDefault(const Constant(false))();
  TextColumn get localPath => text().nullable()();
  IntColumn get pluginId => integer().nullable()();
}
