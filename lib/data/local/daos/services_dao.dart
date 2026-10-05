import 'package:drift/drift.dart';

import '../database/app_database.dart' as app_db;

class ServicesDao extends DatabaseAccessor<app_db.AppDatabase> {
  ServicesDao(super.attachedDatabase);

  app_db.AppDatabase get db => attachedDatabase;

  Future<void> insertService(app_db.ServicesCompanion companion) async {
    await into(db.services).insert(companion);
  }

  Future<void> updateService(app_db.ServicesCompanion companion) async {
    await (update(
      db.services,
    )..where((t) => t.id.equals(companion.id.value))).write(companion);
  }

  Future<app_db.Service?> getServiceById(String id) async {
    return (select(
      db.services,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<app_db.Service>> getActiveServices() async {
    return (select(db.services)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  Future<List<app_db.Service>> getAllServices() async {
    return (select(
      db.services,
    )..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
  }

  Future<void> replaceServiceItemTypes(
    String serviceId,
    List<app_db.ServiceItemTypesCompanion> companions,
  ) async {
    final incomingIds = companions.map((c) => c.id.value).toSet();
    await (delete(
      db.serviceItemTypes,
    )..where((t) => t.serviceId.equals(serviceId) & t.id.isNotIn(incomingIds))).go();

    for (final companion in companions) {
      await into(db.serviceItemTypes).insertOnConflictUpdate(companion);
    }
  }

  Future<List<app_db.ServiceItemType>> getServiceItemTypes(
    String serviceId,
  ) async {
    return (select(db.serviceItemTypes)
          ..where((t) => t.serviceId.equals(serviceId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<app_db.ServiceItemType?> getServiceItemType(
    String serviceId,
    String itemTypeId,
  ) async {
    return (select(db.serviceItemTypes)..where(
          (t) =>
              t.serviceId.equals(serviceId) & t.itemTypeId.equals(itemTypeId),
        ))
        .getSingleOrNull();
  }

  Future<List<String>> getSupportedItemTypeIds(String serviceId) async {
    final query = selectOnly(db.serviceItemTypes)
      ..where(db.serviceItemTypes.serviceId.equals(serviceId))
      ..addColumns([db.serviceItemTypes.itemTypeId]);
    final rows = await query.get();
    return rows.map((r) => r.read(db.serviceItemTypes.itemTypeId)!).toList();
  }

  Future<List<({app_db.Service service, app_db.ServiceItemType serviceItemType})>>
  getServicesWithPricingForItemType(String itemTypeId) async {
    final query =
        select(db.services).join([
            innerJoin(
              db.serviceItemTypes,
              db.serviceItemTypes.serviceId.equalsExp(db.services.id),
            ),
          ])
          ..where(
            db.services.isActive.equals(true) &
                db.serviceItemTypes.itemTypeId.equals(itemTypeId),
          )
          ..orderBy([OrderingTerm.asc(db.services.name)]);

    final rows = await query.get();
    return rows
        .map(
          (r) => (
            service: r.readTable(db.services),
            serviceItemType: r.readTable(db.serviceItemTypes),
          ),
        )
        .toList();
  }

  Future<void> setActiveStatus(
    String id,
    bool isActive,
    DateTime updatedAt,
  ) async {
    await (update(db.services)..where((t) => t.id.equals(id))).write(
      app_db.ServicesCompanion(
        isActive: Value(isActive),
        updatedAt: Value(updatedAt),
      ),
    );
  }
}
