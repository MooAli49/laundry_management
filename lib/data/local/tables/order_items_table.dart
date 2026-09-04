import 'package:drift/drift.dart';
import 'orders_table.dart';
import 'item_types_table.dart';
import 'item_definitions_table.dart';
import 'services_table.dart';

class OrderItems extends Table {
  @override
  String get tableName => 'order_items';

  TextColumn get id => text()();
  TextColumn get orderId =>
      text().references(Orders, #id, onDelete: KeyAction.restrict)();
  TextColumn get itemTypeId =>
      text().references(ItemTypes, #id, onDelete: KeyAction.restrict)();
  TextColumn get itemDefinitionId => text().nullable().references(
    ItemDefinitions,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get serviceId =>
      text().references(Services, #id, onDelete: KeyAction.restrict)();
  TextColumn get itemTypeNameSnapshot => text()();
  TextColumn get itemDefinitionNameSnapshot => text().nullable()();
  TextColumn get serviceNameSnapshot => text()();
  TextColumn get pricingType => text()();
  RealColumn get quantity => real()();
  IntColumn get unitPrice => integer()();
  IntColumn get calculatedTotal => integer()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (quantity > 0)',
    'CHECK (unit_price >= 0)',
    'CHECK (calculated_total >= 0)',
  ];
}
