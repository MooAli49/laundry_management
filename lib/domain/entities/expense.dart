import '../value_objects/money.dart';
import '../value_objects/order_date.dart';

class Expense {
  final String id;
  final String expenseCategoryId;
  final Money amount;
  final String? expenseName;
  final OrderDate expenseDate;
  final String? notes;
  final String categoryNameSnapshot;
  final DateTime createdAt;
  final DateTime updatedAt;

  Expense({
    required this.id,
    required this.expenseCategoryId,
    required this.amount,
    this.expenseName,
    required this.expenseDate,
    this.notes,
    required this.categoryNameSnapshot,
    required this.createdAt,
    required this.updatedAt,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('Expense id cannot be empty');
    }
    if (expenseCategoryId.trim().isEmpty) {
      throw ArgumentError('Expense expenseCategoryId cannot be empty');
    }
    if (!amount.isPositive) {
      throw ArgumentError.value(amount, 'amount', 'Expense amount must be greater than 0');
    }
    if (categoryNameSnapshot.trim().isEmpty) {
      throw ArgumentError('Expense categoryNameSnapshot cannot be empty');
    }
    if (categoryNameSnapshot == 'أخرى' && (expenseName == null || expenseName!.trim().isEmpty)) {
      throw ArgumentError('Expense using category "أخرى" must provide an expenseName');
    }
  }

  Expense copyWith({
    String? id,
    String? expenseCategoryId,
    Money? amount,
    String? expenseName,
    OrderDate? expenseDate,
    String? notes,
    String? categoryNameSnapshot,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      expenseCategoryId: expenseCategoryId ?? this.expenseCategoryId,
      amount: amount ?? this.amount,
      expenseName: expenseName ?? this.expenseName,
      expenseDate: expenseDate ?? this.expenseDate,
      notes: notes ?? this.notes,
      categoryNameSnapshot: categoryNameSnapshot ?? this.categoryNameSnapshot,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Expense &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          expenseCategoryId == other.expenseCategoryId &&
          amount == other.amount &&
          expenseName == other.expenseName &&
          expenseDate == other.expenseDate &&
          notes == other.notes &&
          categoryNameSnapshot == other.categoryNameSnapshot &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        expenseCategoryId,
        amount,
        expenseName,
        expenseDate,
        notes,
        categoryNameSnapshot,
        createdAt,
        updatedAt,
      );

  @override
  String toString() =>
      'Expense(id: $id, amount: $amount, category: $categoryNameSnapshot, name: $expenseName)';
}
