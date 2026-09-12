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

      expect(
        () => Expense(
          id: 'exp-6',
          expenseCategoryId: 'cat-1',
          amount: const Money.fromPiastres(-500),
          expenseDate: OrderDate(2026, 9, 4),
          categoryNameSnapshot: 'كهرباء',
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError on empty required fields', () {
      expect(
        () => Expense(
          id: '   ',
          expenseCategoryId: 'cat-1',
          amount: const Money.fromPiastres(100),
          expenseDate: OrderDate(2026, 9, 4),
          categoryNameSnapshot: 'كهرباء',
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );

      expect(
        () => Expense(
          id: 'exp-1',
          expenseCategoryId: '   ',
          amount: const Money.fromPiastres(100),
          expenseDate: OrderDate(2026, 9, 4),
          categoryNameSnapshot: 'كهرباء',
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );

      expect(
        () => Expense(
          id: 'exp-1',
          expenseCategoryId: 'cat-1',
          amount: const Money.fromPiastres(100),
          expenseDate: OrderDate(2026, 9, 4),
          categoryNameSnapshot: '   ',
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );
    });

    test('supports copyWith, value equality, and preserve category snapshot', () {
      final exp1 = Expense(
        id: 'exp-1',
        expenseCategoryId: 'cat-1',
        amount: const Money.fromPiastres(500),
        expenseDate: OrderDate(2026, 9, 4),
        categoryNameSnapshot: 'صيانة',
        createdAt: now,
        updatedAt: now,
      );

      final exp2 = exp1.copyWith(amount: const Money.fromPiastres(800));
      expect(exp2.amount, const Money.fromPiastres(800));
      expect(exp2.categoryNameSnapshot, 'صيانة');
      expect(exp1 == exp2, isFalse);

      final exp1Clone = exp1.copyWith();
      expect(exp1 == exp1Clone, isTrue);
      expect(exp1.hashCode, exp1Clone.hashCode);
    });
  });
}

