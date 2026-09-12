import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/failures.dart';
import '../../../../domain/entities/dashboard_order_item.dart';
import '../../../../domain/entities/payment.dart';
import '../../../../domain/enums/order_status.dart';
import '../../../../domain/enums/payment_method.dart';
import '../../../../domain/repositories/order_repository.dart';
import '../../../../domain/repositories/payment_repository.dart';
import '../../../../domain/value_objects/money.dart';
import 'record_payment_state.dart';

class RecordPaymentCubit extends Cubit<RecordPaymentState> {
  final OrderRepository _orderRepository;
  final PaymentRepository _paymentRepository;
  final Uuid _uuid;

  RecordPaymentCubit({
    required OrderRepository orderRepository,
    required PaymentRepository paymentRepository,
    Uuid uuid = const Uuid(),
  })  : _orderRepository = orderRepository,
        _paymentRepository = paymentRepository,
        _uuid = uuid,
        super(const RecordPaymentState());

  Future<void> searchOrders([String? query]) async {
    emit(state.copyWith(isLoadingOrders: true, clearErrorMessage: true));
    try {
      final ordersRaw = await _orderRepository.getOrders(
        hasRemaining: true,
        query: query?.trim().isNotEmpty == true ? query!.trim() : null,
        limit: 30,
      );

      final nonCancelled = ordersRaw
          .where((o) => o.status != OrderStatus.cancelled)
          .toList();

      if (nonCancelled.isEmpty) {
        emit(state.copyWith(isLoadingOrders: false, orders: []));
        return;
      }

      final orderIds = nonCancelled.map((o) => o.id).toList();
      final summaries = await _paymentRepository.getPaymentSummariesForOrders(orderIds);

      final items = nonCancelled.map((order) {
        final summary = summaries[order.id];
        return DashboardOrderItem(
          order: order,
          totalPaid: summary?.totalPaid ?? Money.zero,
          remainingAmount: summary?.remaining ?? order.total,
        );
      }).where((item) => item.remainingAmount.isPositive).toList();

      emit(state.copyWith(isLoadingOrders: false, orders: items));
    } catch (_) {
      emit(state.copyWith(
        isLoadingOrders: false,
        errorMessage: 'تعذر البحث عن الطلبات، يرجى المحاولة مرة أخرى',
      ));
    }
  }

  void selectOrder(DashboardOrderItem order) {
    emit(state.copyWith(
      selectedOrder: order,
      step: RecordPaymentStep.enterPayment,
      clearErrorMessage: true,
    ));
  }

  void backToOrderSelection() {
    emit(state.copyWith(
      step: RecordPaymentStep.selectOrder,
      clearSelectedOrder: true,
      clearErrorMessage: true,
    ));
  }

  Future<Payment?> recordPayment({
    required Money amount,
    required PaymentMethod method,
  }) async {
    final selected = state.selectedOrder;
    if (selected == null) return null;

    if (amount.isZero || amount.isNegative) {
      emit(state.copyWith(errorMessage: 'يرجى إدخال مبلغ أكبر من الصفر'));
      return null;
    }

    if (amount > selected.remainingAmount) {
      emit(state.copyWith(errorMessage: 'المبلغ المدخل يتجاوز المبلغ المتبقي على الطلب'));
      return null;
    }

    emit(state.copyWith(isRecordingPayment: true, clearErrorMessage: true));
    try {
      final now = DateTime.now();
      final payment = Payment(
        id: _uuid.v4(),
        orderId: selected.order.id,
        amount: amount,
        paymentMethod: method,
        paidAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final createdPayment = await _paymentRepository.recordPayment(payment);
      emit(state.copyWith(
        isRecordingPayment: false,
        isPaymentSuccess: true,
      ));
      return createdPayment;
    } on Failure catch (e) {
      emit(state.copyWith(isRecordingPayment: false, errorMessage: e.message));
      return null;
    } catch (e) {
      emit(state.copyWith(
        isRecordingPayment: false,
        errorMessage: e.toString().replaceFirst('BusinessRuleFailure: ', ''),
      ));
      return null;
    }
  }
}
