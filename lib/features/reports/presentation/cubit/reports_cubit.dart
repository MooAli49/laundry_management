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
        super(const ReportsState());

  Future<void> loadReports({
    ReportsTab tab = ReportsTab.orders,
    ReportPeriod period = ReportPeriod.thisMonth,
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    emit(state.copyWith(isLoading: true, clearErrorMessage: true));

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
        state.copyWith(
          selectedTab: tab,
          selectedPeriod: period,
          startDate: range.start,
          endDate: range.end,
          customStartDate: customStart,
          customEndDate: customEnd,
          ordersReport: ordersReport,
          financialReport: financialReport,
          isLoading: false,
          clearErrorMessage: true,
        ),
      );
    } on Failure catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.message));
    } catch (_) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'تعذر تحميل التقارير، يرجى المحاولة مرة أخرى',
      ));
    }
  }

  void selectTab(ReportsTab tab) {
    emit(state.copyWith(selectedTab: tab));
  }

  Future<void> selectPeriod(
    ReportPeriod period, {
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    await loadReports(
      tab: state.selectedTab,
      period: period,
      customStart: customStart,
      customEnd: customEnd,
    );
  }

  Future<void> refresh() async {
    await loadReports(
      tab: state.selectedTab,
      period: state.selectedPeriod,
      customStart: state.customStartDate,
      customEnd: state.customEndDate,
    );
  }
}
