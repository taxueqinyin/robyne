import 'package:drift/drift.dart';

class Plugins extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get author => text().withLength(min: 1, max: 255)();
  TextColumn get version => text().withLength(min: 1, max: 50)();
  TextColumn get localPath => text()();
  TextColumn get subscriptionUrl => text().nullable()();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get installedAt => dateTime().withDefault(currentDateAndTime)();
}
