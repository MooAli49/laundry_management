import '../../../../domain/entities/customer.dart';
import '../../../../domain/entities/order.dart';
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

  bool get isFullyPaid => remainingAmount.isZero || remainingAmount.isNegative;
  bool get isOverdue => order.isOverdue;
}
