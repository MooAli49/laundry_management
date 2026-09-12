import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/failures.dart';
import '../../../../domain/entities/expense.dart';
import '../../../../domain/entities/expense_category.dart';
import '../../../../domain/repositories/expense_category_repository.dart';
import '../../../../domain/repositories/expense_repository.dart';
import '../../../../domain/value_objects/money.dart';
import '../../../../domain/value_objects/order_date.dart';
import 'add_expense_state.dart';

class AddExpenseCubit extends Cubit<AddExpenseState> {
  final ExpenseCategoryRepository _categoryRepository;
  final ExpenseRepository _expenseRepository;
  final Uuid _uuid;

  AddExpenseCubit({
    required ExpenseCategoryRepository categoryRepository,
    required ExpenseRepository expenseRepository,
    Uuid uuid = const Uuid(),
  })  : _categoryRepository = categoryRepository,
        _expenseRepository = expenseRepository,
        _uuid = uuid,
        super(const AddExpenseState());

  Future<void> loadCategories() async {
    emit(state.copyWith(isLoadingCategories: true, clearErrorMessage: true));
    try {
      final categories = await _categoryRepository.getActiveCategories();
      ExpenseCategory? defaultCategory;
      if (categories.isNotEmpty) {
        defaultCategory = categories.firstWhere(
          (c) => c.name != 'أخرى' && !c.name.contains('أخرى'),
          orElse: () => categories.first,
        );
      }
      emit(state.copyWith(
        isLoadingCategories: false,
        categories: categories,
        selectedCategory: defaultCategory,
      ));
    } catch (_) {
      emit(state.copyWith(
        isLoadingCategories: false,
        errorMessage: 'تعذر تحميل تصنيفات المصروفات',
      ));
    }
  }

  void selectCategory(ExpenseCategory category) {
    emit(state.copyWith(selectedCategory: category, clearErrorMessage: true));
  }

  Future<Expense?> createExpense({
    Money? amount,
    String? amountText,
    ExpenseCategory? category,
    String? expenseName,
    OrderDate? expenseDate,
    String? notes,
  }) async {
    Money? resolvedAmount = amount;
    if (amountText != null) {
      final trimmedText = amountText.trim();
      if (trimmedText.isEmpty) {
        emit(state.copyWith(errorMessage: 'يرجى إدخال مبلغ صحيح أكبر من الصفر'));
        return null;
      }
      resolvedAmount = Money.tryParseEgp(trimmedText);
      if (resolvedAmount == null) {
        emit(state.copyWith(errorMessage: 'يرجى إدخال مبلغ صحيح'));
        return null;
      }
    }

    if (resolvedAmount == null || resolvedAmount.isZero || resolvedAmount.isNegative) {
      emit(state.copyWith(errorMessage: 'يرجى إدخال مبلغ صحيح أكبر من الصفر'));
      return null;
    }

    if (category == null) {
      emit(state.copyWith(errorMessage: 'يرجى اختيار تصنيف المصروف'));
      return null;
    }

    if (!category.isActive) {
      emit(state.copyWith(errorMessage: 'تصنيف المصروف غير مفعل'));
      return null;
    }

    final isOther = category.name == 'أخرى' || category.name.contains('أخرى');
    final trimmedName = expenseName?.trim();
    if (isOther && (trimmedName == null || trimmedName.isEmpty)) {
      emit(state.copyWith(errorMessage: 'يرجى إدخال اسم المصروف عند اختيار تصنيف أخرى'));
      return null;
    }

    if (expenseDate == null) {
      emit(state.copyWith(errorMessage: 'يرجى تحديد تاريخ المصروف'));
      return null;
    }

    emit(state.copyWith(isSaving: true, clearErrorMessage: true));
    try {
      final now = DateTime.now();
      final expense = Expense(
        id: _uuid.v4(),
        expenseCategoryId: category.id,
        amount: resolvedAmount,
        expenseName: trimmedName?.isNotEmpty == true ? trimmedName : null,
        expenseDate: expenseDate,
        notes: notes?.trim().isNotEmpty == true ? notes!.trim() : null,
        categoryNameSnapshot: category.name,
        createdAt: now,
        updatedAt: now,
      );

      await _expenseRepository.createExpense(expense);
      emit(state.copyWith(isSaving: false, isSuccess: true, createdExpense: expense));
      return expense;
    } on Failure catch (e) {
      emit(state.copyWith(isSaving: false, errorMessage: e.message));
      return null;
    } catch (_) {
      emit(state.copyWith(isSaving: false, errorMessage: 'حدث خطأ أثناء حفظ المصروف'));
      return null;
    }
  }
}
