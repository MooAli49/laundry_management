import '../../../../domain/entities/order_item.dart';
import '../../../../domain/entities/storage_location.dart';
import '../../../../domain/entities/storage_record.dart';

class StorageItemQueryResult {
  final OrderItem orderItem;
  final StorageRecord storageRecord;
  final StorageLocation storageLocation;

  const StorageItemQueryResult({
    required this.orderItem,
    required this.storageRecord,
    required this.storageLocation,
  });
}
