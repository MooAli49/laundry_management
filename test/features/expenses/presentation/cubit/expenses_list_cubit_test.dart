import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/domain/entities/expense.dart';
import 'package:laundry_management/domain/entities/expense_category.dart';
import 'package:laundry_management/domain/enums/report_period.dart';
import 'package:laundry_management/domain/repositories/expense_category_repository.dart';
import 'package:laundry_management/domain/repositories/expense_repository.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';
import 'package:laundry_management/features/expenses/presentation/cubit/expenses_list_cubit.dart';

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
  List<Expense> expensesToReturn = [];
  bool shouldThrow = false;
  OrderDate? lastStartDate;
  OrderDate? lastEndDate;
  String? lastCategoryId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<Expense>> getExpenses({
    OrderDate? startDate,
    OrderDate? endDate,
    String? categoryId,
    int limit = 50,
    int offset = 0,
  }) async {
    if (shouldThrow) throw const DatabaseFailure('Database error');
    lastStartDate = startDate;
    lastEndDate = endDate;
    lastCategoryId = categoryId;
    return expensesToReturn;
  }
}

void main() {
  late MockExpenseCategoryRepository categoryRepo;
  late MockExpenseRepository expenseRepo;
  late ExpensesListCubit cubit;

  final cat1 = ExpenseCategory(
    id: 'cat-1',
    name: 'كهرباء',
    isActive: true,
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 1),
  );
  final cat2 = ExpenseCategory(
    id: 'cat-2',
    name: 'منظفات',
    isActive: true,
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 1),
  );

  final exp1 = Expense(
    id: 'exp-1',
    expenseCategoryId: 'cat-1',
    amount: Money.fromPiastres(15000), // 150 EGP
    expenseName: 'فاتورة أغسطس',
    expenseDate: OrderDate(2026, 9, 15),
    notes: 'الدفع نقداً',
    categoryNameSnapshot: 'كهرباء',
    createdAt: DateTime(2026, 9, 15),
    updatedAt: DateTime(2026, 9, 15),
  );
  final exp2 = Expense(
    id: 'exp-2',
    expenseCategoryId: 'cat-2',
    amount: Money.fromPiastres(25000), // 250 EGP
    expenseName: 'شراء صابون',
    expenseDate: OrderDate(2026, 9, 20),
    notes: 'كمية 50 لتر',
    categoryNameSnapshot: 'منظفات',
    createdAt: DateTime(2026, 9, 20),
    updatedAt: DateTime(2026, 9, 20),
  );

  setUp(() {
    categoryRepo = MockExpenseCategoryRepository();
    expenseRepo = MockExpenseRepository();
    categoryRepo.categoriesToReturn = [cat1, cat2];
    expenseRepo.expensesToReturn = [exp1, exp2];
    cubit = ExpensesListCubit(
      expenseRepository: expenseRepo,
      categoryRepository: categoryRepo,
    );
  });

  tearDown(() {
    cubit.close();
  });

  test('initial state has default period thisMonth and empty lists', () {
    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.expenses, isEmpty);
    expect(cubit.state.categories, isEmpty);
    expect(cubit.state.selectedPeriod, equals(ReportPeriod.thisMonth));
    expect(cubit.state.selectedCategoryId, isNull);
    expect(cubit.state.searchQuery, isEmpty);
  });

  test('loadExpenses populates expenses and categories, computes metrics', () async {
    await cubit.loadExpenses();

    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.expenses.length, equals(2));
    expect(cubit.state.categories.length, equals(2));
    expect(cubit.state.totalCount, equals(2));
    expect(cubit.state.totalAmount, equals(Money.fromPiastres(40000))); // 400 EGP
    expect(cubit.state.topCategory?.name, equals('منظفات'));
    expect(cubit.state.topCategory?.amount, equals(Money.fromPiastres(25000)));
  });

  test('selectPeriod updates period and passes date range to repository', () async {
    cubit.selectPeriod(ReportPeriod.today);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(cubit.state.selectedPeriod, equals(ReportPeriod.today));
    final today = OrderDate.today();
    expect(expenseRepo.lastStartDate, equals(today));
    expect(expenseRepo.lastEndDate, equals(today));
  });

  test('selectCategory filters by categoryId and passes it to repository', () async {
    cubit.selectCategory('cat-1');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(cubit.state.selectedCategoryId, equals('cat-1'));
    expect(expenseRepo.lastCategoryId, equals('cat-1'));

    cubit.selectCategory(null);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(cubit.state.selectedCategoryId, isNull);
    expect(expenseRepo.lastCategoryId, isNull);
  });

  test('search filters filteredExpenses in-memory and recalculates totals', () async {
    await cubit.loadExpenses();

    // Search by name
    cubit.search('فاتورة');
    expect(cubit.state.filteredExpenses.length, equals(1));
    expect(cubit.state.filteredExpenses.first.id, equals('exp-1'));
    expect(cubit.state.totalAmount, equals(Money.fromPiastres(15000)));

    // Search by notes
    cubit.search('50 لتر');
    expect(cubit.state.filteredExpenses.length, equals(1));
    expect(cubit.state.filteredExpenses.first.id, equals('exp-2'));
    expect(cubit.state.totalAmount, equals(Money.fromPiastres(25000)));

    // Clear search
    cubit.search('');
    expect(cubit.state.filteredExpenses.length, equals(2));
    expect(cubit.state.totalAmount, equals(Money.fromPiastres(40000)));
  });

  test('handles Failure from repository properly', () async {
    expenseRepo.shouldThrow = true;

    await cubit.loadExpenses();

    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.errorMessage, equals('Database error'));
  });
}
