import '../../core/errors/failures.dart';
import '../../domain/entities/order.dart';
import '../../domain/enums/order_status.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/repositories/payment_repository.dart';
import '../../domain/value_objects/money.dart';

class CompleteOrderInput {
  final String orderId;
  final bool handoverConfirmed;

  const CompleteOrderInput({
    required this.orderId,
    required this.handoverConfirmed,
  });
}

class CompleteOrderUseCase {
  final OrderRepository _orderRepository;
  final PaymentRepository _paymentRepository;

  CompleteOrderUseCase({
    required OrderRepository orderRepository,
    required PaymentRepository paymentRepository,
  })  : _orderRepository = orderRepository,
        _paymentRepository = paymentRepository;

  Future<Order> execute(CompleteOrderInput input) async {
    if (!input.handoverConfirmed) {
      throw const BusinessRuleFailure(
        'Customer handover confirmation is required to complete an order',
      );
    }

    final order = await _orderRepository.getOrderById(input.orderId);
    if (order == null) {
      throw const ValidationFailure('Order not found');
    }
    if (order.status != OrderStatus.ready) {
      throw const BusinessRuleFailure('Only Ready orders can be completed');
    }

    final payments = await _paymentRepository.getPaymentsForOrder(input.orderId);
    var totalPaid = Money.zero;
    for (final payment in payments) {
      totalPaid += payment.amount;
    }

    final remainingAmount = order.total - totalPaid;
    if (remainingAmount > Money.zero) {
      throw OrderNotFullyPaidFailure(
        orderId: input.orderId,
        remainingAmount: remainingAmount.toEgp,
      );
    }

    return await _orderRepository.completeOrder(
      orderId: input.orderId,
      handoverConfirmed: true,
    );
  }
}
