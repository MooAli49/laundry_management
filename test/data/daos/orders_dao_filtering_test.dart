import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/local/daos/customers_dao.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart'
    as db_pkg;
import 'package:laundry_management/domain/enums/order_status.dart';

void main() {
  late db_pkg.AppDatabase db;
  late CustomersDao customersDao;
  late OrdersDao ordersDao;
  late PaymentsDao paymentsDao;

  setUp(() async {
    db = db_pkg.AppDatabase(NativeDatabase.memory());
    customersDao = CustomersDao(db);
    ordersDao = OrdersDao(db);
    paymentsDao = PaymentsDao(db);

    // Seed 2 customers
    await customersDao.insertCustomer(
      db_pkg.CustomersCompanion.insert(
        id: 'cust-ahmed',
        name: 'أحمد محمود',
        phone: '01011112222',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );

    await customersDao.insertCustomer(
      db_pkg.CustomersCompanion.insert(
        id: 'cust-sara',
        name: 'سارة إبراهيم',
        phone: '01033334444',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );

    // Seed Orders:
    // Order 1: Ahmed, processing, total 5000, paid 2000 (hasRemaining = true)
    await ordersDao.insertOrder(
      db_pkg.OrdersCompanion.insert(
        id: 'ord-1',
        orderNumber: '26-001',
        customerId: 'cust-ahmed',
        status: Value(OrderStatus.processing.value),
        expectedPickupDate: DateTime(2026, 9, 10),
        subtotal: 5000,
        total: 5000,
        createdAt: DateTime(2026, 9, 1, 10, 0),
        updatedAt: DateTime(2026, 9, 1, 10, 0),
      ),
    );
    await paymentsDao.insertPayment(
      db_pkg.PaymentsCompanion.insert(
        id: 'pay-1',
        orderId: 'ord-1',
        amount: 2000,
        paymentMethod: 'cash',
        paidAt: DateTime(2026, 9, 1, 10, 5),
        createdAt: DateTime(2026, 9, 1, 10, 5),
        updatedAt: DateTime(2026, 9, 1, 10, 5),
      ),
    );

    // Order 2: Ahmed, ready, total 3000, paid 3000 (hasRemaining = false)
    await ordersDao.insertOrder(
      db_pkg.OrdersCompanion.insert(
        id: 'ord-2',
        orderNumber: '26-002',
        customerId: 'cust-ahmed',
        status: Value(OrderStatus.ready.value),
        expectedPickupDate: DateTime(2026, 9, 11),
        subtotal: 3000,
        total: 3000,
        createdAt: DateTime(2026, 9, 2, 10, 0),
        updatedAt: DateTime(2026, 9, 2, 10, 0),
      ),
    );
    await paymentsDao.insertPayment(
      db_pkg.PaymentsCompanion.insert(
        id: 'pay-2',
        orderId: 'ord-2',
        amount: 3000,
        paymentMethod: 'instapay',
        paidAt: DateTime(2026, 9, 2, 10, 5),
        createdAt: DateTime(2026, 9, 2, 10, 5),
        updatedAt: DateTime(2026, 9, 2, 10, 5),
      ),
    );

    // Order 3: Sara, completed, total 8000, paid 8000 (hasRemaining = false)
    await ordersDao.insertOrder(
      db_pkg.OrdersCompanion.insert(
        id: 'ord-3',
        orderNumber: '26-003',
        customerId: 'cust-sara',
        status: Value(OrderStatus.completed.value),
        expectedPickupDate: DateTime(2026, 9, 8),
        subtotal: 8000,
        total: 8000,
        completedAt: Value(DateTime(2026, 9, 8, 12, 0)),
        createdAt: DateTime(2026, 9, 3, 10, 0),
        updatedAt: DateTime(2026, 9, 3, 10, 0),
      ),
    );
    await paymentsDao.insertPayment(
      db_pkg.PaymentsCompanion.insert(
        id: 'pay-3',
        orderId: 'ord-3',
        amount: 8000,
        paymentMethod: 'cash',
        paidAt: DateTime(2026, 9, 3, 10, 5),
        createdAt: DateTime(2026, 9, 3, 10, 5),
        updatedAt: DateTime(2026, 9, 3, 10, 5),
      ),
    );

    // Order 4: Sara, cancelled, total 4000, paid 0 (hasRemaining = true)
    await ordersDao.insertOrder(
      db_pkg.OrdersCompanion.insert(
        id: 'ord-4',
        orderNumber: '26-004',
        customerId: 'cust-sara',
        status: Value(OrderStatus.cancelled.value),
        expectedPickupDate: DateTime(2026, 9, 9),
        subtotal: 4000,
        total: 4000,
        cancelledAt: Value(DateTime(2026, 9, 4, 15, 0)),
        cancellationReason: const Value('طلب العميل'),
        createdAt: DateTime(2026, 9, 4, 10, 0),
        updatedAt: DateTime(2026, 9, 4, 10, 0),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('OrdersDao Database-Level Filtering & Search', () {
    test('filters by status at SQL level', () async {
      final readyOrders = await ordersDao.getOrders(
        status: OrderStatus.ready.value,
      );
      expect(readyOrders.length, 1);
      expect(readyOrders.first.id, 'ord-2');

      final processingOrders = await ordersDao.getOrders(
        status: OrderStatus.processing.value,
      );
      expect(processingOrders.length, 1);
      expect(processingOrders.first.id, 'ord-1');

      final completedOrders = await ordersDao.getOrders(
        status: OrderStatus.completed.value,
      );
      expect(completedOrders.length, 1);
      expect(completedOrders.first.id, 'ord-3');

      final cancelledOrders = await ordersDao.getOrders(
        status: OrderStatus.cancelled.value,
      );
      expect(cancelledOrders.length, 1);
      expect(cancelledOrders.first.id, 'ord-4');
    });

    test('completed and cancelled filters strictly exclude other statuses at SQL level', () async {
      final completedOrders = await ordersDao.getOrders(
        status: OrderStatus.completed.value,
      );
      for (final order in completedOrders) {
        expect(order.status, equals(OrderStatus.completed.value));
        expect(order.status, isNot(equals(OrderStatus.ready.value)));
        expect(order.status, isNot(equals(OrderStatus.processing.value)));
        expect(order.status, isNot(equals(OrderStatus.cancelled.value)));
      }

      final cancelledOrders = await ordersDao.getOrders(
        status: OrderStatus.cancelled.value,
      );
      for (final order in cancelledOrders) {
        expect(order.status, equals(OrderStatus.cancelled.value));
        expect(order.status, isNot(equals(OrderStatus.ready.value)));
        expect(order.status, isNot(equals(OrderStatus.processing.value)));
        expect(order.status, isNot(equals(OrderStatus.completed.value)));
      }
    });

    test('combines search query with completed and cancelled status filters', () async {
      // Customer 'سارة' has ord-3 (completed) and ord-4 (cancelled)
      final completedSearch = await ordersDao.getOrders(
        query: 'سارة',
        status: OrderStatus.completed.value,
      );
      expect(completedSearch.length, 1);
      expect(completedSearch.first.id, 'ord-3');

      final cancelledSearch = await ordersDao.getOrders(
        query: 'سارة',
        status: OrderStatus.cancelled.value,
      );
      expect(cancelledSearch.length, 1);
      expect(cancelledSearch.first.id, 'ord-4');

      // Search for 'أحمد' (has ord-1 processing, ord-2 ready) with completed status
      final noResults = await ordersDao.getOrders(
        query: 'أحمد',
        status: OrderStatus.completed.value,
      );
      expect(noResults.isEmpty, true);
    });

    test('filters by hasRemaining at SQL level: only active orders with unpaid balance appear', () async {
      final remainingOrders = await ordersDao.getOrders(hasRemaining: true);
      // ord-1 (processing, 5000 - 2000 = 3000) appears.
      // ord-2 (ready, fully paid 3000/3000 = 0) does NOT appear.
      // ord-3 (completed, fully paid 8000/8000 = 0) does NOT appear.
      // ord-4 (cancelled, remaining is 0) does NOT appear even though payments = 0.
      expect(remainingOrders.length, 1);
      expect(remainingOrders.first.id, 'ord-1');

      // hasRemaining: false returns all orders with 0 remaining (fully paid ord-2, ord-3, and cancelled ord-4)
      final zeroRemainingOrders = await ordersDao.getOrders(hasRemaining: false);
      expect(zeroRemainingOrders.length, 3);
      final zeroIds = zeroRemainingOrders.map((o) => o.id).toSet();
      expect(zeroIds, containsAll(['ord-2', 'ord-3', 'ord-4']));
    });

    test('combines status and hasRemaining SQL filters', () async {
      final processingWithRemaining = await ordersDao.getOrders(
        status: OrderStatus.processing.value,
        hasRemaining: true,
      );
      expect(processingWithRemaining.length, 1);
      expect(processingWithRemaining.first.id, 'ord-1');

      final readyWithRemaining = await ordersDao.getOrders(
        status: OrderStatus.ready.value,
        hasRemaining: true,
      );
      expect(readyWithRemaining.isEmpty, true);

      // Cancelled orders never have remaining balance
      final cancelledWithRemaining = await ordersDao.getOrders(
        status: OrderStatus.cancelled.value,
        hasRemaining: true,
      );
      expect(cancelledWithRemaining.isEmpty, true);
    });

    test('searches by order number', () async {
      final results = await ordersDao.getOrders(query: '26-003');
      expect(results.length, 1);
      expect(results.first.id, 'ord-3');
    });

    test('searches by customer name', () async {
      final results = await ordersDao.getOrders(query: 'سارة');
      expect(results.length, 2);
      final ids = results.map((o) => o.id).toSet();
      expect(ids, containsAll(['ord-3', 'ord-4']));
    });

    test('searches by customer phone number', () async {
      final results = await ordersDao.getOrders(query: '01011112222');
      expect(results.length, 2);
      final ids = results.map((o) => o.id).toSet();
      expect(ids, containsAll(['ord-1', 'ord-2']));
    });

    test(
      'orders by createdAt DESC (newest first) and supports limit/offset pagination',
      () async {
        // Page 1 (limit 2, offset 0) -> should be ord-4 and ord-3
        final page1 = await ordersDao.getOrders(limit: 2, offset: 0);
        expect(page1.length, 2);
        expect(page1[0].id, 'ord-4');
        expect(page1[1].id, 'ord-3');

        // Page 2 (limit 2, offset 2) -> should be ord-2 and ord-1
        final page2 = await ordersDao.getOrders(limit: 2, offset: 2);
        expect(page2.length, 2);
        expect(page2[0].id, 'ord-2');
        expect(page2[1].id, 'ord-1');
      },
    );

    group('Date-based Filtering (Today Pickup and Overdue)', () {
      final refDate = DateTime(2026, 9, 26, 12, 0, 0); // Reference "today"
      final todayDate = DateTime(2026, 9, 26);

      setUp(() async {
        // 1. Yesterday pickup (UTC midnight)
        await ordersDao.insertOrder(
          db_pkg.OrdersCompanion.insert(
            id: 'ord-yesterday-utc',
            orderNumber: '26-D01',
            customerId: 'cust-ahmed',
            status: Value(OrderStatus.processing.value),
            expectedPickupDate: DateTime.utc(2026, 9, 25, 0, 0, 0),
            subtotal: 1000,
            total: 1000,
            createdAt: DateTime(2026, 9, 20),
            updatedAt: DateTime(2026, 9, 20),
          ),
        );

        // 2. Yesterday pickup (local afternoon 14:30)
        await ordersDao.insertOrder(
          db_pkg.OrdersCompanion.insert(
            id: 'ord-yesterday-afternoon',
            orderNumber: '26-D02',
            customerId: 'cust-ahmed',
            status: Value(OrderStatus.processing.value),
            expectedPickupDate: DateTime(2026, 9, 25, 14, 30, 0),
            subtotal: 1000,
            total: 1000,
            createdAt: DateTime(2026, 9, 20),
            updatedAt: DateTime(2026, 9, 20),
          ),
        );

        // 3. Today pickup (UTC midnight 00:00:00)
        await ordersDao.insertOrder(
          db_pkg.OrdersCompanion.insert(
            id: 'ord-today-utc-midnight',
            orderNumber: '26-D03',
            customerId: 'cust-ahmed',
            status: Value(OrderStatus.processing.value),
            expectedPickupDate: DateTime.utc(2026, 9, 26, 0, 0, 0),
            subtotal: 1000,
            total: 1000,
            createdAt: DateTime(2026, 9, 21),
            updatedAt: DateTime(2026, 9, 21),
          ),
        );

        // 4. Today pickup (local afternoon 14:30:00)
        await ordersDao.insertOrder(
          db_pkg.OrdersCompanion.insert(
            id: 'ord-today-local-afternoon',
            orderNumber: '26-D04',
            customerId: 'cust-ahmed',
            status: Value(OrderStatus.ready.value),
            expectedPickupDate: DateTime(2026, 9, 26, 14, 30, 0),
            subtotal: 1000,
            total: 1000,
            createdAt: DateTime(2026, 9, 21),
            updatedAt: DateTime(2026, 9, 21),
          ),
        );

        // 5. Today pickup (local end-of-day 23:59:59)
        await ordersDao.insertOrder(
          db_pkg.OrdersCompanion.insert(
            id: 'ord-today-end-of-day',
            orderNumber: '26-D05',
            customerId: 'cust-sara',
            status: Value(OrderStatus.processing.value),
            expectedPickupDate: DateTime(2026, 9, 26, 23, 59, 59),
            subtotal: 1000,
            total: 1000,
            createdAt: DateTime(2026, 9, 21),
            updatedAt: DateTime(2026, 9, 21),
          ),
        );

        // 6. Today pickup (completed status -> excluded from active filters)
        await ordersDao.insertOrder(
          db_pkg.OrdersCompanion.insert(
            id: 'ord-today-completed',
            orderNumber: '26-D06',
            customerId: 'cust-ahmed',
            status: Value(OrderStatus.completed.value),
            expectedPickupDate: DateTime(2026, 9, 26, 10, 0, 0),
            completedAt: Value(DateTime(2026, 9, 26, 11, 0, 0)),
            subtotal: 1000,
            total: 1000,
            createdAt: DateTime(2026, 9, 21),
            updatedAt: DateTime(2026, 9, 21),
          ),
        );

        // 7. Tomorrow pickup (UTC midnight)
        await ordersDao.insertOrder(
          db_pkg.OrdersCompanion.insert(
            id: 'ord-tomorrow-utc',
            orderNumber: '26-D07',
            customerId: 'cust-ahmed',
            status: Value(OrderStatus.processing.value),
            expectedPickupDate: DateTime.utc(2026, 9, 27, 0, 0, 0),
            subtotal: 1000,
            total: 1000,
            createdAt: DateTime(2026, 9, 22),
            updatedAt: DateTime(2026, 9, 22),
          ),
        );

        // 8. Tomorrow pickup (local afternoon)
        await ordersDao.insertOrder(
          db_pkg.OrdersCompanion.insert(
            id: 'ord-tomorrow-afternoon',
            orderNumber: '26-D08',
            customerId: 'cust-ahmed',
            status: Value(OrderStatus.processing.value),
            expectedPickupDate: DateTime(2026, 9, 27, 16, 0, 0),
            subtotal: 1000,
            total: 1000,
            createdAt: DateTime(2026, 9, 22),
            updatedAt: DateTime(2026, 9, 22),
          ),
        );
      });

      test(
        'todayPickup: matches all orders with expectedPickupDate today regardless of time/UTC/local',
        () async {
          final results = await ordersDao.getOrders(
            expectedPickupDate: todayDate,
            excludedStatuses: const ['completed', 'cancelled'],
          );
          final ids = results.map((o) => o.id).toSet();

          // Must include today's active orders:
          expect(ids, contains('ord-today-utc-midnight'));
          expect(ids, contains('ord-today-local-afternoon'));
          expect(ids, contains('ord-today-end-of-day'));

          // Must NOT include yesterday or tomorrow orders:
          expect(ids.contains('ord-yesterday-utc'), isFalse);
          expect(ids.contains('ord-yesterday-afternoon'), isFalse);
          expect(ids.contains('ord-tomorrow-utc'), isFalse);
          expect(ids.contains('ord-tomorrow-afternoon'), isFalse);

          // Must NOT include completed orders:
          expect(ids.contains('ord-today-completed'), isFalse);
        },
      );

      test(
        'overdue: matches orders with expectedPickupDate strictly before today and excludes today/tomorrow',
        () async {
          final results = await ordersDao.getOrders(
            isOverdue: true,
            referenceDate: refDate,
          );
          final ids = results.map((o) => o.id).toSet();

          // Must include yesterday's orders:
          expect(ids, contains('ord-yesterday-utc'));
          expect(ids, contains('ord-yesterday-afternoon'));

          // Must NOT include today's orders (neither midnight, afternoon, nor end-of-day):
          expect(ids.contains('ord-today-utc-midnight'), isFalse);
          expect(ids.contains('ord-today-local-afternoon'), isFalse);
          expect(ids.contains('ord-today-end-of-day'), isFalse);
          expect(ids.contains('ord-today-completed'), isFalse);

          // Must NOT include tomorrow orders:
          expect(ids.contains('ord-tomorrow-utc'), isFalse);
          expect(ids.contains('ord-tomorrow-afternoon'), isFalse);
        },
      );

      test(
        'tomorrow: expectedPickupDate = tomorrow does not appear in today or overdue',
        () async {
          final todayPickups = await ordersDao.getOrders(
            expectedPickupDate: todayDate,
            excludedStatuses: const ['completed', 'cancelled'],
          );
          final overdue = await ordersDao.getOrders(
            isOverdue: true,
            referenceDate: refDate,
          );

          final todayIds = todayPickups.map((o) => o.id).toSet();
          final overdueIds = overdue.map((o) => o.id).toSet();

          expect(todayIds.contains('ord-tomorrow-utc'), isFalse);
          expect(todayIds.contains('ord-tomorrow-afternoon'), isFalse);
          expect(overdueIds.contains('ord-tomorrow-utc'), isFalse);
          expect(overdueIds.contains('ord-tomorrow-afternoon'), isFalse);
        },
      );

      test('date-based filtering works seamlessly with search query', () async {
        final results = await ordersDao.getOrders(
          query: 'أحمد',
          expectedPickupDate: todayDate,
          excludedStatuses: const ['completed', 'cancelled'],
        );
        final ids = results.map((o) => o.id).toSet();

        // Includes Ahmed's active today orders, excludes Sara's order
        expect(ids, contains('ord-today-utc-midnight'));
        expect(ids, contains('ord-today-local-afternoon'));
        expect(ids.contains('ord-today-end-of-day'), isFalse); // Sara
        expect(ids.contains('ord-yesterday-utc'), isFalse);
      });
    });
  });
}
