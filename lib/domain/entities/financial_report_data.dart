import '../value_objects/money.dart';
import 'expense.dart';
import 'expense_category_breakdown_item.dart';
import 'outstanding_order_summary.dart';
import 'payment_method_breakdown_item.dart';

class FinancialReportData {
  final Money totalSales;
  final Money totalPayments;
  final Money totalOperatingExpenses;
  final Money netProfit;
  final Money outstandingAmount;
  final Money totalDiscounts;
  final List<PaymentMethodBreakdownItem> paymentMethodsBreakdown;
  final List<ExpenseCategoryBreakdownItem> expenseCategoriesBreakdown;
  final List<Expense> expenseTransactions;
  final List<OutstandingOrderSummary> outstandingOrders;

  const FinancialReportData({
    required this.totalSales,
    required this.totalPayments,
    required this.totalOperatingExpenses,
    required this.netProfit,
    required this.outstandingAmount,
    required this.totalDiscounts,
    required this.paymentMethodsBreakdown,
    required this.expenseCategoriesBreakdown,
    required this.expenseTransactions,
    required this.outstandingOrders,
  });

  static const empty = FinancialReportData(
    totalSales: Money.zero,
    totalPayments: Money.zero,
    totalOperatingExpenses: Money.zero,
    netProfit: Money.zero,
    outstandingAmount: Money.zero,
    totalDiscounts: Money.zero,
    paymentMethodsBreakdown: [],
    expenseCategoriesBreakdown: [],
    expenseTransactions: [],
    outstandingOrders: [],
  );
}
