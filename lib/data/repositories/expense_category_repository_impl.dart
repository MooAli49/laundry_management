import 'package:drift/drift.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/repositories/expense_category_repository.dart';
import '../local/daos/expense_categories_dao.dart';
import '../local/daos/sync_operations_dao.dart';
import '../local/database/app_database.dart' as app_db;

class ExpenseCategoryRepositoryImpl implements ExpenseCategoryRepository {
  final ExpenseCategoriesDao _expenseCategoriesDao;
  final SyncOperationsDao _syncOperationsDao;
  final app_db.AppDatabase _db;

  ExpenseCategoryRepositoryImpl({
    required ExpenseCategoriesDao expenseCategoriesDao,
    required SyncOperationsDao syncOperationsDao,
    required app_db.AppDatabase db,
  })  : _expenseCategoriesDao = expenseCategoriesDao,
        _syncOperationsDao = syncOperationsDao,
        _db = db;

  @override
  Future<ExpenseCategory> createCategory(ExpenseCategory category) async {
    try {
      return await _db.transaction(() async {
        await _expenseCategoriesDao.insertCategory(
          app_db.ExpenseCategoriesCompanion(
            id: Value(category.id),
            name: Value(category.name),
            isActive: Value(category.isActive),
            createdAt: Value(category.createdAt),
            updatedAt: Value(category.updatedAt),
          ),
        );

        await _syncOperationsDao.recordOperation(
          entityType: 'expense_category',
          entityId: category.id,
          operationType: 'create',
        );

        return category;
      });
    } on ArgumentError catch (e) {
      throw ValidationFailure(e.message.toString());
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<ExpenseCategory> updateCategory(ExpenseCategory category) async {
    try {
      return await _db.transaction(() async {
        final existing = await _expenseCategoriesDao.getCategoryById(category.id);
        if (existing == null) {
          throw ValidationFailure('Expense category not found');
        }

        await _expenseCategoriesDao.updateCategory(
          app_db.ExpenseCategoriesCompanion(
            id: Value(category.id),
            name: Value(category.name),
            isActive: Value(category.isActive),
            createdAt: Value(category.createdAt),
            updatedAt: Value(category.updatedAt),
          ),
        );

        await _syncOperationsDao.recordOperation(
          entityType: 'expense_category',
          entityId: category.id,
          operationType: 'update',
        );

        return category;
      });
    } on ArgumentError catch (e) {
      throw ValidationFailure(e.message.toString());
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<ExpenseCategory?> getCategoryById(String id) async {
    try {
      final row = await _expenseCategoriesDao.getCategoryById(id);
      return row != null ? _mapToDomain(row) : null;
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<List<ExpenseCategory>> getActiveCategories() async {
    try {
      final rows = await _expenseCategoriesDao.getActiveCategories();
      return rows.map(_mapToDomain).toList();
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<List<ExpenseCategory>> getAllCategories() async {
    try {
      final rows = await _expenseCategoriesDao.getAllCategories();
      return rows.map(_mapToDomain).toList();
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<void> activateCategory(String id) async {
    try {
      await _db.transaction(() async {
        final existing = await _expenseCategoriesDao.getCategoryById(id);
        if (existing == null) {
          throw ValidationFailure('Expense category not found');
        }

        await _expenseCategoriesDao.setActiveStatus(id, true, DateTime.now());
        await _syncOperationsDao.recordOperation(
          entityType: 'expense_category',
          entityId: id,
          operationType: 'activate',
        );
      });
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<void> deactivateCategory(String id) async {
    try {
      await _db.transaction(() async {
        final existing = await _expenseCategoriesDao.getCategoryById(id);
        if (existing == null) {
          throw ValidationFailure('Expense category not found');
        }

        await _expenseCategoriesDao.setActiveStatus(id, false, DateTime.now());
        await _syncOperationsDao.recordOperation(
          entityType: 'expense_category',
          entityId: id,
          operationType: 'deactivate',
        );
      });
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  ExpenseCategory _mapToDomain(app_db.ExpenseCategory row) {
    return ExpenseCategory(
      id: row.id,
      name: row.name,
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
