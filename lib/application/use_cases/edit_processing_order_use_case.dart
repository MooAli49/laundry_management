import '../../core/errors/failures.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/value_objects/money.dart';
import '../../domain/value_objects/order_date.dart';
import 'create_order_use_case.dart';

class OrderItemEditInput {
  final String id;
  final String? itemDefinitionId;
  final String serviceId;
  final Money? customUnitPrice;
  final String? notes;
  final CarpetItemInput? carpetData;

  const OrderItemEditInput({
    required this.id,
    this.itemDefinitionId,
    required this.serviceId,
    this.customUnitPrice,
    this.notes,
    this.carpetData,
  });
}

class EditProcessingOrderInput {
  final String orderId;
  final String customerId;
  final OrderDate expectedPickupDate;
  final String? notes;
  final bool customerPickupRequested;
  final Money customerPickupFee;
  final bool customerDeliveryRequested;
  final Money customerDeliveryFee;
  final Money discount;
  final List<OrderItemEditInput> modifiedItems;
  final List<String> deletedItemIds;
  final List<CreateOrderItemInput> newItems;

  const EditProcessingOrderInput({
    required this.orderId,
    required this.customerId,
    required this.expectedPickupDate,
    this.notes,
    this.customerPickupRequested = false,
    this.customerPickupFee = Money.zero,
    this.customerDeliveryRequested = false,
    this.customerDeliveryFee = Money.zero,
    this.discount = Money.zero,
    this.modifiedItems = const [],
    this.deletedItemIds = const [],
    this.newItems = const [],
  });
}

class EditProcessingOrderUseCase {
  final OrderRepository _orderRepository;

  EditProcessingOrderUseCase({
    required OrderRepository orderRepository,
  }) : _orderRepository = orderRepository;

  Future<Order> execute(EditProcessingOrderInput input) async {
    if (input.orderId.trim().isEmpty) {
      throw const ValidationFailure('Order ID cannot be empty');
    }
    if (input.customerId.trim().isEmpty) {
      throw const ValidationFailure('Customer ID cannot be empty');
    }

    final existingOrder = await _orderRepository.getOrderById(input.orderId);
    if (existingOrder == null) {
      throw const ValidationFailure('Order not found');
    }

    // Only validate date is not in past if it was changed
    if (input.expectedPickupDate != existingOrder.expectedPickupDate &&
        input.expectedPickupDate.isBeforeToday) {
      throw const ValidationFailure(
        'Expected pickup date cannot be in the past',
      );
    }

    if (input.customerPickupFee.isNegative) {
      throw const ValidationFailure('Pickup fee cannot be negative');
    }
    if (input.customerDeliveryFee.isNegative) {
      throw const ValidationFailure('Delivery fee cannot be negative');
    }
    if (!input.customerPickupRequested &&
        input.customerPickupFee > Money.zero) {
      throw const ValidationFailure(
        'Pickup fee must be zero when pickup is not requested',
      );
    }
    if (!input.customerDeliveryRequested &&
        input.customerDeliveryFee > Money.zero) {
      throw const ValidationFailure(
        'Delivery fee must be zero when delivery is not requested',
      );
    }
    if (input.discount.isNegative) {
      throw const ValidationFailure('Discount cannot be negative');
    }

    return await _orderRepository.editProcessingOrder(input);
  }
}
