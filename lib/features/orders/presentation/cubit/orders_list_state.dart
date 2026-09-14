import '../models/order_list_filter.dart';
import '../models/order_list_item_view_model.dart';

class OrdersListState {
  final List<OrderListItemViewModel> orders;
  final OrderListFilter activeFilter;
  final String searchQuery;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorMessage;

  const OrdersListState({
    this.orders = const [],
    this.activeFilter = OrderListFilter.all,
    this.searchQuery = '',
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.errorMessage,
  });

  OrdersListState copyWith({
    List<OrderListItemViewModel>? orders,
    OrderListFilter? activeFilter,
    String? searchQuery,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return OrdersListState(
      orders: orders ?? this.orders,
      activeFilter: activeFilter ?? this.activeFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
