import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/domain/entities/expense.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';

void main() {
  group('Expense Domain Entity Invariants', () {
    final now = DateTime.now();

    test('validates normal expense with known category', () {
      final expense = Expense(
        id: 'exp-1',
        expenseCategoryId: 'cat-1',
        amount: const Money.fromPiastres(2500),
        expenseDate: OrderDate(2026, 9, 4),
        categoryNameSnapshot: 'كهرباء',
        createdAt: now,
        updatedAt: now,
      );

      expect(expense.amount, const Money.fromPiastres(2500));
      expect(expense.categoryNameSnapshot, 'كهرباء');
    });

    test('strictly requires expenseName when categoryNameSnapshot is أخرى', () {
      expect(
        () => Expense(
          id: 'exp-2',
          expenseCategoryId: 'cat-7',
          amount: const Money.fromPiastres(1500),
          expenseDate: OrderDate(2026, 9, 4),
          categoryNameSnapshot: 'أخرى',
          expenseName: null, // Invalid!
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );

      expect(
        () => Expense(
          id: 'exp-3',
          expenseCategoryId: 'cat-7',
          amount: const Money.fromPiastres(1500),
          expenseDate: OrderDate(2026, 9, 4),
          categoryNameSnapshot: 'أخرى',
          expenseName: '   ', // Empty string invalid!
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );

      final validOtherExpense = Expense(
        id: 'exp-4',
        expenseCategoryId: 'cat-7',
        amount: const Money.fromPiastres(1500),
        expenseName: 'شراء أدوات نظافة إضافية',
        expenseDate: OrderDate(2026, 9, 4),
        categoryNameSnapshot: 'أخرى',
        createdAt: now,
        updatedAt: now,
      );
      expect(validOtherExpense.expenseName, 'شراء أدوات نظافة إضافية');
    });

    test('throws ArgumentError on non-positive amount', () {
      expect(
        () => Expense(
          id: 'exp-5',
          expenseCategoryId: 'cat-1',
          amount: Money.zero,
          expenseDate: OrderDate(2026, 9, 4),
          categoryNameSnapshot: 'كهرباء',
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );
    });
  });
}
