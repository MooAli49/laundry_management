import 'package:drift/drift.dart';
import 'storage_locations_table.dart';
import 'item_types_table.dart';

class StorageLocationItemTypes extends Table {
  @override
  String get tableName => 'storage_location_item_types';

  TextColumn get id => text()();
  TextColumn get storageLocationId =>
      text().references(StorageLocations, #id, onDelete: KeyAction.restrict)();
  TextColumn get itemTypeId =>
      text().references(ItemTypes, #id, onDelete: KeyAction.restrict)();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {storageLocationId, itemTypeId},
  ];
}
