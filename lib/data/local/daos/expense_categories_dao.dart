import 'package:drift/drift.dart';

import '../database/app_database.dart' as app_db;

class ExpenseCategoriesDao extends DatabaseAccessor<app_db.AppDatabase> {
  ExpenseCategoriesDao(super.attachedDatabase);

  app_db.AppDatabase get db => attachedDatabase;

  Future<void> insertCategory(app_db.ExpenseCategoriesCompanion companion) async {
    await into(db.expenseCategories).insert(companion);
  }

  Future<void> updateCategory(app_db.ExpenseCategoriesCompanion companion) async {
    await (update(db.expenseCategories)..where((t) => t.id.equals(companion.id.value))).write(companion);
  }

  Future<app_db.ExpenseCategory?> getCategoryById(String id) async {
    return (select(db.expenseCategories)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<app_db.ExpenseCategory>> getActiveCategories() async {
    return (select(db.expenseCategories)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  Future<List<app_db.ExpenseCategory>> getAllCategories() async {
    return (select(db.expenseCategories)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
  }

  Future<void> setActiveStatus(String id, bool isActive, DateTime updatedAt) async {
    await (update(db.expenseCategories)..where((t) => t.id.equals(id))).write(
      app_db.ExpenseCategoriesCompanion(
        isActive: Value(isActive),
        updatedAt: Value(updatedAt),
      ),
    );
  }
}
