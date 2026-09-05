import 'package:drift/drift.dart';

import '../database/app_database.dart' as app_db;

class BusinessSettingsDao extends DatabaseAccessor<app_db.AppDatabase> {
  BusinessSettingsDao(super.attachedDatabase);

  app_db.AppDatabase get db => attachedDatabase;

  static const String defaultId = '00000000-0000-0000-0000-000000000001';

  Future<app_db.BusinessSetting> getSettings() async {
    final existing = await (select(db.businessSettings)..limit(1)).getSingleOrNull();
    if (existing != null) {
      return existing;
    }
    // Fallback if not yet seeded
    final now = DateTime.now();
    final companion = app_db.BusinessSettingsCompanion(
      id: const Value(defaultId),
      businessName: const Value(''),
      taxEnabled: const Value(false),
      taxRate: const Value(0.0),
      createdAt: Value(now),
      updatedAt: Value(now),
    );
    await into(db.businessSettings).insert(companion);
    return (await (select(db.businessSettings)..limit(1)).getSingle());
  }

  Future<void> updateSettings(app_db.BusinessSettingsCompanion companion) async {
    await (update(db.businessSettings)..where((t) => t.id.equals(companion.id.value))).write(companion);
  }

  Stream<app_db.BusinessSetting> watchSettings() {
    return (select(db.businessSettings)..limit(1)).watchSingle();
  }
}
