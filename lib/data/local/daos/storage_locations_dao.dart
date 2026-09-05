import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart' as app_db;

class StorageLocationsDao extends DatabaseAccessor<app_db.AppDatabase> {
  StorageLocationsDao(super.attachedDatabase);

  app_db.AppDatabase get db => attachedDatabase;

  Future<void> insertLocation(app_db.StorageLocationsCompanion companion) async {
    await into(db.storageLocations).insert(companion);
  }

  Future<void> updateLocation(app_db.StorageLocationsCompanion companion) async {
    await (update(db.storageLocations)..where((t) => t.id.equals(companion.id.value))).write(companion);
  }

  Future<app_db.StorageLocation?> getLocationById(String id) async {
    return (select(db.storageLocations)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<app_db.StorageLocation>> getActiveLocations() async {
    return (select(db.storageLocations)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  Future<List<app_db.StorageLocation>> getAllLocations() async {
    return (select(db.storageLocations)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
  }

  Future<void> replaceSupportedItemTypes(
    String storageLocationId,
    List<String> itemTypeIds,
  ) async {
    await (delete(db.storageLocationItemTypes)
          ..where((t) => t.storageLocationId.equals(storageLocationId)))
        .go();

    final now = DateTime.now();
    for (final itemTypeId in itemTypeIds) {
      await into(db.storageLocationItemTypes).insert(
        app_db.StorageLocationItemTypesCompanion(
          id: Value(const Uuid().v4()),
          storageLocationId: Value(storageLocationId),
          itemTypeId: Value(itemTypeId),
          createdAt: Value(now),
        ),
      );
    }
  }

  Future<List<String>> getSupportedItemTypeIds(String storageLocationId) async {
    final query = selectOnly(db.storageLocationItemTypes)
      ..where(db.storageLocationItemTypes.storageLocationId.equals(storageLocationId))
      ..addColumns([db.storageLocationItemTypes.itemTypeId]);
    final rows = await query.get();
    return rows.map((r) => r.read(db.storageLocationItemTypes.itemTypeId)!).toList();
  }

  Future<List<app_db.StorageLocation>> getCompatibleLocationsForItemType(String itemTypeId) async {
    final query = select(db.storageLocations).join([
      innerJoin(
        db.storageLocationItemTypes,
        db.storageLocationItemTypes.storageLocationId.equalsExp(db.storageLocations.id),
      ),
    ])
      ..where(
        db.storageLocations.isActive.equals(true) &
            db.storageLocationItemTypes.itemTypeId.equals(itemTypeId),
      )
      ..orderBy([OrderingTerm.asc(db.storageLocations.name)]);

    final rows = await query.get();
    return rows.map((r) => r.readTable(db.storageLocations)).toList();
  }

  Future<void> setActiveStatus(String id, bool isActive, DateTime updatedAt) async {
    await (update(db.storageLocations)..where((t) => t.id.equals(id))).write(
      app_db.StorageLocationsCompanion(
        isActive: Value(isActive),
        updatedAt: Value(updatedAt),
      ),
    );
  }
}
