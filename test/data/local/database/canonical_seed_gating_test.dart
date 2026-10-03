import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/local/database/app_database.dart';
import 'package:laundry_management/data/local/database/dev_test_data.dart';
import 'package:laundry_management/data/local/database/seed_data.dart';

Future<Map<String, int>> _rowCounts(AppDatabase db) async {
  Future<int> count(String table) async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS c FROM $table')
        .getSingle();
    return row.read<int>('c');
  }

  const tables = [
    'business_settings',
    'item_types',
    'expense_categories',
    'services',
    'service_item_types',
    'carpet_sizes',
    'storage_locations',
    'storage_location_item_types',
    'item_definitions',
    'customers',
    'orders',
    'order_items',
    'payments',
    'refunds',
    'expenses',
    'storage_records',
    'sync_state',
    'sync_operations',
  ];
  return {for (final t in tables) t: await count(t)};
}

void main() {
  group('Canonical seed gating (ENABLE_CANONICAL_SEED)', () {
    test('compile-time flags default to false', () {
      expect(SeedData.isEnabled, isFalse);
      expect(DevTestData.isEnabled, isFalse);
    });

    test('default AppDatabase is completely empty (SeedData not executed)',
        () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final counts = await _rowCounts(db);
      expect(counts.values.every((c) => c == 0), isTrue, reason: '$counts');
    });

    test('explicit opt-in executes canonical seed with zero outbox rows',
        () async {
      final db = AppDatabase(NativeDatabase.memory(), true);
      addTearDown(db.close);

      final counts = await _rowCounts(db);
      expect(counts['business_settings'], 1);
      expect(counts['item_types'], 4);
      expect(counts['expense_categories'], 7);
      expect(counts['services'], 5);
      expect(counts['service_item_types'], 5);
      expect(counts['carpet_sizes'], 3);
      expect(counts['storage_locations'], 5);
      expect(counts['storage_location_item_types'], 9);
      expect(counts['item_definitions'], 10);

      // Never seeded, even when canonical seed is enabled.
      for (final t in [
        'customers',
        'orders',
        'order_items',
        'payments',
        'refunds',
        'expenses',
        'storage_records',
        'sync_operations',
      ]) {
        expect(counts[t], 0, reason: '$t must remain empty');
      }
    });

    test('explicit opt-out stays empty regardless of the compile-time flag',
        () async {
      final db = AppDatabase(NativeDatabase.memory(), false);
      addTearDown(db.close);

      final counts = await _rowCounts(db);
      expect(counts.values.every((c) => c == 0), isTrue, reason: '$counts');
    });

    test('DevTestData is independent: running it does not require or trigger '
        'canonical seed, and creates no outbox rows', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      // Canonical seed is off, so the DB is empty before dev data runs.
      expect((await _rowCounts(db))['item_types'], 0);

      await DevTestData.seedDevData(db);

      final counts = await _rowCounts(db);
      expect(counts['customers'], greaterThan(0));
      expect(counts['sync_operations'], 0);
      // DevTestData seeds its own master data; the canonical seed did not run
      // (no business_settings / sync_state singletons were created by it).
      expect(counts['business_settings'], 0);
      expect(counts['sync_state'], 0);
    });
  });
}
