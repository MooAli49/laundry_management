import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/application/use_cases/change_order_status_use_case.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart' hide Order, OrderItem;
import 'package:laundry_management/data/repositories/order_repository_impl.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';

void main() {
  late AppDatabase db;
  late OrdersDao ordersDao;
  late StorageRecordsDao storageRecordsDao;
  late SyncOperationsDao syncOperationsDao;
  late OrderRepositoryImpl orderRepository;
  late ChangeOrderStatusUseCase changeOrderStatusUseCase;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ordersDao = OrdersDao(db);
    storageRecordsDao = StorageRecordsDao(db);
    syncOperationsDao = SyncOperationsDao(db);

    orderRepository = OrderRepositoryImpl(
      ordersDao: ordersDao,
      storageRecordsDao: storageRecordsDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    changeOrderStatusUseCase = ChangeOrderStatusUseCase(orderRepository);

    final nowTimestamp = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    await db.customStatement(
      'INSERT INTO customers (id, name, phone, created_at, updated_at) VALUES (?, ?, ?, ?, ?);',
      ['cust-trans', 'عميل الحالات', '01011223344', nowTimestamp, nowTimestamp],
    );
    await db.customStatement(
      'INSERT INTO services (id, name, pricing_type, price, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, 1, ?, ?);',
      ['srv-trans', 'خدمة الحالات', 'perPiece', 3000, nowTimestamp, nowTimestamp],
    );
    await db.customStatement(
      'INSERT INTO storage_locations (id, name, is_active, created_at, updated_at) VALUES (?, ?, 1, ?, ?);',
      ['loc-trans', 'موقع الحالات', nowTimestamp, nowTimestamp],
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> setupOrder({
    required String orderId,
    required OrderStatus initialStatus,
    bool storeItem = true,
  }) async {
    final now = DateTime.now();
    final order = Order(
      id: orderId,
      orderNumber: '26-200',
      customerId: 'cust-trans',
      customerNameSnapshot: 'عميل الحالات',
      customerPhoneSnapshot: '01011223344',
      status: initialStatus,
      expectedPickupDate: OrderDate(2026, 9, 15),
      subtotal: const Money.fromPiastres(3000),
      total: const Money.fromPiastres(3000),
      completedAt: initialStatus == OrderStatus.completed ? now : null,
      cancelledAt: initialStatus == OrderStatus.cancelled ? now : null,
      cancellationReason: initialStatus == OrderStatus.cancelled ? 'سبب تجريبي' : null,
      createdAt: now,
      updatedAt: now,
    );

    final item = OrderItem(
      id: 'item-$orderId',
      orderId: orderId,
      itemTypeId: '00000000-0000-0000-0001-000000000001',
      serviceId: 'srv-trans',
      itemTypeNameSnapshot: 'ملابس',
      serviceNameSnapshot: 'خدمة الحالات',
      pricingType: PricingType.perPiece,
      quantity: 1.0,
      unitPrice: const Money.fromPiastres(3000),
      calculatedTotal: const Money.fromPiastres(3000),
      createdAt: now,
      updatedAt: now,
    );

    await orderRepository.createOrder(order: order, items: [item]);

    if (storeItem) {
      final nowTimestamp = now.toUtc().millisecondsSinceEpoch ~/ 1000;
      await db.customStatement(
        'INSERT INTO storage_records (id, order_item_id, storage_location_id, is_active, created_at, updated_at) '
        'VALUES (?, ?, ?, 1, ?, ?);',
        ['rec-$orderId', 'item-$orderId', 'loc-trans', nowTimestamp, nowTimestamp],
      );
    }
  }

  group('Status Transitions Hardening Tests', () {
    test('Ready -> Processing requires non-empty reason', () async {
      await setupOrder(orderId: 'ord-r2p', initialStatus: OrderStatus.ready);

      // Empty reason
      expect(
        () => changeOrderStatusUseCase.execute(
          const ChangeOrderStatusInput(
            orderId: 'ord-r2p',
            newStatus: OrderStatus.processing,
            reason: '',
          ),
        ),
        throwsA(
          isA<ValidationFailure>().having(
            (e) => e.message,
            'message',
            contains('reason is required'),
          ),
        ),
      );

      // Whitespace only
      expect(
        () => changeOrderStatusUseCase.execute(
          const ChangeOrderStatusInput(
            orderId: 'ord-r2p',
            newStatus: OrderStatus.processing,
            reason: '   ',
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('Ready -> Processing deactivates active storage, keeps historical records, does not recreate storage', () async {
      await setupOrder(orderId: 'ord-r2p-storage', initialStatus: OrderStatus.ready, storeItem: true);

      // Before transition: active record exists
      final activeBefore = await storageRecordsDao.getActiveRecordForOrderItem('item-ord-r2p-storage');
      expect(activeBefore, isNotNull);
      expect(activeBefore!.isActive, isTrue);

      final updated = await changeOrderStatusUseCase.execute(
        const ChangeOrderStatusInput(
          orderId: 'ord-r2p-storage',
          newStatus: OrderStatus.processing,
          reason: 'تصحيح حالة للغسيل الإضافي',
        ),
      );

      expect(updated.status, OrderStatus.processing);

      // Active storage record MUST be deactivated
      final activeAfter = await storageRecordsDao.getActiveRecordForOrderItem('item-ord-r2p-storage');
      expect(activeAfter, isNull);

      // Historical storage record is preserved
      final allRecords = await (db.select(db.storageRecords)
            ..where((t) => t.orderItemId.equals('item-ord-r2p-storage')))
          .get();
      expect(allRecords.length, 1);
      expect(allRecords.first.isActive, isFalse);
    });

    test('Processing -> Ready rejected when physical items are unstored', () async {
      await setupOrder(orderId: 'ord-p2r-unstored', initialStatus: OrderStatus.processing, storeItem: false);

      // Attempt with valid reason but items are not stored
      expect(
        () => changeOrderStatusUseCase.execute(
          const ChangeOrderStatusInput(
            orderId: 'ord-p2r-unstored',
            newStatus: OrderStatus.ready,
            reason: 'تجاوز يدوي مع عدم التخزين',
          ),
        ),
        throwsA(
          isA<BusinessRuleFailure>().having(
            (e) => e.message,
            'message',
            contains('لم يتم تخزين جميع القطع بعد'),
          ),
        ),
      );

      // Order status remains processing
      final orderAfter = await orderRepository.getOrderById('ord-p2r-unstored');
      expect(orderAfter!.status, OrderStatus.processing);

      // Storage remains untouched
      final allRecords = await (db.select(db.storageRecords)
            ..where((t) => t.orderItemId.equals('item-ord-p2r-unstored')))
          .get();
      expect(allRecords.isEmpty, isTrue);
    });

    test('Processing -> Ready succeeds when all items are stored and requires reason', () async {
      await setupOrder(orderId: 'ord-p2r-stored', initialStatus: OrderStatus.processing, storeItem: true);

      // Empty reason rejected
      expect(
        () => changeOrderStatusUseCase.execute(
          const ChangeOrderStatusInput(
            orderId: 'ord-p2r-stored',
            newStatus: OrderStatus.ready,
            reason: '',
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );

      // Valid reason with stored items succeeds
      final updated = await changeOrderStatusUseCase.execute(
        const ChangeOrderStatusInput(
          orderId: 'ord-p2r-stored',
          newStatus: OrderStatus.ready,
          reason: 'تصحيح الحالة بعد التأكد من التخزين',
        ),
      );

      expect(updated.status, OrderStatus.ready);

      // Active storage records remain active and untouched
      final activeRecord = await storageRecordsDao.getActiveRecordForOrderItem('item-ord-p2r-stored');
      expect(activeRecord, isNotNull);
      expect(activeRecord!.isActive, isTrue);
    });

    test('Ready -> Completed rejected through generic status change', () async {
      await setupOrder(orderId: 'ord-r2c', initialStatus: OrderStatus.ready);

      expect(
        () => changeOrderStatusUseCase.execute(
          const ChangeOrderStatusInput(
            orderId: 'ord-r2c',
            newStatus: OrderStatus.completed,
          ),
        ),
        throwsA(isA<InvalidOrderTransitionFailure>()),
      );
    });

    test('Completed -> Processing requires reason and does NOT reactivate storage', () async {
      await setupOrder(orderId: 'ord-c2p', initialStatus: OrderStatus.completed, storeItem: false);

      // Empty reason rejected
      expect(
        () => changeOrderStatusUseCase.execute(
          const ChangeOrderStatusInput(
            orderId: 'ord-c2p',
            newStatus: OrderStatus.processing,
            reason: '   ',
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );

      // Valid reason
      final updated = await changeOrderStatusUseCase.execute(
        const ChangeOrderStatusInput(
          orderId: 'ord-c2p',
          newStatus: OrderStatus.processing,
          reason: 'إعادة فتح الطلب لطلب خدمة إضافية',
        ),
      );

      expect(updated.status, OrderStatus.processing);
      expect(updated.completedAt, isNull);

      // Storage remains inactive (0 records)
      final allRecords = await (db.select(db.storageRecords)
            ..where((t) => t.orderItemId.equals('item-ord-c2p')))
          .get();
      expect(allRecords.isEmpty, isTrue);
    });

    test('Cancelled cannot transition to any status', () async {
      await setupOrder(orderId: 'ord-canc', initialStatus: OrderStatus.cancelled, storeItem: false);

      for (final targetStatus in [OrderStatus.processing, OrderStatus.ready, OrderStatus.completed]) {
        expect(
          () => changeOrderStatusUseCase.execute(
            ChangeOrderStatusInput(
              orderId: 'ord-canc',
              newStatus: targetStatus,
              reason: 'محاولة تصحيح',
            ),
          ),
          throwsA(isA<InvalidOrderTransitionFailure>()),
        );
      }
    });
  });
}
