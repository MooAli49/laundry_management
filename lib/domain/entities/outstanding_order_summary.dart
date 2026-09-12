import '../value_objects/money.dart';

class OutstandingOrderSummary {
  final String orderId;
  final String orderNumber;
  final DateTime createdAt;
  final String customerName;
  final String customerPhone;
  final Money totalAmount;
  final Money paidAmount;
  final Money remainingAmount;

  const OutstandingOrderSummary({
    required this.orderId,
    required this.orderNumber,
    required this.createdAt,
    required this.customerName,
    required this.customerPhone,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
  });
}
