import '../../core/errors/failures.dart';
import '../../domain/entities/expense_category_breakdown_item.dart';
import '../../domain/entities/financial_report_data.dart';
import '../../domain/entities/orders_report_data.dart';
import '../../domain/entities/outstanding_order_summary.dart';
import '../../domain/entities/payment_method_breakdown_item.dart';
import '../../domain/enums/payment_method.dart';
import '../../domain/repositories/expense_repository.dart';
import '../../domain/repositories/reports_repository.dart';
import '../../domain/value_objects/money.dart';
import '../../domain/value_objects/order_date.dart';
import '../local/daos/expenses_dao.dart';
import '../local/daos/orders_dao.dart';
import '../local/daos/payments_dao.dart';

class ReportsRepositoryImpl implements ReportsRepository {
  final OrdersDao _ordersDao;
  final PaymentsDao _paymentsDao;
  final ExpensesDao _expensesDao;
  final ExpenseRepository _expenseRepository;

  ReportsRepositoryImpl({
    required OrdersDao ordersDao,
    required PaymentsDao paymentsDao,
    required ExpensesDao expensesDao,
    required ExpenseRepository expenseRepository,
  })  : _ordersDao = ordersDao,
        _paymentsDao = paymentsDao,
        _expensesDao = expensesDao,
        _expenseRepository = expenseRepository;

  @override
  Future<OrdersReportData> getOrdersReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final now = DateTime.now();
      final aggregate = await _ordersDao.getOrdersReportAggregate(
        startDate: startDate,
        endDate: endDate,
        overdueCutoff: now,
      );

      return OrdersReportData(
        totalOrders: aggregate.totalOrders,
        totalOrderValue: Money.fromPiastres(aggregate.totalOrderValuePiastres),
        processingOrdersCount: aggregate.processingCount,
        readyOrdersCount: aggregate.readyCount,
        completedOrdersCount: aggregate.completedCount,
        cancelledOrdersCount: aggregate.cancelledCount,
        overdueOrdersCount: aggregate.overdueCount,
      );
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<FinancialReportData> getFinancialReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final now = DateTime.now();

      // 1. Order Aggregates (Sales, Discounts)
      final orderAggregate = await _ordersDao.getOrdersReportAggregate(
        startDate: startDate,
        endDate: endDate,
        overdueCutoff: now,
      );
      final totalSales = Money.fromPiastres(orderAggregate.totalOrderValuePiastres);
      final totalDiscounts = Money.fromPiastres(orderAggregate.totalDiscountsPiastres);

      // 2. Payments in period (by Payment.paidAt)
      final totalPaymentsPiastres = await _paymentsDao.getTotalPayments(
        startDate: startDate,
        endDate: endDate,
      );
      final totalPayments = Money.fromPiastres(totalPaymentsPiastres);

      final paymentsByMethodRaw = await _paymentsDao.getPaymentsGroupedByMethod(
        startDate: startDate,
        endDate: endDate,
      );

      final paymentMethodsBreakdown = <PaymentMethodBreakdownItem>[];
      for (final method in PaymentMethod.values) {
        final record = paymentsByMethodRaw[method.value] ??
            paymentsByMethodRaw[method.name];
        final amountPiastres = record?.total ?? 0;
        final count = record?.count ?? 0;
        final percentage = totalPaymentsPiastres > 0
            ? (amountPiastres / totalPaymentsPiastres) * 100.0
            : 0.0;

        paymentMethodsBreakdown.add(
          PaymentMethodBreakdownItem(
            method: method,
            totalAmount: Money.fromPiastres(amountPiastres),
            count: count,
            percentage: percentage,
          ),
        );
      }

      // 3. Operating Expenses in period (by Expense.expenseDate)
      final totalExpensesPiastres = await _expensesDao.getTotalExpenses(
        startDate: startDate,
        endDate: endDate,
      );
      final totalOperatingExpenses = Money.fromPiastres(totalExpensesPiastres);

      final expensesByCategoryRaw =
          await _expensesDao.getExpensesGroupedByCategorySnapshot(
        startDate: startDate,
        endDate: endDate,
      );

      final expenseCategoriesBreakdown = <ExpenseCategoryBreakdownItem>[];
      expensesByCategoryRaw.forEach((categoryName, stats) {
        final percentage = totalExpensesPiastres > 0
            ? (stats.total / totalExpensesPiastres) * 100.0
            : 0.0;
        expenseCategoriesBreakdown.add(
          ExpenseCategoryBreakdownItem(
            categoryName: categoryName,
            totalAmount: Money.fromPiastres(stats.total),
            count: stats.count,
            percentage: percentage,
          ),
        );
      });
      expenseCategoriesBreakdown.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

      // Detailed expense transactions for the period
      final expenseTransactions = await _expenseRepository.getExpenses(
        startDate: OrderDate.fromDate(startDate),
        endDate: OrderDate.fromDate(endDate),
        limit: 1000,
      );

      // 4. Outstanding Orders for period
      final outstandingRows = await _ordersDao.getOutstandingOrdersForPeriod(
        startDate: startDate,
        endDate: endDate,
      );

      int totalOutstandingPiastres = 0;
      final outstandingOrders = <OutstandingOrderSummary>[];

      for (final row in outstandingRows) {
        totalOutstandingPiastres += row.remainingPiastres;
        outstandingOrders.add(
          OutstandingOrderSummary(
            orderId: row.orderId,
            orderNumber: row.orderNumber,
            createdAt: row.createdAt,
            customerName: row.customerName,
            customerPhone: row.customerPhone,
            totalAmount: Money.fromPiastres(row.totalPiastres),
            paidAmount: Money.fromPiastres(row.paidPiastres),
            remainingAmount: Money.fromPiastres(row.remainingPiastres),
          ),
        );
      }

      final outstandingAmount = Money.fromPiastres(totalOutstandingPiastres);

      // 5. Net Profit = Total Sales - Total Operating Expenses
      // CRITICAL: Payments and Outstanding do NOT reduce Net Profit!
      final netProfit = totalSales - totalOperatingExpenses;

      return FinancialReportData(
        totalSales: totalSales,
        totalPayments: totalPayments,
        totalOperatingExpenses: totalOperatingExpenses,
        netProfit: netProfit,
        outstandingAmount: outstandingAmount,
        totalDiscounts: totalDiscounts,
        paymentMethodsBreakdown: paymentMethodsBreakdown,
        expenseCategoriesBreakdown: expenseCategoriesBreakdown,
        expenseTransactions: expenseTransactions,
        outstandingOrders: outstandingOrders,
      );
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }
}
