import '../value_objects/money.dart';

class OrderPaymentSummary {
  final Money totalPaid;
  final Money remaining;

  const OrderPaymentSummary({
    required this.totalPaid,
    required this.remaining,
  });

  static const zero = OrderPaymentSummary(
    totalPaid: Money.zero,
    remaining: Money.zero,
  );
}
