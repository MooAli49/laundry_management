import 'package:drift/drift.dart';
import 'item_types_table.dart';

class ItemDefinitions extends Table {
  @override
  String get tableName => 'item_definitions';

  TextColumn get id => text()();
  TextColumn get itemTypeId =>
      text().references(ItemTypes, #id, onDelete: KeyAction.restrict)();
  TextColumn get name => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {itemTypeId, name},
  ];
}
