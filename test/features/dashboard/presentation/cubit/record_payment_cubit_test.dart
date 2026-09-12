import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/domain/entities/dashboard_order_item.dart';
import 'package:laundry_management/domain/entities/order.dart';
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
  String? lastQuery;
  bool? lastHasRemaining;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

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
    lastQuery = query;
    lastHasRemaining = hasRemaining;
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim();
      return ordersToReturn.where((o) =>
        o.orderNumber.contains(q) ||
        o.customerNameSnapshot.contains(q) ||
        o.customerPhoneSnapshot.contains(q)
      ).toList();
    }
    return ordersToReturn;
  }
}

class MockPaymentRepository implements PaymentRepository {
  Payment? recordedPayment;
  bool shouldThrow = false;
  Map<String, OrderPaymentSummary> summariesToReturn = {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

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
}

void main() {
  late MockOrderRepository orderRepo;
  late MockPaymentRepository paymentRepo;
  late RecordPaymentCubit cubit;

  final now = DateTime(2026, 9, 12);
  final order1 = Order(
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
  final order2 = Order(
    id: 'ord-2',
    orderNumber: '26-002',
    customerId: 'cust-2',
    customerNameSnapshot: 'سارة عبد الله',
    customerPhoneSnapshot: '01298765432',
    status: OrderStatus.ready,
    expectedPickupDate: OrderDate(2026, 9, 16),
    subtotal: const Money.fromPiastres(8000),
    total: const Money.fromPiastres(8000),
    createdAt: now,
    updatedAt: now,
  );
  final cancelledOrder = Order(
    id: 'ord-cancelled',
    orderNumber: '26-003',
    customerId: 'cust-3',
    customerNameSnapshot: 'خالد منصور',
    customerPhoneSnapshot: '01155554444',
    status: OrderStatus.cancelled,
    expectedPickupDate: OrderDate(2026, 9, 17),
    subtotal: const Money.fromPiastres(5000),
    total: const Money.fromPiastres(5000),
    createdAt: now,
    updatedAt: now,
    cancelledAt: now,
    cancellationReason: 'طلب العميل الإلغاء',
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

  test('empty query forwards hasRemaining=true and loads all outstanding non-cancelled orders', () async {
    orderRepo.ordersToReturn = [order1, order2, cancelledOrder];
    paymentRepo.summariesToReturn = {
      'ord-1': const OrderPaymentSummary(
        totalPaid: Money.fromPiastres(4000),
        remaining: Money.fromPiastres(6000),
      ),
      'ord-2': const OrderPaymentSummary(
        totalPaid: Money.zero,
        remaining: Money.fromPiastres(8000),
      ),
      'ord-cancelled': const OrderPaymentSummary(
        totalPaid: Money.zero,
        remaining: Money.fromPiastres(5000),
      ),
    };

    await cubit.searchOrders('');

    expect(orderRepo.lastHasRemaining, isTrue);
    expect(orderRepo.lastQuery, isNull);
    expect(cubit.state.orders.length, 2);
    expect(cubit.state.orders.any((i) => i.order.id == 'ord-cancelled'), isFalse);
  });

  test('search by order number forwards query and returns matched order', () async {
    orderRepo.ordersToReturn = [order1, order2];
    paymentRepo.summariesToReturn = {
      'ord-1': const OrderPaymentSummary(
        totalPaid: Money.fromPiastres(4000),
        remaining: Money.fromPiastres(6000),
      ),
    };

    await cubit.searchOrders('26-001');

    expect(orderRepo.lastQuery, '26-001');
    expect(orderRepo.lastHasRemaining, isTrue);
    expect(cubit.state.orders.length, 1);
    expect(cubit.state.orders.first.order.id, 'ord-1');
  });

  test('search by customer name forwards query and returns matched order', () async {
    orderRepo.ordersToReturn = [order1, order2];
    paymentRepo.summariesToReturn = {
      'ord-2': const OrderPaymentSummary(
        totalPaid: Money.zero,
        remaining: Money.fromPiastres(8000),
      ),
    };

    await cubit.searchOrders('سارة');

    expect(orderRepo.lastQuery, 'سارة');
    expect(cubit.state.orders.length, 1);
    expect(cubit.state.orders.first.order.customerNameSnapshot, 'سارة عبد الله');
  });

  test('search by customer phone forwards query and returns matched order', () async {
    orderRepo.ordersToReturn = [order1, order2];
    paymentRepo.summariesToReturn = {
      'ord-1': const OrderPaymentSummary(
        totalPaid: Money.fromPiastres(4000),
        remaining: Money.fromPiastres(6000),
      ),
    };

    await cubit.searchOrders('01012345678');

    expect(orderRepo.lastQuery, '01012345678');
    expect(cubit.state.orders.length, 1);
    expect(cubit.state.orders.first.order.customerPhoneSnapshot, '01012345678');
  });

  test('orders with zero remaining are excluded from results', () async {
    orderRepo.ordersToReturn = [order1];
    paymentRepo.summariesToReturn = {
      'ord-1': const OrderPaymentSummary(
        totalPaid: Money.fromPiastres(10000),
        remaining: Money.zero,
      ),
    };

    await cubit.searchOrders();

    expect(cubit.state.orders, isEmpty);
  });

  test('selectOrder changes step to enterPayment and backToOrderSelection returns to selectOrder', () {
    final item = DashboardOrderItem(
      order: order1,
      totalPaid: const Money.fromPiastres(4000),
      remainingAmount: const Money.fromPiastres(6000),
    );

    cubit.selectOrder(item);

    expect(cubit.state.step, RecordPaymentStep.enterPayment);
    expect(cubit.state.selectedOrder, item);

    cubit.backToOrderSelection();

    expect(cubit.state.step, RecordPaymentStep.selectOrder);
    expect(cubit.state.selectedOrder, isNull);
  });

  test('recordPayment rejects non-positive amount and amount exceeding remaining', () async {
    final item = DashboardOrderItem(
      order: order1,
      totalPaid: const Money.fromPiastres(4000),
      remainingAmount: const Money.fromPiastres(6000),
    );
    cubit.selectOrder(item);

    // Zero amount
    var result = await cubit.recordPayment(
      amount: Money.zero,
      method: PaymentMethod.cash,
    );
    expect(result, isNull);
    expect(cubit.state.errorMessage, 'يرجى إدخال مبلغ أكبر من الصفر');

    // Exceeding amount
    result = await cubit.recordPayment(
      amount: const Money.fromPiastres(7000),
      method: PaymentMethod.cash,
    );
    expect(result, isNull);
    expect(cubit.state.errorMessage, 'المبلغ المدخل يتجاوز المبلغ المتبقي على الطلب');
  });

  test('recordPayment successfully records payment and sets isPaymentSuccess', () async {
    final item = DashboardOrderItem(
      order: order1,
      totalPaid: const Money.fromPiastres(4000),
      remainingAmount: const Money.fromPiastres(6000),
    );
    cubit.selectOrder(item);

    final payment = await cubit.recordPayment(
      amount: const Money.fromPiastres(6000),
      method: PaymentMethod.cash,
    );

    expect(payment, isNotNull);
    expect(payment?.amount, const Money.fromPiastres(6000));
    expect(payment?.paymentMethod, PaymentMethod.cash);
    expect(paymentRepo.recordedPayment, isNotNull);
    expect(cubit.state.isPaymentSuccess, isTrue);
    expect(cubit.state.isRecordingPayment, isFalse);
  });

  test('recordPayment handles failure properly', () async {
    paymentRepo.shouldThrow = true;
    final item = DashboardOrderItem(
      order: order1,
      totalPaid: const Money.fromPiastres(4000),
      remainingAmount: const Money.fromPiastres(6000),
    );
    cubit.selectOrder(item);

    final payment = await cubit.recordPayment(
      amount: const Money.fromPiastres(6000),
      method: PaymentMethod.instapay,
    );

    expect(payment, isNull);
    expect(cubit.state.isPaymentSuccess, isFalse);
    expect(cubit.state.isRecordingPayment, isFalse);
    expect(cubit.state.errorMessage, 'Payment failed');
  });
}
