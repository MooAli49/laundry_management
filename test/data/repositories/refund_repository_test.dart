import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/application/use_cases/create_refund_use_case.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/refunds_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart'
    hide Payment, Refund;
import 'package:laundry_management/data/repositories/refund_repository_impl.dart';
import 'package:laundry_management/domain/entities/refund.dart';
import 'package:laundry_management/domain/enums/refund_method.dart';
import 'package:laundry_management/domain/value_objects/money.dart';

void main() {
  late AppDatabase db;
  late RefundsDao refundsDao;
  late PaymentsDao paymentsDao;
  late OrdersDao ordersDao;
  late SyncOperationsDao syncOperationsDao;
  late RefundRepositoryImpl refundRepository;

  Refund createTestRefund({
    required String id,
    required String orderId,
    required int amountPiastres,
    RefundMethod method = RefundMethod.cash,
    String? reason,
    DateTime? refundedAt,
  }) {
    final now = refundedAt ?? DateTime.now();
    return Refund(
      id: id,
      orderId: orderId,
      amount: Money.fromPiastres(amountPiastres),
      refundMethod: method,
      reason: reason,
      refundedAt: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    refundsDao = RefundsDao(db);
    paymentsDao = PaymentsDao(db);
    ordersDao = OrdersDao(db);
    syncOperationsDao = SyncOperationsDao(db);

    refundRepository = RefundRepositoryImpl(
      refundsDao: refundsDao,
      paymentsDao: paymentsDao,
      ordersDao: ordersDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    final nowTimestamp = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

    // Insert test customer
    await db.customStatement(
      'INSERT INTO customers (id, name, phone, created_at, updated_at) VALUES (?, ?, ?, ?, ?);',
      ['cust-ref', 'عميل الاسترجاع', '01011112222', nowTimestamp, nowTimestamp],
    );

    // 1. Cancelled order with 20000 piastres (200 EGP) total
    await db.customStatement(
      'INSERT INTO orders (id, order_number, customer_id, status, expected_pickup_date, '
      'subtotal, total, cancelled_at, cancellation_reason, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
      [
        'ord-cancelled-1',
        '26-101',
        'cust-ref',
        'cancelled',
        nowTimestamp,
        20000,
        20000,
        nowTimestamp,
        'طلب العميل الإلغاء',
        nowTimestamp,
        nowTimestamp,
      ],
    );

    // Initial payment for cancelled order: 20000 piastres
    await db.customStatement(
      'INSERT INTO payments (id, order_id, amount, payment_method, paid_at, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?);',
      [
        'pay-101',
        'ord-cancelled-1',
        20000,
        'cash',
        nowTimestamp,
        nowTimestamp,
        nowTimestamp,
      ],
    );

    // 2. Active processing order (should NOT be refundable)
    await db.customStatement(
      'INSERT INTO orders (id, order_number, customer_id, status, expected_pickup_date, '
      'subtotal, total, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);',
      [
        'ord-active-1',
        '26-102',
        'cust-ref',
        'processing',
        nowTimestamp,
        15000,
        15000,
        nowTimestamp,
        nowTimestamp,
      ],
    );

    await db.customStatement(
      'INSERT INTO payments (id, order_id, amount, payment_method, paid_at, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?);',
      [
        'pay-102',
        'ord-active-1',
        15000,
        'cash',
        nowTimestamp,
        nowTimestamp,
        nowTimestamp,
      ],
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Phase 2: Local Refund Data Layer Tests', () {
    // 1. Refund insert.
    test('1. Refund insert: correctly persists locally and records outbox sync operation', () async {
      final refund = createTestRefund(
        id: 'ref-001',
        orderId: 'ord-cancelled-1',
        amountPiastres: 5000,
        method: RefundMethod.cash,
        reason: 'Refund part 1',
      );

      final result = await refundRepository.createRefund(refund);

      expect(result.id, equals('ref-001'));
      expect(result.amount.piastres, equals(5000));

      // Verify row exists in drift refunds table
      final directRow = await (db.select(db.refunds)
            ..where((t) => t.id.equals('ref-001')))
          .getSingleOrNull();
      expect(directRow, isNotNull);
      expect(directRow!.id, equals('ref-001'));
      expect(directRow.orderId, equals('ord-cancelled-1'));
      expect(directRow.amount, equals(5000));
      expect(directRow.refundMethod, equals('cash'));
      expect(directRow.reason, equals('Refund part 1'));

      // Verify outbox sync operation was created
      final pendingOps = await syncOperationsDao.getPendingOperations();
      final refundOp = pendingOps.firstWhere((op) => op.entityId == 'ref-001');
      expect(refundOp.entityType, equals('refund'));
      expect(refundOp.operationType, equals('create'));
      expect(refundOp.payload, contains('"order_id":"ord-cancelled-1"'));
      expect(refundOp.payload, contains('"amount":5000'));
    });

    // 2. Refund retrieval by ID.
    test('2. Refund retrieval by ID: returns exact domain Refund', () async {
      final refund = createTestRefund(
        id: 'ref-002',
        orderId: 'ord-cancelled-1',
        amountPiastres: 7500,
        method: RefundMethod.instaPay,
        reason: 'By ID retrieval test',
      );
      await refundRepository.createRefund(refund);

      final retrieved = await refundRepository.getRefundById('ref-002');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals('ref-002'));
      expect(retrieved.orderId, equals('ord-cancelled-1'));
      expect(retrieved.amount, equals(Money.fromPiastres(7500)));
      expect(retrieved.refundMethod, equals(RefundMethod.instaPay));
      expect(retrieved.reason, equals('By ID retrieval test'));

      final nonExistent = await refundRepository.getRefundById('unknown-id');
      expect(nonExistent, isNull);
    });

    // 3. Refund retrieval by order ID.
    test('3. Refund retrieval by order ID: returns list ordered newest first', () async {
      final earlier = DateTime(2026, 9, 20, 10, 0);
      final later = DateTime(2026, 9, 20, 14, 0);

      await refundRepository.createRefund(
        createTestRefund(
          id: 'ref-first',
          orderId: 'ord-cancelled-1',
          amountPiastres: 3000,
          refundedAt: earlier,
        ),
      );

      await refundRepository.createRefund(
        createTestRefund(
          id: 'ref-second',
          orderId: 'ord-cancelled-1',
          amountPiastres: 4000,
          refundedAt: later,
        ),
      );

      final refunds = await refundRepository.getRefundsForOrder('ord-cancelled-1');
      expect(refunds.length, equals(2));
      expect(refunds[0].id, equals('ref-second')); // Newer first
      expect(refunds[1].id, equals('ref-first'));
    });

    // 4. Multiple refunds for same order.
    test('4. Multiple refunds for same order: successfully recorded up to refundable balance', () async {
      // Total paid is 20000 piastres
      await refundRepository.createRefund(
        createTestRefund(
          id: 'ref-mult-1',
          orderId: 'ord-cancelled-1',
          amountPiastres: 8000,
        ),
      );

      await refundRepository.createRefund(
        createTestRefund(
          id: 'ref-mult-2',
          orderId: 'ord-cancelled-1',
          amountPiastres: 7000,
        ),
      );

      await refundRepository.createRefund(
        createTestRefund(
          id: 'ref-mult-3',
          orderId: 'ord-cancelled-1',
          amountPiastres: 5000,
        ),
      );

      final totalRefunded = await refundRepository.getTotalRefundedForOrder('ord-cancelled-1');
      expect(totalRefunded.piastres, equals(20000));

      final remaining = await refundRepository.getRemainingRefundableForOrder('ord-cancelled-1');
      expect(remaining.piastres, equals(0));

      // Attempting any further refund exceeds balance
      expect(
        () => refundRepository.createRefund(
          createTestRefund(
            id: 'ref-mult-4',
            orderId: 'ord-cancelled-1',
            amountPiastres: 1,
          ),
        ),
        throwsA(isA<BusinessRuleFailure>()),
      );
    });

    // 5. Total refunded calculation.
    test('5. Total refunded calculation: calculates accurate sum in Money', () async {
      final initialTotal = await refundRepository.getTotalRefundedForOrder('ord-cancelled-1');
      expect(initialTotal, equals(Money.zero));

      await refundRepository.createRefund(
        createTestRefund(
          id: 'ref-tot-1',
          orderId: 'ord-cancelled-1',
          amountPiastres: 4500,
        ),
      );

      final intermediate = await refundRepository.getTotalRefundedForOrder('ord-cancelled-1');
      expect(intermediate, equals(Money.fromPiastres(4500)));

      await refundRepository.createRefund(
        createTestRefund(
          id: 'ref-tot-2',
          orderId: 'ord-cancelled-1',
          amountPiastres: 5500,
        ),
      );

      final finalTotal = await refundRepository.getTotalRefundedForOrder('ord-cancelled-1');
      expect(finalTotal, equals(Money.fromPiastres(10000)));
      expect(finalTotal.toEgp, equals(100.0));
    });

    // 6. Nullable reason.
    test('6. Nullable reason: supports both null and provided reason string', () async {
      final refNull = createTestRefund(
        id: 'ref-null-reason',
        orderId: 'ord-cancelled-1',
        amountPiastres: 2000,
        reason: null,
      );
      await refundRepository.createRefund(refNull);
      final fetchedNull = await refundRepository.getRefundById('ref-null-reason');
      expect(fetchedNull!.reason, isNull);

      final refWithReason = createTestRefund(
        id: 'ref-with-reason',
        orderId: 'ord-cancelled-1',
        amountPiastres: 2000,
        reason: 'Customer was dissatisfied',
      );
      await refundRepository.createRefund(refWithReason);
      final fetchedWith = await refundRepository.getRefundById('ref-with-reason');
      expect(fetchedWith!.reason, equals('Customer was dissatisfied'));
    });

    // 7. All supported refund methods.
    test('7. All supported refund methods: cash, instaPay, eWallet correctly persisted', () async {
      await refundRepository.createRefund(
        createTestRefund(
          id: 'ref-method-cash',
          orderId: 'ord-cancelled-1',
          amountPiastres: 1000,
          method: RefundMethod.cash,
        ),
      );

      await refundRepository.createRefund(
        createTestRefund(
          id: 'ref-method-instapay',
          orderId: 'ord-cancelled-1',
          amountPiastres: 1000,
          method: RefundMethod.instaPay,
        ),
      );

      await refundRepository.createRefund(
        createTestRefund(
          id: 'ref-method-ewallet',
          orderId: 'ord-cancelled-1',
          amountPiastres: 1000,
          method: RefundMethod.eWallet,
        ),
      );

      final cashRefund = await refundRepository.getRefundById('ref-method-cash');
      expect(cashRefund!.refundMethod, equals(RefundMethod.cash));

      final instapayRefund = await refundRepository.getRefundById('ref-method-instapay');
      expect(instapayRefund!.refundMethod, equals(RefundMethod.instaPay));

      final ewalletRefund = await refundRepository.getRefundById('ref-method-ewallet');
      expect(ewalletRefund!.refundMethod, equals(RefundMethod.eWallet));
    });

    // 8. Amount stored correctly in minor units.
    test('8. Amount stored correctly in minor units: piastres preserve exact precision', () async {
      // 123.45 EGP = 12345 piastres
      final refund = createTestRefund(
        id: 'ref-minor-units',
        orderId: 'ord-cancelled-1',
        amountPiastres: 12345,
      );
      await refundRepository.createRefund(refund);

      // Verify at database level
      final rawRow = await db.customSelect(
        'SELECT amount FROM refunds WHERE id = ?;',
        variables: [drift.Variable.withString('ref-minor-units')],
      ).getSingle();

      expect(rawRow.data['amount'], equals(12345));

      // Verify at repository domain level
      final domainRefund = await refundRepository.getRefundById('ref-minor-units');
      expect(domainRefund!.amount.piastres, equals(12345));
      expect(domainRefund.amount.toEgp, equals(123.45));
    });

    // 9. Refund data survives local database reload.
    test('9. Refund data survives local database reload: persists to disk SQLite', () async {
      final tempDir = await Directory.systemTemp.createTemp('drift_refund_test_');
      final dbFile = File('${tempDir.path}/test_refund.db');

      // 1. First DB instance: insert data
      final diskDb1 = AppDatabase(NativeDatabase(dbFile));
      final ordersDao1 = OrdersDao(diskDb1);
      final paymentsDao1 = PaymentsDao(diskDb1);
      final refundsDao1 = RefundsDao(diskDb1);
      final syncDao1 = SyncOperationsDao(diskDb1);
      final repo1 = RefundRepositoryImpl(
        refundsDao: refundsDao1,
        paymentsDao: paymentsDao1,
        ordersDao: ordersDao1,
        syncOperationsDao: syncDao1,
        db: diskDb1,
      );

      final nowTimestamp = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      await diskDb1.customStatement(
        'INSERT INTO customers (id, name, phone, created_at, updated_at) VALUES (?, ?, ?, ?, ?);',
        ['c1', 'Disk Customer', '01000000000', nowTimestamp, nowTimestamp],
      );
      await diskDb1.customStatement(
        'INSERT INTO orders (id, order_number, customer_id, status, expected_pickup_date, subtotal, total, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);',
        ['o1', '26-D1', 'c1', 'cancelled', nowTimestamp, 10000, 10000, nowTimestamp, nowTimestamp],
      );
      await diskDb1.customStatement(
        'INSERT INTO payments (id, order_id, amount, payment_method, paid_at, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?);',
        ['p1', 'o1', 10000, 'cash', nowTimestamp, nowTimestamp, nowTimestamp],
      );

      final refundToPersist = Refund(
        id: 'ref-disk-1',
        orderId: 'o1',
        amount: Money.fromPiastres(6000),
        refundMethod: RefundMethod.instaPay,
        reason: 'Survives reload',
        refundedAt: DateTime.utc(2026, 9, 24, 12, 0),
        createdAt: DateTime.utc(2026, 9, 24, 12, 0),
        updatedAt: DateTime.utc(2026, 9, 24, 12, 0),
      );

      await repo1.createRefund(refundToPersist);
      await diskDb1.close();

      // 2. Second DB instance: reload from the same file
      final diskDb2 = AppDatabase(NativeDatabase(dbFile));
      final ordersDao2 = OrdersDao(diskDb2);
      final paymentsDao2 = PaymentsDao(diskDb2);
      final refundsDao2 = RefundsDao(diskDb2);
      final syncDao2 = SyncOperationsDao(diskDb2);
      final repo2 = RefundRepositoryImpl(
        refundsDao: refundsDao2,
        paymentsDao: paymentsDao2,
        ordersDao: ordersDao2,
        syncOperationsDao: syncDao2,
        db: diskDb2,
      );

      final reloadedRefund = await repo2.getRefundById('ref-disk-1');
      expect(reloadedRefund, isNotNull);
      expect(reloadedRefund!.id, equals('ref-disk-1'));
      expect(reloadedRefund.orderId, equals('o1'));
      expect(reloadedRefund.amount.piastres, equals(6000));
      expect(reloadedRefund.refundMethod, equals(RefundMethod.instaPay));
      expect(reloadedRefund.reason, equals('Survives reload'));

      final totalRefunded = await repo2.getTotalRefundedForOrder('o1');
      expect(totalRefunded.piastres, equals(6000));

      await diskDb2.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    // 10. Refund does not modify Payment.
    test('10. Refund does not modify Payment: payments remain completely immutable', () async {
      // Snapshot payments before refund
      final paymentsBefore = await paymentsDao.getPaymentsForOrder('ord-cancelled-1');
      final totalPaidBefore = await paymentsDao.getTotalPaidForOrder('ord-cancelled-1');
      expect(paymentsBefore.length, equals(1));
      expect(paymentsBefore[0].amount, equals(20000));
      expect(totalPaidBefore, equals(20000));

      // Record a refund
      await refundRepository.createRefund(
        createTestRefund(
          id: 'ref-immutable-check',
          orderId: 'ord-cancelled-1',
          amountPiastres: 8000,
        ),
      );

      // Verify payments table after refund
      final paymentsAfter = await paymentsDao.getPaymentsForOrder('ord-cancelled-1');
      final totalPaidAfter = await paymentsDao.getTotalPaidForOrder('ord-cancelled-1');

      expect(paymentsAfter.length, equals(1));
      expect(paymentsAfter[0].id, equals(paymentsBefore[0].id));
      expect(paymentsAfter[0].amount, equals(paymentsBefore[0].amount));
      expect(paymentsAfter[0].paidAt, equals(paymentsBefore[0].paidAt));
      expect(paymentsAfter[0].paymentMethod, equals(paymentsBefore[0].paymentMethod));
      expect(totalPaidAfter, equals(20000));

      // Assert no negative payments created
      final negativePayments = await (db.select(db.payments)
            ..where((t) => t.amount.isSmallerThanValue(0)))
          .get();
      expect(negativePayments, isEmpty);

      // Assert total refunded is tracked in refunds, not payments
      final totalRefunded = await refundRepository.getTotalRefundedForOrder('ord-cancelled-1');
      expect(totalRefunded.piastres, equals(8000));

      final balanceSummary = await refundRepository.getRefundableBalanceSummary('ord-cancelled-1');
      expect(balanceSummary.totalPaid.piastres, equals(20000));
      expect(balanceSummary.totalRefunded.piastres, equals(8000));
      expect(balanceSummary.remainingRefundable.piastres, equals(12000));
    });

    // 11. Multiple refunds remain immutable.
    test('11. Multiple refunds remain immutable: records cannot be mutated', () async {
      final refund1 = createTestRefund(
        id: 'ref-imm-1',
        orderId: 'ord-cancelled-1',
        amountPiastres: 3000,
      );
      final refund2 = createTestRefund(
        id: 'ref-imm-2',
        orderId: 'ord-cancelled-1',
        amountPiastres: 4000,
      );

      await refundRepository.createRefund(refund1);
      await refundRepository.createRefund(refund2);

      final r1Before = await refundRepository.getRefundById('ref-imm-1');
      final r2Before = await refundRepository.getRefundById('ref-imm-2');

      // Add a third refund
      final refund3 = createTestRefund(
        id: 'ref-imm-3',
        orderId: 'ord-cancelled-1',
        amountPiastres: 2000,
      );
      await refundRepository.createRefund(refund3);

      final r1After = await refundRepository.getRefundById('ref-imm-1');
      final r2After = await refundRepository.getRefundById('ref-imm-2');

      expect(r1After, equals(r1Before));
      expect(r2After, equals(r2Before));
    });

    // 12. No duplicate refund row for the same local ID.
    test('12. No duplicate refund row for the same local ID: throws DatabaseFailure and preserves single row', () async {
      final refund = createTestRefund(
        id: 'ref-unique-id',
        orderId: 'ord-cancelled-1',
        amountPiastres: 5000,
      );

      await refundRepository.createRefund(refund);

      // Attempt to insert duplicate ID
      expect(
        () => refundRepository.createRefund(refund),
        throwsA(isA<DatabaseFailure>()),
      );

      // Verify only 1 row exists
      final rows = await (db.select(db.refunds)
            ..where((t) => t.id.equals('ref-unique-id')))
          .get();
      expect(rows.length, equals(1));
    });

    // Additional boundary and validation tests
    test('Fails when order is not cancelled', () async {
      final refund = createTestRefund(
        id: 'ref-active-order',
        orderId: 'ord-active-1', // Status is processing
        amountPiastres: 5000,
      );

      expect(
        () => refundRepository.createRefund(refund),
        throwsA(
          isA<BusinessRuleFailure>().having(
            (e) => e.message,
            'message',
            contains('Only cancelled orders can be refunded'),
          ),
        ),
      );
    });

    test('Fails when order does not exist', () async {
      final refund = createTestRefund(
        id: 'ref-missing-order',
        orderId: 'non-existent-order',
        amountPiastres: 5000,
      );

      expect(
        () => refundRepository.createRefund(refund),
        throwsA(
          isA<ValidationFailure>().having(
            (e) => e.message,
            'message',
            contains('Order not found'),
          ),
        ),
      );
    });

    test('Fails when refund amount exceeds refundable balance', () async {
      // Order has 20000 piastres paid
      final refund = createTestRefund(
        id: 'ref-excessive',
        orderId: 'ord-cancelled-1',
        amountPiastres: 25000,
      );

      expect(
        () => refundRepository.createRefund(refund),
        throwsA(
          isA<BusinessRuleFailure>().having(
            (e) => e.message,
            'message',
            contains('Refund amount exceeds refundable balance'),
          ),
        ),
      );
    });

    test('Watch refunds stream emits reactive updates on insert', () async {
      final stream = refundRepository.watchRefundsForOrder('ord-cancelled-1');

      expect(
        stream,
        emitsInOrder([
          isEmpty,
          hasLength(1),
          hasLength(2),
        ]),
      );

      await Future.delayed(const Duration(milliseconds: 50));
      await refundRepository.createRefund(
        createTestRefund(
          id: 'ref-watch-1',
          orderId: 'ord-cancelled-1',
          amountPiastres: 2000,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 50));
      await refundRepository.createRefund(
        createTestRefund(
          id: 'ref-watch-2',
          orderId: 'ord-cancelled-1',
          amountPiastres: 3000,
        ),
      );
    });

    test('CreateRefundUseCase contract executes successfully and returns Refund', () async {
      final useCase = CreateRefundUseCase(refundRepository);

      final result = await useCase.execute(
        CreateRefundInput(
          orderId: 'ord-cancelled-1',
          amount: Money.fromPiastres(4000),
          refundMethod: RefundMethod.eWallet,
          reason: 'Via UseCase',
        ),
      );

      expect(result.id, isNotEmpty);
      expect(result.orderId, equals('ord-cancelled-1'));
      expect(result.amount.piastres, equals(4000));
      expect(result.refundMethod, equals(RefundMethod.eWallet));
      expect(result.reason, equals('Via UseCase'));

      final fromRepo = await refundRepository.getRefundById(result.id);
      expect(fromRepo, isNotNull);
      expect(fromRepo!.amount.piastres, equals(4000));
    });
  });
}
