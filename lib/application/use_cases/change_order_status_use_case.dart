import '../../core/errors/failures.dart';
import '../../domain/entities/order.dart';
import '../../domain/enums/order_status.dart';
import '../../domain/repositories/order_repository.dart';

class ChangeOrderStatusInput {
  final String orderId;
  final OrderStatus newStatus;
  final String? reason;

  const ChangeOrderStatusInput({
    required this.orderId,
    required this.newStatus,
    this.reason,
  });
}

class ChangeOrderStatusUseCase {
  final OrderRepository _orderRepository;

  ChangeOrderStatusUseCase(this._orderRepository);

  Future<Order> execute(ChangeOrderStatusInput input) async {
    final order = await _orderRepository.getOrderById(input.orderId);
    if (order == null) {
      throw const ValidationFailure('Order not found');
    }

    if (order.status == input.newStatus) {
      return order;
    }

    switch (order.status) {
      case OrderStatus.processing:
        if (input.newStatus == OrderStatus.ready) {
          if (input.reason == null || input.reason!.trim().isEmpty) {
            throw const ValidationFailure(
              'Manual transition to Ready requires a non-empty reason',
            );
          }
          return await _orderRepository.correctOrderStatus(
            orderId: input.orderId,
            newStatus: OrderStatus.ready,
            reason: input.reason!.trim(),
          );
        } else if (input.newStatus == OrderStatus.cancelled) {
          if (input.reason == null || input.reason!.trim().isEmpty) {
            throw const ValidationFailure('Cancellation reason cannot be empty');
          }
          return await _orderRepository.cancelOrder(
            orderId: input.orderId,
            cancellationReason: input.reason!.trim(),
          );
        } else if (input.newStatus == OrderStatus.completed) {
          throw InvalidOrderTransitionFailure(
            from: order.status.name,
            to: input.newStatus.name,
            message:
                'Cannot transition directly from Processing to Completed. Order must be Ready and verified via CompleteOrderUseCase.',
          );
        }
        break;

      case OrderStatus.ready:
        if (input.newStatus == OrderStatus.processing) {
          return await _orderRepository.correctOrderStatus(
            orderId: input.orderId,
            newStatus: OrderStatus.processing,
            reason: input.reason?.trim(),
          );
        } else if (input.newStatus == OrderStatus.cancelled) {
          if (input.reason == null || input.reason!.trim().isEmpty) {
            throw const ValidationFailure('Cancellation reason cannot be empty');
          }
          return await _orderRepository.cancelOrder(
            orderId: input.orderId,
            cancellationReason: input.reason!.trim(),
          );
        } else if (input.newStatus == OrderStatus.completed) {
          throw InvalidOrderTransitionFailure(
            from: order.status.name,
            to: input.newStatus.name,
            message:
                'Completion requires payment and handover verification. Use CompleteOrderUseCase.',
          );
        }
        break;

      case OrderStatus.completed:
        if (input.newStatus == OrderStatus.processing) {
          if (input.reason == null || input.reason!.trim().isEmpty) {
            throw const ValidationFailure(
              'Correction from Completed back to Processing requires a non-empty reason',
            );
          }
          return await _orderRepository.correctOrderStatus(
            orderId: input.orderId,
            newStatus: OrderStatus.processing,
            reason: input.reason!.trim(),
          );
        } else if (input.newStatus == OrderStatus.ready ||
            input.newStatus == OrderStatus.cancelled) {
          throw InvalidOrderTransitionFailure(
            from: order.status.name,
            to: input.newStatus.name,
            message:
                'Completed orders cannot transition to ${input.newStatus.name}',
          );
        }
        break;

      case OrderStatus.cancelled:
        throw InvalidOrderTransitionFailure(
          from: order.status.name,
          to: input.newStatus.name,
          message:
              'Cancelled orders cannot be transitioned to any other status in V1',
        );
    }

    throw InvalidOrderTransitionFailure(
      from: order.status.name,
      to: input.newStatus.name,
    );
  }
}
