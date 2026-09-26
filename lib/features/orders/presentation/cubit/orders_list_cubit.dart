import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../../../domain/enums/order_status.dart';
import '../../../../domain/repositories/customer_repository.dart';
import '../../../../domain/repositories/order_repository.dart';
import '../../../../domain/repositories/payment_repository.dart';
import '../../../../domain/value_objects/order_date.dart';
import '../models/order_list_filter.dart';
import '../models/order_list_item_view_model.dart';
import 'orders_list_state.dart';

class OrdersListCubit extends Cubit<OrdersListState> {
  final OrderRepository _orderRepository;
  final CustomerRepository _customerRepository;
  final PaymentRepository _paymentRepository;
  final DateTime Function() _clock;

  static const int _pageSize = 20;

  StreamSubscription<void>? _dbSubscription;
  int _loadRequestId = 0;
  bool _hasPendingReload = false;

  @visibleForTesting
  bool get hasPendingReload => _hasPendingReload;

  OrdersListCubit({
    required OrderRepository orderRepository,
    required CustomerRepository customerRepository,
    required PaymentRepository paymentRepository,
    DateTime Function()? clock,
  }) : _orderRepository = orderRepository,
       _customerRepository = customerRepository,
       _paymentRepository = paymentRepository,
       _clock = clock ?? DateTime.now,
       super(const OrdersListState()) {
    _dbSubscription = _orderRepository.watchOrderTableUpdates().listen((_) {
      if (isClosed) return;
      if (state.orders.length > _pageSize) return;
      if (state.isLoading) {
        _hasPendingReload = true;
        return;
      }
      loadOrders(refresh: true);
    });
  }

  Future<void> loadOrders({bool refresh = false}) async {
    final requestId = ++_loadRequestId;
    emit(state.copyWith(isLoading: true, clearErrorMessage: true));

    try {
      final params = _resolveQueryParams();
      final orders = await _orderRepository.getOrders(
        status: params.status,
        excludedStatuses: params.excludedStatuses,
        expectedPickupDate: params.expectedPickupDate,
        isOverdue: params.isOverdue,
        referenceDate: _clock(),
        createdFrom: params.createdFrom,
        createdTo: params.createdTo,
        hasRemaining: params.hasRemaining,
        query: state.searchQuery.isNotEmpty ? state.searchQuery : null,
        limit: _pageSize,
        offset: 0,
      );

      final viewModels = await _enrichOrders(orders);

      if (isClosed || requestId != _loadRequestId) return;

      emit(
        state.copyWith(
          orders: viewModels,
          isLoading: false,
          hasMore: orders.length == _pageSize,
        ),
      );
    } on Failure catch (f) {
      if (isClosed || requestId != _loadRequestId) return;
      emit(state.copyWith(isLoading: false, errorMessage: f.message));
    } catch (e) {
      if (isClosed || requestId != _loadRequestId) return;
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    } finally {
      if (!isClosed && requestId == _loadRequestId && _hasPendingReload) {
        _hasPendingReload = false;
        if (state.orders.length <= _pageSize) {
          await loadOrders(refresh: true);
        }
      }
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    emit(state.copyWith(isLoadingMore: true, clearErrorMessage: true));

    try {
      final params = _resolveQueryParams();
      final nextOrders = await _orderRepository.getOrders(
        status: params.status,
        excludedStatuses: params.excludedStatuses,
        expectedPickupDate: params.expectedPickupDate,
        isOverdue: params.isOverdue,
        referenceDate: _clock(),
        createdFrom: params.createdFrom,
        createdTo: params.createdTo,
        hasRemaining: params.hasRemaining,
        query: state.searchQuery.isNotEmpty ? state.searchQuery : null,
        limit: _pageSize,
        offset: state.orders.length,
      );

      final nextViewModels = await _enrichOrders(nextOrders);

      emit(
        state.copyWith(
          orders: [...state.orders, ...nextViewModels],
          isLoadingMore: false,
          hasMore: nextOrders.length == _pageSize,
        ),
      );
    } on Failure catch (f) {
      emit(state.copyWith(isLoadingMore: false, errorMessage: f.message));
    } catch (e) {
      emit(state.copyWith(isLoadingMore: false, errorMessage: e.toString()));
    }
  }

  void setFilter(OrderListFilter filter) {
    if (filter == state.activeFilter) return;
    emit(state.copyWith(activeFilter: filter));
    loadOrders(refresh: true);
  }

  void setFilterByName(String filterName) {
    final filter = OrderListFilter.fromString(filterName);
    setFilter(filter);
  }

  void search(String query) {
    final trimmed = query.trim();
    if (trimmed == state.searchQuery) return;
    emit(state.copyWith(searchQuery: trimmed));
    loadOrders(refresh: true);
  }

  Future<List<OrderListItemViewModel>> _enrichOrders(
    List<dynamic> orders,
  ) async {
    final viewModels = <OrderListItemViewModel>[];
    for (final order in orders) {
      final customer = await _customerRepository.getCustomerById(
        order.customerId,
      );
      final totalPaid = await _paymentRepository.getTotalPaidForOrder(order.id);
      final remaining = await _paymentRepository.getRemainingAmountForOrder(
        order.id,
      );

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

  ({
    OrderStatus? status,
    List<OrderStatus>? excludedStatuses,
    OrderDate? expectedPickupDate,
    bool? isOverdue,
    DateTime? createdFrom,
    DateTime? createdTo,
    bool? hasRemaining,
  })
  _resolveQueryParams() {
    final filter = state.activeFilter;
    OrderStatus? status = filter.status;
    List<OrderStatus>? excludedStatuses;
    OrderDate? expectedPickupDate;
    bool? isOverdue;
    DateTime? createdFrom;
    DateTime? createdTo;
    final hasRemaining = filter.requiresRemainingOnly ? true : null;

    if (filter.requiresTodayOnly) {
      final now = _clock();
      createdFrom = DateTime(now.year, now.month, now.day, 0, 0, 0);
      createdTo = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    } else if (filter.requiresOverdueOnly) {
      isOverdue = true;
    } else if (filter.requiresTodayPickupOnly) {
      final now = _clock();
      expectedPickupDate = OrderDate(now.year, now.month, now.day);
      excludedStatuses = const [OrderStatus.completed, OrderStatus.cancelled];
    } else if (filter.requiresRemainingOnly) {
      excludedStatuses = const [OrderStatus.cancelled];
    }

    return (
      status: status,
      excludedStatuses: excludedStatuses,
      expectedPickupDate: expectedPickupDate,
      isOverdue: isOverdue,
      createdFrom: createdFrom,
      createdTo: createdTo,
      hasRemaining: hasRemaining,
    );
  }

  @override
  Future<void> close() {
    _dbSubscription?.cancel();
    return super.close();
  }
}
