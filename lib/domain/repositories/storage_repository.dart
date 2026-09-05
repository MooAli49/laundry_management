import '../entities/order_item.dart';
import '../entities/storage_record.dart';

abstract class StorageRepository {
  Future<StorageRecord> storeItem({
    required String orderItemId,
    required String storageLocationId,
  });

  Future<StorageRecord> moveItem({
    required String orderItemId,
    required String newStorageLocationId,
  });

  Future<void> bulkStoreItems({
    required List<String> orderItemIds,
    required String storageLocationId,
  });

  Future<StorageRecord?> getActiveRecordForOrderItem(String orderItemId);

  Future<List<StorageRecord>> getActiveRecordsForLocation(String storageLocationId);

  Future<List<OrderItem>> getItemsRequiringStorage({int limit = 50, int offset = 0});

  Stream<List<StorageRecord>> watchActiveRecordsForLocation(String storageLocationId);

  Future<bool> areAllOrderItemsStored(String orderId);
}
