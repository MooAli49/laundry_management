import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/domain/entities/expense.dart';
import 'package:laundry_management/domain/entities/expense_category.dart';
import 'package:laundry_management/domain/repositories/expense_category_repository.dart';
import 'package:laundry_management/domain/repositories/expense_repository.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';
import 'package:laundry_management/features/expenses/presentation/cubit/add_expense_cubit.dart';

class MockExpenseCategoryRepository implements ExpenseCategoryRepository {
  List<ExpenseCategory> categoriesToReturn = [];
  bool shouldThrow = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<ExpenseCategory>> getActiveCategories() async {
    if (shouldThrow) throw Exception('Database error');
    return categoriesToReturn;
  }
}

class MockExpenseRepository implements ExpenseRepository {
  Expense? createdExpense;
  bool shouldThrow = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Expense> createExpense(Expense expense) async {
    if (shouldThrow) throw const BusinessRuleFailure('Creation failed');
    createdExpense = expense;
    return expense;
  }
}

void main() {
  late MockExpenseCategoryRepository categoryRepo;
  late MockExpenseRepository expenseRepo;
  late AddExpenseCubit cubit;

  final cat1 = ExpenseCategory(
    id: 'cat-1',
    name: 'كهرباء',
    isActive: true,
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 1),
  );
  final catOther = ExpenseCategory(
    id: 'cat-other',
    name: 'أخرى',
    isActive: true,
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 1),
  );

  setUp(() {
    categoryRepo = MockExpenseCategoryRepository();
    expenseRepo = MockExpenseRepository();
    cubit = AddExpenseCubit(
      categoryRepository: categoryRepo,
      expenseRepository: expenseRepo,
    );
  });

  tearDown(() {
    cubit.close();
  });

  test('initial state has empty categories and is not saving', () {
    expect(cubit.state.isLoadingCategories, isFalse);
    expect(cubit.state.categories, isEmpty);
    expect(cubit.state.selectedCategory, isNull);
    expect(cubit.state.isSaving, isFalse);
    expect(cubit.state.isSuccess, isFalse);
  });

  test('loadCategories loads active categories and picks non-other default', () async {
    categoryRepo.categoriesToReturn = [catOther, cat1];

    await cubit.loadCategories();

    expect(cubit.state.isLoadingCategories, isFalse);
    expect(cubit.state.categories.length, 2);
    expect(cubit.state.selectedCategory?.id, 'cat-1');
  });

  test('selectCategory updates selectedCategory', () async {
    cubit.selectCategory(catOther);
    expect(cubit.state.selectedCategory?.id, 'cat-other');
  });

  test('createExpense successfully constructs and saves Expense', () async {
    final result = await cubit.createExpense(
      amount: const Money.fromPiastres(5000),
      category: cat1,
      expenseName: null,
      expenseDate: OrderDate(2026, 9, 12),
      notes: 'ملاحظة',
    );

    expect(result, isNotNull);
    expect(cubit.state.isSuccess, isTrue);
    expect(cubit.state.isSaving, isFalse);
    expect(expenseRepo.createdExpense, isNotNull);
    expect(expenseRepo.createdExpense?.amount, const Money.fromPiastres(5000));
    expect(expenseRepo.createdExpense?.categoryNameSnapshot, 'كهرباء');
    expect(expenseRepo.createdExpense?.notes, 'ملاحظة');
  });

  test('createExpense rejects invalid amount string', () async {
    final result = await cubit.createExpense(
      amountText: 'invalid',
      category: cat1,
      expenseDate: OrderDate(2026, 9, 12),
    );

    expect(result, isNull);
    expect(cubit.state.errorMessage, 'يرجى إدخال مبلغ صحيح');
  });

  test('createExpense rejects zero amount', () async {
    final result = await cubit.createExpense(
      amount: Money.zero,
      category: cat1,
      expenseDate: OrderDate(2026, 9, 12),
    );

    expect(result, isNull);
    expect(cubit.state.errorMessage, 'يرجى إدخال مبلغ صحيح أكبر من الصفر');
  });

  test('createExpense rejects missing category', () async {
    final result = await cubit.createExpense(
      amount: const Money.fromPiastres(1000),
      category: null,
      expenseDate: OrderDate(2026, 9, 12),
    );

    expect(result, isNull);
    expect(cubit.state.errorMessage, 'يرجى اختيار تصنيف المصروف');
  });

  test('createExpense rejects category أخرى when expense name is missing', () async {
    final result = await cubit.createExpense(
      amount: const Money.fromPiastres(1000),
      category: catOther,
      expenseName: '   ',
      expenseDate: OrderDate(2026, 9, 12),
    );

    expect(result, isNull);
    expect(cubit.state.errorMessage, 'يرجى إدخال اسم المصروف عند اختيار تصنيف أخرى');
  });

  test('createExpense rejects invalid precision (> 2 decimal places)', () async {
    final result = await cubit.createExpense(
      amountText: '10.999',
      category: cat1,
      expenseDate: OrderDate(2026, 9, 12),
    );

    expect(result, isNull);
    expect(cubit.state.errorMessage, 'يرجى إدخال مبلغ صحيح');
  });

  test('createExpense handles failure properly', () async {
    expenseRepo.shouldThrow = true;

    final result = await cubit.createExpense(
      amount: const Money.fromPiastres(5000),
      category: cat1,
      expenseDate: OrderDate(2026, 9, 12),
    );

    expect(result, isNull);
    expect(cubit.state.isSuccess, isFalse);
    expect(cubit.state.isSaving, isFalse);
    expect(cubit.state.errorMessage, 'Creation failed');
  });
}
