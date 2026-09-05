import 'package:get_it/get_it.dart';

import '../../data/local/daos/business_settings_dao.dart';
import '../../data/local/daos/carpet_sizes_dao.dart';
import '../../data/local/daos/customers_dao.dart';
import '../../data/local/daos/expense_categories_dao.dart';
import '../../data/local/daos/expenses_dao.dart';
import '../../data/local/daos/item_definitions_dao.dart';
import '../../data/local/daos/item_types_dao.dart';
import '../../data/local/daos/orders_dao.dart';
import '../../data/local/daos/payments_dao.dart';
import '../../data/local/daos/services_dao.dart';
import '../../data/local/daos/storage_locations_dao.dart';
import '../../data/local/daos/storage_records_dao.dart';
import '../../data/local/daos/sync_operations_dao.dart';
import '../../data/local/database/app_database.dart';
import '../../data/repositories/carpet_size_repository_impl.dart';
import '../../data/repositories/customer_repository_impl.dart';
import '../../data/repositories/expense_category_repository_impl.dart';
import '../../data/repositories/expense_repository_impl.dart';
import '../../data/repositories/item_definition_repository_impl.dart';
import '../../data/repositories/item_type_repository_impl.dart';
import '../../data/repositories/order_repository_impl.dart';
import '../../data/repositories/payment_repository_impl.dart';
import '../../data/repositories/service_repository_impl.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../data/repositories/storage_location_repository_impl.dart';
import '../../data/repositories/storage_repository_impl.dart';
import '../../domain/repositories/carpet_size_repository.dart';
import '../../domain/repositories/customer_repository.dart';
import '../../domain/repositories/expense_category_repository.dart';
import '../../domain/repositories/expense_repository.dart';
import '../../domain/repositories/item_definition_repository.dart';
import '../../domain/repositories/item_type_repository.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/repositories/payment_repository.dart';
import '../../domain/repositories/service_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/storage_location_repository.dart';
import '../../domain/repositories/storage_repository.dart';

final getIt = GetIt.instance;

Future<void> initDependencies() async {
  // 1. Core Local Database
  if (!getIt.isRegistered<AppDatabase>()) {
    getIt.registerLazySingleton<AppDatabase>(() => AppDatabase());
  }

  // 2. DAOs
  if (!getIt.isRegistered<CustomersDao>()) {
    getIt.registerLazySingleton<CustomersDao>(() => CustomersDao(getIt<AppDatabase>()));
  }
  if (!getIt.isRegistered<OrdersDao>()) {
    getIt.registerLazySingleton<OrdersDao>(() => OrdersDao(getIt<AppDatabase>()));
  }
  if (!getIt.isRegistered<PaymentsDao>()) {
    getIt.registerLazySingleton<PaymentsDao>(() => PaymentsDao(getIt<AppDatabase>()));
  }
  if (!getIt.isRegistered<StorageLocationsDao>()) {
    getIt.registerLazySingleton<StorageLocationsDao>(() => StorageLocationsDao(getIt<AppDatabase>()));
  }
  if (!getIt.isRegistered<StorageRecordsDao>()) {
    getIt.registerLazySingleton<StorageRecordsDao>(() => StorageRecordsDao(getIt<AppDatabase>()));
  }
  if (!getIt.isRegistered<ServicesDao>()) {
    getIt.registerLazySingleton<ServicesDao>(() => ServicesDao(getIt<AppDatabase>()));
  }
  if (!getIt.isRegistered<ItemTypesDao>()) {
    getIt.registerLazySingleton<ItemTypesDao>(() => ItemTypesDao(getIt<AppDatabase>()));
  }
  if (!getIt.isRegistered<ItemDefinitionsDao>()) {
    getIt.registerLazySingleton<ItemDefinitionsDao>(() => ItemDefinitionsDao(getIt<AppDatabase>()));
  }
  if (!getIt.isRegistered<CarpetSizesDao>()) {
    getIt.registerLazySingleton<CarpetSizesDao>(() => CarpetSizesDao(getIt<AppDatabase>()));
  }
  if (!getIt.isRegistered<ExpenseCategoriesDao>()) {
    getIt.registerLazySingleton<ExpenseCategoriesDao>(() => ExpenseCategoriesDao(getIt<AppDatabase>()));
  }
  if (!getIt.isRegistered<ExpensesDao>()) {
    getIt.registerLazySingleton<ExpensesDao>(() => ExpensesDao(getIt<AppDatabase>()));
  }
  if (!getIt.isRegistered<BusinessSettingsDao>()) {
    getIt.registerLazySingleton<BusinessSettingsDao>(() => BusinessSettingsDao(getIt<AppDatabase>()));
  }
  if (!getIt.isRegistered<SyncOperationsDao>()) {
    getIt.registerLazySingleton<SyncOperationsDao>(() => SyncOperationsDao(getIt<AppDatabase>()));
  }

  // 3. Repositories (Bound to Domain interfaces)
  if (!getIt.isRegistered<CustomerRepository>()) {
    getIt.registerLazySingleton<CustomerRepository>(
      () => CustomerRepositoryImpl(
        customersDao: getIt<CustomersDao>(),
        syncOperationsDao: getIt<SyncOperationsDao>(),
        db: getIt<AppDatabase>(),
      ),
    );
  }
  if (!getIt.isRegistered<OrderRepository>()) {
    getIt.registerLazySingleton<OrderRepository>(
      () => OrderRepositoryImpl(
        ordersDao: getIt<OrdersDao>(),
        storageRecordsDao: getIt<StorageRecordsDao>(),
        syncOperationsDao: getIt<SyncOperationsDao>(),
        db: getIt<AppDatabase>(),
      ),
    );
  }
  if (!getIt.isRegistered<PaymentRepository>()) {
    getIt.registerLazySingleton<PaymentRepository>(
      () => PaymentRepositoryImpl(
        paymentsDao: getIt<PaymentsDao>(),
        ordersDao: getIt<OrdersDao>(),
        syncOperationsDao: getIt<SyncOperationsDao>(),
        db: getIt<AppDatabase>(),
      ),
    );
  }
  if (!getIt.isRegistered<StorageRepository>()) {
    getIt.registerLazySingleton<StorageRepository>(
      () => StorageRepositoryImpl(
        storageRecordsDao: getIt<StorageRecordsDao>(),
        storageLocationsDao: getIt<StorageLocationsDao>(),
        syncOperationsDao: getIt<SyncOperationsDao>(),
        db: getIt<AppDatabase>(),
      ),
    );
  }
  if (!getIt.isRegistered<StorageLocationRepository>()) {
    getIt.registerLazySingleton<StorageLocationRepository>(
      () => StorageLocationRepositoryImpl(
        storageLocationsDao: getIt<StorageLocationsDao>(),
        storageRecordsDao: getIt<StorageRecordsDao>(),
        syncOperationsDao: getIt<SyncOperationsDao>(),
        db: getIt<AppDatabase>(),
      ),
    );
  }
  if (!getIt.isRegistered<ServiceRepository>()) {
    getIt.registerLazySingleton<ServiceRepository>(
      () => ServiceRepositoryImpl(
        servicesDao: getIt<ServicesDao>(),
        syncOperationsDao: getIt<SyncOperationsDao>(),
        db: getIt<AppDatabase>(),
      ),
    );
  }
  if (!getIt.isRegistered<ItemTypeRepository>()) {
    getIt.registerLazySingleton<ItemTypeRepository>(
      () => ItemTypeRepositoryImpl(
        itemTypesDao: getIt<ItemTypesDao>(),
        syncOperationsDao: getIt<SyncOperationsDao>(),
        db: getIt<AppDatabase>(),
      ),
    );
  }
  if (!getIt.isRegistered<ItemDefinitionRepository>()) {
    getIt.registerLazySingleton<ItemDefinitionRepository>(
      () => ItemDefinitionRepositoryImpl(
        itemDefinitionsDao: getIt<ItemDefinitionsDao>(),
        syncOperationsDao: getIt<SyncOperationsDao>(),
        db: getIt<AppDatabase>(),
      ),
    );
  }
  if (!getIt.isRegistered<CarpetSizeRepository>()) {
    getIt.registerLazySingleton<CarpetSizeRepository>(
      () => CarpetSizeRepositoryImpl(
        carpetSizesDao: getIt<CarpetSizesDao>(),
        syncOperationsDao: getIt<SyncOperationsDao>(),
        db: getIt<AppDatabase>(),
      ),
    );
  }
  if (!getIt.isRegistered<ExpenseCategoryRepository>()) {
    getIt.registerLazySingleton<ExpenseCategoryRepository>(
      () => ExpenseCategoryRepositoryImpl(
        expenseCategoriesDao: getIt<ExpenseCategoriesDao>(),
        syncOperationsDao: getIt<SyncOperationsDao>(),
        db: getIt<AppDatabase>(),
      ),
    );
  }
  if (!getIt.isRegistered<ExpenseRepository>()) {
    getIt.registerLazySingleton<ExpenseRepository>(
      () => ExpenseRepositoryImpl(
        expensesDao: getIt<ExpensesDao>(),
        syncOperationsDao: getIt<SyncOperationsDao>(),
        db: getIt<AppDatabase>(),
      ),
    );
  }
  if (!getIt.isRegistered<SettingsRepository>()) {
    getIt.registerLazySingleton<SettingsRepository>(
      () => SettingsRepositoryImpl(
        settingsDao: getIt<BusinessSettingsDao>(),
        syncOperationsDao: getIt<SyncOperationsDao>(),
        db: getIt<AppDatabase>(),
      ),
    );
  }
}
