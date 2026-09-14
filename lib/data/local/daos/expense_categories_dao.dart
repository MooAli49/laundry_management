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
    final raw = await (select(db.expenseCategories)
          ..where((t) => t.isActive.equals(true)))
        .get();
    final list = List<app_db.ExpenseCategory>.from(raw);
    list.sort((a, b) {
      if (a.name == 'أخرى') return 1;
      if (b.name == 'أخرى') return -1;
      return a.name.compareTo(b.name);
    });
    return list;
  }

  Future<List<app_db.ExpenseCategory>> getAllCategories() async {
    final raw = await select(db.expenseCategories).get();
    final list = List<app_db.ExpenseCategory>.from(raw);
    list.sort((a, b) {
      if (a.name == 'أخرى') return 1;
      if (b.name == 'أخرى') return -1;
      return a.name.compareTo(b.name);
    });
    return list;
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
