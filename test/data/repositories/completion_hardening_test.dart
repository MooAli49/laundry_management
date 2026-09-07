import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart' hide Order, OrderItem, Payment;
import 'package:laundry_management/data/repositories/order_repository_impl.dart';
import 'package:laundry_management/data/repositories/payment_repository_impl.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/entities/payment.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/enums/payment_method.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';

void main() {
  late AppDatabase db;
  late OrdersDao ordersDao;
  late StorageRecordsDao storageRecordsDao;
  late SyncOperationsDao syncOperationsDao;
  late PaymentsDao paymentsDao;
  late OrderRepositoryImpl orderRepository;
  late PaymentRepositoryImpl paymentRepository;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ordersDao = OrdersDao(db);
    storageRecordsDao = StorageRecordsDao(db);
    syncOperationsDao = SyncOperationsDao(db);
    paymentsDao = PaymentsDao(db);

    orderRepository = OrderRepositoryImpl(
      ordersDao: ordersDao,
      storageRecordsDao: storageRecordsDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    paymentRepository = PaymentRepositoryImpl(
      paymentsDao: paymentsDao,
      ordersDao: ordersDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    final nowTimestamp = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    await db.customStatement(
      'INSERT INTO customers (id, name, phone, created_at, updated_at) VALUES (?, ?, ?, ?, ?);',
      ['cust-comp', 'عميل التسليم', '01012341234', nowTimestamp, nowTimestamp],
    );
    await db.customStatement(
      'INSERT INTO services (id, name, pricing_type, price, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, 1, ?, ?);',
      ['srv-comp', 'خدمة التسليم', 'perPiece', 5000, nowTimestamp, nowTimestamp],
    );
    await db.customStatement(
      'INSERT INTO storage_locations (id, name, is_active, created_at, updated_at) VALUES (?, ?, 1, ?, ?);',
      ['loc-comp', 'موقع التسليم', nowTimestamp, nowTimestamp],
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> setupOrder({
    required String orderId,
    required OrderStatus initialStatus,
    required int totalPiastres,
    bool storeItem = true,
  }) async {
    final now = DateTime.now();
    final order = Order(
      id: orderId,
      orderNumber: '26-100',
      customerId: 'cust-comp',
      status: initialStatus,
      expectedPickupDate: OrderDate(2026, 9, 15),
      subtotal: Money.fromPiastres(totalPiastres),
      total: Money.fromPiastres(totalPiastres),
      createdAt: now,
      updatedAt: now,
    );

    final item = OrderItem(
      id: 'item-$orderId',
      orderId: orderId,
      itemTypeId: '00000000-0000-0000-0001-000000000001',
      serviceId: 'srv-comp',
      itemTypeNameSnapshot: 'ملابس',
      serviceNameSnapshot: 'خدمة التسليم',
      pricingType: PricingType.perPiece,
      quantity: 1.0,
      unitPrice: Money.fromPiastres(totalPiastres),
      calculatedTotal: Money.fromPiastres(totalPiastres),
      createdAt: now,
      updatedAt: now,
    );

    await orderRepository.createOrder(order: order, items: [item]);

    if (storeItem) {
      final nowTimestamp = now.toUtc().millisecondsSinceEpoch ~/ 1000;
      await db.customStatement(
        'INSERT INTO storage_records (id, order_item_id, storage_location_id, is_active, created_at, updated_at) '
        'VALUES (?, ?, ?, 1, ?, ?);',
        ['rec-$orderId', 'item-$orderId', 'loc-comp', nowTimestamp, nowTimestamp],
      );
    }
  }

  group('OrderRepositoryImpl Completion Hardening Tests', () {
    test('status != Ready is rejected with BusinessRuleFailure', () async {
      await setupOrder(orderId: 'ord-proc', initialStatus: OrderStatus.processing, totalPiastres: 5000);

      expect(
        () => orderRepository.completeOrder(
          orderId: 'ord-proc',
          handoverConfirmed: true,
        ),
        throwsA(
          isA<BusinessRuleFailure>().having(
            (e) => e.message,
            'message',
            contains('Only Ready orders can be completed'),
          ),
        ),
      );
    });

    test('remaining > 0 is rejected with BusinessRuleFailure', () async {
      await setupOrder(orderId: 'ord-unpaid', initialStatus: OrderStatus.ready, totalPiastres: 5000);

      // Attempt completion when 0 paid out of 5000
      expect(
        () => orderRepository.completeOrder(
          orderId: 'ord-unpaid',
          handoverConfirmed: true,
        ),
        throwsA(
          isA<BusinessRuleFailure>().having(
            (e) => e.message,
            'message',
            contains('remaining balance'),
          ),
        ),
      );

      // Add partial payment of 3000 (remaining is 2000)
      final now = DateTime.now();
      await paymentRepository.recordPayment(
        Payment(
          id: 'pay-part',
          orderId: 'ord-unpaid',
          amount: const Money.fromPiastres(3000),
          paymentMethod: PaymentMethod.cash,
          paidAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Still rejected because remaining is 2000
      expect(
        () => orderRepository.completeOrder(
          orderId: 'ord-unpaid',
          handoverConfirmed: true,
        ),
        throwsA(isA<BusinessRuleFailure>()),
      );
    });

    test('handoverConfirmed == false is rejected with BusinessRuleFailure', () async {
      await setupOrder(orderId: 'ord-no-handover', initialStatus: OrderStatus.ready, totalPiastres: 5000);

      final now = DateTime.now();
      await paymentRepository.recordPayment(
        Payment(
          id: 'pay-full1',
          orderId: 'ord-no-handover',
          amount: const Money.fromPiastres(5000),
          paymentMethod: PaymentMethod.cash,
          paidAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(
        () => orderRepository.completeOrder(
          orderId: 'ord-no-handover',
          handoverConfirmed: false,
        ),
        throwsA(
          isA<BusinessRuleFailure>().having(
            (e) => e.message,
            'message',
            contains('handover confirmation is required'),
          ),
        ),
      );
    });

    test('successful completion sets status Completed, completedAt, Option A getter, and deactivates storage', () async {
      await setupOrder(orderId: 'ord-success', initialStatus: OrderStatus.ready, totalPiastres: 5000);

      final now = DateTime.now();
      await paymentRepository.recordPayment(
        Payment(
          id: 'pay-success',
          orderId: 'ord-success',
          amount: const Money.fromPiastres(5000),
          paymentMethod: PaymentMethod.cash,
          paidAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Verify storage record is active before completion
      final activeBefore = await storageRecordsDao.getActiveRecordForOrderItem('item-ord-success');
      expect(activeBefore, isNotNull);

      final completed = await orderRepository.completeOrder(
        orderId: 'ord-success',
        handoverConfirmed: true,
      );

      expect(completed.status, OrderStatus.completed);
      expect(completed.completedAt, isNotNull);
      expect(completed.customerHandoverConfirmedAt, completed.completedAt);

      // Storage record MUST be deactivated
      final activeAfter = await storageRecordsDao.getActiveRecordForOrderItem('item-ord-success');
      expect(activeAfter, isNull);

      // Historical storage record is preserved
      final allRecords = await (db.select(db.storageRecords)
            ..where((t) => t.orderItemId.equals('item-ord-success')))
          .get();
      expect(allRecords.length, 1);
      expect(allRecords.first.isActive, isFalse);
    });

    test('completion is atomic: if payment check or invariant fails, no changes persist', () async {
      await setupOrder(orderId: 'ord-atomic', initialStatus: OrderStatus.ready, totalPiastres: 5000);

      // Storage is active
      final activeBefore = await storageRecordsDao.getActiveRecordForOrderItem('item-ord-atomic');
      expect(activeBefore, isNotNull);

      // Attempt completion while unpaid
      try {
        await orderRepository.completeOrder(orderId: 'ord-atomic', handoverConfirmed: true);
      } catch (_) {}

      // Order must still be Ready, completedAt null, storage STILL active
      final orderAfter = await ordersDao.getOrderById('ord-atomic');
      expect(orderAfter!.status, 'ready');
      expect(orderAfter.completedAt, isNull);

      final activeAfter = await storageRecordsDao.getActiveRecordForOrderItem('item-ord-atomic');
      expect(activeAfter, isNotNull);
    });
  });
}
