import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../tables/business_settings_table.dart';
import '../tables/carpet_sizes_table.dart';
import '../tables/customers_table.dart';
import '../tables/expense_categories_table.dart';
import '../tables/expenses_table.dart';
import '../tables/item_definitions_table.dart';
import '../tables/item_types_table.dart';
import '../tables/license_cache_table.dart';
import '../tables/order_item_carpets_table.dart';
import '../tables/order_items_table.dart';
import '../tables/orders_table.dart';
import '../tables/payments_table.dart';
import '../tables/refunds_table.dart';
import '../tables/service_item_types_table.dart';
import '../tables/services_table.dart';
import '../tables/storage_location_item_types_table.dart';
import '../tables/storage_locations_table.dart';
import '../tables/storage_records_table.dart';
import '../tables/sync_conflicts_table.dart';
import '../tables/sync_operations_table.dart';
import '../tables/sync_states_table.dart';
import 'seed_data.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Customers,
    Orders,
    OrderItems,
    OrderItemCarpets,
    Payments,
    Refunds,
    StorageLocations,
    StorageRecords,
    ItemTypes,
    ItemDefinitions,
    Services,
    ServiceItemTypes,
    StorageLocationItemTypes,
    CarpetSizes,
    ExpenseCategories,
    Expenses,
    BusinessSettings,
    SyncOperations,
    SyncConflicts,
    SyncStates,
    LicenseCache,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Creates the application database.
  ///
  /// [enableCanonicalSeed] controls whether [SeedData.seedInitialData] runs on
  /// open. It defaults to [SeedData.isEnabled] (`ENABLE_CANONICAL_SEED`,
  /// default `false`), so a fresh database is EMPTY unless explicitly opted in.
  AppDatabase([QueryExecutor? e, bool? enableCanonicalSeed])
    : _enableCanonicalSeed = enableCanonicalSeed ?? SeedData.isEnabled,
      super(e ?? _openConnection());

  final bool _enableCanonicalSeed;

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _createIndexes();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.addColumn(orders, orders.customerNameSnapshot);
        await m.addColumn(orders, orders.customerPhoneSnapshot);

        await customStatement('''
          UPDATE orders
          SET customer_name_snapshot =
                COALESCE(
                  (SELECT name
                   FROM customers
                   WHERE customers.id = orders.customer_id),
                  ''
                ),
              customer_phone_snapshot =
                COALESCE(
                  (SELECT phone
                   FROM customers
                   WHERE customers.id = orders.customer_id),
                  ''
                )
          WHERE customer_name_snapshot = ''
             OR customer_name_snapshot IS NULL;
        ''');
      }
      if (from < 3) {
        await m.addColumn(syncOperations, syncOperations.nextRetryAt);

        await customStatement('''
          UPDATE sync_operations
          SET status = 'synced'
          WHERE status = 'completed';
        ''');

        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_sync_operations_status_next_retry ON sync_operations(status, next_retry_at);',
        );
      }
      if (from < 4) {
        await m.createTable(syncStates);
      }
      if (from < 5) {
        await m.createTable(refunds);
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_refunds_order_id ON refunds(order_id);',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_refunds_refunded_at ON refunds(refunded_at);',
        );
      }
      if (from < 6) {
        await m.addColumn(customers, customers.address);
      }
      if (from < 7) {
        // Add local license cache table.
        // Single-row singleton that mirrors the remote license_info state.
        // This table does NOT participate in the SyncEngine or outbox.
        await m.createTable(licenseCache);
      }
      if (from < 8) {
        // Upgrade service_item_types and services to Service + Item Type Pricing Model
        final serviceCols = await customSelect(
          'PRAGMA table_info(services);',
        ).get();
        final hasLegacyServicePricing = serviceCols.any(
          (r) => r.read<String>('name') == 'pricing_type',
        );

        if (hasLegacyServicePricing) {
          await customStatement('''
            CREATE TABLE IF NOT EXISTS service_item_types_new (
              id TEXT NOT NULL PRIMARY KEY,
              service_id TEXT NOT NULL REFERENCES services (id) ON DELETE RESTRICT,
              item_type_id TEXT NOT NULL REFERENCES item_types (id) ON DELETE RESTRICT,
              pricing_type TEXT NOT NULL CHECK (pricing_type IN ('per_piece', 'per_square_meter')),
              price INTEGER NOT NULL CHECK (price > 0),
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              UNIQUE (service_id, item_type_id)
            );
          ''');

          await customStatement('''
            INSERT OR IGNORE INTO service_item_types_new (id, service_id, item_type_id, pricing_type, price, created_at, updated_at)
            SELECT
              sit.id,
              sit.service_id,
              sit.item_type_id,
              CASE WHEN s.pricing_type = 'fixed_price' THEN 'per_piece' ELSE s.pricing_type END,
              s.price,
              sit.created_at,
              sit.created_at
            FROM service_item_types sit
            JOIN services s ON s.id = sit.service_id
            WHERE s.price > 0;
          ''');

          await customStatement('DROP TABLE service_item_types;');
          await customStatement(
            'ALTER TABLE service_item_types_new RENAME TO service_item_types;',
          );

          await customStatement('''
            CREATE TABLE IF NOT EXISTS services_new (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL UNIQUE,
              description TEXT,
              is_active INTEGER NOT NULL DEFAULT 1,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            );
          ''');

          await customStatement('''
            INSERT OR IGNORE INTO services_new (id, name, description, is_active, created_at, updated_at)
            SELECT id, name, description, is_active, created_at, updated_at
            FROM services;
          ''');

          await customStatement('DROP TABLE services;');
          await customStatement('ALTER TABLE services_new RENAME TO services;');
        }

        await customStatement('''
          UPDATE order_items SET pricing_type = 'per_piece' WHERE pricing_type = 'fixed_price';
        ''');
      }
      if (from < 9) {
        await m.createTable(syncConflicts);
      }
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
      await _createIndexes();
      if (_enableCanonicalSeed) {
        await SeedData.seedInitialData(this);
      }
    },
  );

  Future<void> _createIndexes() async {
    // 1. Partial Unique Index for StorageRecords (BR-045, Section 29)
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_storage_records_active_item
      ON storage_records(order_item_id)
      WHERE is_active = 1;
    ''');

    // 2. Operational indexes per docs/04-database/indexes.md
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders(customer_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_orders_expected_pickup_date ON orders(expected_pickup_date);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at);',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_order_items_item_type_id ON order_items(item_type_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_order_items_service_id ON order_items(service_id);',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_payments_order_id ON payments(order_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_payments_paid_at ON payments(paid_at);',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_refunds_order_id ON refunds(order_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_refunds_refunded_at ON refunds(refunded_at);',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_storage_locations_is_active ON storage_locations(is_active);',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_storage_records_order_item_id ON storage_records(order_item_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_storage_records_location_id ON storage_records(storage_location_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_storage_records_location_active ON storage_records(storage_location_id, is_active);',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_item_types_is_active ON item_types(is_active);',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_item_definitions_item_type_id ON item_definitions(item_type_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_item_definitions_item_type_active ON item_definitions(item_type_id, is_active);',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_services_is_active ON services(is_active);',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_service_item_types_service_id ON service_item_types(service_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_service_item_types_item_type_id ON service_item_types(item_type_id);',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_storage_location_item_types_location_id ON storage_location_item_types(storage_location_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_storage_location_item_types_item_type_id ON storage_location_item_types(item_type_id);',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_carpet_sizes_is_active ON carpet_sizes(is_active);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_order_item_carpets_carpet_size_id ON order_item_carpets(carpet_size_id);',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_expense_categories_is_active ON expense_categories(is_active);',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_expenses_category_id ON expenses(expense_category_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(expense_date);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_expenses_date_category ON expenses(expense_date, expense_category_id);',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_operations_status ON sync_operations(status);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_operations_status_created_at ON sync_operations(status, created_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_operations_status_next_retry ON sync_operations(status, next_retry_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_operations_entity ON sync_operations(entity_type, entity_id);',
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'laundry_management.db'));
    return NativeDatabase.createInBackground(file);
  });
}
