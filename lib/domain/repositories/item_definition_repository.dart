import '../entities/item_definition.dart';

abstract class ItemDefinitionRepository {
  Future<ItemDefinition> createItemDefinition(ItemDefinition itemDefinition);
  Future<ItemDefinition> updateItemDefinition(ItemDefinition itemDefinition);
  Future<ItemDefinition?> getItemDefinitionById(String id);
  Future<List<ItemDefinition>> getDefinitionsForItemType(
    String itemTypeId, {
    bool activeOnly = true,
  });
  Future<List<ItemDefinition>> getAllDefinitions();
  Future<void> activateItemDefinition(String id);
  Future<void> deactivateItemDefinition(String id);
}
