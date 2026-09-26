import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/application/use_cases/edit_processing_order_use_case.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/repositories/order_repository.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';

class MockOrderRepository implements OrderRepository {
  Order? orderToReturn;
  List<OrderItem> itemsToReturn = [];
  EditProcessingOrderInput? lastInput;

  @override
  Future<Order?> getOrderById(String id) async => orderToReturn;

  @override
  Future<List<OrderItem>> getOrderItems(String orderId) async => itemsToReturn;

  @override
  Future<Order> editProcessingOrder(EditProcessingOrderInput input) async {
    lastInput = input;
    final base = orderToReturn!;
    return base.copyWith(
      customerId: input.customerId,
      notes: input.notes,
      customerPickupRequested: input.customerPickupRequested,
      customerPickupFee: input.customerPickupFee,
      customerDeliveryRequested: input.customerDeliveryRequested,
      customerDeliveryFee: input.customerDeliveryFee,
      discount: input.discount,
      expectedPickupDate: input.expectedPickupDate,
      subtotal: Money.fromEgp(40),
      total: Money.fromEgp(55),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockOrderRepository mockOrderRepository;
  late EditProcessingOrderUseCase useCase;

  final now = DateTime.now();

  final testExistingItem = OrderItem(
    id: 'item-1',
    orderId: 'order-1',
    itemTypeId: 'type-1',
    itemTypeNameSnapshot: 'ثوب',
    serviceId: 'srv-1',
    serviceNameSnapshot: 'غسيل وكوي',
    pricingType: PricingType.perPiece,
    quantity: 2,
    unitPrice: Money.fromEgp(15),
    calculatedTotal: Money.fromEgp(30),
    createdAt: now,
    updatedAt: now,
  );

  final testOrder = Order(
    id: 'order-1',
    orderNumber: '26-001',
    customerId: 'cust-1',
    customerNameSnapshot: 'أحمد علي',
    customerPhoneSnapshot: '0501234567',
    status: OrderStatus.processing,
    subtotal: Money.fromEgp(30),
    total: Money.fromEgp(30),
    expectedPickupDate: OrderDate.fromDate(now.add(const Duration(days: 2))),
    createdAt: now,
    updatedAt: now,
  );

  setUp(() {
    mockOrderRepository = MockOrderRepository();
    mockOrderRepository.orderToReturn = testOrder;
    mockOrderRepository.itemsToReturn = [testExistingItem];

    useCase = EditProcessingOrderUseCase(
      orderRepository: mockOrderRepository,
    );
  });

  group('EditProcessingOrderUseCase', () {
    test('rejects if order ID is empty', () async {
      expect(
        () => useCase.execute(
          EditProcessingOrderInput(
            orderId: '  ',
            customerId: 'cust-1',
            expectedPickupDate: OrderDate.fromDate(now),
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects if customer ID is empty', () async {
      expect(
        () => useCase.execute(
          EditProcessingOrderInput(
            orderId: 'order-1',
            customerId: '',
            expectedPickupDate: OrderDate.fromDate(now),
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects if order does not exist', () async {
      mockOrderRepository.orderToReturn = null;

      expect(
        () => useCase.execute(
          EditProcessingOrderInput(
            orderId: 'non-existent',
            customerId: 'cust-1',
            expectedPickupDate: OrderDate.fromDate(now),
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects if changed expected pickup date is in the past', () async {
      expect(
        () => useCase.execute(
          EditProcessingOrderInput(
            orderId: 'order-1',
            customerId: 'cust-1',
            expectedPickupDate: OrderDate(2020, 1, 1),
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects if pickup fee is negative', () async {
      expect(
        () => useCase.execute(
          EditProcessingOrderInput(
            orderId: 'order-1',
            customerId: 'cust-1',
            expectedPickupDate: testOrder.expectedPickupDate,
            customerPickupRequested: true,
            customerPickupFee: const Money.fromPiastres(-100),
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects if delivery fee is provided but delivery is false', () async {
      expect(
        () => useCase.execute(
          EditProcessingOrderInput(
            orderId: 'order-1',
            customerId: 'cust-1',
            expectedPickupDate: testOrder.expectedPickupDate,
            customerDeliveryRequested: false,
            customerDeliveryFee: Money.fromEgp(10),
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('successfully delegates to repository for valid input', () async {
      final updated = await useCase.execute(
        EditProcessingOrderInput(
          orderId: 'order-1',
          customerId: 'cust-1',
          expectedPickupDate: OrderDate.fromDate(now.add(const Duration(days: 3))),
          notes: 'ملاحظة محدثة',
          customerDeliveryRequested: true,
          customerDeliveryFee: Money.fromEgp(15),
          modifiedItems: [
            OrderItemEditInput(
              id: 'item-1',
              serviceId: 'srv-1',
              customUnitPrice: Money.fromEgp(20),
            ),
          ],
        ),
      );

      expect(updated.id, 'order-1');
      expect(updated.notes, 'ملاحظة محدثة');
      expect(updated.customerDeliveryRequested, isTrue);
      expect(updated.customerDeliveryFee, Money.fromEgp(15));
      expect(updated.total, Money.fromEgp(55));
      expect(mockOrderRepository.lastInput, isNotNull);
      expect(mockOrderRepository.lastInput?.modifiedItems.length, 1);
      expect(mockOrderRepository.lastInput?.modifiedItems.first.id, 'item-1');
    });
  });
}
