import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/local/database/app_database.dart';
import 'package:laundry_management/data/local/database/seed_data.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    // In-memory database for fast, isolated testing
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('1. Schema and Table Initialization', () {
    test('all 17 tables exist and schema version is 1', () async {
      expect(db.schemaVersion, equals(1));

      // Query sqlite_master to verify all 17 tables are physically present
      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%';",
          )
          .get();

      final tableNames = tables.map((row) => row.read<String>('name')).toSet();

      final expectedTables = {
        'customers',
        'orders',
        'order_items',
        'order_item_carpets',
        'payments',
        'storage_locations',
        'storage_records',
        'item_types',
        'item_definitions',
        'services',
        'service_item_types',
        'storage_location_item_types',
        'carpet_sizes',
        'expense_categories',
        'expenses',
        'business_settings',
        'sync_operations',
      };

      for (final table in expectedTables) {
        expect(
          tableNames,
          contains(table),
          reason: 'Table $table should exist in the schema',
        );
      }
    });
  });

  group('2. OrderItemCarpet Constraints (Confirmed Decision)', () {
    test(
      'uses independent UUID id as PK and enforces UNIQUE(order_item_id) for 1:0..1 relationship',
      () async {
        final now = DateTime.now();

        // Seed required master data and parent order/order_item
        await db
            .into(db.customers)
            .insert(
              CustomersCompanion.insert(
                id: 'cust-1',
                name: 'عميل اختبار',
                phone: '01011111111',
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.orders)
            .insert(
              OrdersCompanion.insert(
                id: 'order-1',
                orderNumber: '26-001',
                customerId: 'cust-1',
                expectedPickupDate: now,
                subtotal: 10000,
                total: 10000,
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.services)
            .insert(
              ServicesCompanion.insert(
                id: 'serv-1',
                name: 'غسيل سجاد',
                pricingType: 'per_square_meter',
                price: 5000,
                createdAt: now,
                updatedAt: now,
              ),
            );

        // ItemType 'سجاد' was already seeded with id '00000000-0000-0000-0001-000000000003'
        const carpetItemTypeId = '00000000-0000-0000-0001-000000000003';

        await db
            .into(db.orderItems)
            .insert(
              OrderItemsCompanion.insert(
                id: 'item-carpet-1',
                orderId: 'order-1',
                itemTypeId: carpetItemTypeId,
                serviceId: 'serv-1',
                itemTypeNameSnapshot: 'سجاد',
                serviceNameSnapshot: 'غسيل سجاد',
                pricingType: 'per_square_meter',
                quantity: 6.0,
                unitPrice: 5000,
                calculatedTotal: 30000,
                createdAt: now,
                updatedAt: now,
              ),
            );

        // 1. Insert first OrderItemCarpet with independent UUID id
        await db
            .into(db.orderItemCarpets)
            .insert(
              OrderItemCarpetsCompanion.insert(
                id: 'carpet-rec-1',
                orderItemId: 'item-carpet-1',
                length: 3.0,
                width: 2.0,
                area: 6.0,
                createdAt: now,
                updatedAt: now,
              ),
            );

        final retrieved = await (db.select(
          db.orderItemCarpets,
        )..where((t) => t.id.equals('carpet-rec-1'))).getSingle();

        expect(retrieved.id, equals('carpet-rec-1'));
        expect(retrieved.orderItemId, equals('item-carpet-1'));
        expect(retrieved.length, equals(3.0));
        expect(retrieved.width, equals(2.0));
        expect(retrieved.area, equals(6.0));

        // 2. EXPLICIT TEST: Attempting to insert a SECOND OrderItemCarpet referencing
        // the SAME order_item_id MUST fail due to UNIQUE(order_item_id)
        expect(
          () async => await db
              .into(db.orderItemCarpets)
              .insert(
                OrderItemCarpetsCompanion.insert(
                  id: 'carpet-rec-2',
                  orderItemId: 'item-carpet-1', // Duplicate reference!
                  length: 4.0,
                  width: 3.0,
                  area: 12.0,
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
          throwsA(isA<SqliteException>()),
        );
      },
    );
  });

  group('3. Delivery Fields Independence', () {
    test('supports independent pickup and delivery flags and fees', () async {
      final now = DateTime.now();

      await db
          .into(db.customers)
          .insert(
            CustomersCompanion.insert(
              id: 'cust-delivery',
              name: 'عميل توصيل',
              phone: '01022222222',
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Case 1: Both false (false + false)
      await db
          .into(db.orders)
          .insert(
            OrdersCompanion.insert(
              id: 'order-no-delivery',
              orderNumber: '26-002',
              customerId: 'cust-delivery',
              expectedPickupDate: now,
              customerPickupRequested: const Value(false),
              customerPickupFee: const Value(0),
              customerDeliveryRequested: const Value(false),
              customerDeliveryFee: const Value(0),
              subtotal: 5000,
              total: 5000,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Case 2: Pickup only (true + false)
      await db
          .into(db.orders)
          .insert(
            OrdersCompanion.insert(
              id: 'order-pickup-only',
              orderNumber: '26-003',
              customerId: 'cust-delivery',
              expectedPickupDate: now,
              customerPickupRequested: const Value(true),
              customerPickupFee: const Value(2500), // 25.00 EGP
              customerDeliveryRequested: const Value(false),
              customerDeliveryFee: const Value(0),
              subtotal: 5000,
              total: 7500,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Case 3: Delivery only (false + true)
      await db
          .into(db.orders)
          .insert(
            OrdersCompanion.insert(
              id: 'order-delivery-only',
              orderNumber: '26-004',
              customerId: 'cust-delivery',
              expectedPickupDate: now,
              customerPickupRequested: const Value(false),
              customerPickupFee: const Value(0),
              customerDeliveryRequested: const Value(true),
              customerDeliveryFee: const Value(3000), // 30.00 EGP
              subtotal: 5000,
              total: 8000,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Case 4: Both requested (true + true)
      await db
          .into(db.orders)
          .insert(
            OrdersCompanion.insert(
              id: 'order-both-delivery',
              orderNumber: '26-005',
              customerId: 'cust-delivery',
              expectedPickupDate: now,
              customerPickupRequested: const Value(true),
              customerPickupFee: const Value(2500),
              customerDeliveryRequested: const Value(true),
              customerDeliveryFee: const Value(3000),
              subtotal: 5000,
              total: 10500,
              createdAt: now,
              updatedAt: now,
            ),
          );

      final bothOrder = await (db.select(
        db.orders,
      )..where((t) => t.id.equals('order-both-delivery'))).getSingle();

      expect(bothOrder.customerPickupRequested, isTrue);
      expect(bothOrder.customerPickupFee, equals(2500));
      expect(bothOrder.customerDeliveryRequested, isTrue);
      expect(bothOrder.customerDeliveryFee, equals(3000));
      expect(bothOrder.total, equals(10500));
    });
  });

  group('4. BusinessSettings & Tax Rate Precision', () {
    test(
      'stores optional fields and preserves exact decimal tax_rate percentage (14.5) without precision loss',
      () async {
        final now = DateTime.now();

        // Update the seeded BusinessSettings record
        await (db.update(
          db.businessSettings,
        )..where((t) => t.id.equals(SeedData.defaultBusinessSettingsId))).write(
          BusinessSettingsCompanion(
            businessName: const Value('مغسلة النقاء الحديثة'),
            address: const Value('شارع التحرير، القاهرة'),
            phone: const Value('01099999999'),
            logoReference: const Value('assets/images/logo.png'),
            invoiceFooterText: const Value('شكراً لاختياركم مغسلة النقاء'),
            taxEnabled: const Value(true),
            taxRate: const Value(14.5), // 14.5% normal decimal percentage
            updatedAt: Value(now),
          ),
        );

        final settings =
            await (db.select(db.businessSettings)..where(
                  (t) => t.id.equals(SeedData.defaultBusinessSettingsId),
                ))
                .getSingle();

        expect(settings.businessName, equals('مغسلة النقاء الحديثة'));
        expect(settings.address, equals('شارع التحرير، القاهرة'));
        expect(settings.phone, equals('01099999999'));
        expect(settings.logoReference, equals('assets/images/logo.png'));
        expect(
          settings.invoiceFooterText,
          equals('شكراً لاختياركم مغسلة النقاء'),
        );
        expect(settings.taxEnabled, isTrue);

        // EXPLICIT TEST: 14.5 is preserved exactly (not rounded to 14 or multiplied to 1450)
        expect(settings.taxRate, equals(14.5));
      },
    );
  });

  group('5. OrderItem Quantity Precision & Physical Identity', () {
    test(
      'stores exact decimal quantities for kg/sqm and preserves piece rows',
      () async {
        final now = DateTime.now();

        await db
            .into(db.customers)
            .insert(
              CustomersCompanion.insert(
                id: 'cust-qty',
                name: 'عميل أوزان',
                phone: '01033333333',
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.orders)
            .insert(
              OrdersCompanion.insert(
                id: 'order-qty',
                orderNumber: '26-006',
                customerId: 'cust-qty',
                expectedPickupDate: now,
                subtotal: 17500,
                total: 17500,
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.services)
            .insert(
              ServicesCompanion.insert(
                id: 'serv-kg',
                name: 'غسيل بالكيلو',
                pricingType: 'per_kg',
                price: 5000,
                createdAt: now,
                updatedAt: now,
              ),
            );

        // Clothing ItemType id from seed
        const clothingItemTypeId = '00000000-0000-0000-0001-000000000001';

        // Insert item with 3.5 kg decimal quantity
        await db
            .into(db.orderItems)
            .insert(
              OrderItemsCompanion.insert(
                id: 'item-kg-1',
                orderId: 'order-qty',
                itemTypeId: clothingItemTypeId,
                serviceId: 'serv-kg',
                itemTypeNameSnapshot: 'ملابس',
                serviceNameSnapshot: 'غسيل بالكيلو',
                pricingType: 'per_kg',
                quantity: 3.5, // Exact decimal quantity
                unitPrice: 5000,
                calculatedTotal: 17500,
                createdAt: now,
                updatedAt: now,
              ),
            );

        final item = await (db.select(
          db.orderItems,
        )..where((t) => t.id.equals('item-kg-1'))).getSingle();

        expect(item.quantity, equals(3.5));
        expect(item.unitPrice, equals(5000));
        expect(item.calculatedTotal, equals(17500));
      },
    );
  });

  group('6. SQLite Foreign Key Enforcement', () {
    test(
      'enforces foreign key constraints when PRAGMA foreign_keys = ON',
      () async {
        final now = DateTime.now();

        // Order referencing non-existent customer must fail
        expect(
          () async => await db
              .into(db.orders)
              .insert(
                OrdersCompanion.insert(
                  id: 'order-bad-fk',
                  orderNumber: '26-999',
                  customerId: 'non-existent-customer-id',
                  expectedPickupDate: now,
                  subtotal: 1000,
                  total: 1000,
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
          throwsA(isA<SqliteException>()),
        );

        // OrderItem referencing non-existent order must fail
        expect(
          () async => await db
              .into(db.orderItems)
              .insert(
                OrderItemsCompanion.insert(
                  id: 'item-bad-fk',
                  orderId: 'non-existent-order-id',
                  itemTypeId: '00000000-0000-0000-0001-000000000001',
                  serviceId: 'serv-1',
                  itemTypeNameSnapshot: 'ملابس',
                  serviceNameSnapshot: 'غسيل',
                  pricingType: 'per_piece',
                  quantity: 1.0,
                  unitPrice: 1000,
                  calculatedTotal: 1000,
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
          throwsA(isA<SqliteException>()),
        );

        // Payment referencing non-existent order must fail
        expect(
          () async => await db
              .into(db.payments)
              .insert(
                PaymentsCompanion.insert(
                  id: 'pay-bad-fk',
                  orderId: 'non-existent-order-id',
                  amount: 5000,
                  paymentMethod: 'cash',
                  paidAt: now,
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
          throwsA(isA<SqliteException>()),
        );

        // Expense referencing non-existent expense category must fail
        expect(
          () async => await db
              .into(db.expenses)
              .insert(
                ExpensesCompanion.insert(
                  id: 'exp-bad-fk',
                  expenseCategoryId: 'non-existent-cat-id',
                  amount: 1500,
                  expenseDate: now,
                  categoryNameSnapshot: 'غير معروف',
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
          throwsA(isA<SqliteException>()),
        );
      },
    );

    test('ON DELETE RESTRICT blocks deleting customer with orders', () async {
      final now = DateTime.now();

      await db
          .into(db.customers)
          .insert(
            CustomersCompanion.insert(
              id: 'cust-restrict',
              name: 'عميل حماية',
              phone: '01044444444',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db
          .into(db.orders)
          .insert(
            OrdersCompanion.insert(
              id: 'order-restrict',
              orderNumber: '26-007',
              customerId: 'cust-restrict',
              expectedPickupDate: now,
              subtotal: 1000,
              total: 1000,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Attempting to delete customer while order exists must be rejected
      expect(
        () async => await (db.delete(
          db.customers,
        )..where((t) => t.id.equals('cust-restrict'))).go(),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  group('7. Unique Constraints', () {
    test('duplicate customer phone is rejected', () async {
      final now = DateTime.now();

      await db
          .into(db.customers)
          .insert(
            CustomersCompanion.insert(
              id: 'cust-u1',
              name: 'عميل أول',
              phone: '01055555555',
              createdAt: now,
              updatedAt: now,
            ),
          );

      expect(
        () async => await db
            .into(db.customers)
            .insert(
              CustomersCompanion.insert(
                id: 'cust-u2',
                name: 'عميل ثانٍ',
                phone: '01055555555', // Duplicate phone
                createdAt: now,
                updatedAt: now,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('duplicate order number is rejected', () async {
      final now = DateTime.now();

      await db
          .into(db.customers)
          .insert(
            CustomersCompanion.insert(
              id: 'cust-order-u',
              name: 'عميل طلب',
              phone: '01066666666',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db
          .into(db.orders)
          .insert(
            OrdersCompanion.insert(
              id: 'order-u1',
              orderNumber: '26-100',
              customerId: 'cust-order-u',
              expectedPickupDate: now,
              subtotal: 1000,
              total: 1000,
              createdAt: now,
              updatedAt: now,
            ),
          );

      expect(
        () async => await db
            .into(db.orders)
            .insert(
              OrdersCompanion.insert(
                id: 'order-u2',
                orderNumber: '26-100', // Duplicate order number
                customerId: 'cust-order-u',
                expectedPickupDate: now,
                subtotal: 1000,
                total: 1000,
                createdAt: now,
                updatedAt: now,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test(
      'composite UNIQUE(item_type_id, name) in item_definitions is enforced',
      () async {
        final now = DateTime.now();
        const itemTypeId = '00000000-0000-0000-0001-000000000001';

        await db
            .into(db.itemDefinitions)
            .insert(
              ItemDefinitionsCompanion.insert(
                id: 'def-1',
                itemTypeId: itemTypeId,
                name: 'قميص',
                createdAt: now,
                updatedAt: now,
              ),
            );

        // Same name under the same item type must fail
        expect(
          () async => await db
              .into(db.itemDefinitions)
              .insert(
                ItemDefinitionsCompanion.insert(
                  id: 'def-2',
                  itemTypeId: itemTypeId,
                  name: 'قميص',
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
          throwsA(isA<SqliteException>()),
        );
      },
    );
  });

  group('8. Storage Integrity & Partial Unique Index', () {
    test(
      'allows only ONE active StorageRecord per order_item_id (partial unique index)',
      () async {
        final now = DateTime.now();

        await db
            .into(db.customers)
            .insert(
              CustomersCompanion.insert(
                id: 'cust-storage',
                name: 'عميل تخزين',
                phone: '01077777777',
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.orders)
            .insert(
              OrdersCompanion.insert(
                id: 'order-storage',
                orderNumber: '26-200',
                customerId: 'cust-storage',
                expectedPickupDate: now,
                subtotal: 1000,
                total: 1000,
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.services)
            .insert(
              ServicesCompanion.insert(
                id: 'serv-storage',
                name: 'خدمة تخزين',
                pricingType: 'per_piece',
                price: 1000,
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.orderItems)
            .insert(
              OrderItemsCompanion.insert(
                id: 'item-storage-1',
                orderId: 'order-storage',
                itemTypeId: '00000000-0000-0000-0001-000000000001',
                serviceId: 'serv-storage',
                itemTypeNameSnapshot: 'ملابس',
                serviceNameSnapshot: 'خدمة تخزين',
                pricingType: 'per_piece',
                quantity: 1.0,
                unitPrice: 1000,
                calculatedTotal: 1000,
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.storageLocations)
            .insert(
              StorageLocationsCompanion.insert(
                id: 'loc-A1',
                name: 'A-01',
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.storageLocations)
            .insert(
              StorageLocationsCompanion.insert(
                id: 'loc-A2',
                name: 'A-02',
                createdAt: now,
                updatedAt: now,
              ),
            );

        // 1. First active storage record succeeds
        await db
            .into(db.storageRecords)
            .insert(
              StorageRecordsCompanion.insert(
                id: 'st-rec-1',
                orderItemId: 'item-storage-1',
                storageLocationId: 'loc-A1',
                isActive: const Value(true),
                createdAt: now,
                updatedAt: now,
              ),
            );

        // 2. Second ACTIVE record for same item fails due to idx_storage_records_active_item
        expect(
          () async => await db
              .into(db.storageRecords)
              .insert(
                StorageRecordsCompanion.insert(
                  id: 'st-rec-2',
                  orderItemId: 'item-storage-1',
                  storageLocationId: 'loc-A2',
                  isActive: const Value(true), // Active duplicate!
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
          throwsA(isA<SqliteException>()),
        );

        // 3. Deactivate first record
        await (db.update(
          db.storageRecords,
        )..where((t) => t.id.equals('st-rec-1'))).write(
          StorageRecordsCompanion(
            isActive: const Value(false),
            updatedAt: Value(now),
          ),
        );

        // 4. Now inserting a new active record succeeds
        await db
            .into(db.storageRecords)
            .insert(
              StorageRecordsCompanion.insert(
                id: 'st-rec-3',
                orderItemId: 'item-storage-1',
                storageLocationId: 'loc-A2',
                isActive: const Value(true),
                createdAt: now,
                updatedAt: now,
              ),
            );

        final activeCount =
            await (db.select(db.storageRecords)..where(
                  (t) =>
                      t.orderItemId.equals('item-storage-1') &
                      t.isActive.equals(true),
                ))
                .get();

        expect(activeCount.length, equals(1));
        expect(activeCount.first.storageLocationId, equals('loc-A2'));
      },
    );
  });

  group('9. Seed Data Idempotency & Safety', () {
    test(
      'seeds initial settings, 4 item types, and 7 expense categories',
      () async {
        // Check BusinessSettings
        final settings = await db.select(db.businessSettings).get();
        expect(settings.length, equals(1));
        expect(settings.first.id, equals(SeedData.defaultBusinessSettingsId));

        // Check ItemTypes
        final itemTypes = await db.select(db.itemTypes).get();
        expect(itemTypes.length, equals(4));
        final typeNames = itemTypes.map((t) => t.name).toSet();
        expect(typeNames, containsAll({'ملابس', 'بطاطين', 'سجاد', 'أغطية'}));

        // Check ExpenseCategories (7 approved V1 categories)
        final categories = await db.select(db.expenseCategories).get();
        expect(categories.length, equals(7));
        final catNames = categories.map((c) => c.name).toSet();
        expect(
          catNames,
          containsAll({
            'كهرباء',
            'مياه',
            'منظفات',
            'صيانة',
            'مستلزمات',
            'نقل',
            'أخرى',
          }),
        );

        // Invariant: Transactional tables MUST be empty!
        expect((await db.select(db.customers).get()).isEmpty, isTrue);
        expect((await db.select(db.orders).get()).isEmpty, isTrue);
        expect((await db.select(db.orderItems).get()).isEmpty, isTrue);
        expect((await db.select(db.payments).get()).isEmpty, isTrue);
        expect((await db.select(db.expenses).get()).isEmpty, isTrue);
        expect((await db.select(db.storageRecords).get()).isEmpty, isTrue);
      },
    );

    test(
      're-running seed data is idempotent and does not overwrite modifications',
      () async {
        // Modify an expense category name
        await (db.update(db.expenseCategories)..where(
              (t) => t.id.equals('00000000-0000-0000-0002-000000000001'),
            ))
            .write(
              const ExpenseCategoriesCompanion(name: Value('كهرباء وإنارة')),
            );

        // Deactivate another category
        await (db.update(db.expenseCategories)..where(
              (t) => t.id.equals('00000000-0000-0000-0002-000000000002'),
            ))
            .write(const ExpenseCategoriesCompanion(isActive: Value(false)));

        // Re-run seed method
        await SeedData.seedInitialData(db);

        // Category count should remain 7 (no duplicate rows inserted)
        final categories = await db.select(db.expenseCategories).get();
        expect(categories.length, equals(7));

        // User modified name must NOT be overwritten
        final cat1 = categories.firstWhere(
          (c) => c.id == '00000000-0000-0000-0002-000000000001',
        );
        expect(cat1.name, equals('كهرباء وإنارة'));

        // User deactivated state must NOT be overwritten
        final cat2 = categories.firstWhere(
          (c) => c.id == '00000000-0000-0000-0002-000000000002',
        );
        expect(cat2.isActive, isFalse);
      },
    );
  });

  group('10. SQLite CHECK Constraints Enforcement', () {
    test('rejects negative monetary values on orders', () async {
      final now = DateTime.now();

      await db
          .into(db.customers)
          .insert(
            CustomersCompanion.insert(
              id: 'cust-chk-1',
              name: 'عميل قيود',
              phone: '01088888881',
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Negative subtotal must fail SQLite CHECK constraint
      expect(
        () async => await db
            .into(db.orders)
            .insert(
              OrdersCompanion.insert(
                id: 'order-neg-subtotal',
                orderNumber: '26-801',
                customerId: 'cust-chk-1',
                expectedPickupDate: now,
                subtotal: -100, // Invalid!
                total: 0,
                createdAt: now,
                updatedAt: now,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );

      // Negative pickup fee must fail SQLite CHECK constraint
      expect(
        () async => await db
            .into(db.orders)
            .insert(
              OrdersCompanion.insert(
                id: 'order-neg-pickup',
                orderNumber: '26-802',
                customerId: 'cust-chk-1',
                expectedPickupDate: now,
                customerPickupFee: const Value(-500), // Invalid!
                subtotal: 1000,
                total: 1000,
                createdAt: now,
                updatedAt: now,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );

      // Negative delivery fee must fail SQLite CHECK constraint
      expect(
        () async => await db
            .into(db.orders)
            .insert(
              OrdersCompanion.insert(
                id: 'order-neg-deliv',
                orderNumber: '26-803',
                customerId: 'cust-chk-1',
                expectedPickupDate: now,
                customerDeliveryFee: const Value(-500), // Invalid!
                subtotal: 1000,
                total: 1000,
                createdAt: now,
                updatedAt: now,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('rejects negative price on services', () async {
      final now = DateTime.now();

      expect(
        () async => await db
            .into(db.services)
            .insert(
              ServicesCompanion.insert(
                id: 'serv-neg-price',
                name: 'خدمة سالبة',
                pricingType: 'per_piece',
                price: -1000, // Invalid!
                createdAt: now,
                updatedAt: now,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test(
      'rejects zero or negative quantity and negative prices on order_items',
      () async {
        final now = DateTime.now();

        await db
            .into(db.customers)
            .insert(
              CustomersCompanion.insert(
                id: 'cust-chk-2',
                name: 'عميل بنود',
                phone: '01088888882',
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.orders)
            .insert(
              OrdersCompanion.insert(
                id: 'order-chk-2',
                orderNumber: '26-804',
                customerId: 'cust-chk-2',
                expectedPickupDate: now,
                subtotal: 1000,
                total: 1000,
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.services)
            .insert(
              ServicesCompanion.insert(
                id: 'serv-chk-2',
                name: 'خدمة فحص',
                pricingType: 'per_piece',
                price: 1000,
                createdAt: now,
                updatedAt: now,
              ),
            );

        const itemTypeId = '00000000-0000-0000-0001-000000000001';

        // Zero quantity must fail (CHECK quantity > 0)
        expect(
          () async => await db
              .into(db.orderItems)
              .insert(
                OrderItemsCompanion.insert(
                  id: 'item-zero-qty',
                  orderId: 'order-chk-2',
                  itemTypeId: itemTypeId,
                  serviceId: 'serv-chk-2',
                  itemTypeNameSnapshot: 'ملابس',
                  serviceNameSnapshot: 'خدمة فحص',
                  pricingType: 'per_piece',
                  quantity: 0.0, // Invalid!
                  unitPrice: 1000,
                  calculatedTotal: 0,
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
          throwsA(isA<SqliteException>()),
        );

        // Negative quantity must fail
        expect(
          () async => await db
              .into(db.orderItems)
              .insert(
                OrderItemsCompanion.insert(
                  id: 'item-neg-qty',
                  orderId: 'order-chk-2',
                  itemTypeId: itemTypeId,
                  serviceId: 'serv-chk-2',
                  itemTypeNameSnapshot: 'ملابس',
                  serviceNameSnapshot: 'خدمة فحص',
                  pricingType: 'per_piece',
                  quantity: -2.5, // Invalid!
                  unitPrice: 1000,
                  calculatedTotal: 0,
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
          throwsA(isA<SqliteException>()),
        );

        // Negative unitPrice must fail
        expect(
          () async => await db
              .into(db.orderItems)
              .insert(
                OrderItemsCompanion.insert(
                  id: 'item-neg-price',
                  orderId: 'order-chk-2',
                  itemTypeId: itemTypeId,
                  serviceId: 'serv-chk-2',
                  itemTypeNameSnapshot: 'ملابس',
                  serviceNameSnapshot: 'خدمة فحص',
                  pricingType: 'per_piece',
                  quantity: 1.0,
                  unitPrice: -500, // Invalid!
                  calculatedTotal: 0,
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
          throwsA(isA<SqliteException>()),
        );
      },
    );

    test('rejects zero or negative payment amount', () async {
      final now = DateTime.now();

      await db
          .into(db.customers)
          .insert(
            CustomersCompanion.insert(
              id: 'cust-chk-3',
              name: 'عميل دفع',
              phone: '01088888883',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db
          .into(db.orders)
          .insert(
            OrdersCompanion.insert(
              id: 'order-chk-3',
              orderNumber: '26-805',
              customerId: 'cust-chk-3',
              expectedPickupDate: now,
              subtotal: 5000,
              total: 5000,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Zero payment amount must fail (CHECK amount > 0)
      expect(
        () async => await db
            .into(db.payments)
            .insert(
              PaymentsCompanion.insert(
                id: 'pay-zero',
                orderId: 'order-chk-3',
                amount: 0, // Invalid!
                paymentMethod: 'cash',
                paidAt: now,
                createdAt: now,
                updatedAt: now,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );

      // Negative payment amount must fail
      expect(
        () async => await db
            .into(db.payments)
            .insert(
              PaymentsCompanion.insert(
                id: 'pay-neg',
                orderId: 'order-chk-3',
                amount: -1000, // Invalid!
                paymentMethod: 'cash',
                paidAt: now,
                createdAt: now,
                updatedAt: now,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('rejects zero or negative expense amount', () async {
      final now = DateTime.now();
      const catId = '00000000-0000-0000-0002-000000000001';

      // Zero expense amount must fail (CHECK amount > 0)
      expect(
        () async => await db
            .into(db.expenses)
            .insert(
              ExpensesCompanion.insert(
                id: 'exp-zero',
                expenseCategoryId: catId,
                amount: 0, // Invalid!
                expenseDate: now,
                categoryNameSnapshot: 'كهرباء',
                createdAt: now,
                updatedAt: now,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );

      // Negative expense amount must fail
      expect(
        () async => await db
            .into(db.expenses)
            .insert(
              ExpensesCompanion.insert(
                id: 'exp-neg',
                expenseCategoryId: catId,
                amount: -500, // Invalid!
                expenseDate: now,
                categoryNameSnapshot: 'كهرباء',
                createdAt: now,
                updatedAt: now,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('rejects zero or negative carpet dimensions', () async {
      final now = DateTime.now();

      // Zero dimension in CarpetSizes must fail
      expect(
        () async => await db
            .into(db.carpetSizes)
            .insert(
              CarpetSizesCompanion.insert(
                id: 'cs-zero',
                length: 0.0, // Invalid!
                width: 2.0,
                area: 0.0,
                createdAt: now,
                updatedAt: now,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );

      // Negative dimension in CarpetSizes must fail
      expect(
        () async => await db
            .into(db.carpetSizes)
            .insert(
              CarpetSizesCompanion.insert(
                id: 'cs-neg',
                length: 3.0,
                width: -2.0, // Invalid!
                area: 6.0,
                createdAt: now,
                updatedAt: now,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('rejects negative tax_rate in business_settings', () async {
      expect(
        () async =>
            await (db.update(db.businessSettings)..where(
                  (t) => t.id.equals(SeedData.defaultBusinessSettingsId),
                ))
                .write(
                  const BusinessSettingsCompanion(
                    taxRate: Value(-5.0), // Invalid!
                  ),
                ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('rejects negative retry_count in sync_operations', () async {
      final now = DateTime.now();

      expect(
        () async => await db
            .into(db.syncOperations)
            .insert(
              SyncOperationsCompanion.insert(
                id: 'sync-neg-retry',
                entityType: 'Order',
                entityId: 'ord-1',
                operationType: 'create',
                retryCount: const Value(-1), // Invalid!
                createdAt: now,
                updatedAt: now,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  group('11. ON DELETE SET NULL Behaviors', () {
    test(
      'deleting ItemDefinition sets order_items.item_definition_id to NULL and preserves snapshot',
      () async {
        final now = DateTime.now();
        const itemTypeId = '00000000-0000-0000-0001-000000000001';

        await db
            .into(db.itemDefinitions)
            .insert(
              ItemDefinitionsCompanion.insert(
                id: 'def-setnull-1',
                itemTypeId: itemTypeId,
                name: 'بدلة رجالي',
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.customers)
            .insert(
              CustomersCompanion.insert(
                id: 'cust-setnull-1',
                name: 'عميل حذف مراجع',
                phone: '01088888884',
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.orders)
            .insert(
              OrdersCompanion.insert(
                id: 'order-setnull-1',
                orderNumber: '26-806',
                customerId: 'cust-setnull-1',
                expectedPickupDate: now,
                subtotal: 15000,
                total: 15000,
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.services)
            .insert(
              ServicesCompanion.insert(
                id: 'serv-setnull-1',
                name: 'غسيل بدلة',
                pricingType: 'per_piece',
                price: 15000,
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.orderItems)
            .insert(
              OrderItemsCompanion.insert(
                id: 'item-setnull-1',
                orderId: 'order-setnull-1',
                itemTypeId: itemTypeId,
                itemDefinitionId: const Value('def-setnull-1'),
                serviceId: 'serv-setnull-1',
                itemTypeNameSnapshot: 'ملابس',
                itemDefinitionNameSnapshot: const Value('بدلة رجالي'),
                serviceNameSnapshot: 'غسيل بدلة',
                pricingType: 'per_piece',
                quantity: 1.0,
                unitPrice: 15000,
                calculatedTotal: 15000,
                createdAt: now,
                updatedAt: now,
              ),
            );

        // Verify itemDefinitionId is populated
        var item = await (db.select(
          db.orderItems,
        )..where((t) => t.id.equals('item-setnull-1'))).getSingle();
        expect(item.itemDefinitionId, equals('def-setnull-1'));
        expect(item.itemDefinitionNameSnapshot, equals('بدلة رجالي'));

        // Delete the ItemDefinition
        await (db.delete(
          db.itemDefinitions,
        )..where((t) => t.id.equals('def-setnull-1'))).go();

        // Verify order_items.item_definition_id became NULL (ON DELETE SET NULL)
        item = await (db.select(
          db.orderItems,
        )..where((t) => t.id.equals('item-setnull-1'))).getSingle();
        expect(item.itemDefinitionId, isNull);

        // Invariant: Historical snapshot must remain unchanged
        expect(item.itemDefinitionNameSnapshot, equals('بدلة رجالي'));
      },
    );

    test(
      'deleting CarpetSize sets order_item_carpets.carpet_size_id to NULL and preserves dimensions',
      () async {
        final now = DateTime.now();
        const carpetItemTypeId = '00000000-0000-0000-0001-000000000003';

        await db
            .into(db.carpetSizes)
            .insert(
              CarpetSizesCompanion.insert(
                id: 'size-setnull-1',
                length: 3.0,
                width: 2.0,
                area: 6.0,
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.customers)
            .insert(
              CustomersCompanion.insert(
                id: 'cust-setnull-2',
                name: 'عميل سجاد حذف',
                phone: '01088888885',
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.orders)
            .insert(
              OrdersCompanion.insert(
                id: 'order-setnull-2',
                orderNumber: '26-807',
                customerId: 'cust-setnull-2',
                expectedPickupDate: now,
                subtotal: 30000,
                total: 30000,
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.services)
            .insert(
              ServicesCompanion.insert(
                id: 'serv-setnull-2',
                name: 'تنظيف سجاد فاخر',
                pricingType: 'per_square_meter',
                price: 5000,
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.orderItems)
            .insert(
              OrderItemsCompanion.insert(
                id: 'item-setnull-carpet-1',
                orderId: 'order-setnull-2',
                itemTypeId: carpetItemTypeId,
                serviceId: 'serv-setnull-2',
                itemTypeNameSnapshot: 'سجاد',
                serviceNameSnapshot: 'تنظيف سجاد فاخر',
                pricingType: 'per_square_meter',
                quantity: 6.0,
                unitPrice: 5000,
                calculatedTotal: 30000,
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.orderItemCarpets)
            .insert(
              OrderItemCarpetsCompanion.insert(
                id: 'oic-setnull-1',
                orderItemId: 'item-setnull-carpet-1',
                carpetSizeId: const Value('size-setnull-1'),
                length: 3.0,
                width: 2.0,
                area: 6.0,
                createdAt: now,
                updatedAt: now,
              ),
            );

        // Verify carpetSizeId is populated
        var carpetRecord = await (db.select(
          db.orderItemCarpets,
        )..where((t) => t.id.equals('oic-setnull-1'))).getSingle();
        expect(carpetRecord.carpetSizeId, equals('size-setnull-1'));

        // Delete the CarpetSize
        await (db.delete(
          db.carpetSizes,
        )..where((t) => t.id.equals('size-setnull-1'))).go();

        // Verify carpet_size_id became NULL (ON DELETE SET NULL)
        carpetRecord = await (db.select(
          db.orderItemCarpets,
        )..where((t) => t.id.equals('oic-setnull-1'))).getSingle();
        expect(carpetRecord.carpetSizeId, isNull);

        // Invariant: Dimensions remain preserved
        expect(carpetRecord.length, equals(3.0));
        expect(carpetRecord.width, equals(2.0));
        expect(carpetRecord.area, equals(6.0));
      },
    );
  });

  group('12. Complete UNIQUE Constraints Coverage', () {
    test('duplicate services.name is rejected', () async {
      final now = DateTime.now();

      await db
          .into(db.services)
          .insert(
            ServicesCompanion.insert(
              id: 'serv-u-1',
              name: 'كي بالبخار',
              pricingType: 'per_piece',
              price: 2000,
              createdAt: now,
              updatedAt: now,
            ),
          );

      expect(
        () async => await db
            .into(db.services)
            .insert(
              ServicesCompanion.insert(
                id: 'serv-u-2',
                name: 'كي بالبخار', // Duplicate name!
                pricingType: 'per_piece',
                price: 2500,
                createdAt: now,
                updatedAt: now,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('duplicate storage_locations.name is rejected', () async {
      final now = DateTime.now();

      await db
          .into(db.storageLocations)
          .insert(
            StorageLocationsCompanion.insert(
              id: 'loc-u-1',
              name: 'رف-01',
              createdAt: now,
              updatedAt: now,
            ),
          );

      expect(
        () async => await db
            .into(db.storageLocations)
            .insert(
              StorageLocationsCompanion.insert(
                id: 'loc-u-2',
                name: 'رف-01', // Duplicate name!
                createdAt: now,
                updatedAt: now,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('duplicate item_types.name is rejected', () async {
      final now = DateTime.now();

      // 'ملابس' was already seeded
      expect(
        () async => await db
            .into(db.itemTypes)
            .insert(
              ItemTypesCompanion.insert(
                id: 'it-dup-name',
                name: 'ملابس', // Duplicate!
                createdAt: now,
                updatedAt: now,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('duplicate expense_categories.name is rejected', () async {
      final now = DateTime.now();

      // 'كهرباء' was already seeded
      expect(
        () async => await db
            .into(db.expenseCategories)
            .insert(
              ExpenseCategoriesCompanion.insert(
                id: 'ec-dup-name',
                name: 'كهرباء', // Duplicate!
                createdAt: now,
                updatedAt: now,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test(
      'duplicate service_item_types(service_id, item_type_id) is rejected',
      () async {
        final now = DateTime.now();
        const itemTypeId = '00000000-0000-0000-0001-000000000001';

        await db
            .into(db.services)
            .insert(
              ServicesCompanion.insert(
                id: 'serv-sit-1',
                name: 'خدمة تجربة توافق',
                pricingType: 'per_piece',
                price: 1000,
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.serviceItemTypes)
            .insert(
              ServiceItemTypesCompanion.insert(
                id: 'sit-1',
                serviceId: 'serv-sit-1',
                itemTypeId: itemTypeId,
                createdAt: now,
              ),
            );

        // Inserting exact same pair must fail
        expect(
          () async => await db
              .into(db.serviceItemTypes)
              .insert(
                ServiceItemTypesCompanion.insert(
                  id: 'sit-2',
                  serviceId: 'serv-sit-1',
                  itemTypeId: itemTypeId, // Duplicate composite pair!
                  createdAt: now,
                ),
              ),
          throwsA(isA<SqliteException>()),
        );
      },
    );

    test(
      'duplicate storage_location_item_types(storage_location_id, item_type_id) is rejected',
      () async {
        final now = DateTime.now();
        const itemTypeId = '00000000-0000-0000-0001-000000000001';

        await db
            .into(db.storageLocations)
            .insert(
              StorageLocationsCompanion.insert(
                id: 'loc-slit-1',
                name: 'موقع-توافق-1',
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.storageLocationItemTypes)
            .insert(
              StorageLocationItemTypesCompanion.insert(
                id: 'slit-1',
                storageLocationId: 'loc-slit-1',
                itemTypeId: itemTypeId,
                createdAt: now,
              ),
            );

        // Inserting exact same pair must fail
        expect(
          () async => await db
              .into(db.storageLocationItemTypes)
              .insert(
                StorageLocationItemTypesCompanion.insert(
                  id: 'slit-2',
                  storageLocationId: 'loc-slit-1',
                  itemTypeId: itemTypeId, // Duplicate composite pair!
                  createdAt: now,
                ),
              ),
          throwsA(isA<SqliteException>()),
        );
      },
    );
  });

  group('13. Historical Snapshot Immutability', () {
    test(
      'updating ItemType, ItemDefinition, or Service name does NOT alter historical OrderItem snapshots',
      () async {
        final now = DateTime.now();

        await db
            .into(db.itemTypes)
            .insert(
              ItemTypesCompanion.insert(
                id: 'it-snap-1',
                name: 'مفروشات أصلية',
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.itemDefinitions)
            .insert(
              ItemDefinitionsCompanion.insert(
                id: 'id-snap-1',
                itemTypeId: 'it-snap-1',
                name: 'مفرش سرير أصلي',
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.services)
            .insert(
              ServicesCompanion.insert(
                id: 'serv-snap-1',
                name: 'تنظيف جاف أصلي',
                pricingType: 'per_piece',
                price: 5000,
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.customers)
            .insert(
              CustomersCompanion.insert(
                id: 'cust-snap-1',
                name: 'عميل لقطات تاريخية',
                phone: '01088888886',
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.orders)
            .insert(
              OrdersCompanion.insert(
                id: 'order-snap-1',
                orderNumber: '26-808',
                customerId: 'cust-snap-1',
                expectedPickupDate: now,
                subtotal: 5000,
                total: 5000,
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.orderItems)
            .insert(
              OrderItemsCompanion.insert(
                id: 'item-snap-1',
                orderId: 'order-snap-1',
                itemTypeId: 'it-snap-1',
                itemDefinitionId: const Value('id-snap-1'),
                serviceId: 'serv-snap-1',
                itemTypeNameSnapshot: 'مفروشات أصلية',
                itemDefinitionNameSnapshot: const Value('مفرش سرير أصلي'),
                serviceNameSnapshot: 'تنظيف جاف أصلي',
                pricingType: 'per_piece',
                quantity: 1.0,
                unitPrice: 5000,
                calculatedTotal: 5000,
                createdAt: now,
                updatedAt: now,
              ),
            );

        // Now mutate master data records
        await (db.update(db.itemTypes)..where((t) => t.id.equals('it-snap-1')))
            .write(const ItemTypesCompanion(name: Value('مفروشات معدلة')));

        await (db.update(
          db.itemDefinitions,
        )..where((t) => t.id.equals('id-snap-1'))).write(
          const ItemDefinitionsCompanion(name: Value('مفرش سرير معدل')),
        );

        await (db.update(db.services)..where((t) => t.id.equals('serv-snap-1')))
            .write(const ServicesCompanion(name: Value('تنظيف جاف معدل')));

        // Reload existing OrderItem
        final reloadedItem = await (db.select(
          db.orderItems,
        )..where((t) => t.id.equals('item-snap-1'))).getSingle();

        // Assert all snapshots remained completely unchanged
        expect(reloadedItem.itemTypeNameSnapshot, equals('مفروشات أصلية'));
        expect(
          reloadedItem.itemDefinitionNameSnapshot,
          equals('مفرش سرير أصلي'),
        );
        expect(reloadedItem.serviceNameSnapshot, equals('تنظيف جاف أصلي'));
      },
    );

    test(
      'renaming ExpenseCategory does NOT alter existing Expense category_name_snapshot',
      () async {
        final now = DateTime.now();

        await db
            .into(db.expenseCategories)
            .insert(
              ExpenseCategoriesCompanion.insert(
                id: 'ec-snap-1',
                name: 'وقود ومحروقات',
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.expenses)
            .insert(
              ExpensesCompanion.insert(
                id: 'exp-snap-1',
                expenseCategoryId: 'ec-snap-1',
                amount: 25000,
                expenseDate: now,
                categoryNameSnapshot: 'وقود ومحروقات',
                createdAt: now,
                updatedAt: now,
              ),
            );

        // Mutate ExpenseCategory name
        await (db.update(
          db.expenseCategories,
        )..where((t) => t.id.equals('ec-snap-1'))).write(
          const ExpenseCategoriesCompanion(name: Value('محروقات وسيارات')),
        );

        // Reload Expense
        final reloadedExpense = await (db.select(
          db.expenses,
        )..where((t) => t.id.equals('exp-snap-1'))).getSingle();

        // Invariant: Snapshot remains unchanged
        expect(reloadedExpense.categoryNameSnapshot, equals('وقود ومحروقات'));
      },
    );
  });
}
