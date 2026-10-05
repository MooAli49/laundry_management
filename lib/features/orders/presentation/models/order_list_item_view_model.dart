import '../../../../domain/entities/customer.dart';
import '../../../../domain/entities/order.dart';
import '../../../../domain/enums/order_status.dart';
import '../../../../domain/value_objects/money.dart';

class OrderListItemViewModel {
  final Order order;
  final Customer? customer;
  final Money totalPaid;
  final Money remainingAmount;

  const OrderListItemViewModel({
    required this.order,
    this.customer,
    required this.totalPaid,
    required this.remainingAmount,
  });

  bool get isCancelled => order.status == OrderStatus.cancelled;

  /// A cancelled order is a historical record; a zero remaining amount there
  /// does not mean the order was paid, so it is never "fully paid".
  bool get isFullyPaid =>
      !isCancelled && (remainingAmount.isZero || remainingAmount.isNegative);

  /// Neutral financial label for cancelled orders (cancellation stays primary
  /// via the status badge). Never implies "fully paid".
  String get cancelledFinancialLabel => totalPaid.isPositive
      ? 'المدفوع: ${totalPaid.toEgp.toStringAsFixed(2)} ج.م'
      : 'غير مدفوع';

  bool get isOverdue => order.isOverdue;
}
