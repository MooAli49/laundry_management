import '../../../../domain/entities/financial_report_data.dart';
import '../../../../domain/entities/orders_report_data.dart';
import '../../../../domain/enums/report_period.dart';

enum ReportsTab {
  orders,
  financial,
}

abstract class ReportsState {
  const ReportsState();
}

class ReportsInitial extends ReportsState {
  const ReportsInitial();
}

class ReportsLoading extends ReportsState {
  const ReportsLoading();
}

class ReportsLoaded extends ReportsState {
  final ReportsTab selectedTab;
  final ReportPeriod selectedPeriod;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final OrdersReportData ordersReport;
  final FinancialReportData financialReport;

  const ReportsLoaded({
    required this.selectedTab,
    required this.selectedPeriod,
    required this.startDate,
    required this.endDate,
    this.customStartDate,
    this.customEndDate,
    required this.ordersReport,
    required this.financialReport,
  });

  ReportsLoaded copyWith({
    ReportsTab? selectedTab,
    ReportPeriod? selectedPeriod,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? customStartDate,
    DateTime? customEndDate,
    OrdersReportData? ordersReport,
    FinancialReportData? financialReport,
  }) {
    return ReportsLoaded(
      selectedTab: selectedTab ?? this.selectedTab,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
      ordersReport: ordersReport ?? this.ordersReport,
      financialReport: financialReport ?? this.financialReport,
    );
  }
}

class ReportsError extends ReportsState {
  final String message;

  const ReportsError(this.message);
}
