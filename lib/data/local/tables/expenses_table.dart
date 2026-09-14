import 'package:drift/drift.dart';
import 'expense_categories_table.dart';

class Expenses extends Table {
  @override
  String get tableName => 'expenses';

  TextColumn get id => text()();
  TextColumn get expenseCategoryId =>
      text().references(ExpenseCategories, #id, onDelete: KeyAction.restrict)();
  IntColumn get amount => integer()();
  TextColumn get expenseName => text().nullable()();
  DateTimeColumn get expenseDate => dateTime()();
  TextColumn get notes => text().nullable()();
  TextColumn get categoryNameSnapshot => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (amount > 0)'];
}
