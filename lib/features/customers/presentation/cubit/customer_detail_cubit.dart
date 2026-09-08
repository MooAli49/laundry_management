import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../domain/repositories/customer_repository.dart';
import '../../../../domain/repositories/order_repository.dart';
import '../../../../domain/repositories/payment_repository.dart';
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
    emit(state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
      clearActionSuccessMessage: true,
    ));
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

      final aggregate = await _orderRepository.getCustomerOrderAggregate(customerId);
      final orders = await _orderRepository.getOrders(
        customerId: customerId,
        limit: 20,
        offset: 0,
      );
      final orderIds = orders.map((o) => o.id).toList();
      final summaries = await _paymentRepository.getPaymentSummariesForOrders(orderIds);
      final hasMore = orders.length < aggregate.totalOrders;

      final detailModel = CustomerDetailViewModel(
        customer: customer,
        orders: orders,
        aggregate: aggregate,
        paymentSummaries: summaries,
      );

      if (isClosed) return;
      emit(state.copyWith(
        isLoading: false,
        data: detailModel,
        hasMoreOrders: hasMore,
      ));
    } on Failure catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      ));
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(
        isLoading: false,
        errorMessage: AppStrings.unexpectedError,
      ));
    }
  }

  Future<void> loadMoreOrders() async {
    if (state.isLoadingMore || !state.hasMoreOrders || state.data == null) return;
    emit(state.copyWith(isLoadingMore: true, clearErrorMessage: true));
    try {
      final customerId = state.data!.customer.id;
      final currentOrders = state.data!.orders;
      final nextOrders = await _orderRepository.getOrders(
        customerId: customerId,
        limit: 20,
        offset: currentOrders.length,
      );
      final nextOrderIds = nextOrders.map((o) => o.id).toList();
      final nextSummaries = await _paymentRepository.getPaymentSummariesForOrders(nextOrderIds);

      final combinedOrders = [...currentOrders, ...nextOrders];
      final combinedSummaries = {...state.data!.paymentSummaries, ...nextSummaries};
      final hasMore = combinedOrders.length < state.data!.aggregate.totalOrders;

      if (isClosed) return;
      emit(state.copyWith(
        isLoadingMore: false,
        hasMoreOrders: hasMore,
        data: state.data!.copyWith(
          orders: combinedOrders,
          paymentSummaries: combinedSummaries,
        ),
      ));
    } on Failure catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        isLoadingMore: false,
        errorMessage: e.message,
      ));
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(
        isLoadingMore: false,
        errorMessage: AppStrings.unexpectedError,
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
    } catch (_) {
      if (isClosed) return false;
      emit(state.copyWith(
        isSaving: false,
        errorMessage: AppStrings.unexpectedError,
      ));
      return false;
    }
  }
}
