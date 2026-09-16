import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/sync/sync_payload_builder.dart';
import 'package:laundry_management/domain/entities/business_settings.dart';
import 'package:laundry_management/domain/entities/carpet_size.dart';
import 'package:laundry_management/domain/entities/expense.dart';
import 'package:laundry_management/domain/entities/expense_category.dart';
import 'package:laundry_management/domain/entities/item_definition.dart';
import 'package:laundry_management/domain/entities/item_type.dart';
import 'package:laundry_management/domain/entities/storage_location.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';

void main() {
  group('SyncPayloadBuilder — Expense & Expense Category Serialization Tests', () {
    final testCreatedAt = DateTime.utc(2026, 9, 16, 10, 30, 0);
    final testUpdatedAt = DateTime.utc(2026, 9, 16, 11, 45, 0);

    test('buildExpenseCategoryPayload serializes all category fields correctly', () {
      final category = ExpenseCategory(
        id: 'cat-test-101',
        name: 'منظفات',
        isActive: true,
        createdAt: testCreatedAt,
        updatedAt: testUpdatedAt,
      );

      final jsonString = SyncPayloadBuilder.buildExpenseCategoryPayload(category);
      final map = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(map['id'], 'cat-test-101');
      expect(map['name'], 'منظفات');
      expect(map['is_active'], isTrue);
      expect(map['created_at'], '2026-09-16T10:30:00.000Z');
      expect(map['updated_at'], '2026-09-16T11:45:00.000Z');
    });

    test('buildExpenseCategoryUpdatePayload serializes rename and active state', () {
      final category = ExpenseCategory(
        id: 'cat-test-101',
        name: 'منظفات ومعقمات',
        isActive: false,
        createdAt: testCreatedAt,
        updatedAt: testUpdatedAt,
      );

      final jsonString = SyncPayloadBuilder.buildExpenseCategoryUpdatePayload(category);
      final map = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(map.containsKey('id'), isFalse);
      expect(map['name'], 'منظفات ومعقمات');
      expect(map['is_active'], isFalse);
      expect(map['updated_at'], '2026-09-16T11:45:00.000Z');
    });

    test('buildExpenseCategoryStatusPayload serializes activation and deactivation', () {
      final activateJson = SyncPayloadBuilder.buildExpenseCategoryStatusPayload(
        'cat-test-101',
        true,
        updatedAt: testUpdatedAt,
      );
      final activateMap = jsonDecode(activateJson) as Map<String, dynamic>;
      expect(activateMap['id'], 'cat-test-101');
      expect(activateMap['is_active'], isTrue);
      expect(activateMap['updated_at'], '2026-09-16T11:45:00.000Z');

      final deactivateJson = SyncPayloadBuilder.buildExpenseCategoryStatusPayload(
        'cat-test-101',
        false,
        updatedAt: testUpdatedAt,
      );
      final deactivateMap = jsonDecode(deactivateJson) as Map<String, dynamic>;
      expect(deactivateMap['id'], 'cat-test-101');
      expect(deactivateMap['is_active'], isFalse);
      expect(deactivateMap['updated_at'], '2026-09-16T11:45:00.000Z');
    });

    test('buildExpensePayload serializes full expense with custom name and notes', () {
      final expense = Expense(
        id: 'exp-test-201',
        expenseCategoryId: 'cat-test-other',
        amount: const Money.fromPiastres(15000), // 150.00 EGP
        expenseName: 'إصلاح باب المحل',
        expenseDate: OrderDate(2026, 9, 16),
        notes: 'تم الدفع نقدا للنجار',
        categoryNameSnapshot: 'أخرى',
        createdAt: testCreatedAt,
        updatedAt: testUpdatedAt,
      );

      final jsonString = SyncPayloadBuilder.buildExpensePayload(expense);
      final map = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(map['id'], 'exp-test-201');
      expect(map['expense_category_id'], 'cat-test-other');
      expect(map['amount'], 15000); // Integer minor units (piastres)
      expect(map['amount'], isA<int>());
      expect(map['expense_name'], 'إصلاح باب المحل');
      expect(map['expense_date'], '2026-09-16'); // Date-only YYYY-MM-DD
      expect(map['notes'], 'تم الدفع نقدا للنجار');
      expect(map['category_name_snapshot'], 'أخرى');
      expect(map['created_at'], '2026-09-16T10:30:00.000Z');
      expect(map['updated_at'], '2026-09-16T11:45:00.000Z');
    });

    test('buildExpensePayload preserves nulls for optional expense_name and notes', () {
      final expense = Expense(
        id: 'exp-test-202',
        expenseCategoryId: 'cat-test-water',
        amount: const Money.fromPiastres(3550), // 35.50 EGP
        expenseDate: OrderDate(2026, 8, 25),
        categoryNameSnapshot: 'مياه',
        createdAt: testCreatedAt,
        updatedAt: testUpdatedAt,
      );

      final jsonString = SyncPayloadBuilder.buildExpensePayload(expense);
      final map = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(map['id'], 'exp-test-202');
      expect(map['expense_category_id'], 'cat-test-water');
      expect(map['amount'], 3550);
      expect(map['expense_name'], isNull);
      expect(map['expense_date'], '2026-08-25');
      expect(map['notes'], isNull);
      expect(map['category_name_snapshot'], 'مياه');
    });

    test('buildExpenseUpdatePayload serializes only updatable fields', () {
      final expense = Expense(
        id: 'exp-test-203',
        expenseCategoryId: 'cat-test-water',
        amount: const Money.fromPiastres(4200),
        expenseName: 'فاتورة مياه معدلة',
        expenseDate: OrderDate(2026, 9, 1),
        notes: 'تعديل المبلغ بعد المراجعة',
        categoryNameSnapshot: 'مياه',
        createdAt: testCreatedAt,
        updatedAt: testUpdatedAt,
      );

      final jsonString = SyncPayloadBuilder.buildExpenseUpdatePayload(expense);
      final map = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(map.containsKey('id'), isFalse);
      expect(map.containsKey('expense_category_id'), isFalse);
      expect(map.containsKey('category_name_snapshot'), isFalse);
      expect(map.containsKey('created_at'), isFalse);

      expect(map['amount'], 4200);
      expect(map['expense_name'], 'فاتورة مياه معدلة');
      expect(map['expense_date'], '2026-09-01');
      expect(map['notes'], 'تعديل المبلغ بعد المراجعة');
      expect(map['updated_at'], '2026-09-16T11:45:00.000Z');
    });
  });

  group('SyncPayloadBuilder — Master Data Serialization Tests (Step 12)', () {
    final testCreatedAt = DateTime.utc(2026, 9, 16, 10, 0, 0);
    final testUpdatedAt = DateTime.utc(2026, 9, 16, 12, 0, 0);

    test('buildItemTypePayload serializes all item type fields', () {
      final itemType = ItemType(
        id: 'it-001',
        name: 'بطانية',
        isActive: true,
        createdAt: testCreatedAt,
        updatedAt: testUpdatedAt,
      );

      final jsonString = SyncPayloadBuilder.buildItemTypePayload(itemType);
      final map = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(map['id'], 'it-001');
      expect(map['name'], 'بطانية');
      expect(map['is_active'], isTrue);
      expect(map['created_at'], '2026-09-16T10:00:00.000Z');
      expect(map['updated_at'], '2026-09-16T12:00:00.000Z');
    });

    test('buildItemTypeUpdatePayload and buildItemTypeStatusPayload serialize correctly', () {
      final itemType = ItemType(
        id: 'it-001',
        name: 'بطانية صوف',
        isActive: false,
        createdAt: testCreatedAt,
        updatedAt: testUpdatedAt,
      );

      final updateMap = jsonDecode(SyncPayloadBuilder.buildItemTypeUpdatePayload(itemType)) as Map<String, dynamic>;
      expect(updateMap.containsKey('id'), isFalse);
      expect(updateMap['name'], 'بطانية صوف');
      expect(updateMap['is_active'], isFalse);

      final statusMap = jsonDecode(SyncPayloadBuilder.buildItemTypeStatusPayload('it-001', true, updatedAt: testUpdatedAt)) as Map<String, dynamic>;
      expect(statusMap['id'], 'it-001');
      expect(statusMap['is_active'], isTrue);
      expect(statusMap['updated_at'], '2026-09-16T12:00:00.000Z');
    });

    test('buildItemDefinitionPayload and update serialize correctly', () {
      final itemDef = ItemDefinition(
        id: 'idef-001',
        itemTypeId: 'it-001',
        name: 'بطانية نفرين',
        isActive: true,
        createdAt: testCreatedAt,
        updatedAt: testUpdatedAt,
      );

      final map = jsonDecode(SyncPayloadBuilder.buildItemDefinitionPayload(itemDef)) as Map<String, dynamic>;
      expect(map['id'], 'idef-001');
      expect(map['item_type_id'], 'it-001');
      expect(map['name'], 'بطانية نفرين');
      expect(map['is_active'], isTrue);

      final updateMap = jsonDecode(SyncPayloadBuilder.buildItemDefinitionUpdatePayload(itemDef)) as Map<String, dynamic>;
      expect(updateMap.containsKey('id'), isFalse);
      expect(updateMap['item_type_id'], 'it-001');
      expect(updateMap['name'], 'بطانية نفرين');
    });

    test('buildCarpetSizePayload and update serialize dimensions and area correctly', () {
      final carpetSize = CarpetSize(
        id: 'cs-001',
        length: 3.0,
        width: 2.0,
        area: 6.0,
        isActive: true,
        createdAt: testCreatedAt,
        updatedAt: testUpdatedAt,
      );

      final map = jsonDecode(SyncPayloadBuilder.buildCarpetSizePayload(carpetSize)) as Map<String, dynamic>;
      expect(map['id'], 'cs-001');
      expect(map['length'], 3.0);
      expect(map['width'], 2.0);
      expect(map['area'], 6.0);
      expect(map['is_active'], isTrue);

      final updateMap = jsonDecode(SyncPayloadBuilder.buildCarpetSizeUpdatePayload(carpetSize)) as Map<String, dynamic>;
      expect(updateMap.containsKey('id'), isFalse);
      expect(updateMap['length'], 3.0);
      expect(updateMap['width'], 2.0);
      expect(updateMap['area'], 6.0);
    });

    test('buildStorageLocationPayload includes supported_item_type_ids', () {
      final location = StorageLocation(
        id: 'loc-001',
        name: 'رف أ-1',
        isActive: true,
        createdAt: testCreatedAt,
        updatedAt: testUpdatedAt,
      );

      final map = jsonDecode(SyncPayloadBuilder.buildStorageLocationPayload(
        location,
        ['it-001', 'it-002'],
      )) as Map<String, dynamic>;

      expect(map['id'], 'loc-001');
      expect(map['name'], 'رف أ-1');
      expect(map['is_active'], isTrue);
      expect(map['supported_item_type_ids'], ['it-001', 'it-002']);

      final updateMap = jsonDecode(SyncPayloadBuilder.buildStorageLocationUpdatePayload(
        location,
        ['it-003'],
      )) as Map<String, dynamic>;
      expect(updateMap.containsKey('id'), isFalse);
      expect(updateMap['supported_item_type_ids'], ['it-003']);
    });

    test('buildBusinessSettingsPayload serializes singleton settings', () {
      final settings = BusinessSettings(
        id: '00000000-0000-0000-0000-000000000001',
        businessName: 'مغسلة الأمانة الحديثة',
        address: 'شارع الملك فهد',
        phone: '0501234567',
        logoReference: 'assets/logo.png',
        invoiceFooterText: 'شكراً لتعاملكم معنا',
        taxEnabled: true,
        taxRate: 15.0,
        createdAt: testCreatedAt,
        updatedAt: testUpdatedAt,
      );

      final map = jsonDecode(SyncPayloadBuilder.buildBusinessSettingsPayload(settings)) as Map<String, dynamic>;

      expect(map['id'], '00000000-0000-0000-0000-000000000001');
      expect(map['business_name'], 'مغسلة الأمانة الحديثة');
      expect(map['address'], 'شارع الملك فهد');
      expect(map['phone'], '0501234567');
      expect(map['logo_reference'], 'assets/logo.png');
      expect(map['invoice_footer_text'], 'شكراً لتعاملكم معنا');
      expect(map['tax_enabled'], isTrue);
      expect(map['tax_rate'], 15.0);
      expect(map['created_at'], '2026-09-16T10:00:00.000Z');
      expect(map['updated_at'], '2026-09-16T12:00:00.000Z');
    });
  });
}
