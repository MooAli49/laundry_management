import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/enums/payment_method.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';
import 'package:laundry_management/features/orders/presentation/models/order_list_filter.dart';
import 'package:laundry_management/features/orders/presentation/models/order_list_item_view_model.dart';
import 'package:laundry_management/features/orders/presentation/widgets/add_payment_dialog.dart';
import 'package:laundry_management/features/orders/presentation/widgets/cancel_order_dialog.dart';
import 'package:laundry_management/features/orders/presentation/widgets/order_card.dart';
import 'package:laundry_management/features/orders/presentation/widgets/order_status_badge.dart';
import 'package:laundry_management/features/orders/presentation/widgets/orders_filter_bar.dart';

Widget testBoilerplate(Widget child) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('Orders Presentation Widgets Tests', () {
    testWidgets('OrderStatusBadge renders correct Arabic status labels', (tester) async {
      await tester.pumpWidget(testBoilerplate(
        const Column(
          children: [
            OrderStatusBadge(status: OrderStatus.processing),
            OrderStatusBadge(status: OrderStatus.ready),
            OrderStatusBadge(status: OrderStatus.completed),
            OrderStatusBadge(status: OrderStatus.cancelled),
          ],
        ),
      ));

      expect(find.text('قيد التجهيز'), findsOneWidget);
      expect(find.text('جاهز'), findsOneWidget);
      expect(find.text('مكتمل'), findsOneWidget);
      expect(find.text('ملغي'), findsOneWidget);
    });

    testWidgets('OrdersFilterBar renders all filters and triggers selection', (tester) async {
      OrderListFilter? selected;
      await tester.pumpWidget(testBoilerplate(
        OrdersFilterBar(
          selectedFilter: OrderListFilter.all,
          onFilterSelected: (f) => selected = f,
        ),
      ));

      expect(find.text('الكل'), findsOneWidget);
      expect(find.text('قيد التجهيز'), findsOneWidget);
      expect(find.text('جاهز'), findsOneWidget);
      expect(find.text('مكتمل'), findsOneWidget);
      expect(find.text('ملغي'), findsOneWidget);
      expect(find.text('يوجد مبلغ متبقي'), findsOneWidget);

      await tester.tap(find.text('جاهز'));
      await tester.pumpAndSettle();

      expect(selected, OrderListFilter.ready);
    });

    testWidgets('OrderCard displays order number, customer, status, total and remaining', (tester) async {
      final now = DateTime(2026, 9, 1);
      final order = Order(
        id: 'ord-1',
        orderNumber: '26-001',
        customerId: 'cust-1',
        status: OrderStatus.processing,
        expectedPickupDate: OrderDate(2026, 9, 10),
        subtotal: const Money.fromPiastres(5000),
        total: const Money.fromPiastres(5000),
        createdAt: now,
        updatedAt: now,
      );

      final customer = Customer(
        id: 'cust-1',
        name: 'عمرو خالد',
        phone: '01012345678',
        createdAt: now,
        updatedAt: now,
      );

      final vm = OrderListItemViewModel(
        order: order,
        customer: customer,
        totalPaid: const Money.fromPiastres(2000),
        remainingAmount: const Money.fromPiastres(3000),
      );

      bool tapped = false;
      await tester.pumpWidget(testBoilerplate(
        OrderCard(
          item: vm,
          onTap: () => tapped = true,
        ),
      ));

      expect(find.text('#26-001'), findsOneWidget);
      expect(find.text('عمرو خالد'), findsOneWidget);
      expect(find.text('قيد التجهيز'), findsOneWidget);
      expect(find.text('الإجمالي: 50.00 ج.م'), findsOneWidget);
      expect(find.text('المتبقي: 30.00 ج.م'), findsOneWidget);

      await tester.tap(find.byType(OrderCard));
      expect(tapped, isTrue);
    });

    testWidgets('CancelOrderDialog enforces required cancellation reason', (tester) async {
      String? submittedReason;
      await tester.pumpWidget(testBoilerplate(
        CancelOrderDialog(
          onConfirmCancel: (reason) async => submittedReason = reason,
        ),
      ));

      // Attempt submit with empty text
      await tester.tap(find.text('تأكيد الإلغاء'));
      await tester.pumpAndSettle();

      expect(find.text('سبب الإلغاء مطلوب'), findsOneWidget);
      expect(submittedReason, isNull);

      // Enter valid reason
      await tester.enterText(find.byType(TextField), 'العميل سافر');
      await tester.tap(find.text('تأكيد الإلغاء'));
      await tester.pumpAndSettle();

      expect(submittedReason, 'العميل سافر');
    });

    testWidgets('AddPaymentDialog validates amount and handles quick-fill remaining', (tester) async {
      Money? submittedAmount;
      PaymentMethod? submittedMethod;

      await tester.pumpWidget(testBoilerplate(
        AddPaymentDialog(
          remainingAmount: const Money.fromPiastres(5000), // 50 EGP
          onConfirm: ({required amount, required method}) async {
            submittedAmount = amount;
            submittedMethod = method;
          },
        ),
      ));

      expect(find.text('المبلغ المتبقي'), findsOneWidget);
      expect(find.text('50.00 ج.م'), findsOneWidget);

      // Tap "المبلغ كامل"
      await tester.tap(find.text('المبلغ كامل'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, '50.00'), findsOneWidget);

      // Submit payment
      await tester.tap(find.text('تأكيد الدفع'));
      await tester.pumpAndSettle();

      expect(submittedAmount, const Money.fromPiastres(5000));
      expect(submittedMethod, PaymentMethod.cash);
    });
  });
}
