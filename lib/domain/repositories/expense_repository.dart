import '../entities/expense.dart';
import '../value_objects/money.dart';
import '../value_objects/order_date.dart';

abstract class ExpenseRepository {
  Future<Expense> createExpense(Expense expense);
  Future<Expense> updateExpense(Expense expense);
  Future<Expense?> getExpenseById(String id);
  Future<List<Expense>> getExpenses({
    OrderDate? startDate,
    OrderDate? endDate,
    String? categoryId,
    int limit = 50,
    int offset = 0,
  });
  Stream<List<Expense>> watchExpensesForDate(OrderDate date);
  Future<Money> getTotalExpenses({
    required OrderDate startDate,
    required OrderDate endDate,
  });
  Future<Map<String, Money>> getExpensesGroupedByCategory({
    required OrderDate startDate,
    required OrderDate endDate,
  });
}
