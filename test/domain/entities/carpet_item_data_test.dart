import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/domain/entities/carpet_item_data.dart';

void main() {
  group('CarpetItemData Domain Entity', () {
    final now = DateTime.now();

    test('validates correct area calculation', () {
      final carpet = CarpetItemData(
        id: 'c-1',
        orderItemId: 'item-1',
        length: 2.0,
        width: 3.0,
        area: 6.0,
        createdAt: now,
        updatedAt: now,
      );

      expect(carpet.area, 6.0);
      expect(carpet.length, 2.0);
      expect(carpet.width, 3.0);
    });

    test('throws ArgumentError when area does not match length * width', () {
      expect(
        () => CarpetItemData(
          id: 'c-2',
          orderItemId: 'item-1',
          length: 2.0,
          width: 3.0,
          area: 7.5, // Mismatch!
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for non-positive dimensions', () {
      expect(
        () => CarpetItemData(
          id: 'c-3',
          orderItemId: 'item-1',
          length: -1.0,
          width: 3.0,
          area: -3.0,
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );

      expect(
        () => CarpetItemData(
          id: 'c-4',
          orderItemId: 'item-1',
          length: 2.0,
          width: 0,
          area: 0,
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );
    });
  });
}
