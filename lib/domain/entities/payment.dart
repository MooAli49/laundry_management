import '../enums/payment_method.dart';
import '../value_objects/money.dart';

class Payment {
  final String id;
  final String orderId;
  final Money amount;
  final PaymentMethod paymentMethod;
  final DateTime paidAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Payment({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.paymentMethod,
    required this.paidAt,
    required this.createdAt,
    required this.updatedAt,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('Payment id cannot be empty');
    }
    if (orderId.trim().isEmpty) {
      throw ArgumentError('Payment orderId cannot be empty');
    }
    if (!amount.isPositive) {
      throw ArgumentError.value(amount, 'amount', 'Payment amount must be greater than 0');
    }
  }

  Payment copyWith({
    String? id,
    String? orderId,
    Money? amount,
    PaymentMethod? paymentMethod,
    DateTime? paidAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Payment(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paidAt: paidAt ?? this.paidAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Payment &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          orderId == other.orderId &&
          amount == other.amount &&
          paymentMethod == other.paymentMethod &&
          paidAt == other.paidAt &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(id, orderId, amount, paymentMethod, paidAt, createdAt, updatedAt);

  @override
  String toString() => 'Payment(id: $id, orderId: $orderId, amount: $amount, method: $paymentMethod)';
}
