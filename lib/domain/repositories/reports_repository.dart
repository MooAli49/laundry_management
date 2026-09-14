import '../entities/financial_report_data.dart';
import '../entities/orders_report_data.dart';

abstract class ReportsRepository {
  Future<OrdersReportData> getOrdersReport({
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<FinancialReportData> getFinancialReport({
    required DateTime startDate,
    required DateTime endDate,
  });
}
