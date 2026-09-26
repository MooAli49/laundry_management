import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/repositories/dashboard_repository.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final DashboardRepository _dashboardRepository;
  StreamSubscription? _subscription;

  DashboardCubit({required DashboardRepository dashboardRepository})
    : _dashboardRepository = dashboardRepository,
      super(const DashboardState());

  Future<void> loadDashboard() async {
    emit(state.copyWith(isLoading: true, clearErrorMessage: true));
    _subscription?.cancel();
    _subscription = _dashboardRepository.watchDashboardData().listen(
      (data) {
        emit(
          state.copyWith(data: data, isLoading: false, clearErrorMessage: true),
        );
      },
      onError: (_) {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: 'تعذر تحميل بيانات الرئيسية',
          ),
        );
      },
    );

    try {
      final initialData = await _dashboardRepository.getDashboardData();
      emit(
        state.copyWith(
          data: initialData,
          isLoading: false,
          clearErrorMessage: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'تعذر تحميل بيانات الرئيسية',
        ),
      );
    }
  }

  Future<void> refresh() async {
    try {
      final data = await _dashboardRepository.getDashboardData();
      emit(state.copyWith(data: data, clearErrorMessage: true));
    } catch (_) {
      emit(state.copyWith(errorMessage: 'تعذر تحديث بيانات الرئيسية'));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
