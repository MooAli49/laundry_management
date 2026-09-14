import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/local/daos/expense_categories_dao.dart';
import 'package:laundry_management/data/local/daos/expenses_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart' as db_pkg;
import 'package:laundry_management/data/repositories/expense_category_repository_impl.dart';
import 'package:laundry_management/data/repositories/expense_repository_impl.dart';
import 'package:laundry_management/domain/entities/expense.dart';
import 'package:laundry_management/domain/entities/expense_category.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';

void main() {
  late db_pkg.AppDatabase db;
  late ExpensesDao expensesDao;
  late ExpenseCategoriesDao expenseCategoriesDao;
  late SyncOperationsDao syncOperationsDao;

  late ExpenseRepositoryImpl expenseRepository;
  late ExpenseCategoryRepositoryImpl expenseCategoryRepository;

  setUp(() async {
    db = db_pkg.AppDatabase(NativeDatabase.memory());
    expensesDao = ExpensesDao(db);
    expenseCategoriesDao = ExpenseCategoriesDao(db);
    syncOperationsDao = SyncOperationsDao(db);

    expenseRepository = ExpenseRepositoryImpl(
      expensesDao: expensesDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    expenseCategoryRepository = ExpenseCategoryRepositoryImpl(
      expenseCategoriesDao: expenseCategoriesDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Expense & ExpenseCategory Repository Implementation Tests', () {
    test('manages categories lifecycle: create, rename, deactivate, activate', () async {
      final now = DateTime.now();
      final cat = ExpenseCategory(
        id: 'cat-test-1',
        name: 'إنترنت',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      // Create
      await expenseCategoryRepository.createCategory(cat);
      final fetched = await expenseCategoryRepository.getCategoryById('cat-test-1');
      expect(fetched, isNotNull);
      expect(fetched!.name, 'إنترنت');
      expect(fetched.isActive, isTrue);

      // Rename
      final renamed = fetched.copyWith(name: 'اشتراك إنترنت');
      await expenseCategoryRepository.updateCategory(renamed);
      final fetchedRenamed = await expenseCategoryRepository.getCategoryById('cat-test-1');
      expect(fetchedRenamed!.name, 'اشتراك إنترنت');

      // Deactivate
      await expenseCategoryRepository.deactivateCategory('cat-test-1');
      final activeCats = await expenseCategoryRepository.getActiveCategories();
      expect(activeCats.any((c) => c.id == 'cat-test-1'), isFalse);

      final allCats = await expenseCategoryRepository.getAllCategories();
      expect(allCats.any((c) => c.id == 'cat-test-1'), isTrue);

      // Reactivate
      await expenseCategoryRepository.activateCategory('cat-test-1');
      final reactivated = await expenseCategoryRepository.getActiveCategories();
      expect(reactivated.any((c) => c.id == 'cat-test-1'), isTrue);
    });

    test('creates and retrieves an expense with snapshot and sync operation', () async {
      final now = DateTime.now();
      final cats = await expenseCategoryRepository.getAllCategories();
      final cleaningCat = cats.firstWhere((c) => c.name == 'منظفات');

      final expense = Expense(
        id: 'exp-101',
        expenseCategoryId: cleaningCat.id,
        amount: const Money.fromPiastres(12550), // 125.50 EGP
        expenseDate: OrderDate(2026, 8, 25),
        notes: 'شراء مسحوق غسيل',
        categoryNameSnapshot: cleaningCat.name,
        createdAt: now,
        updatedAt: now,
      );

      final created = await expenseRepository.createExpense(expense);
      expect(created.id, 'exp-101');
      expect(created.amount, const Money.fromPiastres(12550));
      expect(created.categoryNameSnapshot, 'منظفات');

      final fetched = await expenseRepository.getExpenseById('exp-101');
      expect(fetched, isNotNull);
      expect(fetched!.categoryNameSnapshot, 'منظفات');
      expect(fetched.notes, 'شراء مسحوق غسيل');

      // Sync operation recorded
      final pendingOps = await syncOperationsDao.getPendingOperations();
      expect(pendingOps.any((op) => op.entityId == 'exp-101' && op.entityType == 'expense'), isTrue);
    });

    test('filters expenses by date and category, aggregates totals and groups', () async {
      final now = DateTime.now();
      final cats = await expenseCategoryRepository.getAllCategories();
      final electricityCat = cats.firstWhere((c) => c.name == 'كهرباء');
      final waterCat = cats.firstWhere((c) => c.name == 'مياه');

      // Expense 1: 2026-08-10, electricity 200 EGP
      await expenseRepository.createExpense(
        Expense(
          id: 'exp-1',
          expenseCategoryId: electricityCat.id,
          amount: const Money.fromPiastres(20000),
          expenseDate: OrderDate(2026, 8, 10),
          categoryNameSnapshot: electricityCat.name,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Expense 2: 2026-08-15, water 100 EGP
      await expenseRepository.createExpense(
        Expense(
          id: 'exp-2',
          expenseCategoryId: waterCat.id,
          amount: const Money.fromPiastres(10000),
          expenseDate: OrderDate(2026, 8, 15),
          categoryNameSnapshot: waterCat.name,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Expense 3: 2026-09-01 (outside August), electricity 300 EGP
      await expenseRepository.createExpense(
        Expense(
          id: 'exp-3',
          expenseCategoryId: electricityCat.id,
          amount: const Money.fromPiastres(30000),
          expenseDate: OrderDate(2026, 9, 1),
          categoryNameSnapshot: electricityCat.name,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Total for August
      final augustTotal = await expenseRepository.getTotalExpenses(
        startDate: OrderDate(2026, 8, 1),
        endDate: OrderDate(2026, 8, 31),
      );
      expect(augustTotal, const Money.fromPiastres(30000)); // 200 + 100 = 300 EGP

      // Category filter for August
      final elecExpenses = await expenseRepository.getExpenses(
        startDate: OrderDate(2026, 8, 1),
        endDate: OrderDate(2026, 8, 31),
        categoryId: electricityCat.id,
      );
      expect(elecExpenses.length, 1);
      expect(elecExpenses.first.id, 'exp-1');

      // Total grouped by category for August
      final grouped = await expenseRepository.getExpensesGroupedByCategory(
        startDate: OrderDate(2026, 8, 1),
        endDate: OrderDate(2026, 8, 31),
      );
      expect(grouped[electricityCat.id], const Money.fromPiastres(20000));
      expect(grouped[waterCat.id], const Money.fromPiastres(10000));
    });

    test('historical expense preserves category snapshot even if category is renamed/deactivated', () async {
      final now = DateTime.now();
      final cats = await expenseCategoryRepository.getAllCategories();
      final transportCat = cats.firstWhere((c) => c.name == 'نقل');

      await expenseRepository.createExpense(
        Expense(
          id: 'exp-hist-1',
          expenseCategoryId: transportCat.id,
          amount: const Money.fromPiastres(5000),
          expenseDate: OrderDate(2026, 8, 20),
          categoryNameSnapshot: 'نقل وتوصيل قديم', // Snapshot at transaction time
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Deactivate category
      await expenseCategoryRepository.deactivateCategory(transportCat.id);

      // Historical expense remains valid and retains its historical snapshot
      final fetched = await expenseRepository.getExpenseById('exp-hist-1');
      expect(fetched, isNotNull);
      expect(fetched!.categoryNameSnapshot, 'نقل وتوصيل قديم');
      expect(fetched.amount, const Money.fromPiastres(5000));
    });
  });
}
