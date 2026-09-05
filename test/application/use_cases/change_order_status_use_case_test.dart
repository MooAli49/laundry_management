import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/application/use_cases/change_order_status_use_case.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/repositories/order_repository.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';

class FakeOrderRepository implements OrderRepository {
  final Map<String, Order> orders = {};
  bool correctOrderStatusCalled = false;
  bool cancelOrderCalled = false;

  @override
  Future<Order?> getOrderById(String id) async => orders[id];

  @override
  Future<Order> correctOrderStatus({
    required String orderId,
    required OrderStatus newStatus,
    String? reason,
  }) async {
    correctOrderStatusCalled = true;
    final existing = orders[orderId]!;
    final updated = Order(
      id: existing.id,
      orderNumber: existing.orderNumber,
      customerId: existing.customerId,
      status: newStatus,
      expectedPickupDate: existing.expectedPickupDate,
      notes: existing.notes,
      customerPickupRequested: existing.customerPickupRequested,
      customerPickupFee: existing.customerPickupFee,
      customerDeliveryRequested: existing.customerDeliveryRequested,
      customerDeliveryFee: existing.customerDeliveryFee,
      subtotal: existing.subtotal,
      discount: existing.discount,
      tax: existing.tax,
      total: existing.total,
      completedAt: newStatus == OrderStatus.processing ? null : existing.completedAt,
      cancelledAt: existing.cancelledAt,
      cancellationReason: existing.cancellationReason,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    );
    orders[orderId] = updated;
    return updated;
  }

  @override
  Future<Order> cancelOrder({
    required String orderId,
    required String cancellationReason,
  }) async {
    cancelOrderCalled = true;
    final existing = orders[orderId]!;
    final updated = existing.copyWith(
      status: OrderStatus.cancelled,
      cancelledAt: DateTime.now(),
      cancellationReason: cancellationReason,
    );
    orders[orderId] = updated;
    return updated;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeOrderRepository orderRepo;
  late ChangeOrderStatusUseCase useCase;

  final now = DateTime.now();

  Order makeOrder(String id, OrderStatus status) {
    return Order(
      id: id,
      orderNumber: '26-001',
      customerId: 'cust-1',
      status: status,
      expectedPickupDate: OrderDate.today(),
      subtotal: const Money.fromPiastres(1000),
      total: const Money.fromPiastres(1000),
      completedAt: status == OrderStatus.completed ? now : null,
      cancelledAt: status == OrderStatus.cancelled ? now : null,
      cancellationReason: status == OrderStatus.cancelled ? 'سبب الإلغاء' : null,
      createdAt: now,
      updatedAt: now,
    );
  }

  setUp(() {
    orderRepo = FakeOrderRepository();
    useCase = ChangeOrderStatusUseCase(orderRepo);

    orderRepo.orders['ord-proc'] = makeOrder('ord-proc', OrderStatus.processing);
    orderRepo.orders['ord-ready'] = makeOrder('ord-ready', OrderStatus.ready);
    orderRepo.orders['ord-comp'] = makeOrder('ord-comp', OrderStatus.completed);
    orderRepo.orders['ord-canc'] = makeOrder('ord-canc', OrderStatus.cancelled);
  });

  group('ChangeOrderStatusUseCase Transition Matrix', () {
    test('same-status transition is a no-op', () async {
      final result = await useCase.execute(
        const ChangeOrderStatusInput(
          orderId: 'ord-proc',
          newStatus: OrderStatus.processing,
        ),
      );

      expect(result.status, OrderStatus.processing);
      expect(orderRepo.correctOrderStatusCalled, false);
      expect(orderRepo.cancelOrderCalled, false);
    });

    test('manual Processing -> Ready requires non-empty reason', () async {
      // Missing reason
      expect(
        () => useCase.execute(
          const ChangeOrderStatusInput(
            orderId: 'ord-proc',
            newStatus: OrderStatus.ready,
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );

      // Empty reason
      expect(
        () => useCase.execute(
          const ChangeOrderStatusInput(
            orderId: 'ord-proc',
            newStatus: OrderStatus.ready,
            reason: '   ',
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );

      // Valid reason succeeds
      final result = await useCase.execute(
        const ChangeOrderStatusInput(
          orderId: 'ord-proc',
          newStatus: OrderStatus.ready,
          reason: 'تجاوز يدوي: تم التجهيز بالكامل بدون رف',
        ),
      );

      expect(result.status, OrderStatus.ready);
      expect(orderRepo.correctOrderStatusCalled, true);
    });

    test('Processing -> Cancelled requires non-empty reason', () async {
      expect(
        () => useCase.execute(
          const ChangeOrderStatusInput(
            orderId: 'ord-proc',
            newStatus: OrderStatus.cancelled,
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );

      final result = await useCase.execute(
        const ChangeOrderStatusInput(
          orderId: 'ord-proc',
          newStatus: OrderStatus.cancelled,
          reason: 'طلب العميل الإلغاء',
        ),
      );

      expect(result.status, OrderStatus.cancelled);
      expect(orderRepo.cancelOrderCalled, true);
    });

    test('LOCKED RULE: Processing -> Completed is FORBIDDEN directly', () async {
      expect(
        () => useCase.execute(
          const ChangeOrderStatusInput(
            orderId: 'ord-proc',
            newStatus: OrderStatus.completed,
          ),
        ),
        throwsA(isA<InvalidOrderTransitionFailure>()),
      );
    });

    test('Ready -> Processing is allowed', () async {
      final result = await useCase.execute(
        const ChangeOrderStatusInput(
          orderId: 'ord-ready',
          newStatus: OrderStatus.processing,
          reason: 'إعادة غسيل قميص',
        ),
      );

      expect(result.status, OrderStatus.processing);
      expect(orderRepo.correctOrderStatusCalled, true);
    });

    test('Ready -> Cancelled requires reason and succeeds', () async {
      final result = await useCase.execute(
        const ChangeOrderStatusInput(
          orderId: 'ord-ready',
          newStatus: OrderStatus.cancelled,
          reason: 'العميل تراجع عن الاستلام',
        ),
      );

      expect(result.status, OrderStatus.cancelled);
      expect(orderRepo.cancelOrderCalled, true);
    });

    test('LOCKED RULE: Ready -> Completed is FORBIDDEN via generic UseCase (must use CompleteOrderUseCase)', () async {
      expect(
        () => useCase.execute(
          const ChangeOrderStatusInput(
            orderId: 'ord-ready',
            newStatus: OrderStatus.completed,
          ),
        ),
        throwsA(isA<InvalidOrderTransitionFailure>()),
      );
    });

    test('Completed -> Processing requires non-empty reason', () async {
      expect(
        () => useCase.execute(
          const ChangeOrderStatusInput(
            orderId: 'ord-comp',
            newStatus: OrderStatus.processing,
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );

      final result = await useCase.execute(
        const ChangeOrderStatusInput(
          orderId: 'ord-comp',
          newStatus: OrderStatus.processing,
          reason: 'تصحيح خطأ إغلاق الطلب',
        ),
      );

      expect(result.status, OrderStatus.processing);
      expect(result.completedAt, isNull);
    });

    test('Completed -> Ready is FORBIDDEN', () async {
      expect(
        () => useCase.execute(
          const ChangeOrderStatusInput(
            orderId: 'ord-comp',
            newStatus: OrderStatus.ready,
          ),
        ),
        throwsA(isA<InvalidOrderTransitionFailure>()),
      );
    });

    test('Completed -> Cancelled is FORBIDDEN', () async {
      expect(
        () => useCase.execute(
          const ChangeOrderStatusInput(
            orderId: 'ord-comp',
            newStatus: OrderStatus.cancelled,
            reason: 'محاولة إلغاء مكتمل',
          ),
        ),
        throwsA(isA<InvalidOrderTransitionFailure>()),
      );
    });

    test('Cancelled -> Any is FORBIDDEN in V1', () async {
      expect(
        () => useCase.execute(
          const ChangeOrderStatusInput(
            orderId: 'ord-canc',
            newStatus: OrderStatus.processing,
          ),
        ),
        throwsA(isA<InvalidOrderTransitionFailure>()),
      );

      expect(
        () => useCase.execute(
          const ChangeOrderStatusInput(
            orderId: 'ord-canc',
            newStatus: OrderStatus.ready,
          ),
        ),
        throwsA(isA<InvalidOrderTransitionFailure>()),
      );

      expect(
        () => useCase.execute(
          const ChangeOrderStatusInput(
            orderId: 'ord-canc',
            newStatus: OrderStatus.completed,
          ),
        ),
        throwsA(isA<InvalidOrderTransitionFailure>()),
      );
    });
  });
}
