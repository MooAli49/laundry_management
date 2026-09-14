import '../../../../domain/entities/dashboard_data.dart';

class DashboardState {
  final DashboardData data;
  final bool isLoading;
  final String? errorMessage;

  const DashboardState({
    this.data = DashboardData.empty,
    this.isLoading = false,
    this.errorMessage,
  });

  DashboardState copyWith({
    DashboardData? data,
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return DashboardState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
