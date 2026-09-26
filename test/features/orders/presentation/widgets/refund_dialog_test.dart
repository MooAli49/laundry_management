import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:laundry_management/application/use_cases/create_refund_use_case.dart';
import 'package:laundry_management/core/theme/app_theme.dart';
import 'package:laundry_management/domain/entities/refund.dart';
import 'package:laundry_management/domain/entities/refund_balance_summary.dart';
import 'package:laundry_management/domain/enums/refund_method.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/features/orders/presentation/cubit/refund_cubit.dart';
import 'package:laundry_management/features/orders/presentation/widgets/refund_dialog.dart';

class FakeCreateRefundUseCase implements CreateRefundUseCase {
  int executeCallCount = 0;
  CreateRefundInput? lastInput;
  Refund? refundToReturn;
  Object? errorToThrow;

  @override
  Future<Refund> execute(CreateRefundInput input) async {
    executeCallCount++;
    lastInput = input;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return refundToReturn ??
        Refund(
          id: 'ref-default',
          orderId: input.orderId,
          amount: input.amount,
          refundMethod: input.refundMethod,
          reason: input.reason,
          refundedAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
  }
}

Widget testBoilerplate(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  late FakeCreateRefundUseCase fakeUseCase;
  late RefundCubit cubit;

  const testSummary = RefundBalanceSummary(
    totalPaid: Money.fromPiastres(10000), // 100.00 EGP
    totalRefunded: Money.fromPiastres(3000), // 30.00 EGP
    remainingRefundable: Money.fromPiastres(7000), // 70.00 EGP
  );

  setUp(() {
    fakeUseCase = FakeCreateRefundUseCase();
    cubit = RefundCubit(createRefundUseCase: fakeUseCase);
  });

  tearDown(() async {
    await cubit.close();
  });

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('RefundDialog Widget Tests (Part O: 6-13)', () {
    testWidgets(
      '6, 7, 8. Displays total paid, total refunded, and refundable amount',
      (tester) async {
        configureViewport(tester);
        await tester.pumpWidget(
          testBoilerplate(
            RefundDialog(
              orderId: 'ord-123',
              refundBalance: testSummary,
              cubit: cubit,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 6. Displays total paid
        expect(find.text('المبلغ المدفوع'), findsOneWidget);
        expect(find.text('100.00 ج.م'), findsOneWidget);

        // 7. Displays total refunded
        expect(find.text('المبلغ المسترد'), findsOneWidget);
        expect(find.text('30.00 ج.م'), findsOneWidget);

        // 8. Displays refundable amount
        expect(find.text('المبلغ القابل للاسترداد'), findsOneWidget);
        expect(find.text('70.00 ج.م'), findsOneWidget);
      },
    );

    testWidgets('9. Amount validation: rejected when empty or <= 0', (
      tester,
    ) async {
      configureViewport(tester);
      await tester.pumpWidget(
        testBoilerplate(
          RefundDialog(
            orderId: 'ord-123',
            refundBalance: testSummary,
            cubit: cubit,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap confirm with empty amount
      final confirmBtn = find.text('تأكيد الاسترداد');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(find.text('يرجى إدخال مبلغ الاسترداد'), findsOneWidget);
      expect(fakeUseCase.executeCallCount, 0);

      // Enter 0.00
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, '0.00');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(
        find.text('مبلغ الاسترداد يجب أن يكون أكبر من الصفر'),
        findsOneWidget,
      );
      expect(fakeUseCase.executeCallCount, 0);
    });

    testWidgets(
      '10. Amount validation: rejected when amount > refundable balance',
      (tester) async {
        configureViewport(tester);
        await tester.pumpWidget(
          testBoilerplate(
            RefundDialog(
              orderId: 'ord-123',
              refundBalance: testSummary, // 70.00 refundable
              cubit: cubit,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final textField = find.byType(TextField).first;
        await tester.enterText(textField, '75.00');

        final confirmBtn = find.text('تأكيد الاسترداد');
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        expect(
          find.text('مبلغ الاسترداد يتجاوز المبلغ القابل للاسترداد'),
          findsOneWidget,
        );
        expect(fakeUseCase.executeCallCount, 0);
      },
    );

    testWidgets('11. Refund method selection works and defaults to cash', (
      tester,
    ) async {
      configureViewport(tester);
      await tester.pumpWidget(
        testBoilerplate(
          RefundDialog(
            orderId: 'ord-123',
            refundBalance: testSummary,
            cubit: cubit,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('نقدي'), findsOneWidget);
      expect(find.text('InstaPay'), findsOneWidget);
      expect(find.text('محفظة إلكترونية'), findsOneWidget);

      // Select InstaPay
      await tester.tap(find.text('InstaPay'));
      await tester.pumpAndSettle();

      final textField = find.byType(TextField).first;
      await tester.enterText(textField, '25.00');

      await tester.tap(find.text('تأكيد الاسترداد'));
      await tester.pumpAndSettle();

      expect(fakeUseCase.executeCallCount, 1);
      expect(fakeUseCase.lastInput?.refundMethod, RefundMethod.instaPay);
      expect(fakeUseCase.lastInput?.amount, Money.fromPiastres(2500));
    });

    testWidgets('12. Reason is optional and trims whitespace', (
      tester,
    ) async {
      configureViewport(tester);
      await tester.pumpWidget(
        testBoilerplate(
          RefundDialog(
            orderId: 'ord-123',
            refundBalance: testSummary,
            cubit: cubit,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      final amountField = textFields.first;
      final reasonField = textFields.last;

      await tester.enterText(amountField, '20.00');
      await tester.enterText(reasonField, '  سبب تجريبي للاسترداد  ');

      await tester.tap(find.text('تأكيد الاسترداد'));
      await tester.pumpAndSettle();

      expect(fakeUseCase.executeCallCount, 1);
      expect(fakeUseCase.lastInput?.reason, 'سبب تجريبي للاسترداد');
    });

    testWidgets(
      '13. Full refund convenience button fills exact refundable amount',
      (tester) async {
        configureViewport(tester);
        await tester.pumpWidget(
          testBoilerplate(
            RefundDialog(
              orderId: 'ord-123',
              refundBalance: testSummary, // 70.00 refundable
              cubit: cubit,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final fullRefundBtn = find.text('استرداد كامل المبلغ');
        expect(fullRefundBtn, findsOneWidget);

        await tester.tap(fullRefundBtn);
        await tester.pumpAndSettle();

        // Check text field has 70.00
        final textField = tester.widget<TextField>(
          find.byType(TextField).first,
        );
        expect(textField.controller?.text, '70.00');

        await tester.tap(find.text('تأكيد الاسترداد'));
        await tester.pumpAndSettle();

        expect(fakeUseCase.executeCallCount, 1);
        expect(fakeUseCase.lastInput?.amount, Money.fromPiastres(7000));
      },
    );
  });
}
