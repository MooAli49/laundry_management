import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/local/daos/expenses_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/daos/sync_state_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart' as app_db;
import 'package:laundry_management/data/remote/dto/sync_change_dto.dart';
import 'package:laundry_management/data/repositories/expense_repository_impl.dart';
import 'package:laundry_management/data/sync/remote_change_applier.dart';
import 'package:laundry_management/domain/entities/expense.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';

void main() {
  late app_db.AppDatabase dbTerminal1;
  late ExpensesDao expensesDaoT1;
  late SyncOperationsDao syncOperationsDaoT1;
  late ExpenseRepositoryImpl expenseRepoT1;

  late app_db.AppDatabase dbTerminal2;
  late ExpensesDao expensesDaoT2;
  late SyncStateDao syncStateDaoT2;
  late RemoteChangeApplier applierT2;

  final catAId = '00000000-0000-0000-0002-000000000001'; // كهرباء (seeded)
  final catBId = '00000000-0000-0000-0002-000000000002'; // مياه (seeded)
  final catOtherId = '00000000-0000-0000-0002-000000000007'; // أخرى (seeded)

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    // Terminal 1 setup
    dbTerminal1 = app_db.AppDatabase(NativeDatabase.memory());
    expensesDaoT1 = ExpensesDao(dbTerminal1);
    syncOperationsDaoT1 = SyncOperationsDao(dbTerminal1);

    expenseRepoT1 = ExpenseRepositoryImpl(
      expensesDao: expensesDaoT1,
      syncOperationsDao: syncOperationsDaoT1,
      db: dbTerminal1,
    );

    // Terminal 2 setup
    dbTerminal2 = app_db.AppDatabase(NativeDatabase.memory());
    expensesDaoT2 = ExpensesDao(dbTerminal2);
    syncStateDaoT2 = SyncStateDao(dbTerminal2);
    applierT2 = RemoteChangeApplier(
      db: dbTerminal2,
      syncStateDao: syncStateDaoT2,
    );
  });

  tearDown(() async {
    await dbTerminal1.close();
    await dbTerminal2.close();
  });

  group('BUG-05: Expense Update / expense_category_id Regression Tests', () {
    final now = DateTime.utc(2026, 9, 16, 12, 0, 0);

    test(
      'TEST 1: Create expense with Category A -> edit to Category B -> verify local result in Drift',
      () async {
        final initialExpense = Expense(
          id: 'exp-test-1',
          expenseCategoryId: catAId,
          amount: const Money.fromPiastres(3500),
          expenseName: 'فاتورة كهرباء يوليو',
          expenseDate: OrderDate(2026, 9, 1),
          notes: 'ملاحظة مبدئية',
          categoryNameSnapshot: 'كهرباء',
          createdAt: now,
          updatedAt: now,
        );

        // 1. Create on Terminal 1
        await expenseRepoT1.createExpense(initialExpense);
        final created = await expensesDaoT1.getExpenseById('exp-test-1');
        expect(created, isNotNull);
        expect(created!.expenseCategoryId, catAId);
        expect(created.categoryNameSnapshot, 'كهرباء');

        // 2. Edit category to Category B
        final updatedExpense = initialExpense.copyWith(
          expenseCategoryId: catBId,
          categoryNameSnapshot: 'مياه',
          updatedAt: now.add(const Duration(minutes: 5)),
        );
        await expenseRepoT1.updateExpense(updatedExpense);

        // 3. Verify local Drift row in Terminal 1
        final stored = await expensesDaoT1.getExpenseById('exp-test-1');
        expect(stored, isNotNull);
        expect(stored!.expenseCategoryId, catBId);
        expect(stored.categoryNameSnapshot, 'مياه');
        expect(stored.amount, 3500);
      },
    );

    test(
      'TEST 2: Create expense with Category A -> edit category to empty/invalid -> verify rejected and preserved',
      () async {
        final initialExpense = Expense(
          id: 'exp-test-2',
          expenseCategoryId: catAId,
          amount: const Money.fromPiastres(2000),
          expenseName: 'فاتورة عادية',
          expenseDate: OrderDate(2026, 9, 2),
          categoryNameSnapshot: 'كهرباء',
          createdAt: now,
          updatedAt: now,
        );

        await expenseRepoT1.createExpense(initialExpense);

        // Attempting to construct Expense with empty category must throw ArgumentError
        expect(
          () => initialExpense.copyWith(expenseCategoryId: '   '),
          throwsA(isA<ArgumentError>()),
        );

        // Verify local row still has Category A
        final stored = await expensesDaoT1.getExpenseById('exp-test-2');
        expect(stored!.expenseCategoryId, catAId);
      },
    );

    test(
      'TEST 3: Create expense with empty category -> verify rejected at domain layer',
      () {
        expect(
          () => Expense(
            id: 'exp-test-3',
            expenseCategoryId: '',
            amount: const Money.fromPiastres(1000),
            expenseDate: OrderDate(2026, 9, 3),
            categoryNameSnapshot: 'كهرباء',
            createdAt: now,
            updatedAt: now,
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test(
      'TEST 4: Verify generated sync payload contains updated expense_category_id and category_name_snapshot',
      () async {
        final initialExpense = Expense(
          id: 'exp-test-4',
          expenseCategoryId: catAId,
          amount: const Money.fromPiastres(5000),
          expenseDate: OrderDate(2026, 9, 4),
          categoryNameSnapshot: 'كهرباء',
          createdAt: now,
          updatedAt: now,
        );

        await expenseRepoT1.createExpense(initialExpense);

        final updatedExpense = initialExpense.copyWith(
          expenseCategoryId: catBId,
          categoryNameSnapshot: 'مياه',
          notes: 'تم تصحيح البند إلى مياه',
          updatedAt: now.add(const Duration(minutes: 10)),
        );

        await expenseRepoT1.updateExpense(updatedExpense);

        // Inspect the outbox operation payload
        final pendingOps = await syncOperationsDaoT1.getPendingOperations();
        final updateOp = pendingOps.firstWhere(
          (op) => op.entityId == 'exp-test-4' && op.operationType == 'update',
        );

        final payloadMap = jsonDecode(updateOp.payload!) as Map<String, dynamic>;

        // CRITICAL BUG-05 ASSERTION: expense_category_id must be in the update payload!
        expect(
          payloadMap['expense_category_id'],
          equals(catBId),
          reason: 'BUG-05: Outbox update payload must contain the updated expense_category_id',
        );
        expect(
          payloadMap['category_name_snapshot'],
          equals('مياه'),
          reason: 'BUG-05: Outbox update payload must contain the updated category_name_snapshot',
        );
        expect(payloadMap['notes'], equals('تم تصحيح البند إلى مياه'));
        expect(payloadMap['amount'], equals(5000));
      },
    );

    test(
      'TEST 5 & 6: Simulate remote change pulled into Terminal 2 and verify expense_category_id updated',
      () async {
        // Terminal 2 initially receives the create change for the expense with Category A
        final createChange = SyncChangeDto(
          sequence: 1,
          operationId: 'op-exp-create-1',
          entityType: 'expense',
          entityId: 'exp-test-5',
          operationType: 'create',
          payload: {
            'id': 'exp-test-5',
            'expense_category_id': catAId,
            'category_name_snapshot': 'كهرباء',
            'amount': 4000,
            'expense_name': 'كهرباء المحل',
            'expense_date': '2026-09-05',
            'notes': null,
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          },
          createdAt: now,
        );

        await applierT2.applyBatch([createChange]);

        // Verify Terminal 2 has Category A
        var storedT2 = await expensesDaoT2.getExpenseById('exp-test-5');
        expect(storedT2, isNotNull);
        expect(storedT2!.expenseCategoryId, equals(catAId));
        expect(storedT2.categoryNameSnapshot, equals('كهرباء'));

        // Next, Terminal 2 pulls the update change where category was changed to Category B
        final updateChange = SyncChangeDto(
          sequence: 2,
          operationId: 'op-exp-update-2',
          entityType: 'expense',
          entityId: 'exp-test-5',
          operationType: 'update',
          payload: {
            'id': 'exp-test-5',
            'expense_category_id': catBId,
            'category_name_snapshot': 'مياه',
            'amount': 4200,
            'expense_name': 'مياه المحل',
            'expense_date': '2026-09-05',
            'notes': 'تصحيح الفاتورة لتكون مياه',
            'created_at': now.toIso8601String(),
            'updated_at': now.add(const Duration(minutes: 15)).toIso8601String(),
          },
          createdAt: now.add(const Duration(minutes: 15)),
        );

        await applierT2.applyBatch([updateChange]);

        // CRITICAL BUG-05 ASSERTION: Terminal 2 must now have Category B!
        storedT2 = await expensesDaoT2.getExpenseById('exp-test-5');
        expect(storedT2, isNotNull);
        expect(
          storedT2!.expenseCategoryId,
          equals(catBId),
          reason: 'BUG-05: Terminal 2 must have updated expense_category_id after pull',
        );
        expect(
          storedT2.categoryNameSnapshot,
          equals('مياه'),
          reason: 'BUG-05: Terminal 2 must have updated category_name_snapshot after pull',
        );
        expect(storedT2.amount, equals(4200));
        expect(storedT2.expenseName, equals('مياه المحل'));
        expect(storedT2.notes, equals('تصحيح الفاتورة لتكون مياه'));
      },
    );

    test(
      'TEST 7: Other expense fields continue to synchronize correctly when category is updated',
      () async {
        final initialExpense = Expense(
          id: 'exp-test-7',
          expenseCategoryId: catAId,
          amount: const Money.fromPiastres(1200),
          expenseName: 'اسم قديم',
          expenseDate: OrderDate(2026, 9, 1),
          notes: 'ملاحظة قديمة',
          categoryNameSnapshot: 'كهرباء',
          createdAt: now,
          updatedAt: now,
        );

        await expenseRepoT1.createExpense(initialExpense);

        // Edit category AND amount AND date AND notes AND name
        final fullyUpdated = initialExpense.copyWith(
          expenseCategoryId: catBId,
          categoryNameSnapshot: 'مياه',
          amount: const Money.fromPiastres(9900),
          expenseName: 'اسم جديد',
          expenseDate: OrderDate(2026, 9, 10),
          notes: 'ملاحظة جديدة كاملة',
          updatedAt: now.add(const Duration(hours: 1)),
        );

        await expenseRepoT1.updateExpense(fullyUpdated);

        final pendingOps = await syncOperationsDaoT1.getPendingOperations();
        final op = pendingOps.firstWhere((o) => o.entityId == 'exp-test-7' && o.operationType == 'update');
        final map = jsonDecode(op.payload!) as Map<String, dynamic>;

        expect(map['expense_category_id'], catBId);
        expect(map['category_name_snapshot'], 'مياه');
        expect(map['amount'], 9900);
        expect(map['expense_name'], 'اسم جديد');
        expect(map['expense_date'], '2026-09-10');
        expect(map['notes'], 'ملاحظة جديدة كاملة');
      },
    );

    test(
      'TEST 8: Partial payload robustness in RemoteChangeApplier does NOT wipe existing category',
      () async {
        // Initial create on Terminal 2
        final createChange = SyncChangeDto(
          sequence: 10,
          operationId: 'op-partial-1',
          entityType: 'expense',
          entityId: 'exp-partial-1',
          operationType: 'create',
          payload: {
            'id': 'exp-partial-1',
            'expense_category_id': catAId,
            'category_name_snapshot': 'كهرباء',
            'amount': 5000,
            'expense_name': 'فاتورة كهرباء',
            'expense_date': '2026-09-08',
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          },
          createdAt: now,
        );
        await applierT2.applyBatch([createChange]);

        // A partial update payload that only contains amount and notes (no category field)
        final partialChange = SyncChangeDto(
          sequence: 11,
          operationId: 'op-partial-2',
          entityType: 'expense',
          entityId: 'exp-partial-1',
          operationType: 'update',
          payload: {
            'id': 'exp-partial-1',
            'amount': 6000,
            'notes': 'تعديل المبلغ فقط بدون تغيير التصنيف',
            'updated_at': now.add(const Duration(minutes: 5)).toIso8601String(),
          },
          createdAt: now.add(const Duration(minutes: 5)),
        );

        await applierT2.applyBatch([partialChange]);

        final row = await expensesDaoT2.getExpenseById('exp-partial-1');
        expect(row, isNotNull);
        expect(row!.amount, 6000);
        expect(row.notes, 'تعديل المبلغ فقط بدون تغيير التصنيف');
        // Crucial: Category A must NOT have been wiped to empty string!
        expect(row.expenseCategoryId, equals(catAId));
        expect(row.categoryNameSnapshot, equals('كهرباء'));
      },
    );

    test(
      'TEST 9: Changing category to أخرى requires non-empty expenseName',
      () async {
        final expense = Expense(
          id: 'exp-other-test',
          expenseCategoryId: catAId,
          amount: const Money.fromPiastres(1500),
          expenseDate: OrderDate(2026, 9, 1),
          categoryNameSnapshot: 'كهرباء',
          createdAt: now,
          updatedAt: now,
        );

        await expenseRepoT1.createExpense(expense);

        // Attempting to copy with category 'أخرى' and null expenseName must throw ArgumentError
        expect(
          () => expense.copyWith(
            expenseCategoryId: catOtherId,
            categoryNameSnapshot: 'أخرى',
            expenseName: null,
          ),
          throwsA(isA<ArgumentError>()),
        );

        // With valid expenseName, succeeds
        final validOther = expense.copyWith(
          expenseCategoryId: catOtherId,
          categoryNameSnapshot: 'أخرى',
          expenseName: 'شراء أدوات خاصة',
        );
        await expenseRepoT1.updateExpense(validOther);

        final stored = await expensesDaoT1.getExpenseById('exp-other-test');
        expect(stored!.expenseCategoryId, catOtherId);
        expect(stored.categoryNameSnapshot, 'أخرى');
        expect(stored.expenseName, 'شراء أدوات خاصة');
      },
    );
  });
}
