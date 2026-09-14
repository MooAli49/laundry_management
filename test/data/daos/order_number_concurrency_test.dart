import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart' hide Order, OrderItem;
import 'package:laundry_management/data/repositories/order_repository_impl.dart';
import 'package:laundry_management/domain/entities/order.dart' as domain;
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

    // Setup foreign key dependencies
    final nowTimestamp = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    await db.customStatement(
      'INSERT INTO customers (id, name, phone, created_at, updated_at) VALUES (?, ?, ?, ?, ?);',
      ['cust-test', 'عميل تجريبي', '01011112222', nowTimestamp, nowTimestamp],
    );
    await db.customStatement(
      'INSERT INTO services (id, name, pricing_type, price, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, 1, ?, ?);',
      ['srv-test', 'غسيل تجريبي', 'perPiece', 2000, nowTimestamp, nowTimestamp],
    );
  });

  tearDown(() async {
    await db.close();
  });

  domain.Order createDraftOrder({
    required String id,
    String orderNumber = '',
  }) {
    final now = DateTime.now();
    return domain.Order(
      id: id,
      orderNumber: orderNumber,
      customerId: 'cust-test',
      customerNameSnapshot: 'عميل التزامن',
      customerPhoneSnapshot: '01011223344',
      status: OrderStatus.processing,
      expectedPickupDate: OrderDate(2026, 9, 15),
      subtotal: const Money.fromPiastres(2000),
      total: const Money.fromPiastres(2000),
      createdAt: now,
      updatedAt: now,
    );
  }

  OrderItem createOrderItem({
    required String id,
    required String orderId,
  }) {
    final now = DateTime.now();
    return OrderItem(
      id: id,
      orderId: orderId,
      itemTypeId: '00000000-0000-0000-0001-000000000001',
      serviceId: 'srv-test',
      itemTypeNameSnapshot: 'ملابس',
      serviceNameSnapshot: 'غسيل تجريبي',
      pricingType: PricingType.perPiece,
      quantity: 1.0,
      unitPrice: const Money.fromPiastres(2000),
      calculatedTotal: const Money.fromPiastres(2000),
      createdAt: now,
      updatedAt: now,
    );
  }

  group('Order Number Concurrency & Format & Immutability', () {
    test('order numbers follow YY-XXX format strictly and sequential generation', () async {
      final now = DateTime.now();
      final yearPrefix = (now.year % 100).toString().padLeft(2, '0');

      final num1 = await ordersDao.generateNextOrderNumber();
      expect(num1, '$yearPrefix-001');

      // Create first order
      final order1 = await orderRepository.createOrder(
        order: createDraftOrder(id: 'ord-1'),
        items: [createOrderItem(id: 'item-1', orderId: 'ord-1')],
      );
      expect(order1.orderNumber, '$yearPrefix-001');

      // Next generated number should be 002
      final num2 = await ordersDao.generateNextOrderNumber();
      expect(num2, '$yearPrefix-002');

      final order2 = await orderRepository.createOrder(
        order: createDraftOrder(id: 'ord-2'),
        items: [createOrderItem(id: 'item-2', orderId: 'ord-2')],
      );
      expect(order2.orderNumber, '$yearPrefix-002');
    });

    test('order number collision triggers entire transaction retry and succeeds', () async {
      final now = DateTime.now();
      final yearPrefix = (now.year % 100).toString().padLeft(2, '0');
      final collidingNumber = '$yearPrefix-001';

      // Manually insert an order with 'YY-001' to create a collision condition
      final nowTimestamp = now.toUtc().millisecondsSinceEpoch ~/ 1000;
      await db.customStatement(
        'INSERT INTO orders (id, order_number, customer_id, status, expected_pickup_date, '
        'subtotal, total, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);',
        ['colliding-ord', collidingNumber, 'cust-test', 'processing', nowTimestamp, 2000, 2000, nowTimestamp, nowTimestamp],
      );

      // Inject _CollidingOrdersDao to force Attempt 1 to generate the existing order number ('YY-001').
      // This guarantees an actual SQLite UNIQUE constraint violation during Attempt 1.
      final testOrdersDao = _CollidingOrdersDao(db, collidingNumber: collidingNumber);
      final testOrderRepo = OrderRepositoryImpl(
        ordersDao: testOrdersDao,
        storageRecordsDao: storageRecordsDao,
        syncOperationsDao: syncOperationsDao,
        db: db,
      );

      // Now call createOrder without orderNumber.
      // Attempt 1: generates 'YY-001' -> UNIQUE collision -> transaction rolls back.
      // Attempt 2: generates 'YY-002' -> succeeds -> transaction commits.
      final created = await testOrderRepo.createOrder(
        order: createDraftOrder(id: 'ord-new'),
        items: [createOrderItem(id: 'item-new', orderId: 'ord-new')],
      );

      // Verify Attempt 1 collided, rolled back, and Attempt 2 succeeded
      expect(testOrdersDao.generateCallCount, 2);
      expect(testOrdersDao.generatedNumbers, [collidingNumber, '$yearPrefix-002']);
      expect(created.orderNumber, '$yearPrefix-002');

      // Verify the persisted order in database
      final persisted = await ordersDao.getOrderById('ord-new');
      expect(persisted, isNotNull);
      expect(persisted!.orderNumber, '$yearPrefix-002');

      // Verify transaction atomicity: items from rolled-back Attempt 1 do not linger
      final items = await (db.select(db.orderItems)..where((t) => t.orderId.equals('ord-new'))).get();
      expect(items.length, 1);
      expect(items.first.id, 'item-new');

      // Verify sync operation was recorded only once
      final syncOps = await (db.select(db.syncOperations)..where((t) => t.entityId.equals('ord-new'))).get();
      expect(syncOps.length, 1);
    });

    test('order number collision exhausts 5 retries and rolls back transaction', () async {
      final now = DateTime.now();
      final yearPrefix = (now.year % 100).toString().padLeft(2, '0');
      final collidingNumber = '$yearPrefix-001';

      // Manually insert an order with 'YY-001'
      final nowTimestamp = now.toUtc().millisecondsSinceEpoch ~/ 1000;
      await db.customStatement(
        'INSERT INTO orders (id, order_number, customer_id, status, expected_pickup_date, '
        'subtotal, total, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);',
        ['colliding-ord-exhaust', collidingNumber, 'cust-test', 'processing', nowTimestamp, 2000, 2000, nowTimestamp, nowTimestamp],
      );

      final alwaysCollidingDao = _AlwaysCollidingOrdersDao(db, collidingNumber: collidingNumber);
      final testOrderRepo = OrderRepositoryImpl(
        ordersDao: alwaysCollidingDao,
        storageRecordsDao: storageRecordsDao,
        syncOperationsDao: syncOperationsDao,
        db: db,
      );

      await expectLater(
        () => testOrderRepo.createOrder(
          order: createDraftOrder(id: 'ord-fail'),
          items: [createOrderItem(id: 'item-fail', orderId: 'ord-fail')],
        ),
        throwsA(isA<DatabaseFailure>()),
      );

      // Verify all 5 attempts were made before giving up
      expect(alwaysCollidingDao.generateCallCount, 5);

      // Verify transaction was rolled back and order was NOT saved
      final persisted = await ordersDao.getOrderById('ord-fail');
      expect(persisted, isNull);

      final items = await (db.select(db.orderItems)..where((t) => t.orderId.equals('ord-fail'))).get();
      expect(items, isEmpty);
    });

    test('rapid / concurrent order creations succeed without collisions or duplicates', () async {
      final now = DateTime.now();
      final yearPrefix = (now.year % 100).toString().padLeft(2, '0');

      // Launch 10 orders concurrently
      final futures = <Future<domain.Order>>[];
      for (var i = 1; i <= 10; i++) {
        futures.add(
          orderRepository.createOrder(
            order: createDraftOrder(id: 'concurrent-ord-$i'),
            items: [createOrderItem(id: 'concurrent-item-$i', orderId: 'concurrent-ord-$i')],
          ),
        );
      }

      final createdOrders = await Future.wait(futures);

      // Check that all 10 orders were created
      expect(createdOrders.length, 10);

      // Extract order numbers
      final orderNumbers = createdOrders.map((o) => o.orderNumber).toSet();
      // All order numbers must be unique
      expect(orderNumbers.length, 10);

      // All order numbers must match YY-XXX regex
      final pattern = RegExp(r'^\d{2}-\d{3}$');
      for (final num in orderNumbers) {
        expect(pattern.hasMatch(num), isTrue);
        expect(num.startsWith('$yearPrefix-'), isTrue);
      }
    });

    test('Order Number is immutable and cannot be changed on update', () async {
      final created = await orderRepository.createOrder(
        order: createDraftOrder(id: 'ord-immut'),
        items: [createOrderItem(id: 'item-immut', orderId: 'ord-immut')],
      );
      final originalNumber = created.orderNumber;

      // Attempt to update with a different orderNumber
      final mutatedOrder = created.copyWith(orderNumber: '99-999');

      expect(
        () => orderRepository.updateOrder(mutatedOrder),
        throwsA(
          isA<BusinessRuleFailure>().having(
            (e) => e.message,
            'message',
            contains('Order number is immutable and cannot be changed'),
          ),
        ),
      );

      // Re-read from database and verify order number is unchanged
      final reloaded = await ordersDao.getOrderById('ord-immut');
      expect(reloaded!.orderNumber, originalNumber);
    });
  });
}

class _CollidingOrdersDao extends OrdersDao {
  _CollidingOrdersDao(super.db, {required this.collidingNumber});

  final String collidingNumber;
  int generateCallCount = 0;
  final List<String> generatedNumbers = [];

  @override
  Future<String> generateNextOrderNumber() async {
    generateCallCount++;
    if (generateCallCount == 1) {
      // Return existing order number to guarantee SQLite UNIQUE constraint collision on attempt 1
      generatedNumbers.add(collidingNumber);
      return collidingNumber;
    }
    final next = await super.generateNextOrderNumber();
    generatedNumbers.add(next);
    return next;
  }
}

class _AlwaysCollidingOrdersDao extends OrdersDao {
  _AlwaysCollidingOrdersDao(super.db, {required this.collidingNumber});

  final String collidingNumber;
  int generateCallCount = 0;

  @override
  Future<String> generateNextOrderNumber() async {
    generateCallCount++;
    return collidingNumber;
  }
}
