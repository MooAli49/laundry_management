import 'package:drift/drift.dart';

import '../database/app_database.dart' as app_db;

class ItemDefinitionsDao extends DatabaseAccessor<app_db.AppDatabase> {
  ItemDefinitionsDao(super.attachedDatabase);

  app_db.AppDatabase get db => attachedDatabase;

  Future<void> insertItemDefinition(app_db.ItemDefinitionsCompanion companion) async {
    await into(db.itemDefinitions).insert(companion);
  }

  Future<void> updateItemDefinition(app_db.ItemDefinitionsCompanion companion) async {
    await (update(db.itemDefinitions)..where((t) => t.id.equals(companion.id.value))).write(companion);
  }

  Future<app_db.ItemDefinition?> getItemDefinitionById(String id) async {
    return (select(db.itemDefinitions)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<app_db.ItemDefinition>> getDefinitionsForItemType(
    String itemTypeId, {
    bool activeOnly = true,
  }) async {
    final query = select(db.itemDefinitions)
      ..where((t) => t.itemTypeId.equals(itemTypeId));
    if (activeOnly) {
      query.where((t) => t.isActive.equals(true));
    }
    query.orderBy([(t) => OrderingTerm.asc(t.name)]);
    return query.get();
  }

  Future<List<app_db.ItemDefinition>> getAllDefinitions() async {
    return (select(db.itemDefinitions)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
  }

  Future<void> setActiveStatus(String id, bool isActive, DateTime updatedAt) async {
    await (update(db.itemDefinitions)..where((t) => t.id.equals(id))).write(
      app_db.ItemDefinitionsCompanion(
        isActive: Value(isActive),
        updatedAt: Value(updatedAt),
      ),
    );
  }
}
