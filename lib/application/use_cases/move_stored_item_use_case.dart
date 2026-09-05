import '../../core/errors/failures.dart';
import '../../domain/entities/storage_record.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/repositories/storage_location_repository.dart';
import '../../domain/repositories/storage_repository.dart';

class MoveStoredItemInput {
  final String orderItemId;
  final String newStorageLocationId;

  const MoveStoredItemInput({
    required this.orderItemId,
    required this.newStorageLocationId,
  });
}

class MoveStoredItemUseCase {
  final OrderRepository _orderRepository;
  final StorageRepository _storageRepository;
  final StorageLocationRepository _storageLocationRepository;

  MoveStoredItemUseCase({
    required OrderRepository orderRepository,
    required StorageRepository storageRepository,
    required StorageLocationRepository storageLocationRepository,
  })  : _orderRepository = orderRepository,
        _storageRepository = storageRepository,
        _storageLocationRepository = storageLocationRepository;

  Future<StorageRecord> execute(MoveStoredItemInput input) async {
    if (input.orderItemId.trim().isEmpty) {
      throw const ValidationFailure('Order item id cannot be empty');
    }
    if (input.newStorageLocationId.trim().isEmpty) {
      throw const ValidationFailure('Storage location id cannot be empty');
    }

    final orderItem = await _orderRepository.getOrderItemById(input.orderItemId);
    if (orderItem == null) {
      throw const ValidationFailure('Order item not found');
    }

    final targetLocation = await _storageLocationRepository.getStorageLocationById(
      input.newStorageLocationId,
    );
    if (targetLocation == null) {
      throw const ValidationFailure('New storage location not found');
    }
    if (!targetLocation.isActive) {
      throw const BusinessRuleFailure('Cannot move item to an inactive storage location');
    }

    final compatibleLocations = await _storageLocationRepository.getCompatibleLocationsForItemType(
      orderItem.itemTypeId,
    );
    final isCompatible = compatibleLocations.any((loc) => loc.id == input.newStorageLocationId);
    if (!isCompatible) {
      throw IncompatibleStorageLocationFailure(
        storageLocationId: input.newStorageLocationId,
        itemTypeId: orderItem.itemTypeId,
      );
    }

    final activeRecord = await _storageRepository.getActiveRecordForOrderItem(
      input.orderItemId,
    );
    if (activeRecord == null) {
      throw const BusinessRuleFailure('Item has no active storage location to move from');
    }

    if (activeRecord.storageLocationId == input.newStorageLocationId) {
      return activeRecord;
    }

    return await _storageRepository.moveItem(
      orderItemId: input.orderItemId,
      newStorageLocationId: input.newStorageLocationId,
    );
  }
}
