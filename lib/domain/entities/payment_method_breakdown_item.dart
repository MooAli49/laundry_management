import '../enums/payment_method.dart';
import '../value_objects/money.dart';

class PaymentMethodBreakdownItem {
  final PaymentMethod method;
  final Money totalAmount;
  final int count;
  final double percentage;

  const PaymentMethodBreakdownItem({
    required this.method,
    required this.totalAmount,
    required this.count,
    required this.percentage,
  });

  String get arabicName {
    switch (method) {
      case PaymentMethod.cash:
        return 'كاش';
      case PaymentMethod.instapay:
        return 'InstaPay';
      case PaymentMethod.ewallet:
        return 'محفظة إلكترونية';
    }
  }
}
