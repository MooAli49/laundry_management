import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../application/use_cases/create_refund_use_case.dart';
import '../../../../core/errors/failures.dart';
import '../../../../domain/enums/refund_method.dart';
import '../../../../domain/value_objects/money.dart';
import 'refund_state.dart';

class RefundCubit extends Cubit<RefundState> {
  final CreateRefundUseCase _createRefundUseCase;

  RefundCubit({
    required CreateRefundUseCase createRefundUseCase,
  })  : _createRefundUseCase = createRefundUseCase,
        super(const RefundState());

  Future<void> submitRefund({
    required String orderId,
    required Money amount,
    required RefundMethod refundMethod,
    String? reason,
  }) async {
    // 18. Duplicate submission protection
    if (state.isSubmitting) return;

    emit(
      state.copyWith(
        isSubmitting: true,
        clearErrorMessage: true,
        clearRefund: true,
      ),
    );

    try {
      final refund = await _createRefundUseCase.execute(
        CreateRefundInput(
          orderId: orderId,
          amount: amount,
          refundMethod: refundMethod,
          reason: reason,
        ),
      );
      emit(
        state.copyWith(
          isSubmitting: false,
          refund: refund,
        ),
      );
    } on Failure catch (f) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: _mapFailureToMessage(f),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: _mapExceptionToMessage(e),
        ),
      );
    }
  }

  void reset() {
    emit(const RefundState());
  }

  static String _mapFailureToMessage(Failure failure) {
    final msg = failure.message.toLowerCase();
    if (msg.contains('only cancelled') || msg.contains('not cancelled')) {
      return 'لا يمكن استرداد مبالغ إلا للطلبات الملغاة فقط.';
    }
    if (msg.contains('exceeds refundable') || msg.contains('exceeds')) {
      return 'مبلغ الاسترداد يتجاوز المبلغ القابل للاسترداد.';
    }
    if (msg.contains('greater than zero') || msg.contains('greater than 0')) {
      return 'مبلغ الاسترداد يجب أن يكون أكبر من الصفر.';
    }
    if (msg.contains('order not found') || msg.contains('order id')) {
      return 'الطلب غير موجود.';
    }
    if (failure is DatabaseFailure) {
      return 'حدث خطأ في قاعدة البيانات المحلية. يرجى المحاولة مرة أخرى.';
    }
    return failure.message.isNotEmpty
        ? failure.message
        : 'تعذر تسجيل الاسترداد. يرجى المحاولة مرة أخرى.';
  }

  static String _mapExceptionToMessage(Object error) {
    final str = error.toString().toLowerCase();
    if (str.contains('only cancelled')) {
      return 'لا يمكن استرداد مبالغ إلا للطلبات الملغاة فقط.';
    }
    if (str.contains('exceeds refundable')) {
      return 'مبلغ الاسترداد يتجاوز المبلغ القابل للاسترداد.';
    }
    if (str.contains('greater than zero') || str.contains('greater than 0')) {
      return 'مبلغ الاسترداد يجب أن يكون أكبر من الصفر.';
    }
    return 'تعذر تسجيل الاسترداد. يرجى المحاولة مرة أخرى.';
  }
}
