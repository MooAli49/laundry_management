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
import '../tables/order_item_carpets_table.dart';
import '../tables/order_items_table.dart';
import '../tables/orders_table.dart';
import '../tables/payments_table.dart';
import '../tables/service_item_types_table.dart';
import '../tables/services_table.dart';
import '../tables/storage_location_item_types_table.dart';
import '../tables/storage_locations_table.dart';
import '../tables/storage_records_table.dart';
import '../tables/sync_operations_table.dart';
import 'seed_data.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Customers,
    Orders,
    OrderItems,
    OrderItemCarpets,
    Payments,
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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _createIndexes();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // Migration foundation prepared for future schema upgrades
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
      await _createIndexes();
      await SeedData.seedInitialData(this);
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
