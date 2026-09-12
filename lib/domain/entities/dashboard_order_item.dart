import 'order.dart';
import '../value_objects/money.dart';

class DashboardOrderItem {
  final Order order;
  final Money totalPaid;
  final Money remainingAmount;

  const DashboardOrderItem({
    required this.order,
    required this.totalPaid,
    required this.remainingAmount,
  });

  bool get isFullyPaid => remainingAmount.isZero || remainingAmount.isNegative;
}
