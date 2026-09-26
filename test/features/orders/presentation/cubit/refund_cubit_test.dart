import 'package:flutter_test/flutter_test.dart';

import 'package:laundry_management/application/use_cases/create_refund_use_case.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/domain/entities/refund.dart';
import 'package:laundry_management/domain/enums/refund_method.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/features/orders/presentation/cubit/refund_cubit.dart';
import 'package:laundry_management/features/orders/presentation/cubit/refund_state.dart';

class FakeCreateRefundUseCase implements CreateRefundUseCase {
  int executeCallCount = 0;
  CreateRefundInput? lastInput;
  Refund? refundToReturn;
  Object? errorToThrow;
  Duration delay = Duration.zero;

  @override
  Future<Refund> execute(CreateRefundInput input) async {
    executeCallCount++;
    lastInput = input;
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return refundToReturn!;
  }
}

void main() {
  late FakeCreateRefundUseCase fakeCreateRefundUseCase;
  late RefundCubit cubit;

  final testRefund = Refund(
    id: 'ref-1',
    orderId: 'ord-1',
    amount: Money.fromPiastres(3500),
    refundMethod: RefundMethod.cash,
    reason: 'Customer requested refund',
    refundedAt: DateTime(2026, 9, 24, 10, 0),
    createdAt: DateTime(2026, 9, 24, 10, 0),
    updatedAt: DateTime(2026, 9, 24, 10, 0),
  );

  setUp(() {
    fakeCreateRefundUseCase = FakeCreateRefundUseCase();
    cubit = RefundCubit(createRefundUseCase: fakeCreateRefundUseCase);
  });

  tearDown(() async {
    await cubit.close();
  });

  group('RefundCubit (Part O: 14-18)', () {
    test('14. Initial state has default values', () {
      expect(cubit.state, const RefundState());
      expect(cubit.state.isSubmitting, isFalse);
      expect(cubit.state.refund, isNull);
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.isSuccess, isFalse);
      expect(cubit.state.hasError, isFalse);
    });

    test(
      '15 & 16. Successful refund creation emits submitting then success state',
      () async {
        fakeCreateRefundUseCase.refundToReturn = testRefund;

        final expected = [
          const RefundState(isSubmitting: true),
          RefundState(isSubmitting: false, refund: testRefund),
        ];

        expectLater(cubit.stream, emitsInOrder(expected));

        await cubit.submitRefund(
          orderId: 'ord-1',
          amount: Money.fromPiastres(3500),
          refundMethod: RefundMethod.cash,
          reason: 'Customer requested refund',
        );

        expect(fakeCreateRefundUseCase.executeCallCount, 1);
        expect(fakeCreateRefundUseCase.lastInput?.orderId, 'ord-1');
        expect(
          fakeCreateRefundUseCase.lastInput?.amount,
          Money.fromPiastres(3500),
        );
        expect(
          fakeCreateRefundUseCase.lastInput?.refundMethod,
          RefundMethod.cash,
        );
        expect(cubit.state.isSuccess, isTrue);
        expect(cubit.state.refund, testRefund);
      },
    );

    test(
      '17. Failure state when use case throws BusinessRuleFailure (exceeds balance)',
      () async {
        fakeCreateRefundUseCase.errorToThrow = const BusinessRuleFailure(
          'Refund amount exceeds refundable balance',
        );

        final expected = [
          const RefundState(isSubmitting: true),
          predicate<RefundState>(
            (s) =>
                !s.isSubmitting &&
                s.errorMessage != null &&
                s.errorMessage!.contains('مبلغ الاسترداد يتجاوز المبلغ القابل للاسترداد'),
          ),
        ];

        expectLater(cubit.stream, emitsInOrder(expected));

        await cubit.submitRefund(
          orderId: 'ord-1',
          amount: Money.fromPiastres(5000),
          refundMethod: RefundMethod.cash,
        );

        expect(cubit.state.hasError, isTrue);
      },
    );

    test('17b. Failure state when order is not cancelled', () async {
      fakeCreateRefundUseCase.errorToThrow = const BusinessRuleFailure(
        'Only cancelled orders can be refunded',
      );

      final expected = [
        const RefundState(isSubmitting: true),
        predicate<RefundState>(
          (s) =>
              !s.isSubmitting &&
              s.errorMessage != null &&
              s.errorMessage!.contains('لا يمكن استرداد مبالغ إلا للطلبات الملغاة فقط'),
        ),
      ];

      expectLater(cubit.stream, emitsInOrder(expected));

      await cubit.submitRefund(
        orderId: 'ord-1',
        amount: Money.fromPiastres(1000),
        refundMethod: RefundMethod.instaPay,
      );

      expect(cubit.state.hasError, isTrue);
    });

    test('18. Duplicate submission protection prevents double execution', () async {
      fakeCreateRefundUseCase.delay = const Duration(milliseconds: 50);
      fakeCreateRefundUseCase.refundToReturn = testRefund;

      // Launch first submission
      final f1 = cubit.submitRefund(
        orderId: 'ord-1',
        amount: Money.fromPiastres(3500),
        refundMethod: RefundMethod.cash,
      );

      expect(cubit.state.isSubmitting, isTrue);

      // Launch second submission while first is still submitting
      final f2 = cubit.submitRefund(
        orderId: 'ord-1',
        amount: Money.fromPiastres(3500),
        refundMethod: RefundMethod.cash,
      );

      await Future.wait([f1, f2]);

      // Verify use case was invoked only once
      expect(fakeCreateRefundUseCase.executeCallCount, 1);
      expect(cubit.state.isSuccess, isTrue);
      expect(cubit.state.refund, testRefund);
    });

    test('reset() emits default RefundState', () {
      cubit.reset();
      expect(cubit.state, const RefundState());
    });
  });
}
