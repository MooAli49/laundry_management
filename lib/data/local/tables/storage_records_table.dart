import 'package:drift/drift.dart';
import 'order_items_table.dart';
import 'storage_locations_table.dart';

class StorageRecords extends Table {
  @override
  String get tableName => 'storage_records';

  TextColumn get id => text()();
  TextColumn get orderItemId =>
      text().references(OrderItems, #id, onDelete: KeyAction.restrict)();
  TextColumn get storageLocationId =>
      text().references(StorageLocations, #id, onDelete: KeyAction.restrict)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
