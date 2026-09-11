import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/domain/entities/expense_category.dart';

void main() {
  group('ExpenseCategory Domain Entity Tests', () {
    final now = DateTime.now();

    test('creates valid active expense category with defaults', () {
      final cat = ExpenseCategory(
        id: 'cat-1',
        name: 'كهرباء',
        createdAt: now,
        updatedAt: now,
      );

      expect(cat.id, 'cat-1');
      expect(cat.name, 'كهرباء');
      expect(cat.isActive, isTrue);
    });

    test('throws ArgumentError on empty id or name', () {
      expect(
        () => ExpenseCategory(
          id: '',
          name: 'كهرباء',
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );

      expect(
        () => ExpenseCategory(
          id: 'cat-1',
          name: '   ',
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );
    });

    test('supports activation/deactivation via copyWith', () {
      final activeCat = ExpenseCategory(
        id: 'cat-1',
        name: 'كهرباء',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final inactiveCat = activeCat.copyWith(isActive: false);
      expect(inactiveCat.isActive, isFalse);
      expect(inactiveCat.name, 'كهرباء');
    });

    test('verifies value equality and hash code', () {
      final cat1 = ExpenseCategory(
        id: 'cat-1',
        name: 'مياه',
        createdAt: now,
        updatedAt: now,
      );

      final cat2 = ExpenseCategory(
        id: 'cat-1',
        name: 'مياه',
        createdAt: now,
        updatedAt: now,
      );

      expect(cat1, equals(cat2));
      expect(cat1.hashCode, equals(cat2.hashCode));
    });
  });
}
