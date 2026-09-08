import '../models/customer_list_item_view_model.dart';

class CustomersListState {
  final List<CustomerListItemViewModel> customers;
  final bool isLoading;
  final String searchQuery;
  final String? errorMessage;

  const CustomersListState({
    this.customers = const [],
    this.isLoading = false,
    this.searchQuery = '',
    this.errorMessage,
  });

  CustomersListState copyWith({
    List<CustomerListItemViewModel>? customers,
    bool? isLoading,
    String? searchQuery,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return CustomersListState(
      customers: customers ?? this.customers,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
