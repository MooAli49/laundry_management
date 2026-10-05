import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/theme/app_theme.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';
import 'package:laundry_management/features/orders/presentation/cubit/order_detail_state.dart';
import 'package:laundry_management/features/orders/presentation/models/order_list_item_view_model.dart';
import 'package:laundry_management/features/orders/presentation/widgets/order_card.dart';

Order _order(OrderStatus status) {
  final now = DateTime(2026, 9, 1);
  return Order(
    id: 'ord-1',
    orderNumber: '26-009',
    customerId: 'cust-1',
    customerNameSnapshot: 'عمرو خالد',
    customerPhoneSnapshot: '01012345678',
    status: status,
    expectedPickupDate: OrderDate(2026, 9, 10),
    subtotal: const Money.fromPiastres(18000),
    total: const Money.fromPiastres(18000),
    cancelledAt: status == OrderStatus.cancelled ? now : null,
    cancellationReason: status == OrderStatus.cancelled ? 'إلغاء تجريبي' : null,
    createdAt: now,
    updatedAt: now,
  );
}

OrderListItemViewModel _vm(OrderStatus status, int paid, int remaining) =>
    OrderListItemViewModel(
      order: _order(status),
      totalPaid: Money.fromPiastres(paid),
      remainingAmount: Money.fromPiastres(remaining),
    );

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(body: child),
  ),
);

void main() {
  group('Cancelled order financial presentation', () {
    testWidgets('cancelled, paid 0 is not fully paid and shows غير مدفوع', (
      tester,
    ) async {
      // Repository returns remaining == 0 for cancelled orders.
      final vm = _vm(OrderStatus.cancelled, 0, 0);
      expect(vm.isFullyPaid, isFalse);

      await tester.pumpWidget(_wrap(OrderCard(item: vm, onTap: () {})));
      expect(find.text('مدفوع بالكامل'), findsNothing);
      expect(find.text('غير مدفوع'), findsOneWidget);
      expect(find.text('ملغي'), findsOneWidget);
    });

    testWidgets('cancelled, paid 100 is not fully paid', (tester) async {
      final vm = _vm(OrderStatus.cancelled, 10000, 0);
      expect(vm.isFullyPaid, isFalse);

      await tester.pumpWidget(_wrap(OrderCard(item: vm, onTap: () {})));
      expect(find.text('مدفوع بالكامل'), findsNothing);
      expect(find.text('المدفوع: 100.00 ج.م'), findsOneWidget);
    });

    testWidgets('cancelled, paid == total never says مدفوع بالكامل', (
      tester,
    ) async {
      final vm = _vm(OrderStatus.cancelled, 18000, 0);
      expect(vm.isFullyPaid, isFalse);

      await tester.pumpWidget(_wrap(OrderCard(item: vm, onTap: () {})));
      expect(find.text('مدفوع بالكامل'), findsNothing);
      expect(find.text('ملغي'), findsOneWidget);
    });

    testWidgets('active, paid 180 stays fully paid', (tester) async {
      final vm = _vm(OrderStatus.processing, 18000, 0);
      expect(vm.isFullyPaid, isTrue);

      await tester.pumpWidget(_wrap(OrderCard(item: vm, onTap: () {})));
      expect(find.text('مدفوع بالكامل'), findsOneWidget);
    });

    testWidgets('active, paid 100 keeps remaining behavior', (tester) async {
      final vm = _vm(OrderStatus.processing, 10000, 8000);
      expect(vm.isFullyPaid, isFalse);

      await tester.pumpWidget(_wrap(OrderCard(item: vm, onTap: () {})));
      expect(find.text('مدفوع بالكامل'), findsNothing);
      expect(find.text('المتبقي: 80.00 ج.م'), findsOneWidget);
    });

    test('OrderDetailState: cancelled is never fully paid, active is', () {
      expect(
        OrderDetailState(order: _order(OrderStatus.cancelled)).isFullyPaid,
        isFalse,
      );
      expect(
        OrderDetailState(order: _order(OrderStatus.processing)).isFullyPaid,
        isTrue,
      );
      expect(
        OrderDetailState(
          order: _order(OrderStatus.processing),
          remainingAmount: const Money.fromPiastres(8000),
        ).isFullyPaid,
        isFalse,
      );
    });
  });
}
