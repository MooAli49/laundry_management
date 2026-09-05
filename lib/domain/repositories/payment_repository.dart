import '../entities/payment.dart';
import '../value_objects/money.dart';

abstract class PaymentRepository {
  Future<Payment> recordPayment(Payment payment);
  Future<List<Payment>> getPaymentsForOrder(String orderId);
  Stream<List<Payment>> watchPaymentsForOrder(String orderId);
  Future<Money> getTotalPaidForOrder(String orderId);
  Future<Money> getRemainingAmountForOrder(String orderId);
}
