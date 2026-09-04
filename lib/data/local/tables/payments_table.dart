import 'package:drift/drift.dart';
import 'orders_table.dart';

class Payments extends Table {
  @override
  String get tableName => 'payments';

  TextColumn get id => text()();
  TextColumn get orderId =>
      text().references(Orders, #id, onDelete: KeyAction.restrict)();
  IntColumn get amount => integer()();
  TextColumn get paymentMethod => text()();
  DateTimeColumn get paidAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (amount > 0)'];
}
