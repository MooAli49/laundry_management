import 'package:drift/drift.dart';

class StorageLocations extends Table {
  @override
  String get tableName => 'storage_locations';

  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
