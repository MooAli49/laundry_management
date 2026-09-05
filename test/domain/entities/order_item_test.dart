import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/value_objects/money.dart';

void main() {
  group('OrderItem Domain Entity Invariants', () {
    final now = DateTime.now();

    test('validates correctly created order item', () {
      final item = OrderItem(
        id: 'item-1',
        orderId: 'ord-1',
        itemTypeId: 'type-1',
        serviceId: 'srv-1',
        itemTypeNameSnapshot: 'قميص',
        serviceNameSnapshot: 'غسيل ومكواة',
        pricingType: PricingType.perPiece,
        quantity: 2.0,
        unitPrice: const Money.fromPiastres(1500),
        calculatedTotal: const Money.fromPiastres(3000),
        createdAt: now,
        updatedAt: now,
      );

      expect(item.quantity, 2.0);
      expect(item.unitPrice, const Money.fromPiastres(1500));
      expect(item.calculatedTotal, const Money.fromPiastres(3000));
    });

    test('throws ArgumentError on non-positive quantity', () {
      expect(
        () => OrderItem(
          id: 'item-2',
          orderId: 'ord-1',
          itemTypeId: 'type-1',
          serviceId: 'srv-1',
          itemTypeNameSnapshot: 'قميص',
          serviceNameSnapshot: 'غسيل ومكواة',
          pricingType: PricingType.perPiece,
          quantity: 0,
          unitPrice: const Money.fromPiastres(1500),
          calculatedTotal: const Money.fromPiastres(0),
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError on negative prices', () {
      expect(
        () => OrderItem(
          id: 'item-3',
          orderId: 'ord-1',
          itemTypeId: 'type-1',
          serviceId: 'srv-1',
          itemTypeNameSnapshot: 'قميص',
          serviceNameSnapshot: 'غسيل ومكواة',
          pricingType: PricingType.perPiece,
          quantity: 1,
          unitPrice: const Money.fromPiastres(-100),
          calculatedTotal: const Money.fromPiastres(-100),
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );
    });
  });
}
