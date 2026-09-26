import '../enums/refund_method.dart';
import '../value_objects/money.dart';

class Refund {
  final String id;
  final String orderId;
  final Money amount;
  final RefundMethod refundMethod;
  final String? reason;
  final DateTime refundedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Refund({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.refundMethod,
    this.reason,
    required this.refundedAt,
    required this.createdAt,
    required this.updatedAt,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('Refund id cannot be empty');
    }
    if (orderId.trim().isEmpty) {
      throw ArgumentError('Refund orderId cannot be empty');
    }
    if (!amount.isPositive) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Refund amount must be greater than 0',
      );
    }
  }

  Refund copyWith({
    String? id,
    String? orderId,
    Money? amount,
    RefundMethod? refundMethod,
    String? reason,
    DateTime? refundedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Refund(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      amount: amount ?? this.amount,
      refundMethod: refundMethod ?? this.refundMethod,
      reason: reason ?? this.reason,
      refundedAt: refundedAt ?? this.refundedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Refund &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          orderId == other.orderId &&
          amount == other.amount &&
          refundMethod == other.refundMethod &&
          reason == other.reason &&
          refundedAt == other.refundedAt &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        orderId,
        amount,
        refundMethod,
        reason,
        refundedAt,
        createdAt,
        updatedAt,
      );

  @override
  String toString() =>
      'Refund(id: $id, orderId: $orderId, amount: $amount, method: $refundMethod, reason: $reason)';
}
