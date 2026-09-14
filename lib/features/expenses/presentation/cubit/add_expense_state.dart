import '../../../../domain/entities/expense.dart';
import '../../../../domain/entities/expense_category.dart';

class AddExpenseState {
  final bool isLoadingCategories;
  final List<ExpenseCategory> categories;
  final ExpenseCategory? selectedCategory;
  final bool isSaving;
  final bool isSuccess;
  final Expense? createdExpense;
  final String? errorMessage;

  const AddExpenseState({
    this.isLoadingCategories = false,
    this.categories = const [],
    this.selectedCategory,
    this.isSaving = false,
    this.isSuccess = false,
    this.createdExpense,
    this.errorMessage,
  });

  AddExpenseState copyWith({
    bool? isLoadingCategories,
    List<ExpenseCategory>? categories,
    ExpenseCategory? selectedCategory,
    bool? isSaving,
    bool? isSuccess,
    Expense? createdExpense,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return AddExpenseState(
      isLoadingCategories: isLoadingCategories ?? this.isLoadingCategories,
      categories: categories ?? this.categories,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      isSaving: isSaving ?? this.isSaving,
      isSuccess: isSuccess ?? this.isSuccess,
      createdExpense: createdExpense ?? this.createdExpense,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
