import 'package:drift/drift.dart';

class SeedData {
  static const String defaultBusinessSettingsId =
      '00000000-0000-0000-0000-000000000001';

  static const List<Map<String, String>> defaultItemTypes = [
    {'id': '00000000-0000-0000-0001-000000000001', 'name': 'ملابس'},
    {'id': '00000000-0000-0000-0001-000000000002', 'name': 'بطاطين'},
    {'id': '00000000-0000-0000-0001-000000000003', 'name': 'سجاد'},
    {'id': '00000000-0000-0000-0001-000000000004', 'name': 'أغطية'},
  ];

  static const List<Map<String, String>> defaultExpenseCategories = [
    {'id': '00000000-0000-0000-0002-000000000001', 'name': 'كهرباء'},
    {'id': '00000000-0000-0000-0002-000000000002', 'name': 'مياه'},
    {'id': '00000000-0000-0000-0002-000000000003', 'name': 'منظفات'},
    {'id': '00000000-0000-0000-0002-000000000004', 'name': 'صيانة'},
    {'id': '00000000-0000-0000-0002-000000000005', 'name': 'مستلزمات'},
    {'id': '00000000-0000-0000-0002-000000000006', 'name': 'نقل'},
    {'id': '00000000-0000-0000-0002-000000000007', 'name': 'أخرى'},
  ];

  static Future<void> seedInitialData(GeneratedDatabase db) async {
    final nowTimestamp = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

    // 1. Seed BusinessSettings (exactly 1 record, idempotent)
    await db.customStatement(
      'INSERT OR IGNORE INTO business_settings '
      '(id, business_name, tax_enabled, tax_rate, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?);',
      [defaultBusinessSettingsId, '', 0, 0.0, nowTimestamp, nowTimestamp],
    );

    // 2. Seed Default ItemTypes (4 types, idempotent)
    for (final itemType in defaultItemTypes) {
      await db.customStatement(
        'INSERT OR IGNORE INTO item_types '
        '(id, name, is_active, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?);',
        [itemType['id'], itemType['name'], 1, nowTimestamp, nowTimestamp],
      );
    }

    // 3. Seed Default ExpenseCategories (7 categories, idempotent)
    for (final category in defaultExpenseCategories) {
      await db.customStatement(
        'INSERT OR IGNORE INTO expense_categories '
        '(id, name, is_active, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?);',
        [category['id'], category['name'], 1, nowTimestamp, nowTimestamp],
      );
    }

    // Explicit Invariant:
    // customers, orders, order_items, payments, expenses, storage_records
    // are NEVER seeded. They remain strictly empty.
  }
}
