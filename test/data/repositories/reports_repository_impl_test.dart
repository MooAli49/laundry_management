import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/local/daos/customers_dao.dart';
import 'package:laundry_management/data/local/daos/expense_categories_dao.dart';
import 'package:laundry_management/data/local/daos/expenses_dao.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/refunds_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart'
    as db_pkg;
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
  late RefundsDao refundsDao;
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
    refundsDao = RefundsDao(db);
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
      refundsDao: refundsDao,
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
    test(
      'calculates orders report metrics accurately including statuses and overdue',
      () async {
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
            expectedPickupDate: DateTime.now().subtract(
              const Duration(days: 1),
            ),
            subtotal: 30000, // 300 EGP
            total: 30000,
            createdAt: DateTime(2026, 8, 10),
            updatedAt: DateTime(2026, 8, 10),
          ),
        );

        // Order 3: completed
        await ordersDao.insertOrder(
          db_pkg.OrdersCompanion.insert(
            id: 'ord-3',
            orderNumber: '26-003',
            customerId: 'cust-1',
            customerNameSnapshot: const Value('أحمد محمود'),
            customerPhoneSnapshot: const Value('01012345678'),
            status: const Value('completed'),
            expectedPickupDate: DateTime.now().add(const Duration(days: 5)),
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
        expect(
          report.totalOrderValue,
          const Money.fromPiastres(110000),
        ); // 200 + 300 + 500 + 100 = 1100 EGP
        expect(report.processingOrdersCount, 1);
        expect(report.readyOrdersCount, 1);
        expect(report.completedOrdersCount, 1);
        expect(report.cancelledOrdersCount, 1);
        expect(report.overdueOrdersCount, 1); // Only ord-2 is ready & past due
        expect(report.activeOrdersCount, 2); // 1 processing + 1 ready
      },
    );

    test(
      'calculates financial report metrics and strictly enforces net profit formula',
      () async {
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
        expect(
          report.totalSales,
          const Money.fromPiastres(100000),
        ); // 1,000 EGP
        expect(
          report.totalPayments,
          const Money.fromPiastres(70000),
        ); // 700 EGP
        expect(report.totalRefunds, Money.zero);
        expect(report.netPayments, const Money.fromPiastres(70000));
        expect(
          report.totalOperatingExpenses,
          const Money.fromPiastres(15000),
        ); // 150 EGP
        expect(
          report.outstandingAmount,
          const Money.fromPiastres(30000),
        ); // 300 EGP (1000 - 700)
        expect(report.totalDiscounts, const Money.fromPiastres(5000)); // 50 EGP

        // CRITICAL: Net Profit = Total Sales (1,000) - Total Operating Expenses (150) = 850 EGP
        expect(report.netProfit, const Money.fromPiastres(85000));
        // Invariant: Payments (700 EGP) must NOT reduce Net Profit
        expect(
          report.netProfit,
          equals(report.totalSales - report.totalOperatingExpenses),
        );
        expect(
          report.netProfit,
          isNot(equals(report.totalPayments - report.totalOperatingExpenses)),
        );

        // Payment Methods Breakdown
        expect(report.paymentMethodsBreakdown.length, 3);
        final cashBreakdown = report.paymentMethodsBreakdown.firstWhere(
          (p) => p.method == PaymentMethod.cash,
        );
        expect(cashBreakdown.totalAmount, const Money.fromPiastres(40000));
        expect(cashBreakdown.count, 1);
        expect(cashBreakdown.percentage, closeTo(57.14, 0.1));

        final instapayBreakdown = report.paymentMethodsBreakdown.firstWhere(
          (p) => p.method == PaymentMethod.instapay,
        );
        expect(instapayBreakdown.totalAmount, const Money.fromPiastres(20000));
        expect(instapayBreakdown.count, 1);
        expect(instapayBreakdown.percentage, closeTo(28.57, 0.1));

        final ewalletBreakdown = report.paymentMethodsBreakdown.firstWhere(
          (p) => p.method == PaymentMethod.ewallet,
        );
        expect(ewalletBreakdown.totalAmount, const Money.fromPiastres(10000));
        expect(ewalletBreakdown.count, 1);
        expect(ewalletBreakdown.percentage, closeTo(14.28, 0.1));

        // Expenses Categories Breakdown
        expect(report.expenseCategoriesBreakdown.length, 2);
        expect(
          report.expenseCategoriesBreakdown[0].categoryName,
          cleaningCat.name,
        );
        expect(
          report.expenseCategoriesBreakdown[0].totalAmount,
          const Money.fromPiastres(10000),
        );
        expect(
          report.expenseCategoriesBreakdown[1].categoryName,
          elecCat.name,
        );
        expect(
          report.expenseCategoriesBreakdown[1].totalAmount,
          const Money.fromPiastres(5000),
        );

        // Outstanding orders list
        expect(report.outstandingOrders.length, 1);
        expect(report.outstandingOrders.first.orderNumber, '26-101');
        expect(
          report.outstandingOrders.first.totalAmount,
          const Money.fromPiastres(100000),
        );
        expect(
          report.outstandingOrders.first.paidAmount,
          const Money.fromPiastres(70000),
        );
        expect(
          report.outstandingOrders.first.remainingAmount,
          const Money.fromPiastres(30000),
        );

        // Expense Transactions list
        expect(report.expenseTransactions.length, 2);
      },
    );

    test(
      'Part K: Deterministic example validation with Order A (processing), Order B (ready), Order C (cancelled), and Expenses',
      () async {
        final periodStart = DateTime(2026, 8, 1, 0, 0, 0);
        final periodEnd = DateTime(2026, 8, 31, 23, 59, 59);

        // Order A: total = 100, processing, paid = 50
        await ordersDao.insertOrder(
          db_pkg.OrdersCompanion.insert(
            id: 'ord-det-a',
            orderNumber: '26-A',
            customerId: 'cust-1',
            status: const Value('processing'),
            expectedPickupDate: DateTime(2026, 8, 10),
            subtotal: 10000,
            total: 10000, // 100 EGP
            createdAt: DateTime(2026, 8, 5),
            updatedAt: DateTime(2026, 8, 5),
          ),
        );
        await paymentsDao.insertPayment(
          db_pkg.PaymentsCompanion.insert(
            id: 'pay-det-a',
            orderId: 'ord-det-a',
            amount: 5000, // 50 EGP
            paymentMethod: PaymentMethod.cash.value,
            paidAt: DateTime(2026, 8, 5, 10, 0),
            createdAt: DateTime(2026, 8, 5, 10, 0),
            updatedAt: DateTime(2026, 8, 5, 10, 0),
          ),
        );

        // Order B: total = 200, ready, paid = 200
        await ordersDao.insertOrder(
          db_pkg.OrdersCompanion.insert(
            id: 'ord-det-b',
            orderNumber: '26-B',
            customerId: 'cust-1',
            status: const Value('ready'),
            expectedPickupDate: DateTime(2026, 8, 15),
            subtotal: 20000,
            total: 20000, // 200 EGP
            createdAt: DateTime(2026, 8, 8),
            updatedAt: DateTime(2026, 8, 8),
          ),
        );
        await paymentsDao.insertPayment(
          db_pkg.PaymentsCompanion.insert(
            id: 'pay-det-b',
            orderId: 'ord-det-b',
            amount: 20000, // 200 EGP
            paymentMethod: PaymentMethod.cash.value,
            paidAt: DateTime(2026, 8, 8, 11, 0),
            createdAt: DateTime(2026, 8, 8, 11, 0),
            updatedAt: DateTime(2026, 8, 8, 11, 0),
          ),
        );

        // Order C: total = 115, cancelled, paid = 35, refunded = 35
        await ordersDao.insertOrder(
          db_pkg.OrdersCompanion.insert(
            id: 'ord-det-c',
            orderNumber: '26-C',
            customerId: 'cust-1',
            status: const Value('cancelled'),
            expectedPickupDate: DateTime(2026, 8, 20),
            subtotal: 11500,
            total: 11500, // 115 EGP
            createdAt: DateTime(2026, 8, 12),
            updatedAt: DateTime(2026, 8, 12),
          ),
        );
        await paymentsDao.insertPayment(
          db_pkg.PaymentsCompanion.insert(
            id: 'pay-det-c',
            orderId: 'ord-det-c',
            amount: 3500, // 35 EGP
            paymentMethod: PaymentMethod.instapay.value,
            paidAt: DateTime(2026, 8, 12, 12, 0),
            createdAt: DateTime(2026, 8, 12, 12, 0),
            updatedAt: DateTime(2026, 8, 12, 12, 0),
          ),
        );
        await refundsDao.insertRefund(
          db_pkg.RefundsCompanion.insert(
            id: 'ref-det-c',
            orderId: 'ord-det-c',
            amount: 3500, // 35 EGP
            refundMethod: 'cash',
            refundedAt: DateTime(2026, 8, 13, 14, 0),
            createdAt: DateTime(2026, 8, 13, 14, 0),
            updatedAt: DateTime(2026, 8, 13, 14, 0),
          ),
        );

        // Expenses: 100 EGP
        final cats = await expenseCategoriesDao.getAllCategories();
        final cleaningCat = cats.firstWhere((c) => c.name == 'منظفات');
        await expenseRepository.createExpense(
          Expense(
            id: 'exp-det-1',
            expenseCategoryId: cleaningCat.id,
            amount: const Money.fromPiastres(10000), // 100 EGP
            expenseDate: OrderDate(2026, 8, 14),
            categoryNameSnapshot: cleaningCat.name,
            createdAt: DateTime(2026, 8, 14),
            updatedAt: DateTime(2026, 8, 14),
          ),
        );

        final report = await reportsRepository.getFinancialReport(
          startDate: periodStart,
          endDate: periodEnd,
        );

        // Total Sales = 100 + 200 = 300 EGP (Order C cancelled contributes 0)
        expect(report.totalSales, const Money.fromPiastres(30000));

        // Total Payments = 50 + 200 + 35 = 285 EGP
        expect(report.totalPayments, const Money.fromPiastres(28500));

        // Total Refunds = 35 EGP
        expect(report.totalRefunds, const Money.fromPiastres(3500));

        // Net Payments = 285 - 35 = 250 EGP
        expect(report.netPayments, const Money.fromPiastres(25000));

        // Outstanding = 50 EGP (Order A has 100 - 50 = 50; Order B is 0; Order C cancelled contributes 0)
        expect(report.outstandingAmount, const Money.fromPiastres(5000));

        // Operating Expenses = 100 EGP
        expect(report.totalOperatingExpenses, const Money.fromPiastres(10000));

        // Net Profit = 300 - 100 = 200 EGP
        expect(report.netProfit, const Money.fromPiastres(20000));
      },
    );

    test(
      'Part M: Cancelled order regression verifies 0 sales, 0 outstanding, 0 net payments',
      () async {
        final periodStart = DateTime(2026, 8, 1, 0, 0, 0);
        final periodEnd = DateTime(2026, 8, 31, 23, 59, 59);

        // Cancelled order: total = 115, paid = 35, refund = 35
        await ordersDao.insertOrder(
          db_pkg.OrdersCompanion.insert(
            id: 'ord-uat-canc',
            orderNumber: '26-UAT',
            customerId: 'cust-1',
            status: const Value('cancelled'),
            expectedPickupDate: DateTime(2026, 8, 10),
            subtotal: 11500,
            total: 11500, // 115 EGP
            createdAt: DateTime(2026, 8, 5),
            updatedAt: DateTime(2026, 8, 5),
          ),
        );
        await paymentsDao.insertPayment(
          db_pkg.PaymentsCompanion.insert(
            id: 'pay-uat-canc',
            orderId: 'ord-uat-canc',
            amount: 3500, // 35 EGP
            paymentMethod: PaymentMethod.cash.value,
            paidAt: DateTime(2026, 8, 5, 10, 0),
            createdAt: DateTime(2026, 8, 5, 10, 0),
            updatedAt: DateTime(2026, 8, 5, 10, 0),
          ),
        );
        await refundsDao.insertRefund(
          db_pkg.RefundsCompanion.insert(
            id: 'ref-uat-canc',
            orderId: 'ord-uat-canc',
            amount: 3500, // 35 EGP
            refundMethod: 'cash',
            refundedAt: DateTime(2026, 8, 6, 12, 0),
            createdAt: DateTime(2026, 8, 6, 12, 0),
            updatedAt: DateTime(2026, 8, 6, 12, 0),
          ),
        );

        final report = await reportsRepository.getFinancialReport(
          startDate: periodStart,
          endDate: periodEnd,
        );

        // Total Sales contribution = 0
        expect(report.totalSales, Money.zero);

        // Total Payments contribution = 35 EGP
        expect(report.totalPayments, const Money.fromPiastres(3500));

        // Total Refunds contribution = 35 EGP
        expect(report.totalRefunds, const Money.fromPiastres(3500));

        // Net Payments contribution = 0 EGP (35 - 35 = 0)
        expect(report.netPayments, Money.zero);

        // Outstanding contribution = 0 EGP
        expect(report.outstandingAmount, Money.zero);

        // Net Profit contribution = 0 EGP (0 sales - 0 expenses)
        expect(report.netProfit, Money.zero);

        // Invariant: original payment in DB is completely untouched
        final payments = await paymentsDao.getPaymentsForOrder('ord-uat-canc');
        expect(payments.length, 1);
        expect(payments.first.amount, 3500);

        // Invariant: order in DB remains cancelled
        final orderRow = await ordersDao.getOrderById('ord-uat-canc');
        expect(orderRow?.status, 'cancelled');
      },
    );

    test(
      'Part L: Date boundary testing: independent transaction date semantics',
      () async {
        final augustStart = DateTime(2026, 8, 1, 0, 0, 0);
        final augustEnd = DateTime(2026, 8, 31, 23, 59, 59, 999);

        // Order created in July (outside August period)
        await ordersDao.insertOrder(
          db_pkg.OrdersCompanion.insert(
            id: 'ord-july',
            orderNumber: '26-JUL',
            customerId: 'cust-1',
            status: const Value('completed'),
            expectedPickupDate: DateTime(2026, 7, 25),
            subtotal: 50000,
            total: 50000, // 500 EGP
            createdAt: DateTime(2026, 7, 20),
            updatedAt: DateTime(2026, 7, 20),
          ),
        );

        // Payment for July order occurred in August!
        await paymentsDao.insertPayment(
          db_pkg.PaymentsCompanion.insert(
            id: 'pay-august',
            orderId: 'ord-july',
            amount: 50000, // 500 EGP
            paymentMethod: PaymentMethod.cash.value,
            paidAt: DateTime(2026, 8, 2, 10, 0),
            createdAt: DateTime(2026, 8, 2, 10, 0),
            updatedAt: DateTime(2026, 8, 2, 10, 0),
          ),
        );

        // Order created in August, cancelled in August, but refund recorded in September!
        await ordersDao.insertOrder(
          db_pkg.OrdersCompanion.insert(
            id: 'ord-aug-canc',
            orderNumber: '26-AUG-CANC',
            customerId: 'cust-1',
            status: const Value('cancelled'),
            expectedPickupDate: DateTime(2026, 8, 25),
            subtotal: 20000,
            total: 20000, // 200 EGP
            createdAt: DateTime(2026, 8, 15),
            updatedAt: DateTime(2026, 8, 15),
          ),
        );
        await refundsDao.insertRefund(
          db_pkg.RefundsCompanion.insert(
            id: 'ref-sept',
            orderId: 'ord-aug-canc',
            amount: 20000, // 200 EGP
            refundMethod: 'cash',
            refundedAt: DateTime(2026, 9, 2, 10, 0), // In September!
            createdAt: DateTime(2026, 9, 2, 10, 0),
            updatedAt: DateTime(2026, 9, 2, 10, 0),
          ),
        );

        final augustReport = await reportsRepository.getFinancialReport(
          startDate: augustStart,
          endDate: augustEnd,
        );

        // August Sales: 0 (July order created in July; Aug order is cancelled)
        expect(augustReport.totalSales, Money.zero);

        // August Payments: 500 EGP (Payment occurred in August)
        expect(augustReport.totalPayments, const Money.fromPiastres(50000));

        // August Refunds: 0 (Refund occurred in September)
        expect(augustReport.totalRefunds, Money.zero);
        expect(augustReport.netPayments, const Money.fromPiastres(50000));

        // September Report
        final septStart = DateTime(2026, 9, 1, 0, 0, 0);
        final septEnd = DateTime(2026, 9, 30, 23, 59, 59, 999);

        final septReport = await reportsRepository.getFinancialReport(
          startDate: septStart,
          endDate: septEnd,
        );

        // September Sales: 0
        expect(septReport.totalSales, Money.zero);

        // September Payments: 0
        expect(septReport.totalPayments, Money.zero);

        // September Refunds: 200 EGP (refundedAt is in September)
        expect(septReport.totalRefunds, const Money.fromPiastres(20000));

        // September Net Payments: 0 - 200 = -200 EGP
        expect(septReport.netPayments, const Money.fromPiastres(-20000));
      },
    );

    test(
      'Part N: Sales includes processing, ready, completed orders, and excludes cancelled orders',
      () async {
        final periodStart = DateTime(2026, 8, 1, 0, 0, 0);
        final periodEnd = DateTime(2026, 8, 31, 23, 59, 59);

        // 1. Processing: 100 EGP
        await ordersDao.insertOrder(
          db_pkg.OrdersCompanion.insert(
            id: 'ord-st-proc',
            orderNumber: '26-P',
            customerId: 'cust-1',
            status: const Value('processing'),
            expectedPickupDate: DateTime(2026, 8, 10),
            subtotal: 10000,
            total: 10000,
            createdAt: DateTime(2026, 8, 2),
            updatedAt: DateTime(2026, 8, 2),
          ),
        );

        // 2. Ready: 200 EGP
        await ordersDao.insertOrder(
          db_pkg.OrdersCompanion.insert(
            id: 'ord-st-ready',
            orderNumber: '26-R',
            customerId: 'cust-1',
            status: const Value('ready'),
            expectedPickupDate: DateTime(2026, 8, 12),
            subtotal: 20000,
            total: 20000,
            createdAt: DateTime(2026, 8, 4),
            updatedAt: DateTime(2026, 8, 4),
          ),
        );

        // 3. Completed: 300 EGP
        await ordersDao.insertOrder(
          db_pkg.OrdersCompanion.insert(
            id: 'ord-st-comp',
            orderNumber: '26-K',
            customerId: 'cust-1',
            status: const Value('completed'),
            expectedPickupDate: DateTime(2026, 8, 14),
            subtotal: 30000,
            total: 30000,
            createdAt: DateTime(2026, 8, 6),
            updatedAt: DateTime(2026, 8, 6),
          ),
        );

        // 4. Cancelled: 400 EGP
        await ordersDao.insertOrder(
          db_pkg.OrdersCompanion.insert(
            id: 'ord-st-canc',
            orderNumber: '26-X',
            customerId: 'cust-1',
            status: const Value('cancelled'),
            expectedPickupDate: DateTime(2026, 8, 16),
            subtotal: 40000,
            total: 40000,
            createdAt: DateTime(2026, 8, 8),
            updatedAt: DateTime(2026, 8, 8),
          ),
        );

        final report = await reportsRepository.getFinancialReport(
          startDate: periodStart,
          endDate: periodEnd,
        );

        // Total Sales = 100 + 200 + 300 = 600 EGP. Cancelled 400 EGP is excluded!
        expect(report.totalSales, const Money.fromPiastres(60000));
      },
    );

    test(
      'Part N: Multiple refunds aggregate correctly by refundedAt',
      () async {
        final periodStart = DateTime(2026, 8, 1, 0, 0, 0);
        final periodEnd = DateTime(2026, 8, 31, 23, 59, 59);

        await ordersDao.insertOrder(
          db_pkg.OrdersCompanion.insert(
            id: 'ord-multi',
            orderNumber: '26-MULTI',
            customerId: 'cust-1',
            status: const Value('cancelled'),
            expectedPickupDate: DateTime(2026, 8, 20),
            subtotal: 10000,
            total: 10000,
            createdAt: DateTime(2026, 8, 1),
            updatedAt: DateTime(2026, 8, 1),
          ),
        );

        await refundsDao.insertRefund(
          db_pkg.RefundsCompanion.insert(
            id: 'ref-multi-1',
            orderId: 'ord-multi',
            amount: 3000, // 30 EGP
            refundMethod: 'cash',
            refundedAt: DateTime(2026, 8, 5, 10, 0),
            createdAt: DateTime(2026, 8, 5, 10, 0),
            updatedAt: DateTime(2026, 8, 5, 10, 0),
          ),
        );

        await refundsDao.insertRefund(
          db_pkg.RefundsCompanion.insert(
            id: 'ref-multi-2',
            orderId: 'ord-multi',
            amount: 2000, // 20 EGP
            refundMethod: 'instaPay',
            refundedAt: DateTime(2026, 8, 10, 11, 0),
            createdAt: DateTime(2026, 8, 10, 11, 0),
            updatedAt: DateTime(2026, 8, 10, 11, 0),
          ),
        );

        await refundsDao.insertRefund(
          db_pkg.RefundsCompanion.insert(
            id: 'ref-multi-3',
            orderId: 'ord-multi',
            amount: 5000, // 50 EGP
            refundMethod: 'eWallet',
            refundedAt: DateTime(2026, 8, 15, 12, 0),
            createdAt: DateTime(2026, 8, 15, 12, 0),
            updatedAt: DateTime(2026, 8, 15, 12, 0),
          ),
        );

        final report = await reportsRepository.getFinancialReport(
          startDate: periodStart,
          endDate: periodEnd,
        );

        expect(
          report.totalRefunds,
          const Money.fromPiastres(10000),
        ); // 30 + 20 + 50 = 100 EGP
      },
    );

    test(
      'Part N: Empty period returns zero values for all metrics',
      () async {
        final periodStart = DateTime(2026, 1, 1, 0, 0, 0);
        final periodEnd = DateTime(2026, 1, 31, 23, 59, 59);

        final report = await reportsRepository.getFinancialReport(
          startDate: periodStart,
          endDate: periodEnd,
        );

        expect(report.totalSales, Money.zero);
        expect(report.totalPayments, Money.zero);
        expect(report.totalRefunds, Money.zero);
        expect(report.netPayments, Money.zero);
        expect(report.totalOperatingExpenses, Money.zero);
        expect(report.netProfit, Money.zero);
        expect(report.outstandingAmount, Money.zero);
        expect(report.totalDiscounts, Money.zero);
        expect(report.outstandingOrders, isEmpty);
        expect(report.expenseTransactions, isEmpty);
      },
    );

    test(
      'expense report strictly adheres to expense_date, not created_at',
      () async {
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
        expect(
          augustReport.totalOperatingExpenses,
          const Money.fromPiastres(15000),
        );
      },
    );

    test(
      'UAT-16 regression: single-day report (00:00:00 to 23:59:59) includes expense in totals, category breakdown, and expenseTransactions',
      () async {
        final periodStart = DateTime(2026, 9, 23, 0, 0, 0);
        final periodEnd = DateTime(2026, 9, 23, 23, 59, 59, 999);

        final cats = await expenseCategoriesDao.getAllCategories();
        final cleaningCat = cats.firstWhere((c) => c.name == 'منظفات');

        // Insert a 200 EGP expense for 2026-09-23 (as created in UAT-16)
        await expensesDao.insertExpense(
          db_pkg.ExpensesCompanion.insert(
            id: 'exp-uat-16',
            expenseCategoryId: cleaningCat.id,
            amount: 20000, // 200 EGP
            expenseDate: DateTime(2026, 9, 23),
            categoryNameSnapshot: 'منظفات',
            notes: const Value('cleaning stuff'),
            createdAt: DateTime(2026, 9, 23, 17, 24),
            updatedAt: DateTime(2026, 9, 23, 17, 24),
          ),
        );

        final report = await reportsRepository.getFinancialReport(
          startDate: periodStart,
          endDate: periodEnd,
        );

        // 1. Total expenses must equal 200 EGP
        expect(
          report.totalOperatingExpenses,
          const Money.fromPiastres(20000),
        );

        // 2. Categories breakdown must contain منظفات with 200 EGP
        expect(report.expenseCategoriesBreakdown.length, 1);
        expect(report.expenseCategoriesBreakdown.first.categoryName, 'منظفات');
        expect(
          report.expenseCategoriesBreakdown.first.totalAmount,
          const Money.fromPiastres(20000),
        );
        expect(report.expenseCategoriesBreakdown.first.count, 1);

        // 3. Detailed expense transactions list MUST contain the 200 EGP expense
        expect(report.expenseTransactions.length, 1);
        final txn = report.expenseTransactions.first;
        expect(txn.id, 'exp-uat-16');
        expect(txn.amount, const Money.fromPiastres(20000));
        expect(txn.categoryNameSnapshot, 'منظفات');
        expect(txn.notes, 'cleaning stuff');
        expect(txn.expenseDate, OrderDate(2026, 9, 23));
      },
    );
  });
}
