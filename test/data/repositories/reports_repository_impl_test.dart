import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/local/daos/customers_dao.dart';
import 'package:laundry_management/data/local/daos/expense_categories_dao.dart';
import 'package:laundry_management/data/local/daos/expenses_dao.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart' as db_pkg;
import 'package:laundry_management/data/repositories/expense_repository_impl.dart';
import 'package:laundry_management/data/repositories/reports_repository_impl.dart';
import 'package:laundry_management/domain/entities/expense.dart';
import 'package:laundry_management/domain/enums/payment_method.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';

void main() {
  late db_pkg.AppDatabase db;
  late CustomersDao customersDao;
  late OrdersDao ordersDao;
  late PaymentsDao paymentsDao;
  late ExpensesDao expensesDao;
  late ExpenseCategoriesDao expenseCategoriesDao;
  late SyncOperationsDao syncOperationsDao;

  late ExpenseRepositoryImpl expenseRepository;
  late ReportsRepositoryImpl reportsRepository;

  setUp(() async {
    db = db_pkg.AppDatabase(NativeDatabase.memory());
    customersDao = CustomersDao(db);
    ordersDao = OrdersDao(db);
    paymentsDao = PaymentsDao(db);
    expensesDao = ExpensesDao(db);
    expenseCategoriesDao = ExpenseCategoriesDao(db);
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
      expenseRepository: expenseRepository,
    );

    // Seed customer
    await customersDao.insertCustomer(
      db_pkg.CustomersCompanion.insert(
        id: 'cust-1',
        name: 'أحمد محمود',
        phone: '01012345678',
        createdAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 8, 1),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('ReportsRepositoryImpl Tests', () {
    test('calculates orders report metrics accurately including statuses and overdue', () async {
      final periodStart = DateTime(2026, 8, 1, 0, 0, 0);
      final periodEnd = DateTime(2026, 8, 31, 23, 59, 59);

      // Order 1: processing, normal pickup
      await ordersDao.insertOrder(
        db_pkg.OrdersCompanion.insert(
          id: 'ord-1',
          orderNumber: '26-001',
          customerId: 'cust-1',
          customerNameSnapshot: const Value('أحمد محمود'),
          customerPhoneSnapshot: const Value('01012345678'),
          status: const Value('processing'),
          expectedPickupDate: DateTime.now().add(const Duration(days: 2)),
          subtotal: 20000, // 200 EGP
          total: 20000,
          createdAt: DateTime(2026, 8, 5),
          updatedAt: DateTime(2026, 8, 5),
        ),
      );

      // Order 2: ready, overdue! (expected pickup in the past)
      await ordersDao.insertOrder(
        db_pkg.OrdersCompanion.insert(
          id: 'ord-2',
          orderNumber: '26-002',
          customerId: 'cust-1',
          customerNameSnapshot: const Value('أحمد محمود'),
          customerPhoneSnapshot: const Value('01012345678'),
          status: const Value('ready'),
          expectedPickupDate: DateTime.now().subtract(const Duration(days: 3)),
          subtotal: 30000, // 300 EGP
          total: 30000,
          createdAt: DateTime(2026, 8, 10),
          updatedAt: DateTime(2026, 8, 10),
        ),
      );

      // Order 3: completed, past expected pickup (completed is NOT overdue)
      await ordersDao.insertOrder(
        db_pkg.OrdersCompanion.insert(
          id: 'ord-3',
          orderNumber: '26-003',
          customerId: 'cust-1',
          customerNameSnapshot: const Value('أحمد محمود'),
          customerPhoneSnapshot: const Value('01012345678'),
          status: const Value('completed'),
          expectedPickupDate: DateTime.now().subtract(const Duration(days: 5)),
          subtotal: 50000, // 500 EGP
          total: 50000,
          createdAt: DateTime(2026, 8, 15),
          updatedAt: DateTime(2026, 8, 15),
        ),
      );

      // Order 4: cancelled
      await ordersDao.insertOrder(
        db_pkg.OrdersCompanion.insert(
          id: 'ord-4',
          orderNumber: '26-004',
          customerId: 'cust-1',
          customerNameSnapshot: const Value('أحمد محمود'),
          customerPhoneSnapshot: const Value('01012345678'),
          status: const Value('cancelled'),
          expectedPickupDate: DateTime.now().add(const Duration(days: 1)),
          subtotal: 10000,
          total: 10000,
          createdAt: DateTime(2026, 8, 20),
          updatedAt: DateTime(2026, 8, 20),
        ),
      );

      // Order 5: Outside period (September)
      await ordersDao.insertOrder(
        db_pkg.OrdersCompanion.insert(
          id: 'ord-5',
          orderNumber: '26-005',
          customerId: 'cust-1',
          status: const Value('processing'),
          expectedPickupDate: DateTime(2026, 9, 5),
          subtotal: 40000,
          total: 40000,
          createdAt: DateTime(2026, 9, 2),
          updatedAt: DateTime(2026, 9, 2),
        ),
      );

      final report = await reportsRepository.getOrdersReport(
        startDate: periodStart,
        endDate: periodEnd,
      );

      expect(report.totalOrders, 4); // ord-1, 2, 3, 4
      expect(report.totalOrderValue, const Money.fromPiastres(110000)); // 200 + 300 + 500 + 100 = 1100 EGP
      expect(report.processingOrdersCount, 1);
      expect(report.readyOrdersCount, 1);
      expect(report.completedOrdersCount, 1);
      expect(report.cancelledOrdersCount, 1);
      expect(report.overdueOrdersCount, 1); // Only ord-2 is ready & past due
      expect(report.activeOrdersCount, 2); // 1 processing + 1 ready
    });

    test('calculates financial report metrics and strictly enforces net profit formula', () async {
      final periodStart = DateTime(2026, 8, 1, 0, 0, 0);
      final periodEnd = DateTime(2026, 8, 31, 23, 59, 59);

      // 1. Orders: Total Sales = 1,000 EGP (100,000 piastres), Discounts = 50 EGP (5,000 piastres)
      await ordersDao.insertOrder(
        db_pkg.OrdersCompanion.insert(
          id: 'ord-fin-1',
          orderNumber: '26-101',
          customerId: 'cust-1',
          customerNameSnapshot: const Value('أحمد محمود'),
          customerPhoneSnapshot: const Value('01012345678'),
          status: const Value('ready'),
          expectedPickupDate: DateTime(2026, 8, 28),
          subtotal: 105000,
          discount: const Value(5000), // 50 EGP discount
          total: 100000, // 1,000 EGP
          createdAt: DateTime(2026, 8, 10),
          updatedAt: DateTime(2026, 8, 10),
        ),
      );

      // 2. Payments: Total = 700 EGP (70,000 piastres)
      // Cash: 400 EGP
      await paymentsDao.insertPayment(
        db_pkg.PaymentsCompanion.insert(
          id: 'pay-1',
          orderId: 'ord-fin-1',
          amount: 40000,
          paymentMethod: PaymentMethod.cash.value,
          paidAt: DateTime(2026, 8, 10, 14, 0),
          createdAt: DateTime(2026, 8, 10, 14, 0),
          updatedAt: DateTime(2026, 8, 10, 14, 0),
        ),
      );

      // InstaPay: 200 EGP
      await paymentsDao.insertPayment(
        db_pkg.PaymentsCompanion.insert(
          id: 'pay-2',
          orderId: 'ord-fin-1',
          amount: 20000,
          paymentMethod: PaymentMethod.instapay.value,
          paidAt: DateTime(2026, 8, 15, 11, 0),
          createdAt: DateTime(2026, 8, 15, 11, 0),
          updatedAt: DateTime(2026, 8, 15, 11, 0),
        ),
      );

      // E-Wallet: 100 EGP
      await paymentsDao.insertPayment(
        db_pkg.PaymentsCompanion.insert(
          id: 'pay-3',
          orderId: 'ord-fin-1',
          amount: 10000,
          paymentMethod: PaymentMethod.ewallet.value,
          paidAt: DateTime(2026, 8, 20, 16, 0),
          createdAt: DateTime(2026, 8, 20, 16, 0),
          updatedAt: DateTime(2026, 8, 20, 16, 0),
        ),
      );

      // 3. Operating Expenses: Total = 150 EGP (15,000 piastres)
      final cats = await expenseCategoriesDao.getAllCategories();
      final cleaningCat = cats.firstWhere((c) => c.name == 'منظفات');
      final elecCat = cats.firstWhere((c) => c.name == 'كهرباء');

      await expenseRepository.createExpense(
        Expense(
          id: 'exp-rep-1',
          expenseCategoryId: cleaningCat.id,
          amount: const Money.fromPiastres(10000), // 100 EGP
          expenseDate: OrderDate(2026, 8, 12),
          categoryNameSnapshot: cleaningCat.name,
          createdAt: DateTime(2026, 8, 12),
          updatedAt: DateTime(2026, 8, 12),
        ),
      );

      await expenseRepository.createExpense(
        Expense(
          id: 'exp-rep-2',
          expenseCategoryId: elecCat.id,
          amount: const Money.fromPiastres(5000), // 50 EGP
          expenseDate: OrderDate(2026, 8, 18),
          categoryNameSnapshot: elecCat.name,
          createdAt: DateTime(2026, 8, 18),
          updatedAt: DateTime(2026, 8, 18),
        ),
      );

      // Generate Financial Report
      final report = await reportsRepository.getFinancialReport(
        startDate: periodStart,
        endDate: periodEnd,
      );

      // Metric verifications
      expect(report.totalSales, const Money.fromPiastres(100000)); // 1,000 EGP
      expect(report.totalPayments, const Money.fromPiastres(70000)); // 700 EGP
      expect(report.totalOperatingExpenses, const Money.fromPiastres(15000)); // 150 EGP
      expect(report.outstandingAmount, const Money.fromPiastres(30000)); // 300 EGP (1000 - 700)
      expect(report.totalDiscounts, const Money.fromPiastres(5000)); // 50 EGP

      // CRITICAL: Net Profit = Total Sales (1,000) - Total Operating Expenses (150) = 850 EGP
      expect(report.netProfit, const Money.fromPiastres(85000));
      // Invariant: Payments (700 EGP) must NOT reduce Net Profit
      expect(report.netProfit, equals(report.totalSales - report.totalOperatingExpenses));
      expect(report.netProfit, isNot(equals(report.totalPayments - report.totalOperatingExpenses)));

      // Payment Methods Breakdown
      expect(report.paymentMethodsBreakdown.length, 3);
      final cashBreakdown = report.paymentMethodsBreakdown.firstWhere((p) => p.method == PaymentMethod.cash);
      expect(cashBreakdown.totalAmount, const Money.fromPiastres(40000));
      expect(cashBreakdown.count, 1);
      expect(cashBreakdown.percentage, closeTo(57.14, 0.1));

      final instaBreakdown = report.paymentMethodsBreakdown.firstWhere((p) => p.method == PaymentMethod.instapay);
      expect(instaBreakdown.totalAmount, const Money.fromPiastres(20000));

      final ewalletBreakdown = report.paymentMethodsBreakdown.firstWhere((p) => p.method == PaymentMethod.ewallet);
      expect(ewalletBreakdown.totalAmount, const Money.fromPiastres(10000));

      // Expenses by Category Breakdown
      expect(report.expenseCategoriesBreakdown.length, 2);
      expect(report.expenseCategoriesBreakdown.first.categoryName, 'منظفات');
      expect(report.expenseCategoriesBreakdown.first.totalAmount, const Money.fromPiastres(10000));

      // Outstanding Orders list
      expect(report.outstandingOrders.length, 1);
      expect(report.outstandingOrders.first.orderNumber, '26-101');
      expect(report.outstandingOrders.first.totalAmount, const Money.fromPiastres(100000));
      expect(report.outstandingOrders.first.paidAmount, const Money.fromPiastres(70000));
      expect(report.outstandingOrders.first.remainingAmount, const Money.fromPiastres(30000));

      // Expense Transactions list
      expect(report.expenseTransactions.length, 2);
    });

    test('expense report strictly adheres to expense_date, not created_at', () async {
      final periodStart = DateTime(2026, 8, 1, 0, 0, 0);
      final periodEnd = DateTime(2026, 8, 31, 23, 59, 59);

      final cats = await expenseCategoriesDao.getAllCategories();
      final cat = cats.firstWhere((c) => c.name == 'كهرباء');

      // Expense occurred on 25 August, but entered on 2 September
      await expenseRepository.createExpense(
        Expense(
          id: 'exp-date-1',
          expenseCategoryId: cat.id,
          amount: const Money.fromPiastres(15000),
          expenseDate: OrderDate(2026, 8, 25), // In August!
          categoryNameSnapshot: cat.name,
          createdAt: DateTime(2026, 9, 2), // In September!
          updatedAt: DateTime(2026, 9, 2),
        ),
      );

      final augustReport = await reportsRepository.getFinancialReport(
        startDate: periodStart,
        endDate: periodEnd,
      );
      // Must be included in August report!
      expect(augustReport.totalOperatingExpenses, const Money.fromPiastres(15000));
    });
  });
}
