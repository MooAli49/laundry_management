import '../../core/errors/failures.dart';
import '../../domain/entities/order.dart';
import '../../domain/enums/order_status.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/repositories/storage_location_repository.dart';
import '../../domain/repositories/storage_repository.dart';

class StoreOrderItemsInput {
  final String orderId;
  final List<String> orderItemIds;
  final String storageLocationId;

  const StoreOrderItemsInput({
    required this.orderId,
    required this.orderItemIds,
    required this.storageLocationId,
  });
}

class StoreOrderItemsResult {
  final Order order;
  final bool allStored;

  const StoreOrderItemsResult({
    required this.order,
    required this.allStored,
  });
}

class StoreOrderItemsUseCase {
  final OrderRepository _orderRepository;
  final StorageRepository _storageRepository;
  final StorageLocationRepository _storageLocationRepository;

  StoreOrderItemsUseCase({
    required OrderRepository orderRepository,
    required StorageRepository storageRepository,
    required StorageLocationRepository storageLocationRepository,
  })  : _orderRepository = orderRepository,
        _storageRepository = storageRepository,
        _storageLocationRepository = storageLocationRepository;

  Future<StoreOrderItemsResult> execute(StoreOrderItemsInput input) async {
    if (input.orderItemIds.isEmpty) {
      throw const ValidationFailure('Item list cannot be empty');
    }

    final uniqueItemIds = input.orderItemIds.toSet();
    if (uniqueItemIds.length != input.orderItemIds.length) {
      throw const ValidationFailure('Duplicate item IDs are not allowed in storage request');
    }

    final order = await _orderRepository.getOrderById(input.orderId);
    if (order == null) {
      throw const ValidationFailure('Order not found');
    }
    if (order.status != OrderStatus.processing) {
      throw const BusinessRuleFailure('Only processing orders can store items');
    }

    final location = await _storageLocationRepository.getStorageLocationById(input.storageLocationId);
    if (location == null) {
      throw const ValidationFailure('Storage location not found');
    }
    if (!location.isActive) {
      throw const BusinessRuleFailure('Storage location is inactive');
    }

    final orderItems = await _orderRepository.getOrderItems(input.orderId);
    final orderItemMap = {for (final item in orderItems) item.id: item};

    for (final itemId in input.orderItemIds) {
      final item = orderItemMap[itemId];
      if (item == null) {
        throw BusinessRuleFailure('Item $itemId does not belong to order ${input.orderId}');
      }

      final compatibleLocations = await _storageLocationRepository.getCompatibleLocationsForItemType(
        item.itemTypeId,
      );
      final isCompatible = compatibleLocations.any((loc) => loc.id == input.storageLocationId);
      if (!isCompatible) {
        throw IncompatibleStorageLocationFailure(
          storageLocationId: input.storageLocationId,
          itemTypeId: item.itemTypeId,
        );
      }
    }

    await _storageRepository.bulkStoreItems(
      orderItemIds: input.orderItemIds,
      storageLocationId: input.storageLocationId,
    );

    final allStored = await _storageRepository.areAllOrderItemsStored(input.orderId);
    Order finalOrder = order;

    if (allStored) {
      finalOrder = await _orderRepository.markOrderReady(input.orderId);
    }

    return StoreOrderItemsResult(
      order: finalOrder,
      allStored: allStored,
    );
  }
}
