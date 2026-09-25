import '../value_objects/money.dart';

class OrderPaymentSummary {
  final Money totalPaid;
  final Money remaining;
  final Money totalRefunded;

  const OrderPaymentSummary({
    required this.totalPaid,
    required this.remaining,
    this.totalRefunded = Money.zero,
  });

  static const zero = OrderPaymentSummary(
    totalPaid: Money.zero,
    remaining: Money.zero,
    totalRefunded: Money.zero,
  );
}
