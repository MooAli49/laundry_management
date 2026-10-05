import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../../../domain/enums/report_period.dart';
import '../../../../domain/repositories/expense_category_repository.dart';
import '../../../../domain/repositories/expense_repository.dart';
import '../../../../domain/value_objects/order_date.dart';
import 'expenses_list_state.dart';

class ExpensesListCubit extends Cubit<ExpensesListState> {
  final ExpenseRepository _expenseRepository;
  final ExpenseCategoryRepository _categoryRepository;

  ExpensesListCubit({
    required ExpenseRepository expenseRepository,
    required ExpenseCategoryRepository categoryRepository,
  })  : _expenseRepository = expenseRepository,
        _categoryRepository = categoryRepository,
        super(const ExpensesListState());

  Future<void> loadExpenses({bool refresh = false}) async {
    if (!refresh && state.isLoading) return;

    emit(state.copyWith(isLoading: true, clearErrorMessage: true));

    try {
      // 1. Load active categories for filter if not already loaded
      final categories = state.categories.isEmpty
          ? await _categoryRepository.getActiveCategories()
          : state.categories;

      // 2. Resolve date range from period
      final range = state.selectedPeriod.resolveDateRange(
        customStart: state.customStartDate,
        customEnd: state.customEndDate,
      );

      final startDate = OrderDate.fromDate(range.start);
      final endDate = OrderDate.fromDate(range.end);

      // 3. Query repository
      final expenses = await _expenseRepository.getExpenses(
        startDate: startDate,
        endDate: endDate,
        categoryId: state.selectedCategoryId,
        limit: 200,
      );

      emit(state.copyWith(
        isLoading: false,
        expenses: expenses,
        categories: categories,
        clearErrorMessage: true,
      ));
    } on Failure catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      ));
    } catch (_) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'تعذر تحميل المصروفات، يرجى المحاولة مرة أخرى',
      ));
    }
  }

  void selectPeriod(
    ReportPeriod period, {
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    emit(state.copyWith(
      selectedPeriod: period,
      customStartDate: customStart,
      customEndDate: customEnd,
    ));
    loadExpenses(refresh: true);
  }

  void selectCategory(String? categoryId) {
    if (categoryId == null) {
      emit(state.copyWith(clearCategory: true));
    } else {
      emit(state.copyWith(selectedCategoryId: categoryId));
    }
    loadExpenses(refresh: true);
  }

  void search(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  Future<void> refresh() async {
    await loadExpenses(refresh: true);
  }
}
