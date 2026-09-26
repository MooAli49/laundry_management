import '../../core/errors/failures.dart';
import '../../domain/entities/expense.dart';
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
import '../local/daos/refunds_dao.dart';
import '../local/database/app_database.dart' as app_db;

class ReportsRepositoryImpl implements ReportsRepository {
  final OrdersDao _ordersDao;
  final PaymentsDao _paymentsDao;
  final ExpensesDao _expensesDao;
  final RefundsDao? _refundsDao;

  ReportsRepositoryImpl({
    required OrdersDao ordersDao,
    required PaymentsDao paymentsDao,
    required ExpensesDao expensesDao,
    RefundsDao? refundsDao,
    ExpenseRepository? expenseRepository,
  }) : _ordersDao = ordersDao,
       _paymentsDao = paymentsDao,
       _expensesDao = expensesDao,
       _refundsDao = refundsDao;

  @override
  Future<OrdersReportData> getOrdersReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final now = DateTime.now();
      final todayDate = DateTime.utc(now.year, now.month, now.day);
      final aggregate = await _ordersDao.getOrdersReportAggregate(
        startDate: startDate,
        endDate: endDate,
        overdueCutoff: todayDate,
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
      final todayDate = DateTime.utc(now.year, now.month, now.day);

      // 1. Order Aggregates (Sales, Discounts)
      // Total Sales strictly excludes cancelled orders (Part 1 & Part C)
      final orderAggregate = await _ordersDao.getOrdersReportAggregate(
        startDate: startDate,
        endDate: endDate,
        overdueCutoff: todayDate,
      );
      final totalSales = Money.fromPiastres(
        orderAggregate.totalSalesPiastres,
      );
      final totalDiscounts = Money.fromPiastres(
        orderAggregate.totalDiscountsPiastres,
      );

      // 2. Payments in period (by Payment.paidAt)
      final totalPaymentsPiastres = await _paymentsDao.getTotalPayments(
        startDate: startDate,
        endDate: endDate,
      );
      final totalPayments = Money.fromPiastres(totalPaymentsPiastres);

      // 3. Refunds in period (by Refund.refundedAt) (Part 3 & Part E)
      final totalRefundsPiastres = _refundsDao != null
          ? await _refundsDao.getTotalRefunds(
              startDate: startDate,
              endDate: endDate,
            )
          : 0;
      final totalRefunds = Money.fromPiastres(totalRefundsPiastres);

      // 4. Net Payments = Total Payments - Total Refunds (Part 4 & Part F)
      final netPayments = totalPayments - totalRefunds;

      final paymentsByMethodRaw = await _paymentsDao.getPaymentsGroupedByMethod(
        startDate: startDate,
        endDate: endDate,
      );

      final paymentMethodsBreakdown = <PaymentMethodBreakdownItem>[];
      for (final method in PaymentMethod.values) {
        final record =
            paymentsByMethodRaw[method.value] ??
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

      // 5. Operating Expenses in period (by Expense.expenseDate) (Part 6)
      final totalExpensesPiastres = await _expensesDao.getTotalExpenses(
        startDate: startDate,
        endDate: endDate,
      );
      final totalOperatingExpenses = Money.fromPiastres(totalExpensesPiastres);

      final expensesByCategoryRaw = await _expensesDao
          .getExpensesGroupedByCategorySnapshot(
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
      expenseCategoriesBreakdown.sort(
        (a, b) => b.totalAmount.compareTo(a.totalAmount),
      );

      // Detailed expense transactions for the period (by Expense.expenseDate)
      final expenseRows = await _expensesDao.getExpenses(
        startDate: startDate,
        endDate: endDate,
        limit: 1000,
      );
      final expenseTransactions = expenseRows.map(_mapExpenseToDomain).toList();

      // 6. Outstanding Orders for period (excludes cancelled orders) (Part 5 & Part H)
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

      // 7. Net Profit = Total Sales - Total Operating Expenses (Part 7 & Part G)
      // Refunds are separate and do NOT alter Net Profit.
      // Payments and Outstanding do NOT reduce Net Profit.
      final netProfit = totalSales - totalOperatingExpenses;

      return FinancialReportData(
        totalSales: totalSales,
        totalPayments: totalPayments,
        totalRefunds: totalRefunds,
        netPayments: netPayments,
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

  Expense _mapExpenseToDomain(app_db.Expense row) {
    return Expense(
      id: row.id,
      expenseCategoryId: row.expenseCategoryId,
      amount: Money.fromPiastres(row.amount),
      expenseName: row.expenseName,
      expenseDate: OrderDate.fromDate(row.expenseDate),
      notes: row.notes,
      categoryNameSnapshot: row.categoryNameSnapshot,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
