import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/di/injection.dart';
import 'package:laundry_management/data/local/daos/business_settings_dao.dart';
import 'package:laundry_management/data/local/daos/carpet_sizes_dao.dart';
import 'package:laundry_management/data/local/daos/customers_dao.dart';
import 'package:laundry_management/data/local/daos/expense_categories_dao.dart';
import 'package:laundry_management/data/local/daos/expenses_dao.dart';
import 'package:laundry_management/data/local/daos/item_definitions_dao.dart';
import 'package:laundry_management/data/local/daos/item_types_dao.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/services_dao.dart';
import 'package:laundry_management/data/local/daos/storage_locations_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart';
import 'package:laundry_management/domain/repositories/carpet_size_repository.dart';
import 'package:laundry_management/domain/repositories/customer_repository.dart';
import 'package:laundry_management/domain/repositories/expense_category_repository.dart';
import 'package:laundry_management/domain/repositories/expense_repository.dart';
import 'package:laundry_management/domain/repositories/item_definition_repository.dart';
import 'package:laundry_management/domain/repositories/item_type_repository.dart';
import 'package:laundry_management/domain/repositories/order_repository.dart';
import 'package:laundry_management/domain/repositories/payment_repository.dart';
import 'package:laundry_management/domain/repositories/service_repository.dart';
import 'package:laundry_management/domain/repositories/settings_repository.dart';
import 'package:laundry_management/domain/repositories/storage_location_repository.dart';
import 'package:laundry_management/domain/repositories/storage_repository.dart';

void main() {
  setUp(() async {
    await getIt.reset();
    // Register in-memory AppDatabase for testing
    getIt.registerLazySingleton<AppDatabase>(() => AppDatabase(NativeDatabase.memory()));
    await initDependencies();
  });

  tearDown(() async {
    if (getIt.isRegistered<AppDatabase>()) {
      await getIt<AppDatabase>().close();
    }
    await getIt.reset();
  });

  group('Dependency Injection Container', () {
    test('resolves AppDatabase', () {
      expect(getIt<AppDatabase>(), isNotNull);
    });

    test('resolves all 13 DAOs', () {
      expect(getIt<CustomersDao>(), isNotNull);
      expect(getIt<OrdersDao>(), isNotNull);
      expect(getIt<PaymentsDao>(), isNotNull);
      expect(getIt<StorageLocationsDao>(), isNotNull);
      expect(getIt<StorageRecordsDao>(), isNotNull);
      expect(getIt<ServicesDao>(), isNotNull);
      expect(getIt<ItemTypesDao>(), isNotNull);
      expect(getIt<ItemDefinitionsDao>(), isNotNull);
      expect(getIt<CarpetSizesDao>(), isNotNull);
      expect(getIt<ExpenseCategoriesDao>(), isNotNull);
      expect(getIt<ExpensesDao>(), isNotNull);
      expect(getIt<BusinessSettingsDao>(), isNotNull);
      expect(getIt<SyncOperationsDao>(), isNotNull);
    });

    test('resolves all 12 Repositories via Domain interfaces', () {
      expect(getIt<CustomerRepository>(), isNotNull);
      expect(getIt<OrderRepository>(), isNotNull);
      expect(getIt<PaymentRepository>(), isNotNull);
      expect(getIt<StorageRepository>(), isNotNull);
      expect(getIt<StorageLocationRepository>(), isNotNull);
      expect(getIt<ServiceRepository>(), isNotNull);
      expect(getIt<ItemTypeRepository>(), isNotNull);
      expect(getIt<ItemDefinitionRepository>(), isNotNull);
      expect(getIt<CarpetSizeRepository>(), isNotNull);
      expect(getIt<ExpenseCategoryRepository>(), isNotNull);
      expect(getIt<ExpenseRepository>(), isNotNull);
      expect(getIt<SettingsRepository>(), isNotNull);
    });
  });
}
