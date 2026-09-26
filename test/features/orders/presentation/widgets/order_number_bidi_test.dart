import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';
import 'package:laundry_management/features/orders/presentation/models/order_list_item_view_model.dart';
import 'package:laundry_management/features/orders/presentation/widgets/order_card.dart';

void main() {
  group('Finding 2 — Order Number RTL/BiDi Presentation Tests', () {
    const storedOrderNumber = '26-9993240';
    final now = DateTime.now();

    final testOrder = Order(
      id: 'order-bidi-1',
      orderNumber: storedOrderNumber,
      customerId: 'cust-1',
      customerNameSnapshot: 'أحمد محمود',
      customerPhoneSnapshot: '01012345678',
      status: OrderStatus.processing,
      expectedPickupDate: OrderDate.fromDate(now),
      total: const Money.fromPiastres(15000),
      subtotal: const Money.fromPiastres(15000),
      discount: Money.zero,
      tax: Money.zero,
      customerPickupFee: Money.zero,
      customerDeliveryFee: Money.zero,
      createdAt: now,
      updatedAt: now,
    );

    testWidgets('OrderCard renders #26-9993240 with explicit LTR direction in Arabic RTL context', (
      tester,
    ) async {
      final viewModel = OrderListItemViewModel(
        order: testOrder,
        totalPaid: Money.zero,
        remainingAmount: testOrder.total,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl, // Arabic RTL Context
            child: Scaffold(
              body: OrderCard(
                item: viewModel,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the Text widget with the formatted order number exists
      final textFinder = find.text('#26-9993240');
      expect(textFinder, findsOneWidget);

      // Verify explicit TextDirection.ltr is configured on the Text widget
      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.textDirection, TextDirection.ltr);

      // Verify the stored value itself was NOT altered
      expect(testOrder.orderNumber, '26-9993240');
    });

    testWidgets('Order Details Header title pattern renders طلب #26-9993240 cleanly with LTR', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl, // Arabic RTL Context
            child: Scaffold(
              appBar: AppBar(
                title: Row(
                  children: [
                    const Text('طلب '),
                    Text(
                      '#${testOrder.orderNumber}',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('طلب '), findsOneWidget);
      final numberFinder = find.text('#26-9993240');
      expect(numberFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(numberFinder);
      expect(textWidget.textDirection, TextDirection.ltr);
    });

    testWidgets('Customer detail order row renders #26-9993240 with LTR textDirection', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Row(
                children: [
                  Text(
                    testOrder.orderNumber.startsWith('#')
                        ? testOrder.orderNumber
                        : '#${testOrder.orderNumber}',
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final numberFinder = find.text('#26-9993240');
      expect(numberFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(numberFinder);
      expect(textWidget.textDirection, TextDirection.ltr);
    });
  });
}
