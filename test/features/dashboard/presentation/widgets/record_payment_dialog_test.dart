import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/domain/entities/customer_order_aggregate.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/entities/order_payment_summary.dart';
import 'package:laundry_management/domain/entities/payment.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/enums/payment_method.dart';
import 'package:laundry_management/domain/repositories/order_repository.dart';
import 'package:laundry_management/domain/repositories/payment_repository.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';
import 'package:laundry_management/features/dashboard/presentation/cubit/record_payment_cubit.dart';
import 'package:laundry_management/features/dashboard/presentation/widgets/record_payment_dialog.dart';

class MockOrderRepository implements OrderRepository {
  List<Order> ordersToReturn = [];

  @override
  Future<List<Order>> getOrders({
    OrderStatus? status,
    OrderDate? expectedPickupDate,
    String? customerId,
    bool? hasRemaining,
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    return ordersToReturn;
  }

  @override
  Future<Order> cancelOrder({required String orderId, required String cancellationReason}) => throw UnimplementedError();
  @override
  Future<Order> completeOrder({required String orderId, required bool handoverConfirmed}) => throw UnimplementedError();
  @override
  Future<Order> correctOrderStatus({required String orderId, required OrderStatus newStatus, String? reason}) => throw UnimplementedError();
  @override
  Future<Order> createOrder({required Order order, required List<OrderItem> items}) => throw UnimplementedError();
  @override
  Future<CustomerOrderAggregate> getCustomerOrderAggregate(String customerId) => throw UnimplementedError();
  @override
  Future<Order?> getOrderById(String id) => throw UnimplementedError();
  @override
  Future<Order?> getOrderByNumber(String orderNumber) => throw UnimplementedError();
  @override
  Future<int> getOrderCountByCustomerId(String customerId) => throw UnimplementedError();
  @override
  Future<Map<String, int>> getOrderCountsByCustomer() => throw UnimplementedError();
  @override
  Future<Map<String, int>> getOrderCountsByCustomerIds(List<String> customerIds) => throw UnimplementedError();
  @override
  Future<OrderItem?> getOrderItemById(String id) => throw UnimplementedError();
  @override
  Future<List<OrderItem>> getOrderItems(String orderId) => throw UnimplementedError();
  @override
  Future<Order> markOrderReady(String orderId) => throw UnimplementedError();
  @override
  Future<List<Order>> searchOrders({required String query, int limit = 20, int offset = 0}) => throw UnimplementedError();
  @override
  Future<Order> updateOrder(Order order) => throw UnimplementedError();
  @override
  Stream<Order?> watchOrderById(String id) => throw UnimplementedError();
  @override
  Stream<List<Order>> watchRecentOrders({int limit = 20}) => throw UnimplementedError();
}

class MockPaymentRepository implements PaymentRepository {
  Payment? recordedPayment;
  Map<String, OrderPaymentSummary> summariesToReturn = {};

  @override
  Future<Payment> recordPayment(Payment payment) async {
    recordedPayment = payment;
    return payment;
  }

  @override
  Future<Map<String, OrderPaymentSummary>> getPaymentSummariesForOrders(List<String> orderIds) async {
    return summariesToReturn;
  }

  @override
  Future<List<Payment>> getPaymentsForOrder(String orderId) async => [];
  @override
  Future<Money> getRemainingAmountForOrder(String orderId) async => Money.zero;
  @override
  Future<Money> getTotalPaidForOrder(String orderId) async => Money.zero;
  @override
  Stream<List<Payment>> watchPaymentsForOrder(String orderId) => throw UnimplementedError();
}

void main() {
  late MockOrderRepository orderRepo;
  late MockPaymentRepository paymentRepo;
  late RecordPaymentCubit cubit;

  final now = DateTime(2026, 9, 12);
  final testOrder = Order(
    id: 'ord-1',
    orderNumber: '26-001',
    customerId: 'cust-1',
    customerNameSnapshot: 'أحمد محمود',
    customerPhoneSnapshot: '01012345678',
    status: OrderStatus.processing,
    expectedPickupDate: OrderDate(2026, 9, 15),
    subtotal: const Money.fromPiastres(10000),
    total: const Money.fromPiastres(10000),
    createdAt: now,
    updatedAt: now,
  );

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      locale: const Locale('ar'),
      home: Scaffold(
        body: child,
      ),
    );
  }

  setUp(() {
    orderRepo = MockOrderRepository();
    paymentRepo = MockPaymentRepository();
    orderRepo.ordersToReturn = [testOrder];
    paymentRepo.summariesToReturn = {
      'ord-1': const OrderPaymentSummary(
        totalPaid: Money.fromPiastres(4000),
        remaining: Money.fromPiastres(6000),
      ),
    };
    cubit = RecordPaymentCubit(
      orderRepository: orderRepo,
      paymentRepository: paymentRepo,
    );
  });

  tearDown(() {
    cubit.close();
  });

  testWidgets('RecordPaymentDialog renders Step 1 (search & order list) and allows selecting an order', (tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        RecordPaymentDialog(cubit: cubit),
      ),
    );
    await tester.pumpAndSettle();

    // Step 1 title & search field
    expect(find.text('تسجيل دفعة'), findsOneWidget);
    expect(find.byKey(const ValueKey('payment_order_search_field')), findsOneWidget);

    // Order item is visible
    expect(find.text('#26-001'), findsOneWidget);
    expect(find.text('أحمد محمود'), findsOneWidget);
    expect(find.text('المتبقي: 60.00 ج.م'), findsOneWidget);

    // Tap order to proceed to Step 2
    await tester.tap(find.byKey(const ValueKey('payment_order_item_ord-1')));
    await tester.pumpAndSettle();

    // Step 2 elements
    expect(find.text('فتح الطلب'), findsOneWidget);
    expect(find.text('المبلغ المتبقي'), findsOneWidget);
    expect(find.text('60.00 ج.م'), findsOneWidget);
    expect(find.text('المبلغ كامل'), findsOneWidget);
    expect(find.text('طريقة الدفع *'), findsOneWidget);
    expect(find.text('اختيار طلب آخر'), findsOneWidget);
    expect(find.text('تأكيد الدفع'), findsOneWidget);
  });

  testWidgets('Step 2: "اختيار طلب آخر" navigates back to Step 1', (tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        RecordPaymentDialog(cubit: cubit),
      ),
    );
    await tester.pumpAndSettle();

    // Select order
    await tester.tap(find.byKey(const ValueKey('payment_order_item_ord-1')));
    await tester.pumpAndSettle();

    expect(find.text('اختيار طلب آخر'), findsOneWidget);

    // Tap back button
    await tester.tap(find.byKey(const ValueKey('record_payment_back_button')));
    await tester.pumpAndSettle();

    // Back to Step 1
    expect(find.byKey(const ValueKey('payment_order_search_field')), findsOneWidget);
    expect(find.byKey(const ValueKey('payment_order_item_ord-1')), findsOneWidget);
  });

  testWidgets('Step 2: "المبلغ كامل" fills remaining balance and confirms payment', (tester) async {
    bool paymentSuccessCalled = false;

    await tester.pumpWidget(
      buildTestableWidget(
        RecordPaymentDialog(
          cubit: cubit,
          onPaymentSuccess: () => paymentSuccessCalled = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Select order
    await tester.tap(find.byKey(const ValueKey('payment_order_item_ord-1')));
    await tester.pumpAndSettle();

    // Tap "المبلغ كامل"
    await tester.tap(find.byKey(const ValueKey('record_payment_full_amount_button')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '60.00'), findsOneWidget);

    // Select InstaPay
    await tester.tap(find.byKey(const ValueKey('payment_method_instapay')));
    await tester.pumpAndSettle();

    // Confirm Payment
    await tester.tap(find.byKey(const ValueKey('record_payment_confirm_button')));
    await tester.pumpAndSettle();

    expect(paymentSuccessCalled, isTrue);
    expect(paymentRepo.recordedPayment, isNotNull);
    expect(paymentRepo.recordedPayment?.amount, const Money.fromPiastres(6000));
    expect(paymentRepo.recordedPayment?.paymentMethod, PaymentMethod.instapay);
  });
}
