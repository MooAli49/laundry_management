import 'package:drift/drift.dart';
import 'services_table.dart';
import 'item_types_table.dart';

class ServiceItemTypes extends Table {
  @override
  String get tableName => 'service_item_types';

  TextColumn get id => text()();
  TextColumn get serviceId =>
      text().references(Services, #id, onDelete: KeyAction.restrict)();
  TextColumn get itemTypeId =>
      text().references(ItemTypes, #id, onDelete: KeyAction.restrict)();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {serviceId, itemTypeId},
  ];
}
