import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/application/use_cases/cancel_order_use_case.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/repositories/order_repository.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';

class FakeOrderRepository implements OrderRepository {
  final Map<String, Order> orders = {};
  bool cancelOrderCalled = false;
  String? lastCancellationReason;

  @override
  Future<Order?> getOrderById(String id) async => orders[id];

  @override
  Future<Order> cancelOrder({
    required String orderId,
    required String cancellationReason,
  }) async {
    cancelOrderCalled = true;
    lastCancellationReason = cancellationReason;
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
  late CancelOrderUseCase useCase;

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
      cancellationReason: status == OrderStatus.cancelled ? 'سبب سابق' : null,
      createdAt: now,
      updatedAt: now,
    );
  }

  setUp(() {
    orderRepo = FakeOrderRepository();
    useCase = CancelOrderUseCase(orderRepo);

    orderRepo.orders['ord-proc'] = makeOrder('ord-proc', OrderStatus.processing);
    orderRepo.orders['ord-ready'] = makeOrder('ord-ready', OrderStatus.ready);
    orderRepo.orders['ord-comp'] = makeOrder('ord-comp', OrderStatus.completed);
    orderRepo.orders['ord-canc'] = makeOrder('ord-canc', OrderStatus.cancelled);
  });

  group('CancelOrderUseCase', () {
    test('rejects cancellation when confirmed is false', () async {
      expect(
        () => useCase.execute(
          const CancelOrderInput(
            orderId: 'ord-proc',
            cancellationReason: 'سبب الإلغاء',
            confirmed: false,
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects empty or whitespace-only cancellation reason', () async {
      expect(
        () => useCase.execute(
          const CancelOrderInput(
            orderId: 'ord-proc',
            cancellationReason: '',
            confirmed: true,
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );

      expect(
        () => useCase.execute(
          const CancelOrderInput(
            orderId: 'ord-proc',
            cancellationReason: '    ',
            confirmed: true,
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects non-existent order', () async {
      expect(
        () => useCase.execute(
          const CancelOrderInput(
            orderId: 'non-existent',
            cancellationReason: 'سبب صحيح',
            confirmed: true,
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('LOCKED RULE: completed orders cannot be cancelled', () async {
      expect(
        () => useCase.execute(
          const CancelOrderInput(
            orderId: 'ord-comp',
            cancellationReason: 'محاولة إلغاء طلب مكتمل',
            confirmed: true,
          ),
        ),
        throwsA(isA<BusinessRuleFailure>()),
      );
    });

    test('LOCKED RULE: already cancelled orders cannot be cancelled again', () async {
      expect(
        () => useCase.execute(
          const CancelOrderInput(
            orderId: 'ord-canc',
            cancellationReason: 'إلغاء مكرر',
            confirmed: true,
          ),
        ),
        throwsA(isA<BusinessRuleFailure>()),
      );
    });

    test('successfully cancels a processing order', () async {
      final result = await useCase.execute(
        const CancelOrderInput(
          orderId: 'ord-proc',
          cancellationReason: 'العميل غير رأيه',
          confirmed: true,
        ),
      );

      expect(result.status, OrderStatus.cancelled);
      expect(result.cancelledAt, isNotNull);
      expect(result.cancellationReason, 'العميل غير رأيه');
      expect(orderRepo.cancelOrderCalled, true);
    });

    test('successfully cancels a ready order', () async {
      final result = await useCase.execute(
        const CancelOrderInput(
          orderId: 'ord-ready',
          cancellationReason: 'تعذر استلام العميل',
          confirmed: true,
        ),
      );

      expect(result.status, OrderStatus.cancelled);
      expect(result.cancelledAt, isNotNull);
      expect(result.cancellationReason, 'تعذر استلام العميل');
      expect(orderRepo.cancelOrderCalled, true);
    });
  });
}
