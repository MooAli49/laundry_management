import 'package:drift/drift.dart';
import 'order_items_table.dart';
import 'carpet_sizes_table.dart';

class OrderItemCarpets extends Table {
  @override
  String get tableName => 'order_item_carpets';

  TextColumn get id => text()();
  TextColumn get orderItemId => text().unique().references(
    OrderItems,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get carpetSizeId => text().nullable().references(
    CarpetSizes,
    #id,
    onDelete: KeyAction.setNull,
  )();
  RealColumn get length => real()();
  RealColumn get width => real()();
  RealColumn get area => real()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (length > 0)',
    'CHECK (width > 0)',
    'CHECK (area > 0)',
  ];
}
