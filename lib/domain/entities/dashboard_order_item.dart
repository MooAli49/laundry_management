import '../enums/order_status.dart';
import '../value_objects/money.dart';
import 'order.dart';

class DashboardOrderItem {
  final Order order;
  final Money totalPaid;
  final Money remainingAmount;

  const DashboardOrderItem({
    required this.order,
    required this.totalPaid,
    required this.remainingAmount,
  });

  bool get isCancelled => order.status == OrderStatus.cancelled;

  bool get isFullyPaid =>
      !isCancelled && (remainingAmount.isZero || remainingAmount.isNegative);

  String get cancelledFinancialLabel => totalPaid.isPositive
      ? 'المدفوع: ${totalPaid.toEgp.toStringAsFixed(2)} ج.م'
      : 'غير مدفوع';
}
