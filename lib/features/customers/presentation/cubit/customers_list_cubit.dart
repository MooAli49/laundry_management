import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/repositories/customer_repository.dart';
import '../../../../domain/repositories/order_repository.dart';
import '../models/customer_list_item_view_model.dart';
import 'customers_list_state.dart';

class CustomersListCubit extends Cubit<CustomersListState> {
  final CustomerRepository _customerRepository;
  final OrderRepository _orderRepository;

  CustomersListCubit({
    required CustomerRepository customerRepository,
    required OrderRepository orderRepository,
  })  : _customerRepository = customerRepository,
        _orderRepository = orderRepository,
        super(const CustomersListState());

  Future<void> loadCustomers({bool refresh = false}) async {
    emit(state.copyWith(isLoading: true, clearErrorMessage: true));
    try {
      final query = state.searchQuery.trim().isNotEmpty ? state.searchQuery.trim() : null;
      final customers = await _customerRepository.searchCustomers(query: query);
      final orderCounts = await _orderRepository.getOrderCountsByCustomer();

      final viewModels = customers.map((customer) {
        return CustomerListItemViewModel(
          customer: customer,
          orderCount: orderCounts[customer.id] ?? 0,
        );
      }).toList();

      if (isClosed) return;
      emit(state.copyWith(
        customers: viewModels,
        isLoading: false,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
    }
  }

  void search(String query) {
    final trimmed = query.trim();
    if (trimmed == state.searchQuery) return;
    emit(state.copyWith(searchQuery: trimmed));
    loadCustomers();
  }
}
