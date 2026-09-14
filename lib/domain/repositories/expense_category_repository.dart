import '../entities/expense_category.dart';

abstract class ExpenseCategoryRepository {
  Future<ExpenseCategory> createCategory(ExpenseCategory category);
  Future<ExpenseCategory> updateCategory(ExpenseCategory category);
  Future<ExpenseCategory?> getCategoryById(String id);
  Future<List<ExpenseCategory>> getActiveCategories();
  Future<List<ExpenseCategory>> getAllCategories();
  Future<void> activateCategory(String id);
  Future<void> deactivateCategory(String id);
}
