import '../value_objects/money.dart';

class RefundBalanceSummary {
  final Money totalPaid;
  final Money totalRefunded;
  final Money remainingRefundable;

  const RefundBalanceSummary({
    required this.totalPaid,
    required this.totalRefunded,
    required this.remainingRefundable,
  });

  static const zero = RefundBalanceSummary(
    totalPaid: Money.zero,
    totalRefunded: Money.zero,
    remainingRefundable: Money.zero,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RefundBalanceSummary &&
          runtimeType == other.runtimeType &&
          totalPaid == other.totalPaid &&
          totalRefunded == other.totalRefunded &&
          remainingRefundable == other.remainingRefundable;

  @override
  int get hashCode => Object.hash(
        totalPaid,
        totalRefunded,
        remainingRefundable,
      );

  @override
  String toString() =>
      'RefundBalanceSummary(totalPaid: $totalPaid, totalRefunded: $totalRefunded, remainingRefundable: $remainingRefundable)';
}
