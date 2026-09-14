import '../entities/order_item.dart';
import '../entities/storage_item.dart';
import '../entities/storage_record.dart';
import '../value_objects/order_date.dart';

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

  Future<void> unstoreItem(String orderItemId);

  Future<StorageRecord?> getActiveRecordForOrderItem(String orderItemId);

  Future<List<StorageRecord>> getActiveRecordsForLocation(String storageLocationId);

  Future<List<OrderItem>> getItemsRequiringStorage({int limit = 50, int offset = 0});

  Future<List<StorageItem>> getItemsRequiringStorageWithDetails({
    String? query,
    String? orderId,
    String? itemTypeId,
    String? serviceId,
    OrderDate? expectedPickupDate,
    DateTime? orderReceivedDate,
    int limit = 50,
    int offset = 0,
  });

  Future<int> countItemsRequiringStorage({
    String? query,
    String? orderId,
    String? itemTypeId,
    String? serviceId,
    OrderDate? expectedPickupDate,
    DateTime? orderReceivedDate,
  });

  Future<List<StorageItem>> getCurrentStorageItems({
    String? query,
    String? orderId,
    String? storageLocationId,
    String? itemTypeId,
    String? serviceId,
    OrderDate? expectedPickupDate,
    DateTime? orderReceivedDate,
    int limit = 50,
    int offset = 0,
  });

  Future<int> countCurrentStorageItems({
    String? query,
    String? orderId,
    String? storageLocationId,
    String? itemTypeId,
    String? serviceId,
    OrderDate? expectedPickupDate,
    DateTime? orderReceivedDate,
  });

  Stream<List<StorageRecord>> watchActiveRecordsForLocation(String storageLocationId);

  Future<bool> areAllOrderItemsStored(String orderId);
}
