import 'package:drift/drift.dart';

class ExpenseCategories extends Table {
  @override
  String get tableName => 'expense_categories';

  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
