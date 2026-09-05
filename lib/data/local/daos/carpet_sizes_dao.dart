import 'package:drift/drift.dart';

import '../database/app_database.dart' as app_db;

class CarpetSizesDao extends DatabaseAccessor<app_db.AppDatabase> {
  CarpetSizesDao(super.attachedDatabase);

  app_db.AppDatabase get db => attachedDatabase;

  Future<void> insertCarpetSize(app_db.CarpetSizesCompanion companion) async {
    await into(db.carpetSizes).insert(companion);
  }

  Future<void> updateCarpetSize(app_db.CarpetSizesCompanion companion) async {
    await (update(db.carpetSizes)..where((t) => t.id.equals(companion.id.value))).write(companion);
  }

  Future<app_db.CarpetSize?> getCarpetSizeById(String id) async {
    return (select(db.carpetSizes)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<app_db.CarpetSize>> getActiveCarpetSizes() async {
    return (select(db.carpetSizes)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.area)]))
        .get();
  }

  Future<List<app_db.CarpetSize>> getAllCarpetSizes() async {
    return (select(db.carpetSizes)..orderBy([(t) => OrderingTerm.asc(t.area)])).get();
  }

  Future<void> setActiveStatus(String id, bool isActive, DateTime updatedAt) async {
    await (update(db.carpetSizes)..where((t) => t.id.equals(id))).write(
      app_db.CarpetSizesCompanion(
        isActive: Value(isActive),
        updatedAt: Value(updatedAt),
      ),
    );
  }
}
