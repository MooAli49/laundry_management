import '../models/customer_list_item_view_model.dart';

class CustomersListState {
  final List<CustomerListItemViewModel> customers;
  final int totalCustomersCount;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMoreCustomers;
  final String searchQuery;
  final String? errorMessage;

  const CustomersListState({
    this.customers = const [],
    this.totalCustomersCount = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMoreCustomers = false,
    this.searchQuery = '',
    this.errorMessage,
  });

  CustomersListState copyWith({
    List<CustomerListItemViewModel>? customers,
    int? totalCustomersCount,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMoreCustomers,
    String? searchQuery,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return CustomersListState(
      customers: customers ?? this.customers,
      totalCustomersCount: totalCustomersCount ?? this.totalCustomersCount,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreCustomers: hasMoreCustomers ?? this.hasMoreCustomers,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
