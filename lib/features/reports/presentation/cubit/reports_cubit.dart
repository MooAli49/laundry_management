import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../../../domain/enums/report_period.dart';
import '../../../../domain/repositories/reports_repository.dart';
import 'reports_state.dart';

class ReportsCubit extends Cubit<ReportsState> {
  final ReportsRepository _reportsRepository;

  ReportsCubit({
    required ReportsRepository reportsRepository,
  })  : _reportsRepository = reportsRepository,
        super(const ReportsInitial());

  Future<void> loadReports({
    ReportsTab tab = ReportsTab.orders,
    ReportPeriod period = ReportPeriod.thisMonth,
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    emit(const ReportsLoading());

    try {
      final range = period.resolveDateRange(
        customStart: customStart,
        customEnd: customEnd,
      );

      final ordersReport = await _reportsRepository.getOrdersReport(
        startDate: range.start,
        endDate: range.end,
      );

      final financialReport = await _reportsRepository.getFinancialReport(
        startDate: range.start,
        endDate: range.end,
      );

      emit(
        ReportsLoaded(
          selectedTab: tab,
          selectedPeriod: period,
          startDate: range.start,
          endDate: range.end,
          customStartDate: customStart,
          customEndDate: customEnd,
          ordersReport: ordersReport,
          financialReport: financialReport,
        ),
      );
    } on Failure catch (e) {
      emit(ReportsError(e.message));
    } catch (_) {
      emit(const ReportsError('تعذر تحميل التقارير، يرجى المحاولة مرة أخرى'));
    }
  }

  void selectTab(ReportsTab tab) {
    final currentState = state;
    if (currentState is ReportsLoaded) {
      emit(currentState.copyWith(selectedTab: tab));
    }
  }

  Future<void> selectPeriod(
    ReportPeriod period, {
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    final currentState = state;
    final currentTab = currentState is ReportsLoaded
        ? currentState.selectedTab
        : ReportsTab.orders;

    await loadReports(
      tab: currentTab,
      period: period,
      customStart: customStart,
      customEnd: customEnd,
    );
  }

  Future<void> refresh() async {
    final currentState = state;
    if (currentState is ReportsLoaded) {
      await loadReports(
        tab: currentState.selectedTab,
        period: currentState.selectedPeriod,
        customStart: currentState.customStartDate,
        customEnd: currentState.customEndDate,
      );
    } else {
      await loadReports();
    }
  }
}
