import '../../../../domain/entities/expense.dart';
import '../../../../domain/entities/expense_category.dart';
import '../../../../domain/enums/report_period.dart';
import '../../../../domain/value_objects/money.dart';

class ExpensesListState {
  final bool isLoading;
  final List<Expense> expenses;
  final List<ExpenseCategory> categories;
  final String? selectedCategoryId; // null = all
  final ReportPeriod selectedPeriod;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final String searchQuery;
  final String? errorMessage;

  const ExpensesListState({
    this.isLoading = false,
    this.expenses = const [],
    this.categories = const [],
    this.selectedCategoryId,
    this.selectedPeriod = ReportPeriod.thisMonth,
    this.customStartDate,
    this.customEndDate,
    this.searchQuery = '',
    this.errorMessage,
  });

  ExpensesListState copyWith({
    bool? isLoading,
    List<Expense>? expenses,
    List<ExpenseCategory>? categories,
    String? selectedCategoryId,
    bool clearCategory = false,
    ReportPeriod? selectedPeriod,
    DateTime? customStartDate,
    DateTime? customEndDate,
    String? searchQuery,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ExpensesListState(
      isLoading: isLoading ?? this.isLoading,
      expenses: expenses ?? this.expenses,
      categories: categories ?? this.categories,
      selectedCategoryId: clearCategory
          ? null
          : (selectedCategoryId ?? this.selectedCategoryId),
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }

  List<Expense> get filteredExpenses {
    if (searchQuery.trim().isEmpty) return expenses;
    final q = searchQuery.trim().toLowerCase();
    return expenses.where((e) {
      final name = e.expenseName?.toLowerCase() ?? '';
      final notes = e.notes?.toLowerCase() ?? '';
      final category = e.categoryNameSnapshot.toLowerCase();
      return name.contains(q) || notes.contains(q) || category.contains(q);
    }).toList();
  }

  Money get totalAmount {
    return filteredExpenses.fold(
      Money.zero,
      (prev, e) => prev + e.amount,
    );
  }

  int get totalCount => filteredExpenses.length;

  ({String name, Money amount})? get topCategory {
    if (filteredExpenses.isEmpty) return null;
    final map = <String, int>{};
    for (final e in filteredExpenses) {
      map[e.categoryNameSnapshot] =
          (map[e.categoryNameSnapshot] ?? 0) + e.amount.piastres;
    }
    String topName = '';
    int maxPiastres = -1;
    map.forEach((cat, piastres) {
      if (piastres > maxPiastres) {
        maxPiastres = piastres;
        topName = cat;
      }
    });
    if (maxPiastres <= 0) return null;
    return (name: topName, amount: Money.fromPiastres(maxPiastres));
  }
}
