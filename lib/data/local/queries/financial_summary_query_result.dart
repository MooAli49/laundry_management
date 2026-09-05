import '../../../../domain/value_objects/money.dart';
import '../../../../domain/value_objects/order_date.dart';

class FinancialSummaryQueryResult {
  final OrderDate startDate;
  final OrderDate endDate;
  final Money totalSales;
  final Money totalPayments;
  final Money totalExpenses;
  final Money netProfit;

  const FinancialSummaryQueryResult({
    required this.startDate,
    required this.endDate,
    required this.totalSales,
    required this.totalPayments,
    required this.totalExpenses,
    required this.netProfit,
  });
}
