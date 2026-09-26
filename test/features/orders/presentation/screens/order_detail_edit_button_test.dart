import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
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
      subtotal: Money.fromPiastres(1500),
      discount: Money.zero,
      tax: Money.zero,
      total: Money.fromPiastres(1500),
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
    unitPrice: Money.fromPiastres(1500),
    calculatedTotal: Money.fromPiastres(1500),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets(
    'Edit Order button is visible ONLY when order status is processing',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final processingState = OrderDetailState(
        isLoading: false,
        order: createTestOrder(status: OrderStatus.processing),
        items: [testItem],
        customer: testCustomer,
      );

      final fakeCubit = FakeOrderDetailCubit(processingState);
      getIt.registerFactory<OrderDetailCubit>(() => fakeCubit);

      await tester.pumpWidget(
        const MaterialApp(
          home: OrderDetailScreen(orderId: 'ord-test-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تعديل الطلب'), findsOneWidget);
    },
  );

  testWidgets(
    'Edit Order button is NOT visible when order status is ready',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final readyState = OrderDetailState(
        isLoading: false,
        order: createTestOrder(status: OrderStatus.ready),
        items: [testItem],
        customer: testCustomer,
      );

      final fakeCubit = FakeOrderDetailCubit(readyState);
      getIt.registerFactory<OrderDetailCubit>(() => fakeCubit);

      await tester.pumpWidget(
        const MaterialApp(
          home: OrderDetailScreen(orderId: 'ord-test-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تعديل الطلب'), findsNothing);
    },
  );

  testWidgets(
    'Edit Order button is NOT visible when order status is completed',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final completedState = OrderDetailState(
        isLoading: false,
        order: createTestOrder(status: OrderStatus.completed),
        items: [testItem],
        customer: testCustomer,
      );

      final fakeCubit = FakeOrderDetailCubit(completedState);
      getIt.registerFactory<OrderDetailCubit>(() => fakeCubit);

      await tester.pumpWidget(
        const MaterialApp(
          home: OrderDetailScreen(orderId: 'ord-test-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تعديل الطلب'), findsNothing);
    },
  );

  testWidgets(
    'Edit Order button is NOT visible when order status is cancelled',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cancelledState = OrderDetailState(
        isLoading: false,
        order: createTestOrder(status: OrderStatus.cancelled),
        items: [testItem],
        customer: testCustomer,
      );

      final fakeCubit = FakeOrderDetailCubit(cancelledState);
      getIt.registerFactory<OrderDetailCubit>(() => fakeCubit);

      await tester.pumpWidget(
        const MaterialApp(
          home: OrderDetailScreen(orderId: 'ord-test-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تعديل الطلب'), findsNothing);
    },
  );
}
