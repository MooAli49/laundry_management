import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/local/daos/customers_dao.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart' as db_pkg;
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
      final readyOrders = await ordersDao.getOrders(status: OrderStatus.ready.value);
      expect(readyOrders.length, 1);
      expect(readyOrders.first.id, 'ord-2');

      final processingOrders = await ordersDao.getOrders(status: OrderStatus.processing.value);
      expect(processingOrders.length, 1);
      expect(processingOrders.first.id, 'ord-1');

      final completedOrders = await ordersDao.getOrders(status: OrderStatus.completed.value);
      expect(completedOrders.length, 1);
      expect(completedOrders.first.id, 'ord-3');
    });

    test('filters by hasRemaining at SQL level via subquery', () async {
      final remainingOrders = await ordersDao.getOrders(hasRemaining: true);
      // ord-1 (5000 - 2000 = 3000) and ord-4 (4000 - 0 = 4000)
      expect(remainingOrders.length, 2);
      final ids = remainingOrders.map((o) => o.id).toSet();
      expect(ids, containsAll(['ord-1', 'ord-4']));
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

    test('orders by createdAt DESC (newest first) and supports limit/offset pagination', () async {
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
    });
  });
}
