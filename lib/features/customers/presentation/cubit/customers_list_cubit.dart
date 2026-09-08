import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../domain/repositories/customer_repository.dart';
import '../../../../domain/repositories/order_repository.dart';
import '../models/customer_list_item_view_model.dart';
import 'customers_list_state.dart';

class CustomersListCubit extends Cubit<CustomersListState> {
  final CustomerRepository _customerRepository;
  final OrderRepository _orderRepository;
  Timer? _debounceTimer;
  int _searchRequestId = 0;

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
      final customers = await _customerRepository.searchCustomers(query: query);
      final totalCount = await _customerRepository.getCustomersCount(query: query);
      final orderCounts = await _orderRepository.getOrderCountsByCustomer();

      if (isClosed || requestId != _searchRequestId) return;

      final viewModels = customers.map((customer) {
        return CustomerListItemViewModel(
          customer: customer,
          orderCount: orderCounts[customer.id] ?? 0,
        );
      }).toList();

      emit(state.copyWith(
        customers: viewModels,
        totalCustomersCount: totalCount,
        isLoading: false,
      ));
    } on Failure catch (e) {
      if (isClosed || requestId != _searchRequestId) return;
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      ));
    } catch (_) {
      if (isClosed || requestId != _searchRequestId) return;
      emit(state.copyWith(
        isLoading: false,
        errorMessage: AppStrings.unexpectedError,
      ));
    }
  }

  void search(String query) {
    final trimmed = query.trim();
    if (trimmed == state.searchQuery) return;
    _debounceTimer?.cancel();
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
