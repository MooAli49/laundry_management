import '../models/customer_detail_view_model.dart';

class CustomerDetailState {
  final bool isLoading;
  final bool isLoadingMore;
  final bool isSaving;
  final bool hasMoreOrders;
  final CustomerDetailViewModel? data;
  final String? errorMessage;
  final String? actionSuccessMessage;

  const CustomerDetailState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isSaving = false,
    this.hasMoreOrders = false,
    this.data,
    this.errorMessage,
    this.actionSuccessMessage,
  });

  CustomerDetailState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    bool? isSaving,
    bool? hasMoreOrders,
    CustomerDetailViewModel? data,
    String? errorMessage,
    String? actionSuccessMessage,
    bool clearErrorMessage = false,
    bool clearActionSuccessMessage = false,
  }) {
    return CustomerDetailState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSaving: isSaving ?? this.isSaving,
      hasMoreOrders: hasMoreOrders ?? this.hasMoreOrders,
      data: data ?? this.data,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      actionSuccessMessage: clearActionSuccessMessage
          ? null
          : (actionSuccessMessage ?? this.actionSuccessMessage),
    );
  }
}
