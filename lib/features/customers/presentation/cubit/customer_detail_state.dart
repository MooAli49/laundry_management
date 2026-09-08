import '../models/customer_detail_view_model.dart';

class CustomerDetailState {
  final bool isLoading;
  final bool isSaving;
  final CustomerDetailViewModel? data;
  final String? errorMessage;
  final String? actionSuccessMessage;

  const CustomerDetailState({
    this.isLoading = false,
    this.isSaving = false,
    this.data,
    this.errorMessage,
    this.actionSuccessMessage,
  });

  CustomerDetailState copyWith({
    bool? isLoading,
    bool? isSaving,
    CustomerDetailViewModel? data,
    String? errorMessage,
    String? actionSuccessMessage,
    bool clearErrorMessage = false,
    bool clearActionSuccessMessage = false,
  }) {
    return CustomerDetailState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      data: data ?? this.data,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      actionSuccessMessage: clearActionSuccessMessage
          ? null
          : (actionSuccessMessage ?? this.actionSuccessMessage),
    );
  }
}
