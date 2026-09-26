import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/local/daos/customers_dao.dart';
import 'package:laundry_management/data/local/daos/expenses_dao.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/refunds_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart' as db_pkg;
import 'package:laundry_management/data/repositories/expense_repository_impl.dart';
import 'package:laundry_management/data/repositories/reports_repository_impl.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';

void main() {
  late db_pkg.AppDatabase db;
  late CustomersDao customersDao;
  late OrdersDao ordersDao;
  late PaymentsDao paymentsDao;
  late ExpensesDao expensesDao;
  late RefundsDao refundsDao;
  late SyncOperationsDao syncOperationsDao;
  late ExpenseRepositoryImpl expenseRepository;
  late ReportsRepositoryImpl reportsRepository;

  setUp(() async {
    db = db_pkg.AppDatabase(NativeDatabase.memory());
    customersDao = CustomersDao(db);
    ordersDao = OrdersDao(db);
    paymentsDao = PaymentsDao(db);
    expensesDao = ExpensesDao(db);
    refundsDao = RefundsDao(db);
    syncOperationsDao = SyncOperationsDao(db);

    expenseRepository = ExpenseRepositoryImpl(
      expensesDao: expensesDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    reportsRepository = ReportsRepositoryImpl(
      ordersDao: ordersDao,
      paymentsDao: paymentsDao,
      expensesDao: expensesDao,
      refundsDao: refundsDao,
      expenseRepository: expenseRepository,
    );

    await customersDao.insertCustomer(
      db_pkg.CustomersCompanion.insert(
        id: 'cust-overdue-test',
        name: 'عميل الفحص',
        phone: '01012345678',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Reports Overdue Boundary Tests', () {
    final now = DateTime.now();
    final today = OrderDate.today();
    final yesterday = OrderDate.fromDate(now.subtract(const Duration(days: 1)));
    final tomorrow = OrderDate.fromDate(now.add(const Duration(days: 1)));

    Future<void> insertTestOrder({
      required String id,
      required String orderNumber,
      required OrderDate expectedPickup,
      required String status,
      required DateTime createdAt,
    }) async {
      await db.into(db.orders).insert(
            db_pkg.OrdersCompanion.insert(
              id: id,
              orderNumber: orderNumber,
              customerId: 'cust-overdue-test',
              customerNameSnapshot: const Value('عميل الفحص'),
              customerPhoneSnapshot: const Value('01012345678'),
              status: Value(status),
              expectedPickupDate: expectedPickup.toDateTime(),
              subtotal: 5000,
              discount: const Value(0),
              tax: const Value(0),
              total: 5000,
              createdAt: createdAt,
              updatedAt: createdAt,
            ),
          );
    }

    test('A. Expected pickup = yesterday (active) is counted as OVERDUE', () async {
      await insertTestOrder(
        id: 'ord-yesterday',
        orderNumber: '26-101',
        expectedPickup: yesterday,
        status: 'processing',
        createdAt: now.subtract(const Duration(days: 2)),
      );

      final report = await reportsRepository.getOrdersReport(
        startDate: now.subtract(const Duration(days: 5)),
        endDate: now.add(const Duration(days: 5)),
      );

      expect(report.overdueOrdersCount, 1);
    });

    test('B. Expected pickup = TODAY (active) is NOT overdue', () async {
      await insertTestOrder(
        id: 'ord-today',
        orderNumber: '26-102',
        expectedPickup: today,
        status: 'processing',
        createdAt: now.subtract(const Duration(days: 1)),
      );

      final report = await reportsRepository.getOrdersReport(
        startDate: now.subtract(const Duration(days: 5)),
        endDate: now.add(const Duration(days: 5)),
      );

      expect(report.overdueOrdersCount, 0);
    });

    test('C. Expected pickup = TOMORROW (active) is NOT overdue', () async {
      await insertTestOrder(
        id: 'ord-tomorrow',
        orderNumber: '26-103',
        expectedPickup: tomorrow,
        status: 'processing',
        createdAt: now,
      );

      final report = await reportsRepository.getOrdersReport(
        startDate: now.subtract(const Duration(days: 5)),
        endDate: now.add(const Duration(days: 5)),
      );

      expect(report.overdueOrdersCount, 0);
    });

    test('D. Completed old order (expected pickup = yesterday) is NOT overdue', () async {
      await insertTestOrder(
        id: 'ord-completed-old',
        orderNumber: '26-104',
        expectedPickup: yesterday,
        status: 'completed',
        createdAt: now.subtract(const Duration(days: 3)),
      );

      final report = await reportsRepository.getOrdersReport(
        startDate: now.subtract(const Duration(days: 5)),
        endDate: now.add(const Duration(days: 5)),
      );

      expect(report.overdueOrdersCount, 0);
    });

    test('E. Cancelled old order (expected pickup = yesterday) is NOT overdue', () async {
      await insertTestOrder(
        id: 'ord-cancelled-old',
        orderNumber: '26-105',
        expectedPickup: yesterday,
        status: 'cancelled',
        createdAt: now.subtract(const Duration(days: 3)),
      );

      final report = await reportsRepository.getOrdersReport(
        startDate: now.subtract(const Duration(days: 5)),
        endDate: now.add(const Duration(days: 5)),
      );

      expect(report.overdueOrdersCount, 0);
    });

    test('Combined boundary test: only active past orders are overdue', () async {
      // 1. Yesterday processing -> overdue
      await insertTestOrder(
        id: 'o1',
        orderNumber: '26-201',
        expectedPickup: yesterday,
        status: 'processing',
        createdAt: now.subtract(const Duration(days: 2)),
      );
      // 2. Yesterday ready -> overdue
      await insertTestOrder(
        id: 'o2',
        orderNumber: '26-202',
        expectedPickup: yesterday,
        status: 'ready',
        createdAt: now.subtract(const Duration(days: 2)),
      );
      // 3. Today processing -> NOT overdue
      await insertTestOrder(
        id: 'o3',
        orderNumber: '26-203',
        expectedPickup: today,
        status: 'processing',
        createdAt: now.subtract(const Duration(days: 1)),
      );
      // 4. Tomorrow processing -> NOT overdue
      await insertTestOrder(
        id: 'o4',
        orderNumber: '26-204',
        expectedPickup: tomorrow,
        status: 'processing',
        createdAt: now,
      );
      // 5. Yesterday completed -> NOT overdue
      await insertTestOrder(
        id: 'o5',
        orderNumber: '26-205',
        expectedPickup: yesterday,
        status: 'completed',
        createdAt: now.subtract(const Duration(days: 3)),
      );
      // 6. Yesterday cancelled -> NOT overdue
      await insertTestOrder(
        id: 'o6',
        orderNumber: '26-206',
        expectedPickup: yesterday,
        status: 'cancelled',
        createdAt: now.subtract(const Duration(days: 3)),
      );

      final report = await reportsRepository.getOrdersReport(
        startDate: now.subtract(const Duration(days: 5)),
        endDate: now.add(const Duration(days: 5)),
      );

      // Only o1 and o2 are overdue
      expect(report.overdueOrdersCount, 2);
    });
  });
}
