import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:laundry_management/core/theme/app_theme.dart';
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/entities/refund_balance_summary.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';
import 'package:laundry_management/features/orders/presentation/cubit/order_detail_cubit.dart';
import 'package:laundry_management/features/orders/presentation/cubit/order_detail_state.dart';
import 'package:laundry_management/features/orders/presentation/screens/order_detail_screen.dart';

class FakeOrderDetailCubit extends Cubit<OrderDetailState>
    implements OrderDetailCubit {
  int loadOrderDetailCallCount = 0;

  FakeOrderDetailCubit(super.initialState);

  @override
  Future<void> loadOrderDetail(String orderId) async {
    loadOrderDetailCallCount++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final getIt = GetIt.instance;

  Order createTestOrder({required OrderStatus status}) {
    final now = DateTime.now();
    return Order(
      id: 'ord-test-1',
      orderNumber: 'ORD-001',
      customerId: 'cust-1',
      customerNameSnapshot: 'عميل تجريبي',
      customerPhoneSnapshot: '01012345678',
      status: status,
      completedAt: status == OrderStatus.completed ? now : null,
      cancelledAt: status == OrderStatus.cancelled ? now : null,
      cancellationReason:
          status == OrderStatus.cancelled ? 'إلغاء تجريبي' : null,
      expectedPickupDate: OrderDate.fromDate(
        now.add(const Duration(days: 2)),
      ),
      subtotal: Money.fromPiastres(10000),
      discount: Money.zero,
      tax: Money.zero,
      total: Money.fromPiastres(10000),
      createdAt: now,
      updatedAt: now,
    );
  }

  final testCustomer = Customer(
    id: 'cust-1',
    name: 'عميل تجريبي',
    phone: '01012345678',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final testItem = OrderItem(
    id: 'item-1',
    orderId: 'ord-test-1',
    itemTypeId: '00000000-0000-0000-0001-000000000001',
    serviceId: '00000000-0000-0000-0002-000000000001',
    itemTypeNameSnapshot: 'ملابس',
    serviceNameSnapshot: 'غسيل وكوي',
    pricingType: PricingType.perPiece,
    quantity: 1.0,
    unitPrice: Money.fromPiastres(10000),
    calculatedTotal: Money.fromPiastres(10000),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  tearDown(() async {
    await getIt.reset();
  });

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('Order Details Screen Refund Visibility (Part O: 1-5)', () {
    testWidgets(
      '1. Refund action visible for cancelled order when refundable > 0',
      (tester) async {
        configureViewport(tester);

        final cancelledState = OrderDetailState(
          isLoading: false,
          order: createTestOrder(status: OrderStatus.cancelled),
          items: [testItem],
          customer: testCustomer,
          totalPaid: Money.fromPiastres(10000),
          remainingAmount: Money.zero,
          refundBalance: const RefundBalanceSummary(
            totalPaid: Money.fromPiastres(10000),
            totalRefunded: Money.zero,
            remainingRefundable: Money.fromPiastres(10000),
          ),
        );

        final fakeCubit = FakeOrderDetailCubit(cancelledState);
        getIt.registerFactory<OrderDetailCubit>(() => fakeCubit);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: OrderDetailScreen(orderId: 'ord-test-1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Expect Refund action "استرداد المبلغ" to be visible
        expect(find.text('استرداد المبلغ'), findsAtLeastNWidgets(1));
        expect(
          find.text('يوجد رصيد قابل للاسترداد للعميل بقيمة 100.00 ج.م'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '2. Refund action hidden/not available for processing order',
      (tester) async {
        configureViewport(tester);

        final processingState = OrderDetailState(
          isLoading: false,
          order: createTestOrder(status: OrderStatus.processing),
          items: [testItem],
          customer: testCustomer,
          totalPaid: Money.fromPiastres(5000),
          remainingAmount: Money.fromPiastres(5000),
          refundBalance: const RefundBalanceSummary(
            totalPaid: Money.fromPiastres(5000),
            totalRefunded: Money.zero,
            remainingRefundable: Money.fromPiastres(5000),
          ),
        );

        final fakeCubit = FakeOrderDetailCubit(processingState);
        getIt.registerFactory<OrderDetailCubit>(() => fakeCubit);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: OrderDetailScreen(orderId: 'ord-test-1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('استرداد المبلغ'), findsNothing);
      },
    );

    testWidgets(
      '3. Refund action hidden/not available for ready order',
      (tester) async {
        configureViewport(tester);

        final readyState = OrderDetailState(
          isLoading: false,
          order: createTestOrder(status: OrderStatus.ready),
          items: [testItem],
          customer: testCustomer,
          totalPaid: Money.fromPiastres(10000),
          remainingAmount: Money.zero,
          refundBalance: const RefundBalanceSummary(
            totalPaid: Money.fromPiastres(10000),
            totalRefunded: Money.zero,
            remainingRefundable: Money.fromPiastres(10000),
          ),
        );

        final fakeCubit = FakeOrderDetailCubit(readyState);
        getIt.registerFactory<OrderDetailCubit>(() => fakeCubit);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: OrderDetailScreen(orderId: 'ord-test-1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('استرداد المبلغ'), findsNothing);
      },
    );

    testWidgets(
      '4. Refund action hidden/not available for completed order',
      (tester) async {
        configureViewport(tester);

        final completedState = OrderDetailState(
          isLoading: false,
          order: createTestOrder(status: OrderStatus.completed),
          items: [testItem],
          customer: testCustomer,
          totalPaid: Money.fromPiastres(10000),
          remainingAmount: Money.zero,
          refundBalance: const RefundBalanceSummary(
            totalPaid: Money.fromPiastres(10000),
            totalRefunded: Money.zero,
            remainingRefundable: Money.fromPiastres(10000),
          ),
        );

        final fakeCubit = FakeOrderDetailCubit(completedState);
        getIt.registerFactory<OrderDetailCubit>(() => fakeCubit);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: OrderDetailScreen(orderId: 'ord-test-1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('استرداد المبلغ'), findsNothing);
      },
    );

    testWidgets(
      '5. Refund action unavailable when refundable == 0',
      (tester) async {
        configureViewport(tester);

        final fullyRefundedCancelledState = OrderDetailState(
          isLoading: false,
          order: createTestOrder(status: OrderStatus.cancelled),
          items: [testItem],
          customer: testCustomer,
          totalPaid: Money.fromPiastres(10000),
          remainingAmount: Money.zero,
          refundBalance: const RefundBalanceSummary(
            totalPaid: Money.fromPiastres(10000),
            totalRefunded: Money.fromPiastres(10000),
            remainingRefundable: Money.zero,
          ),
        );

        final fakeCubit = FakeOrderDetailCubit(fullyRefundedCancelledState);
        getIt.registerFactory<OrderDetailCubit>(() => fakeCubit);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: OrderDetailScreen(orderId: 'ord-test-1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // "استرداد المبلغ" action button should NOT be present
        expect(find.text('استرداد المبلغ'), findsNothing);
        // Notice indicating full refund was completed
        expect(find.text('تم استرداد كامل المبلغ المدفوع بنجاح.'), findsOneWidget);
      },
    );
  });
}
