import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:laundry_management/application/use_cases/create_refund_use_case.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/refunds_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart';
import 'package:laundry_management/data/repositories/refund_repository_impl.dart';
import 'package:laundry_management/domain/enums/refund_method.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/features/orders/presentation/cubit/refund_cubit.dart';

void main() {
  late AppDatabase db;
  late RefundsDao refundsDao;
  late PaymentsDao paymentsDao;
  late OrdersDao ordersDao;
  late SyncOperationsDao syncOperationsDao;
  late RefundRepositoryImpl refundRepository;
  late CreateRefundUseCase createRefundUseCase;
  late RefundCubit refundCubit;

  const testOrderId = 'ord-flow-123';
  const testCustomerId = 'cust-flow-123';

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

    createRefundUseCase = CreateRefundUseCase(refundRepository);
    refundCubit = RefundCubit(createRefundUseCase: createRefundUseCase);

    final nowTimestamp = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

    // Seed customer
    await db.customStatement(
      'INSERT INTO customers (id, name, phone, created_at, updated_at) VALUES (?, ?, ?, ?, ?);',
      [testCustomerId, 'عميل التدفق', '01099998888', nowTimestamp, nowTimestamp],
    );

    // Seed Cancelled Order (total = 10000 piastres = 100.00 EGP)
    await db.customStatement(
      'INSERT INTO orders (id, order_number, customer_id, status, expected_pickup_date, '
      'subtotal, total, discount, tax, cancelled_at, cancellation_reason, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
      [
        testOrderId,
        'ORD-FLOW-01',
        testCustomerId,
        'cancelled',
        nowTimestamp + 86400,
        10000,
        10000,
        0,
        0,
        nowTimestamp,
        'طلب العميل الإلغاء',
        nowTimestamp,
        nowTimestamp,
      ],
    );

    // Seed Payment (10000 piastres = 100.00 EGP paid in full)
    await db.customStatement(
      'INSERT INTO payments (id, order_id, amount, payment_method, paid_at, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?);',
      [
        'pay-flow-01',
        testOrderId,
        10000,
        'cash',
        nowTimestamp,
        nowTimestamp,
        nowTimestamp,
      ],
    );
  });

  tearDown(() async {
    await refundCubit.close();
    await db.close();
  });

  group('Refund Flow Integration & Invariants (Part O: 19-27)', () {
    test(
      '19 & 20. Offline local refund creation succeeds and creates Refund row + exactly 1 outbox operation',
      () async {
        // Create 30.00 EGP refund via Cubit
        await refundCubit.submitRefund(
          orderId: testOrderId,
          amount: Money.fromPiastres(3000),
          refundMethod: RefundMethod.cash,
          reason: 'استرجاع جزئي أول',
        );

        expect(refundCubit.state.isSuccess, isTrue);
        final createdRefund = refundCubit.state.refund!;

        // 19a. Verify Refund row in local Drift database
        final storedRefund = await refundsDao.getRefundById(createdRefund.id);
        expect(storedRefund, isNotNull);
        expect(storedRefund?.orderId, testOrderId);
        expect(storedRefund?.amount, 3000);
        expect(storedRefund?.refundMethod, 'cash');
        expect(storedRefund?.reason, 'استرجاع جزئي أول');

        // 19b. Verify exactly one outbox operation in sync_operations
        final pendingOps = await syncOperationsDao.getPendingOperations();
        final refundOps =
            pendingOps.where((op) => op.entityType == 'refund').toList();
        expect(refundOps.length, 1);
        expect(refundOps.first.operationType, 'create');
        expect(refundOps.first.entityId, createdRefund.id);
      },
    );

    test(
      '21-25. Order & Payment invariants are strictly preserved after refund creation',
      () async {
        // Initial state verification
        final orderBefore = await ordersDao.getOrderById(testOrderId);
        final paymentsBefore = await paymentsDao.getPaymentsForOrder(testOrderId);
        final totalPaidBefore =
            await paymentsDao.getTotalPaidForOrder(testOrderId);

        expect(orderBefore?.total, 10000);
        expect(orderBefore?.status, 'cancelled');
        expect(paymentsBefore.length, 1);
        expect(totalPaidBefore, 10000);

        // Perform refund
        await refundCubit.submitRefund(
          orderId: testOrderId,
          amount: Money.fromPiastres(4000),
          refundMethod: RefundMethod.instaPay,
          reason: 'تحقق من الثوابت',
        );
        expect(refundCubit.state.isSuccess, isTrue);

        // 21. Existing payments remain completely unchanged
        final paymentsAfter = await paymentsDao.getPaymentsForOrder(testOrderId);
        expect(paymentsAfter.length, paymentsBefore.length);
        expect(paymentsAfter.first.id, paymentsBefore.first.id);
        expect(paymentsAfter.first.amount, paymentsBefore.first.amount);
        expect(paymentsAfter.first.paymentMethod, paymentsBefore.first.paymentMethod);
        expect(paymentsAfter.first.paidAt, paymentsBefore.first.paidAt);

        // 22. Order total remains unchanged
        final orderAfter = await ordersDao.getOrderById(testOrderId);
        expect(orderAfter?.total, 10000);
        expect(orderAfter?.total, orderBefore?.total);

        // 23. Order paid amount remains unchanged
        final totalPaidAfter =
            await paymentsDao.getTotalPaidForOrder(testOrderId);
        expect(totalPaidAfter, 10000);
        expect(totalPaidAfter, totalPaidBefore);

        // 24. Order remaining remains unchanged
        final remainingPiastres = (orderAfter?.total ?? 0) - totalPaidAfter;
        expect(remainingPiastres, 0);

        // 25. Order status remains cancelled
        expect(orderAfter?.status, 'cancelled');
      },
    );

    test(
      '26 & 27. Multiple refunds update balance correctly; full refund zeroes balance; further refunds rejected',
      () async {
        // Starting balance: Paid = 100.00 EGP, Refunded = 0, Refundable = 100.00 EGP
        var balance =
            await refundRepository.getRefundableBalanceSummary(testOrderId);
        expect(balance.totalPaid, Money.fromPiastres(10000));
        expect(balance.totalRefunded, Money.zero);
        expect(balance.remainingRefundable, Money.fromPiastres(10000));

        // Refund #1 = 30.00 EGP
        await refundCubit.submitRefund(
          orderId: testOrderId,
          amount: Money.fromPiastres(3000),
          refundMethod: RefundMethod.cash,
        );
        expect(refundCubit.state.isSuccess, isTrue);

        balance = await refundRepository.getRefundableBalanceSummary(testOrderId);
        expect(balance.totalRefunded, Money.fromPiastres(3000));
        expect(balance.remainingRefundable, Money.fromPiastres(7000));

        // Refund #2 = 20.00 EGP
        refundCubit.reset();
        await refundCubit.submitRefund(
          orderId: testOrderId,
          amount: Money.fromPiastres(2000),
          refundMethod: RefundMethod.instaPay,
        );
        expect(refundCubit.state.isSuccess, isTrue);

        balance = await refundRepository.getRefundableBalanceSummary(testOrderId);
        expect(balance.totalRefunded, Money.fromPiastres(5000));
        expect(balance.remainingRefundable, Money.fromPiastres(5000));

        // 27. Full refund of remaining 50.00 EGP
        refundCubit.reset();
        await refundCubit.submitRefund(
          orderId: testOrderId,
          amount: Money.fromPiastres(5000),
          refundMethod: RefundMethod.eWallet,
        );
        expect(refundCubit.state.isSuccess, isTrue);

        balance = await refundRepository.getRefundableBalanceSummary(testOrderId);
        expect(balance.totalRefunded, Money.fromPiastres(10000));
        expect(balance.remainingRefundable, Money.zero);

        // Attempting an additional refund must be rejected
        refundCubit.reset();
        await refundCubit.submitRefund(
          orderId: testOrderId,
          amount: Money.fromPiastres(1000),
          refundMethod: RefundMethod.cash,
        );
        expect(refundCubit.state.hasError, isTrue);
        expect(
          refundCubit.state.errorMessage,
          contains('مبلغ الاسترداد يتجاوز المبلغ القابل للاسترداد'),
        );

        // Balance remains unchanged at zero refundable
        balance = await refundRepository.getRefundableBalanceSummary(testOrderId);
        expect(balance.totalRefunded, Money.fromPiastres(10000));
        expect(balance.remainingRefundable, Money.zero);

        // Verify exactly 3 outbox operations exist for the 3 accepted refunds
        final pendingOps = await syncOperationsDao.getPendingOperations();
        final refundOps =
            pendingOps.where((op) => op.entityType == 'refund').toList();
        expect(refundOps.length, 3);
      },
    );
  });
}
