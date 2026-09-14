import '../entities/item_type.dart';

abstract class ItemTypeRepository {
  Future<ItemType> createItemType(ItemType itemType);
  Future<ItemType> updateItemType(ItemType itemType);
  Future<ItemType?> getItemTypeById(String id);
  Future<List<ItemType>> getActiveItemTypes();
  Future<List<ItemType>> getAllItemTypes();
  Future<void> activateItemType(String id);
  Future<void> deactivateItemType(String id);
}
