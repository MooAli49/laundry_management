import '../../core/errors/failures.dart';
import '../../domain/entities/order.dart';
import '../../domain/enums/order_status.dart';
import '../../domain/repositories/order_repository.dart';

class CancelOrderInput {
  final String orderId;
  final String cancellationReason;
  final bool confirmed;

  const CancelOrderInput({
    required this.orderId,
    required this.cancellationReason,
    this.confirmed = false,
  });
}

class CancelOrderUseCase {
  final OrderRepository _orderRepository;

  CancelOrderUseCase(this._orderRepository);

  Future<Order> execute(CancelOrderInput input) async {
    if (!input.confirmed) {
      throw const ValidationFailure('Cancellation must be explicitly confirmed');
    }

    final trimmedReason = input.cancellationReason.trim();
    if (trimmedReason.isEmpty) {
      throw const ValidationFailure('Cancellation reason cannot be empty');
    }

    final order = await _orderRepository.getOrderById(input.orderId);
    if (order == null) {
      throw const ValidationFailure('Order not found');
    }
    if (order.status == OrderStatus.completed) {
      throw const BusinessRuleFailure('Cannot cancel an already completed order');
    }
    if (order.status == OrderStatus.cancelled) {
      throw const BusinessRuleFailure('Order is already cancelled');
    }

    return await _orderRepository.cancelOrder(
      orderId: input.orderId,
      cancellationReason: trimmedReason,
    );
  }
}
