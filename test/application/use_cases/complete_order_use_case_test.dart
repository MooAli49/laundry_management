import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/application/use_cases/complete_order_use_case.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/payment.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/enums/payment_method.dart';
import 'package:laundry_management/domain/repositories/order_repository.dart';
import 'package:laundry_management/domain/repositories/payment_repository.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';

class FakeOrderRepository implements OrderRepository {
  final Map<String, Order> orders = {};
  bool completeOrderCalled = false;

  @override
  Future<Order?> getOrderById(String id) async => orders[id];

  @override
  Future<Order> completeOrder({
    required String orderId,
    required bool handoverConfirmed,
  }) async {
    completeOrderCalled = true;
    final existing = orders[orderId]!;
    final now = DateTime.now();
    final updated = existing.copyWith(
      status: OrderStatus.completed,
      completedAt: now,
    );
    orders[orderId] = updated;
    return updated;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePaymentRepository implements PaymentRepository {
  final Map<String, List<Payment>> paymentsByOrder = {};

  @override
  Future<List<Payment>> getPaymentsForOrder(String orderId) async =>
      paymentsByOrder[orderId] ?? [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeOrderRepository orderRepo;
  late FakePaymentRepository paymentRepo;
  late CompleteOrderUseCase useCase;

  final now = DateTime.now();

  setUp(() {
    orderRepo = FakeOrderRepository();
    paymentRepo = FakePaymentRepository();
    useCase = CompleteOrderUseCase(
      orderRepository: orderRepo,
      paymentRepository: paymentRepo,
    );

    orderRepo.orders['ord-ready-100'] = Order(
      id: 'ord-ready-100',
      orderNumber: '26-001',
      customerId: 'cust-1',
      status: OrderStatus.ready,
      expectedPickupDate: OrderDate.today(),
      subtotal: const Money.fromPiastres(10000), // 100 EGP
      total: const Money.fromPiastres(10000),
      createdAt: now,
      updatedAt: now,
    );

    orderRepo.orders['ord-proc'] = Order(
      id: 'ord-proc',
      orderNumber: '26-002',
      customerId: 'cust-1',
      status: OrderStatus.processing,
      expectedPickupDate: OrderDate.today(),
      subtotal: const Money.fromPiastres(5000),
      total: const Money.fromPiastres(5000),
      createdAt: now,
      updatedAt: now,
    );
  });

  group('CompleteOrderUseCase', () {
    test('rejects completion when handoverConfirmed is false', () async {
      expect(
        () => useCase.execute(
          const CompleteOrderInput(
            orderId: 'ord-ready-100',
            handoverConfirmed: false,
          ),
        ),
        throwsA(isA<BusinessRuleFailure>()),
      );
    });

    test('rejects non-existent order', () async {
      expect(
        () => useCase.execute(
          const CompleteOrderInput(
            orderId: 'non-existent',
            handoverConfirmed: true,
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects order when status is not Ready (e.g. Processing)', () async {
      expect(
        () => useCase.execute(
          const CompleteOrderInput(
            orderId: 'ord-proc',
            handoverConfirmed: true,
          ),
        ),
        throwsA(isA<BusinessRuleFailure>()),
      );
    });

    test('LOCKED RULE: rejects completion when remaining balance > 0 (unpaid)', () async {
      // No payments made -> remaining balance = 100 EGP
      expect(
        () => useCase.execute(
          const CompleteOrderInput(
            orderId: 'ord-ready-100',
            handoverConfirmed: true,
          ),
        ),
        throwsA(isA<OrderNotFullyPaidFailure>()),
      );

      // Partial payment made -> 40 EGP paid, 60 EGP remaining
      paymentRepo.paymentsByOrder['ord-ready-100'] = [
        Payment(
          id: 'pay-1',
          orderId: 'ord-ready-100',
          amount: const Money.fromPiastres(4000), // 40 EGP
          paymentMethod: PaymentMethod.cash,
          paidAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      expect(
        () => useCase.execute(
          const CompleteOrderInput(
            orderId: 'ord-ready-100',
            handoverConfirmed: true,
          ),
        ),
        throwsA(isA<OrderNotFullyPaidFailure>()),
      );
    });

    test('LOCKED RULE: completes order when Ready + Fully Paid + Handover Confirmed', () async {
      // Full payment recorded: 100 EGP
      paymentRepo.paymentsByOrder['ord-ready-100'] = [
        Payment(
          id: 'pay-1',
          orderId: 'ord-ready-100',
          amount: const Money.fromPiastres(10000), // 100 EGP
          paymentMethod: PaymentMethod.cash,
          paidAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final result = await useCase.execute(
        const CompleteOrderInput(
          orderId: 'ord-ready-100',
          handoverConfirmed: true,
        ),
      );

      expect(result.status, OrderStatus.completed);
      expect(result.completedAt, isNotNull);
      expect(result.customerHandoverConfirmedAt, isNotNull);
      expect(orderRepo.completeOrderCalled, true);
    });

    test('completes order when multiple payments sum to total or exceed it', () async {
      // Two payments: 60 EGP + 40 EGP = 100 EGP
      paymentRepo.paymentsByOrder['ord-ready-100'] = [
        Payment(
          id: 'pay-1',
          orderId: 'ord-ready-100',
          amount: const Money.fromPiastres(6000),
          paymentMethod: PaymentMethod.cash,
          paidAt: now,
          createdAt: now,
          updatedAt: now,
        ),
        Payment(
          id: 'pay-2',
          orderId: 'ord-ready-100',
          amount: const Money.fromPiastres(4000),
          paymentMethod: PaymentMethod.ewallet,
          paidAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final result = await useCase.execute(
        const CompleteOrderInput(
          orderId: 'ord-ready-100',
          handoverConfirmed: true,
        ),
      );

      expect(result.status, OrderStatus.completed);
      expect(orderRepo.completeOrderCalled, true);
    });
  });
}
