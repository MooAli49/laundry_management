import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../../../domain/repositories/customer_repository.dart';
import '../../../../domain/repositories/order_repository.dart';
import '../../../../domain/repositories/payment_repository.dart';
import '../models/order_list_filter.dart';
import '../models/order_list_item_view_model.dart';
import 'orders_list_state.dart';

class OrdersListCubit extends Cubit<OrdersListState> {
  final OrderRepository _orderRepository;
  final CustomerRepository _customerRepository;
  final PaymentRepository _paymentRepository;

  static const int _pageSize = 20;

  OrdersListCubit({
    required OrderRepository orderRepository,
    required CustomerRepository customerRepository,
    required PaymentRepository paymentRepository,
  })  : _orderRepository = orderRepository,
        _customerRepository = customerRepository,
        _paymentRepository = paymentRepository,
        super(const OrdersListState());

  Future<void> loadOrders({bool refresh = false}) async {
    if (state.isLoading && !refresh) return;

    emit(state.copyWith(isLoading: true, clearErrorMessage: true));

    try {
      final orders = await _orderRepository.getOrders(
        status: state.activeFilter.status,
        hasRemaining: state.activeFilter.requiresRemainingOnly ? true : null,
        query: state.searchQuery.isNotEmpty ? state.searchQuery : null,
        limit: _pageSize,
        offset: 0,
      );

      final viewModels = await _enrichOrders(orders);

      emit(state.copyWith(
        orders: viewModels,
        isLoading: false,
        hasMore: orders.length == _pageSize,
      ));
    } on Failure catch (f) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: f.message,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    emit(state.copyWith(isLoadingMore: true, clearErrorMessage: true));

    try {
      final nextOrders = await _orderRepository.getOrders(
        status: state.activeFilter.status,
        hasRemaining: state.activeFilter.requiresRemainingOnly ? true : null,
        query: state.searchQuery.isNotEmpty ? state.searchQuery : null,
        limit: _pageSize,
        offset: state.orders.length,
      );

      final nextViewModels = await _enrichOrders(nextOrders);

      emit(state.copyWith(
        orders: [...state.orders, ...nextViewModels],
        isLoadingMore: false,
        hasMore: nextOrders.length == _pageSize,
      ));
    } on Failure catch (f) {
      emit(state.copyWith(
        isLoadingMore: false,
        errorMessage: f.message,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingMore: false,
        errorMessage: e.toString(),
      ));
    }
  }

  void setFilter(OrderListFilter filter) {
    if (filter == state.activeFilter) return;
    emit(state.copyWith(activeFilter: filter));
    loadOrders(refresh: true);
  }

  void search(String query) {
    final trimmed = query.trim();
    if (trimmed == state.searchQuery) return;
    emit(state.copyWith(searchQuery: trimmed));
    loadOrders(refresh: true);
  }

  Future<List<OrderListItemViewModel>> _enrichOrders(List<dynamic> orders) async {
    final viewModels = <OrderListItemViewModel>[];
    for (final order in orders) {
      final customer = await _customerRepository.getCustomerById(order.customerId);
      final totalPaid = await _paymentRepository.getTotalPaidForOrder(order.id);
      final remaining = await _paymentRepository.getRemainingAmountForOrder(order.id);

      viewModels.add(
        OrderListItemViewModel(
          order: order,
          customer: customer,
          totalPaid: totalPaid,
          remainingAmount: remaining,
        ),
      );
    }
    return viewModels;
  }
}
