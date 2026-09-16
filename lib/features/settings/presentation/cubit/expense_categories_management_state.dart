import '../../../../domain/entities/expense_category.dart';

class ExpenseCategoriesManagementState {
  final List<ExpenseCategory> categories;
  final bool isLoading;
  final bool isActionInProgress;
  final String? errorMessage;
  final String? actionSuccessMessage;

  const ExpenseCategoriesManagementState({
    this.categories = const [],
    this.isLoading = false,
    this.isActionInProgress = false,
    this.errorMessage,
    this.actionSuccessMessage,
  });

  ExpenseCategoriesManagementState copyWith({
    List<ExpenseCategory>? categories,
    bool? isLoading,
    bool? isActionInProgress,
    String? errorMessage,
    String? actionSuccessMessage,
    bool clearErrorMessage = false,
    bool clearSuccessMessage = false,
  }) {
    return ExpenseCategoriesManagementState(
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      isActionInProgress: isActionInProgress ?? this.isActionInProgress,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      actionSuccessMessage: clearSuccessMessage
          ? null
          : (actionSuccessMessage ?? this.actionSuccessMessage),
    );
  }
}
