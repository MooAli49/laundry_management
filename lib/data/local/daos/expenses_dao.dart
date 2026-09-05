import 'package:drift/drift.dart';

import '../database/app_database.dart' as app_db;

class ExpensesDao extends DatabaseAccessor<app_db.AppDatabase> {
  ExpensesDao(super.attachedDatabase);

  app_db.AppDatabase get db => attachedDatabase;

  Future<void> insertExpense(app_db.ExpensesCompanion companion) async {
    await into(db.expenses).insert(companion);
  }

  Future<void> updateExpense(app_db.ExpensesCompanion companion) async {
    await (update(db.expenses)..where((t) => t.id.equals(companion.id.value))).write(companion);
  }

  Future<app_db.Expense?> getExpenseById(String id) async {
    return (select(db.expenses)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<app_db.Expense>> getExpenses({
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
    int limit = 50,
    int offset = 0,
  }) async {
    final query = select(db.expenses);
    if (startDate != null) {
      query.where((t) => t.expenseDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where((t) => t.expenseDate.isSmallerOrEqualValue(endDate));
    }
    if (categoryId != null) {
      query.where((t) => t.expenseCategoryId.equals(categoryId));
    }
    query
      ..orderBy([(t) => OrderingTerm.desc(t.expenseDate)])
      ..limit(limit, offset: offset);
    return query.get();
  }

  Stream<List<app_db.Expense>> watchExpensesForDate(DateTime date) {
    final startOfDay = DateTime.utc(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return (select(db.expenses)
          ..where((t) => t.expenseDate.isBiggerOrEqualValue(startOfDay) & t.expenseDate.isSmallerThanValue(endOfDay))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<int> getTotalExpenses({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final sumExp = db.expenses.amount.sum();
    final query = selectOnly(db.expenses)
      ..where(
        db.expenses.expenseDate.isBiggerOrEqualValue(startDate) &
            db.expenses.expenseDate.isSmallerOrEqualValue(endDate),
      )
      ..addColumns([sumExp]);

    final result = await query.map((row) => row.read(sumExp)).getSingle();
    return result ?? 0;
  }

  Future<Map<String, int>> getExpensesGroupedByCategory({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final sumExp = db.expenses.amount.sum();
    final query = selectOnly(db.expenses)
      ..where(
        db.expenses.expenseDate.isBiggerOrEqualValue(startDate) &
            db.expenses.expenseDate.isSmallerOrEqualValue(endDate),
      )
      ..groupBy([db.expenses.expenseCategoryId])
      ..addColumns([db.expenses.expenseCategoryId, sumExp]);

    final rows = await query.get();
    final map = <String, int>{};
    for (final row in rows) {
      final catId = row.read(db.expenses.expenseCategoryId)!;
      final total = row.read(sumExp) ?? 0;
      map[catId] = total;
    }
    return map;
  }
}
