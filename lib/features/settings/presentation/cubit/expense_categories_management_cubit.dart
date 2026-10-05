import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../domain/entities/expense_category.dart';
import '../../../../domain/repositories/expense_category_repository.dart';
import 'expense_categories_management_state.dart';

class ExpenseCategoriesManagementCubit
    extends Cubit<ExpenseCategoriesManagementState> {
  final ExpenseCategoryRepository _expenseCategoryRepository;

  ExpenseCategoriesManagementCubit({
    required ExpenseCategoryRepository expenseCategoryRepository,
  }) : _expenseCategoryRepository = expenseCategoryRepository,
       super(const ExpenseCategoriesManagementState());

  void clearMessages() {
    emit(state.copyWith(clearErrorMessage: true, clearSuccessMessage: true));
  }

  Future<void> loadCategories() async {
    emit(
      state.copyWith(
        isLoading: true,
        clearErrorMessage: true,
        clearSuccessMessage: true,
      ),
    );

    try {
      final categories = await _expenseCategoryRepository.getAllCategories();
      emit(state.copyWith(isLoading: false, categories: categories));
    } on Failure catch (f) {
      emit(state.copyWith(isLoading: false, errorMessage: f.message));
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: AppStrings.unexpectedError,
        ),
      );
    }
  }

  Future<bool> createCategory(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      emit(
        state.copyWith(errorMessage: AppStrings.expenseCategoryNameRequired),
      );
      return false;
    }

    emit(
      state.copyWith(
        isActionInProgress: true,
        clearErrorMessage: true,
        clearSuccessMessage: true,
      ),
    );

    try {
      final now = DateTime.now();
      final category = ExpenseCategory(
        id: const Uuid().v4(),
        name: trimmedName,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      await _expenseCategoryRepository.createCategory(category);
      final categories = await _expenseCategoryRepository.getAllCategories();
      emit(state.copyWith(isActionInProgress: false, categories: categories));
      return true;
    } on Failure catch (f) {
      final msg = _normalizeError(f.message);
      emit(state.copyWith(isActionInProgress: false, errorMessage: msg));
      return false;
    } catch (_) {
      emit(
        state.copyWith(
          isActionInProgress: false,
          errorMessage: AppStrings.unexpectedError,
        ),
      );
      return false;
    }
  }

  Future<bool> updateCategory(ExpenseCategory category) async {
    final trimmedName = category.name.trim();
    if (trimmedName.isEmpty) {
      emit(
        state.copyWith(errorMessage: AppStrings.expenseCategoryNameRequired),
      );
      return false;
    }

    emit(
      state.copyWith(
        isActionInProgress: true,
        clearErrorMessage: true,
        clearSuccessMessage: true,
      ),
    );

    try {
      final updated = category.copyWith(
        name: trimmedName,
        updatedAt: DateTime.now(),
      );

      await _expenseCategoryRepository.updateCategory(updated);
      final categories = await _expenseCategoryRepository.getAllCategories();
      emit(state.copyWith(isActionInProgress: false, categories: categories));
      return true;
    } on Failure catch (f) {
      final msg = _normalizeError(f.message);
      emit(state.copyWith(isActionInProgress: false, errorMessage: msg));
      return false;
    } catch (_) {
      emit(
        state.copyWith(
          isActionInProgress: false,
          errorMessage: AppStrings.unexpectedError,
        ),
      );
      return false;
    }
  }

  Future<void> activateCategory(String id) async {
    emit(state.copyWith(isActionInProgress: true));
    try {
      await _expenseCategoryRepository.activateCategory(id);
      final categories = await _expenseCategoryRepository.getAllCategories();
      emit(state.copyWith(isActionInProgress: false, categories: categories));
    } on Failure catch (f) {
      emit(state.copyWith(isActionInProgress: false, errorMessage: f.message));
    } catch (_) {
      emit(
        state.copyWith(
          isActionInProgress: false,
          errorMessage: AppStrings.unexpectedError,
        ),
      );
    }
  }

  Future<void> deactivateCategory(String id) async {
    emit(state.copyWith(isActionInProgress: true));
    try {
      await _expenseCategoryRepository.deactivateCategory(id);
      final categories = await _expenseCategoryRepository.getAllCategories();
      emit(state.copyWith(isActionInProgress: false, categories: categories));
    } on Failure catch (f) {
      emit(state.copyWith(isActionInProgress: false, errorMessage: f.message));
    } catch (_) {
      emit(
        state.copyWith(
          isActionInProgress: false,
          errorMessage: AppStrings.unexpectedError,
        ),
      );
    }
  }

  String _normalizeError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('unique') ||
        lower.contains('constraint') ||
        lower.contains('duplicate')) {
      return AppStrings.duplicateNameError;
    }
    return message;
  }
}
