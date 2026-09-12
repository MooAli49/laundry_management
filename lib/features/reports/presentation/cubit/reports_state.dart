import '../../../../domain/entities/financial_report_data.dart';
import '../../../../domain/entities/orders_report_data.dart';
import '../../../../domain/enums/report_period.dart';

enum ReportsTab {
  orders,
  financial,
}

class ReportsState {
  final ReportsTab selectedTab;
  final ReportPeriod selectedPeriod;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final OrdersReportData ordersReport;
  final FinancialReportData financialReport;
  final bool isLoading;
  final String? errorMessage;

  const ReportsState({
    this.selectedTab = ReportsTab.orders,
    this.selectedPeriod = ReportPeriod.thisMonth,
    this.startDate,
    this.endDate,
    this.customStartDate,
    this.customEndDate,
    this.ordersReport = OrdersReportData.empty,
    this.financialReport = FinancialReportData.empty,
    this.isLoading = false,
    this.errorMessage,
  });

  ReportsState copyWith({
    ReportsTab? selectedTab,
    ReportPeriod? selectedPeriod,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? customStartDate,
    DateTime? customEndDate,
    OrdersReportData? ordersReport,
    FinancialReportData? financialReport,
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ReportsState(
      selectedTab: selectedTab ?? this.selectedTab,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
      ordersReport: ordersReport ?? this.ordersReport,
      financialReport: financialReport ?? this.financialReport,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
