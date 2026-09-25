import '../entities/refund.dart';
import '../entities/refund_balance_summary.dart';
import '../value_objects/money.dart';

abstract class RefundRepository {
  /// Records a new refund locally within a database transaction,
  /// validates that the order is cancelled, ensures refund amount does not exceed
  /// remaining refundable balance, and enqueues an outbox operation for sync.
  Future<Refund> createRefund(Refund refund);

  /// Retrieves a refund by its unique ID, or null if not found.
  Future<Refund?> getRefundById(String id);

  /// Retrieves all refunds recorded for a given order, ordered newest first.
  Future<List<Refund>> getRefundsForOrder(String orderId);

  /// Watches all refunds recorded for a given order as a reactive stream.
  Stream<List<Refund>> watchRefundsForOrder(String orderId);

  /// Calculates the total refunded amount for a given order.
  Future<Money> getTotalRefundedForOrder(String orderId);

  /// Calculates the remaining refundable balance (totalPaid - totalRefunded).
  /// Note: Server-side validation remains authoritative.
  Future<Money> getRemainingRefundableForOrder(String orderId);

  /// Retrieves the refundable balance summary (totalPaid, totalRefunded, remainingRefundable).
  /// Note: Server-side validation remains authoritative.
  Future<RefundBalanceSummary> getRefundableBalanceSummary(String orderId);
}
