import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../../../domain/repositories/customer_repository.dart';
import '../../../../domain/repositories/order_repository.dart';
import '../../../../domain/repositories/payment_repository.dart';
import '../../../../domain/value_objects/money.dart';
import '../models/customer_detail_view_model.dart';
import 'customer_detail_state.dart';

class CustomerDetailCubit extends Cubit<CustomerDetailState> {
  final CustomerRepository _customerRepository;
  final OrderRepository _orderRepository;
  final PaymentRepository _paymentRepository;

  CustomerDetailCubit({
    required CustomerRepository customerRepository,
    required OrderRepository orderRepository,
    required PaymentRepository paymentRepository,
  })  : _customerRepository = customerRepository,
        _orderRepository = orderRepository,
        _paymentRepository = paymentRepository,
        super(const CustomerDetailState());

  Future<void> loadCustomerDetail(String customerId) async {
    emit(state.copyWith(isLoading: true, clearErrorMessage: true));
    try {
      final customer = await _customerRepository.getCustomerById(customerId);
      if (customer == null) {
        if (isClosed) return;
        emit(state.copyWith(
          isLoading: false,
          errorMessage: 'العميل غير موجود',
        ));
        return;
      }

      final orders = await _orderRepository.getOrders(customerId: customerId);
      final remainingAmounts = <String, Money>{};
      final paidAmounts = <String, Money>{};
      for (final order in orders) {
        final remaining = await _paymentRepository.getRemainingAmountForOrder(order.id);
        final paid = await _paymentRepository.getTotalPaidForOrder(order.id);
        remainingAmounts[order.id] = remaining;
        paidAmounts[order.id] = paid;
      }

      final detailModel = CustomerDetailViewModel(
        customer: customer,
        orders: orders,
        remainingAmounts: remainingAmounts,
        paidAmounts: paidAmounts,
      );

      if (isClosed) return;
      emit(state.copyWith(
        isLoading: false,
        data: detailModel,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<bool> updateCustomerInfo({
    required String name,
    required String phone,
    String? notes,
  }) async {
    if (state.data == null) return false;
    emit(state.copyWith(
      isSaving: true,
      clearErrorMessage: true,
      clearActionSuccessMessage: true,
    ));

    try {
      final current = state.data!.customer;
      final updated = current.copyWith(
        name: name.trim(),
        phone: phone.trim(),
        notes: notes?.trim().isNotEmpty == true ? notes!.trim() : null,
        updatedAt: DateTime.now(),
      );

      final saved = await _customerRepository.updateCustomer(updated);
      if (isClosed) return false;
      emit(state.copyWith(
        isSaving: false,
        data: state.data!.copyWith(customer: saved),
        actionSuccessMessage: 'تم تحديث بيانات العميل بنجاح',
      ));
      return true;
    } on Failure catch (e) {
      if (isClosed) return false;
      emit(state.copyWith(
        isSaving: false,
        errorMessage: e.message,
      ));
      return false;
    } catch (e) {
      if (isClosed) return false;
      emit(state.copyWith(
        isSaving: false,
        errorMessage: e.toString(),
      ));
      return false;
    }
  }
}
