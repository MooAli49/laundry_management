import '../entities/storage_location.dart';

abstract class StorageLocationRepository {
  Future<StorageLocation> createStorageLocation(
    StorageLocation location, {
    required List<String> supportedItemTypeIds,
  });

  Future<StorageLocation> updateStorageLocation(
    StorageLocation location, {
    List<String>? supportedItemTypeIds,
  });

  Future<StorageLocation?> getStorageLocationById(String id);
  Future<List<StorageLocation>> getActiveLocations();
  Future<List<StorageLocation>> getAllLocations();
  Future<List<StorageLocation>> getCompatibleLocationsForItemType(String itemTypeId);
  Future<void> activateStorageLocation(String id);
  Future<void> deactivateStorageLocation(String id);
}
