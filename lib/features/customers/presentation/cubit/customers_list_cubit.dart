import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../domain/entities/customer.dart';
import '../../../../domain/repositories/customer_repository.dart';
import '../../../../domain/repositories/order_repository.dart';
import '../models/customer_list_item_view_model.dart';
import 'customers_list_state.dart';

class CustomersListCubit extends Cubit<CustomersListState> {
  static const int _pageSize = 50;

  final CustomerRepository _customerRepository;
  final OrderRepository _orderRepository;
  Timer? _debounceTimer;
  int _searchRequestId = 0;
  int _latestLoadMoreRequestId = 0;

  bool _isStaleLoadMore(int requestId) {
    if (requestId != _searchRequestId) {
      if (requestId == _latestLoadMoreRequestId && state.isLoadingMore) {
        emit(state.copyWith(isLoadingMore: false));
      }
      return true;
    }
    return false;
  }

  CustomersListCubit({
    required CustomerRepository customerRepository,
    required OrderRepository orderRepository,
  })  : _customerRepository = customerRepository,
        _orderRepository = orderRepository,
        super(const CustomersListState());

  Future<void> loadCustomers({bool refresh = false}) async {
    final requestId = ++_searchRequestId;
    emit(state.copyWith(isLoading: true, clearErrorMessage: true));
    try {
      final rawQuery = state.searchQuery.trim();
      final query = rawQuery.isNotEmpty ? rawQuery : null;
      final customers = await _customerRepository.searchCustomers(
        query: query,
        limit: _pageSize,
        offset: 0,
      );
      final totalCount = await _customerRepository.getCustomersCount(query: query);
      final customerIds = customers.map((c) => c.id).toList();
      final orderCounts = await _orderRepository.getOrderCountsByCustomerIds(customerIds);

      if (isClosed || requestId != _searchRequestId) return;

      final viewModels = customers.map((customer) {
        return CustomerListItemViewModel(
          customer: customer,
          orderCount: orderCounts[customer.id] ?? 0,
        );
      }).toList();

      final hasMore = customers.length == _pageSize && customers.length < totalCount;

      emit(state.copyWith(
        customers: viewModels,
        totalCustomersCount: totalCount,
        hasMoreCustomers: hasMore,
        isLoading: false,
        isLoadingMore: false,
      ));
    } on Failure catch (e) {
      if (isClosed || requestId != _searchRequestId) return;
      emit(state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        errorMessage: e.message,
      ));
    } catch (_) {
      if (isClosed || requestId != _searchRequestId) return;
      emit(state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        errorMessage: AppStrings.unexpectedError,
      ));
    }
  }

  Future<void> loadMoreCustomers() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMoreCustomers || isClosed) {
      return;
    }
    final requestId = ++_searchRequestId;
    _latestLoadMoreRequestId = requestId;
    emit(state.copyWith(isLoadingMore: true, clearErrorMessage: true));
    try {
      final rawQuery = state.searchQuery.trim();
      final query = rawQuery.isNotEmpty ? rawQuery : null;
      final currentCount = state.customers.length;
      final nextCustomers = await _customerRepository.searchCustomers(
        query: query,
        limit: _pageSize,
        offset: currentCount,
      );
      final nextCustomerIds = nextCustomers.map((c) => c.id).toList();
      final nextOrderCounts = await _orderRepository.getOrderCountsByCustomerIds(nextCustomerIds);

      if (isClosed) return;
      if (_isStaleLoadMore(requestId)) return;

      final nextViewModels = nextCustomers.map((customer) {
        return CustomerListItemViewModel(
          customer: customer,
          orderCount: nextOrderCounts[customer.id] ?? 0,
        );
      }).toList();

      final totalLoaded = currentCount + nextCustomers.length;
      final hasMore = nextCustomers.length == _pageSize && totalLoaded < state.totalCustomersCount;

      emit(state.copyWith(
        customers: [...state.customers, ...nextViewModels],
        isLoadingMore: false,
        hasMoreCustomers: hasMore,
      ));
    } on Failure catch (e) {
      if (isClosed) return;
      if (_isStaleLoadMore(requestId)) return;
      emit(state.copyWith(
        isLoadingMore: false,
        errorMessage: e.message,
      ));
    } catch (_) {
      if (isClosed) return;
      if (_isStaleLoadMore(requestId)) return;
      emit(state.copyWith(
        isLoadingMore: false,
        errorMessage: AppStrings.unexpectedError,
      ));
    }
  }

  Future<Customer> createCustomer({
    required String name,
    required String phone,
    String? notes,
  }) async {
    final now = DateTime.now();
    final newCustomer = Customer(
      id: const Uuid().v4(),
      name: name,
      phone: phone,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
    final created = await _customerRepository.createCustomer(newCustomer);
    await loadCustomers(refresh: true);
    return created;
  }

  Future<Customer?> getCustomerByPhone(String phone) {
    return _customerRepository.getCustomerByPhone(phone);
  }

  void search(String query) {
    final trimmed = query.trim();
    if (trimmed == state.searchQuery) return;
    _debounceTimer?.cancel();
    _searchRequestId++; // Immediately invalidate any in-flight requests!
    emit(state.copyWith(searchQuery: trimmed));
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      loadCustomers();
    });
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }
}
