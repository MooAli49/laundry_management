import 'package:drift/drift.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/expense.dart';
import '../../domain/repositories/expense_repository.dart';
import '../../domain/value_objects/money.dart';
import '../../domain/value_objects/order_date.dart';
import '../local/daos/expenses_dao.dart';
import '../local/daos/sync_operations_dao.dart';
import '../local/database/app_database.dart' as app_db;

class ExpenseRepositoryImpl implements ExpenseRepository {
  final ExpensesDao _expensesDao;
  final SyncOperationsDao _syncOperationsDao;
  final app_db.AppDatabase _db;

  ExpenseRepositoryImpl({
    required ExpensesDao expensesDao,
    required SyncOperationsDao syncOperationsDao,
    required app_db.AppDatabase db,
  })  : _expensesDao = expensesDao,
        _syncOperationsDao = syncOperationsDao,
        _db = db;

  @override
  Future<Expense> createExpense(Expense expense) async {
    try {
      return await _db.transaction(() async {
        await _expensesDao.insertExpense(
          app_db.ExpensesCompanion(
            id: Value(expense.id),
            expenseCategoryId: Value(expense.expenseCategoryId),
            amount: Value(expense.amount.piastres),
            expenseName: Value(expense.expenseName),
            expenseDate: Value(expense.expenseDate.toDateTime()),
            notes: Value(expense.notes),
            categoryNameSnapshot: Value(expense.categoryNameSnapshot),
            createdAt: Value(expense.createdAt),
            updatedAt: Value(expense.updatedAt),
          ),
        );

        await _syncOperationsDao.recordOperation(
          entityType: 'expense',
          entityId: expense.id,
          operationType: 'create',
        );

        return expense;
      });
    } on ArgumentError catch (e) {
      throw ValidationFailure(e.message.toString());
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<Expense> updateExpense(Expense expense) async {
    try {
      return await _db.transaction(() async {
        final existing = await _expensesDao.getExpenseById(expense.id);
        if (existing == null) {
          throw ValidationFailure('Expense not found');
        }

        await _expensesDao.updateExpense(
          app_db.ExpensesCompanion(
            id: Value(expense.id),
            expenseCategoryId: Value(expense.expenseCategoryId),
            amount: Value(expense.amount.piastres),
            expenseName: Value(expense.expenseName),
            expenseDate: Value(expense.expenseDate.toDateTime()),
            notes: Value(expense.notes),
            categoryNameSnapshot: Value(expense.categoryNameSnapshot),
            createdAt: Value(expense.createdAt),
            updatedAt: Value(expense.updatedAt),
          ),
        );

        await _syncOperationsDao.recordOperation(
          entityType: 'expense',
          entityId: expense.id,
          operationType: 'update',
        );

        return expense;
      });
    } on ArgumentError catch (e) {
      throw ValidationFailure(e.message.toString());
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<Expense?> getExpenseById(String id) async {
    try {
      final row = await _expensesDao.getExpenseById(id);
      return row != null ? _mapToDomain(row) : null;
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<List<Expense>> getExpenses({
    OrderDate? startDate,
    OrderDate? endDate,
    String? categoryId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final rows = await _expensesDao.getExpenses(
        startDate: startDate?.toDateTime(),
        endDate: endDate?.toDateTime(),
        categoryId: categoryId,
        limit: limit,
        offset: offset,
      );
      return rows.map(_mapToDomain).toList();
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Stream<List<Expense>> watchExpensesForDate(OrderDate date) {
    try {
      return _expensesDao.watchExpensesForDate(date.toDateTime()).map(
            (rows) => rows.map(_mapToDomain).toList(),
          );
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<Money> getTotalExpenses({
    required OrderDate startDate,
    required OrderDate endDate,
  }) async {
    try {
      final totalPiastres = await _expensesDao.getTotalExpenses(
        startDate: startDate.toDateTime(),
        endDate: endDate.toDateTime(),
      );
      return Money.fromPiastres(totalPiastres);
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<Map<String, Money>> getExpensesGroupedByCategory({
    required OrderDate startDate,
    required OrderDate endDate,
  }) async {
    try {
      final rawMap = await _expensesDao.getExpensesGroupedByCategory(
        startDate: startDate.toDateTime(),
        endDate: endDate.toDateTime(),
      );
      return rawMap.map((key, value) => MapEntry(key, Money.fromPiastres(value)));
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  Expense _mapToDomain(app_db.Expense row) {
    return Expense(
      id: row.id,
      expenseCategoryId: row.expenseCategoryId,
      amount: Money.fromPiastres(row.amount),
      expenseName: row.expenseName,
      expenseDate: OrderDate.fromDate(row.expenseDate),
      notes: row.notes,
      categoryNameSnapshot: row.categoryNameSnapshot,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
