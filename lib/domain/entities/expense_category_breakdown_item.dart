import '../value_objects/money.dart';

class ExpenseCategoryBreakdownItem {
  final String categoryName;
  final Money totalAmount;
  final int count;
  final double percentage;

  const ExpenseCategoryBreakdownItem({
    required this.categoryName,
    required this.totalAmount,
    required this.count,
    required this.percentage,
  });
}
