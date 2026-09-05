import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';

void main() {
  group('Order Domain Entity Invariants', () {
    final now = DateTime.now();

    test('successfully instantiates a valid order', () {
      final order = Order(
        id: 'ord-1',
        orderNumber: '26-001',
        customerId: 'cust-1',
        status: OrderStatus.processing,
        expectedPickupDate: OrderDate(2026, 9, 10),
        subtotal: const Money.fromPiastres(10000), // 100 EGP
        discount: const Money.fromPiastres(1000), // 10 EGP
        customerPickupFee: const Money.fromPiastres(1500), // 15 EGP
        customerDeliveryFee: const Money.fromPiastres(2000), // 20 EGP
        tax: const Money.fromPiastres(500), // 5 EGP
        total: const Money.fromPiastres(13000), // 100 - 10 + 15 + 20 + 5 = 130
        createdAt: now,
        updatedAt: now,
      );

      expect(order.total, const Money.fromPiastres(13000));
      expect(order.totalDeliveryFees, const Money.fromPiastres(3500));
      expect(order.customerHandoverConfirmedAt, isNull);
    });

    test('throws ArgumentError when total does not match calculated total', () {
      expect(
        () => Order(
          id: 'ord-1',
          orderNumber: '26-001',
          customerId: 'cust-1',
          expectedPickupDate: OrderDate(2026, 9, 10),
          subtotal: const Money.fromPiastres(10000),
          total: const Money.fromPiastres(9000), // Mismatch!
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );
    });

    test('Option A: customerHandoverConfirmedAt derives from completedAt', () {
      final completedTime = DateTime(2026, 9, 5, 14, 30);
      final completedOrder = Order(
        id: 'ord-2',
        orderNumber: '26-002',
        customerId: 'cust-1',
        status: OrderStatus.completed,
        expectedPickupDate: OrderDate(2026, 9, 10),
        subtotal: const Money.fromPiastres(5000),
        total: const Money.fromPiastres(5000),
        completedAt: completedTime,
        createdAt: now,
        updatedAt: now,
      );

      expect(completedOrder.completedAt, completedTime);
      expect(completedOrder.customerHandoverConfirmedAt, completedTime);
    });

    test('throws ArgumentError if completed order lacks completedAt', () {
      expect(
        () => Order(
          id: 'ord-3',
          orderNumber: '26-003',
          customerId: 'cust-1',
          status: OrderStatus.completed,
          expectedPickupDate: OrderDate(2026, 9, 10),
          subtotal: const Money.fromPiastres(5000),
          total: const Money.fromPiastres(5000),
          completedAt: null, // Invalid!
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError if cancelled order lacks reason or cancelledAt', () {
      expect(
        () => Order(
          id: 'ord-4',
          orderNumber: '26-004',
          customerId: 'cust-1',
          status: OrderStatus.cancelled,
          expectedPickupDate: OrderDate(2026, 9, 10),
          subtotal: const Money.fromPiastres(5000),
          total: const Money.fromPiastres(5000),
          cancelledAt: null,
          cancellationReason: 'Client requested',
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );

      expect(
        () => Order(
          id: 'ord-5',
          orderNumber: '26-005',
          customerId: 'cust-1',
          status: OrderStatus.cancelled,
          expectedPickupDate: OrderDate(2026, 9, 10),
          subtotal: const Money.fromPiastres(5000),
          total: const Money.fromPiastres(5000),
          cancelledAt: now,
          cancellationReason: '  ', // empty reason invalid!
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );
    });

    test('isOverdue identifies processing/ready orders past pickup date', () {
      final pastDate = OrderDate(2020, 1, 1);
      final futureDate = OrderDate(2099, 1, 1);

      final overdueOrder = Order(
        id: 'ord-6',
        orderNumber: '26-006',
        customerId: 'cust-1',
        status: OrderStatus.processing,
        expectedPickupDate: pastDate,
        subtotal: const Money.fromPiastres(5000),
        total: const Money.fromPiastres(5000),
        createdAt: now,
        updatedAt: now,
      );
      expect(overdueOrder.isOverdue, isTrue);

      final notOverdueOrder = overdueOrder.copyWith(
        expectedPickupDate: futureDate,
      );
      expect(notOverdueOrder.isOverdue, isFalse);

      final completedPastOrder = overdueOrder.copyWith(
        status: OrderStatus.completed,
        completedAt: now,
      );
      expect(completedPastOrder.isOverdue, isFalse);
    });
  });
}
