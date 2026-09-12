import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/domain/entities/customer_order_aggregate.dart';
import 'package:laundry_management/domain/entities/dashboard_order_item.dart';
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
import 'package:laundry_management/features/dashboard/presentation/cubit/record_payment_state.dart';

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
  bool shouldThrow = false;
  Map<String, OrderPaymentSummary> summariesToReturn = {};

  @override
  Future<Payment> recordPayment(Payment payment) async {
    if (shouldThrow) throw const BusinessRuleFailure('Payment failed');
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

  setUp(() {
    orderRepo = MockOrderRepository();
    paymentRepo = MockPaymentRepository();
    cubit = RecordPaymentCubit(
      orderRepository: orderRepo,
      paymentRepository: paymentRepo,
    );
  });

  tearDown(() {
    cubit.close();
  });

  test('initial state has step selectOrder and empty orders', () {
    expect(cubit.state.step, RecordPaymentStep.selectOrder);
    expect(cubit.state.orders, isEmpty);
    expect(cubit.state.selectedOrder, isNull);
    expect(cubit.state.isLoadingOrders, isFalse);
    expect(cubit.state.isRecordingPayment, isFalse);
    expect(cubit.state.isPaymentSuccess, isFalse);
  });

  test('searchOrders populates orders with remaining amount', () async {
    orderRepo.ordersToReturn = [testOrder];
    paymentRepo.summariesToReturn = {
      'ord-1': const OrderPaymentSummary(
        totalPaid: Money.fromPiastres(4000),
        remaining: Money.fromPiastres(6000),
      ),
    };

    await cubit.searchOrders('أحمد');

    expect(cubit.state.isLoadingOrders, isFalse);
    expect(cubit.state.orders.length, 1);
    expect(cubit.state.orders.first.order.id, 'ord-1');
    expect(cubit.state.orders.first.remainingAmount, const Money.fromPiastres(6000));
  });

  test('selectOrder changes step to enterPayment and backToOrderSelection returns to selectOrder', () {
    final item = DashboardOrderItem(
      order: testOrder,
      totalPaid: const Money.fromPiastres(4000),
      remainingAmount: const Money.fromPiastres(6000),
    );

    cubit.selectOrder(item);
    expect(cubit.state.step, RecordPaymentStep.enterPayment);
    expect(cubit.state.selectedOrder?.order.id, 'ord-1');

    cubit.backToOrderSelection();
    expect(cubit.state.step, RecordPaymentStep.selectOrder);
    expect(cubit.state.selectedOrder, isNull);
  });

  test('recordPayment rejects non-positive amount and amount exceeding remaining', () async {
    final item = DashboardOrderItem(
      order: testOrder,
      totalPaid: const Money.fromPiastres(4000),
      remainingAmount: const Money.fromPiastres(6000),
    );
    cubit.selectOrder(item);

    // Zero amount
    final res1 = await cubit.recordPayment(
      amount: Money.zero,
      method: PaymentMethod.cash,
    );
    expect(res1, isNull);
    expect(cubit.state.errorMessage, 'يرجى إدخال مبلغ أكبر من الصفر');

    // Amount exceeding remaining
    final res2 = await cubit.recordPayment(
      amount: const Money.fromPiastres(7000),
      method: PaymentMethod.cash,
    );
    expect(res2, isNull);
    expect(cubit.state.errorMessage, 'المبلغ المدخل يتجاوز المبلغ المتبقي على الطلب');
  });

  test('recordPayment successfully records payment and sets isPaymentSuccess', () async {
    final item = DashboardOrderItem(
      order: testOrder,
      totalPaid: const Money.fromPiastres(4000),
      remainingAmount: const Money.fromPiastres(6000),
    );
    cubit.selectOrder(item);

    final payment = await cubit.recordPayment(
      amount: const Money.fromPiastres(6000),
      method: PaymentMethod.instapay,
    );

    expect(payment, isNotNull);
    expect(cubit.state.isPaymentSuccess, isTrue);
    expect(paymentRepo.recordedPayment, isNotNull);
    expect(paymentRepo.recordedPayment?.amount, const Money.fromPiastres(6000));
    expect(paymentRepo.recordedPayment?.paymentMethod, PaymentMethod.instapay);
  });
}
