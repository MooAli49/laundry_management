import 'package:drift/drift.dart';
import 'orders_table.dart';

class Refunds extends Table {
  @override
  String get tableName => 'refunds';

  TextColumn get id => text()();
  TextColumn get orderId =>
      text().references(Orders, #id, onDelete: KeyAction.restrict)();
  IntColumn get amount => integer()();
  TextColumn get refundMethod => text()();
  TextColumn get reason => text().nullable()();
  DateTimeColumn get refundedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (amount > 0)'];
}
