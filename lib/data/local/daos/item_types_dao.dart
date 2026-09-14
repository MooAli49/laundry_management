import 'package:drift/drift.dart';

import '../database/app_database.dart' as app_db;

class ItemTypesDao extends DatabaseAccessor<app_db.AppDatabase> {
  ItemTypesDao(super.attachedDatabase);

  app_db.AppDatabase get db => attachedDatabase;

  Future<void> insertItemType(app_db.ItemTypesCompanion companion) async {
    await into(db.itemTypes).insert(companion);
  }

  Future<void> updateItemType(app_db.ItemTypesCompanion companion) async {
    await (update(db.itemTypes)..where((t) => t.id.equals(companion.id.value))).write(companion);
  }

  Future<app_db.ItemType?> getItemTypeById(String id) async {
    return (select(db.itemTypes)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<app_db.ItemType>> getActiveItemTypes() async {
    return (select(db.itemTypes)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  Future<List<app_db.ItemType>> getAllItemTypes() async {
    return (select(db.itemTypes)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
  }

  Future<void> setActiveStatus(String id, bool isActive, DateTime updatedAt) async {
    await (update(db.itemTypes)..where((t) => t.id.equals(id))).write(
      app_db.ItemTypesCompanion(
        isActive: Value(isActive),
        updatedAt: Value(updatedAt),
      ),
    );
  }
}
