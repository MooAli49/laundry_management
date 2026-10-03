@Timeout(Duration(minutes: 5))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/config/supabase_config.dart';
import 'package:laundry_management/core/network/dio_client.dart';
import 'package:laundry_management/core/network/network_info.dart';
import 'package:laundry_management/data/datasources/remote/customer_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/expense_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/master_data_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/order_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/payment_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/refund_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/remote_api_dispatcher.dart';
import 'package:laundry_management/data/datasources/remote/storage_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/sync_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/sync_remote_data_source.dart';
import 'package:laundry_management/data/local/daos/customers_dao.dart';
import 'package:laundry_management/data/local/daos/expense_categories_dao.dart';
import 'package:laundry_management/data/local/daos/expenses_dao.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/services_dao.dart';
import 'package:laundry_management/data/local/daos/storage_locations_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/daos/sync_state_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart'
    as app_db;
import 'package:laundry_management/data/remote/dto/sync_change_dto.dart';
import 'package:laundry_management/data/repositories/customer_repository_impl.dart';
import 'package:laundry_management/data/repositories/expense_category_repository_impl.dart';
import 'package:laundry_management/data/repositories/expense_repository_impl.dart';
import 'package:laundry_management/data/repositories/order_repository_impl.dart';
import 'package:laundry_management/data/repositories/payment_repository_impl.dart';
import 'package:laundry_management/data/repositories/service_repository_impl.dart';
import 'package:laundry_management/data/repositories/storage_repository_impl.dart';
import 'package:laundry_management/data/sync/remote_change_applier.dart';
import 'package:laundry_management/data/sync/sync_engine.dart';
import 'package:laundry_management/domain/entities/carpet_item_data.dart';
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/domain/entities/expense.dart';
import 'package:laundry_management/domain/entities/expense_category.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/entities/payment.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/enums/payment_method.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/sync/sync_engine_state.dart';
import 'package:laundry_management/domain/sync/sync_error_classifier.dart';
import 'package:laundry_management/domain/sync/sync_retry_policy.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';

class TestNetworkInfo implements NetworkInfo {
  bool _isConnected;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  TestNetworkInfo({bool initialConnected = true})
    : _isConnected = initialConnected;

  @override
  Future<bool> get isConnected async => _isConnected;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  void setConnected(bool value) {
    _isConnected = value;
    _controller.add(value);
  }

  void dispose() {
    _controller.close();
  }
}

class TestDevice {
  final String name;
  final app_db.AppDatabase db;
  final TestNetworkInfo networkInfo;
  final SyncOperationsDao syncOperationsDao;
  final SyncStateDao syncStateDao;
  final CustomersDao customersDao;
  final OrdersDao ordersDao;
  final PaymentsDao paymentsDao;
  final StorageRecordsDao storageRecordsDao;
  final StorageLocationsDao storageLocationsDao;
  final ExpensesDao expensesDao;
  final ExpenseCategoriesDao expenseCategoriesDao;
  final ServicesDao servicesDao;
  final RemoteChangeApplier changeApplier;
  final SyncRemoteDataSource remoteDataSource;
  final RemoteApiDispatcher remoteApiDispatcher;
  final SyncEngine syncEngine;
  final Dio dio;

  final CustomerRepositoryImpl customerRepository;
  final OrderRepositoryImpl orderRepository;
  final PaymentRepositoryImpl paymentRepository;
  final StorageRepositoryImpl storageRepository;
  final ExpenseRepositoryImpl expenseRepository;
  final ExpenseCategoryRepositoryImpl expenseCategoryRepository;
  final ServiceRepositoryImpl serviceRepository;

  TestDevice({
    required this.name,
    required this.db,
    required this.networkInfo,
    required this.syncOperationsDao,
    required this.syncStateDao,
    required this.customersDao,
    required this.ordersDao,
    required this.paymentsDao,
    required this.storageRecordsDao,
    required this.storageLocationsDao,
    required this.expensesDao,
    required this.expenseCategoriesDao,
    required this.servicesDao,
    required this.changeApplier,
    required this.remoteDataSource,
    required this.remoteApiDispatcher,
    required this.syncEngine,
    required this.dio,
    required this.customerRepository,
    required this.orderRepository,
    required this.paymentRepository,
    required this.storageRepository,
    required this.expenseRepository,
    required this.expenseCategoryRepository,
    required this.serviceRepository,
  });

  static Future<TestDevice> create({
    required String name,
    required String baseUrl,
    drift.QueryExecutor? executor,
    bool initialConnected = true,
  }) async {
    final db = app_db.AppDatabase(executor ?? NativeDatabase.memory());
    final networkInfo = TestNetworkInfo(initialConnected: initialConnected);

    final syncOperationsDao = SyncOperationsDao(db);
    final syncStateDao = SyncStateDao(db);
    final customersDao = CustomersDao(db);
    final ordersDao = OrdersDao(db);
    final paymentsDao = PaymentsDao(db);
    final storageRecordsDao = StorageRecordsDao(db);
    final storageLocationsDao = StorageLocationsDao(db);
    final expensesDao = ExpensesDao(db);
    final expenseCategoriesDao = ExpenseCategoriesDao(db);
    final servicesDao = ServicesDao(db);

    final changeApplier = RemoteChangeApplier(
      db: db,
      syncStateDao: syncStateDao,
      syncOperationsDao: syncOperationsDao,
    );

    final dioClient = DioClient(
      baseUrl: baseUrl,
      receiveTimeout: const Duration(seconds: 30),
      connectTimeout: const Duration(seconds: 30),
    );
    final dio = dioClient.dio;

    final remoteDataSource = SyncRemoteDataSourceImpl(SyncRemoteApi(dio));

    final remoteApiDispatcher = RemoteApiDispatcher(
      customerApi: CustomerRemoteApi(dio),
      orderApi: OrderRemoteApi(dio),
      paymentApi: PaymentRemoteApi(dio),
      refundApi: RefundRemoteApi(dio),
      storageApi: StorageRemoteApi(dio),
      expenseApi: ExpenseRemoteApi(dio),
      masterDataApi: MasterDataRemoteApi(dio),
    );

    final syncEngine = SyncEngine(
      syncOperationsDao: syncOperationsDao,
      remoteApiDispatcher: remoteApiDispatcher,
      networkInfo: networkInfo,
      retryPolicy: SyncRetryPolicy(),
      errorClassifier: const SyncErrorClassifier(),
      syncRemoteDataSource: remoteDataSource,
      remoteChangeApplier: changeApplier,
      syncStateDao: syncStateDao,
    );

    final customerRepository = CustomerRepositoryImpl(
      customersDao: customersDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    final orderRepository = OrderRepositoryImpl(
      ordersDao: ordersDao,
      paymentsDao: paymentsDao,
      storageRecordsDao: storageRecordsDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    final paymentRepository = PaymentRepositoryImpl(
      paymentsDao: paymentsDao,
      ordersDao: ordersDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    final storageRepository = StorageRepositoryImpl(
      storageRecordsDao: storageRecordsDao,
      storageLocationsDao: storageLocationsDao,
      syncOperationsDao: syncOperationsDao,
      ordersDao: ordersDao,
      db: db,
    );

    final expenseRepository = ExpenseRepositoryImpl(
      expensesDao: expensesDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    final expenseCategoryRepository = ExpenseCategoryRepositoryImpl(
      expenseCategoriesDao: expenseCategoriesDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    final serviceRepository = ServiceRepositoryImpl(
      servicesDao: servicesDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    return TestDevice(
      name: name,
      db: db,
      networkInfo: networkInfo,
      syncOperationsDao: syncOperationsDao,
      syncStateDao: syncStateDao,
      customersDao: customersDao,
      ordersDao: ordersDao,
      paymentsDao: paymentsDao,
      storageRecordsDao: storageRecordsDao,
      storageLocationsDao: storageLocationsDao,
      expensesDao: expensesDao,
      expenseCategoriesDao: expenseCategoriesDao,
      servicesDao: servicesDao,
      changeApplier: changeApplier,
      remoteDataSource: remoteDataSource,
      remoteApiDispatcher: remoteApiDispatcher,
      syncEngine: syncEngine,
      dio: dio,
      customerRepository: customerRepository,
      orderRepository: orderRepository,
      paymentRepository: paymentRepository,
      storageRepository: storageRepository,
      expenseRepository: expenseRepository,
      expenseCategoryRepository: expenseCategoryRepository,
      serviceRepository: serviceRepository,
    );
  }

  Future<void> dispose() async {
    syncEngine.dispose();
    networkInfo.dispose();
    dio.close();
    await db.close();
  }
}

String? _mutationE2eSkipReason() {
  final url = Platform.environment['SUPABASE_E2E_URL']?.trim();
  final key = Platform.environment['SUPABASE_E2E_ANON_KEY']?.trim();
  if (url == null || url.isEmpty || key == null || key.isEmpty) {
    return 'Set SUPABASE_E2E_URL and SUPABASE_E2E_ANON_KEY for mutation E2E';
  }
  return null;
}

Future<void> seedLocalMasterData(
  TestDevice device, {
  required String serviceId,
  required int servicePrice,
}) async {
  final now = DateTime.now();

  await device.db
      .into(device.db.services)
      .insertOnConflictUpdate(
        app_db.ServicesCompanion.insert(
          id: serviceId,
          name: 'خدمة سجاد E2E',
          isActive: const drift.Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );

  await device.db.customStatement(
    'INSERT OR REPLACE INTO item_types (id, name, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
    [
      '00000000-0000-0000-0001-000000000003',
      'سجاد-carpet',
      1,
      now.millisecondsSinceEpoch ~/ 1000,
      now.millisecondsSinceEpoch ~/ 1000,
    ],
  );

  await device.db
      .into(device.db.serviceItemTypes)
      .insertOnConflictUpdate(
        app_db.ServiceItemTypesCompanion.insert(
          id: 'sit-e2e-${device.name}',
          serviceId: serviceId,
          itemTypeId: '00000000-0000-0000-0001-000000000003',
          pricingType: 'per_square_meter',
          price: servicePrice,
          createdAt: now,
          updatedAt: now,
        ),
      );

  await device.db
      .into(device.db.carpetSizes)
      .insertOnConflictUpdate(
        app_db.CarpetSizesCompanion.insert(
          id: '00000000-0000-0000-0007-000000000001',
          length: 3.0,
          width: 2.0,
          area: 6.0,
          createdAt: now,
          updatedAt: now,
        ),
      );

  await device.db
      .into(device.db.storageLocations)
      .insertOnConflictUpdate(
        app_db.StorageLocationsCompanion.insert(
          id: '00000000-0000-0000-0006-000000000001',
          name: 'Rack 1',
          isActive: const drift.Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );

  await device.db
      .into(device.db.storageLocations)
      .insertOnConflictUpdate(
        app_db.StorageLocationsCompanion.insert(
          id: '00000000-0000-0000-0006-000000000002',
          name: 'Rack 2',
          isActive: const drift.Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );

  await device.db
      .into(device.db.storageLocationItemTypes)
      .insertOnConflictUpdate(
        app_db.StorageLocationItemTypesCompanion.insert(
          id: '00000000-0000-0000-0008-000000000001',
          storageLocationId: '00000000-0000-0000-0006-000000000001',
          itemTypeId: '00000000-0000-0000-0001-000000000003',
          createdAt: now,
        ),
      );

  await device.db
      .into(device.db.storageLocationItemTypes)
      .insertOnConflictUpdate(
        app_db.StorageLocationItemTypesCompanion.insert(
          id: '00000000-0000-0000-0008-000000000002',
          storageLocationId: '00000000-0000-0000-0006-000000000002',
          itemTypeId: '00000000-0000-0000-0001-000000000003',
          createdAt: now,
        ),
      );
}

void main() {
  group(
    'FINAL E2E SYNC VALIDATION — Real Supabase Backend Integration Suite',
    () {
      late String apiBaseUrl;
      late Dio probeDio;

      final runId = (DateTime.now().microsecondsSinceEpoch % 0xFFFFFFFFFFFF)
          .toRadixString(16)
          .padLeft(12, '0');

      late final String testServiceId;
      late final String testCustomerId;
      late final String testCustomerPhone;
      late final String testOrderId;
      late final String testOrderNumber;
      late final String testOrderItemId;
      late final String testCarpetId;

      late TestDevice deviceA;
      late TestDevice deviceB;
      int initialHead = 0;
      var e2eConfigured = false;

      setUpAll(() async {
        drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

        final e2eUrl = Platform.environment['SUPABASE_E2E_URL']?.trim();
        final e2eAnonKey = Platform.environment['SUPABASE_E2E_ANON_KEY']
            ?.trim();
        if (e2eUrl == null ||
            e2eUrl.isEmpty ||
            e2eAnonKey == null ||
            e2eAnonKey.isEmpty) {
          markTestSkipped(
            'Mutation E2E tests require SUPABASE_E2E_URL and '
            'SUPABASE_E2E_ANON_KEY for a dedicated test/dev project.',
          );
          return;
        }

        final config = SupabaseConfig.resolve(
          customUrlRoot: e2eUrl,
          customAnonKey: e2eAnonKey,
          isRelease: false,
        );
        e2eConfigured = true;
        if (config.urlRoot.contains(SupabaseConfig.prodProjectRef)) {
          throw StateError(
            'Refusing mutation E2E against the production Supabase project.',
          );
        }
        apiBaseUrl = '${config.apiUrl}/api/v1';

        final probeClient = DioClient(baseUrl: apiBaseUrl);

        setUp(() {
          if (!e2eConfigured) {
            markTestSkipped(
              'Dedicated mutation E2E credentials are not configured.',
            );
          }
        });
        probeDio = probeClient.dio;

        // Verify backend reachability
        try {
          final probeRes = await probeDio.get(
            '/customers',
            queryParameters: {'limit': 1},
          );
          if (probeRes.statusCode != 200) {
            fail('Backend probe returned status ${probeRes.statusCode}');
          }
        } catch (e) {
          fail(
            'Live Supabase backend at $apiBaseUrl is unreachable: $e. Ensure live backend is operational before running E2E validation.',
          );
        }

        // Provision unique run-scoped identifiers
        testServiceId = 'b0000001-0001-4001-8001-$runId';
        testCustomerId = 'c0000001-0001-4001-8001-$runId';
        testCustomerPhone =
            '012${(DateTime.now().microsecondsSinceEpoch % 100000000).toString().padLeft(8, '0')}';
        testOrderId = 'd0000001-0001-4001-8001-$runId';
        testOrderNumber = 'ORD-E2E-$runId';
        testOrderItemId = 'e0000001-0001-4001-8001-$runId';
        testCarpetId = 'f0000001-0001-4001-8001-$runId';

        // Provision remote test service on Supabase
        final srvRes = await probeDio.post(
          '/services',
          data: {
            'id': testServiceId,
            'name': 'خدمة سجاد E2E $runId',
            'pricing_type': 'per_square_meter',
            'price': 4000,
            'is_active': true,
            'item_type_ids': ['00000000-0000-0000-0001-000000000003'],
          },
          options: Options(
            headers: {'X-Operation-ID': 'op-e2e-srv-create-$runId'},
            validateStatus: (_) => true,
          ),
        );
        expect(srvRes.statusCode, isIn([200, 201]));

        // Create Device A and Device B
        deviceA = await TestDevice.create(
          name: 'Device A',
          baseUrl: apiBaseUrl,
        );
        deviceB = await TestDevice.create(
          name: 'Device B',
          baseUrl: apiBaseUrl,
        );

        // Seed local master data on both devices
        await seedLocalMasterData(
          deviceA,
          serviceId: testServiceId,
          servicePrice: 4000,
        );
        await seedLocalMasterData(
          deviceB,
          serviceId: testServiceId,
          servicePrice: 4000,
        );

        // Fast-forward local cursors to current remote head to isolate test execution
        final probe = await deviceA.remoteDataSource.getChanges(
          after: 0,
          limit: 1,
        );
        initialHead = probe.latestSequence;
        await deviceA.syncStateDao.updateLastAppliedSequence(initialHead);
        await deviceB.syncStateDao.updateLastAppliedSequence(initialHead);
      });

      tearDownAll(() async {
        await deviceA.dispose();
        await deviceB.dispose();
        probeDio.close();
      });

      // =========================================================================
      // SCENARIO A — CUSTOMER -> ORDER -> ITEM (Aggregate Creation & Sync)
      // =========================================================================
      test(
        'Scenario A: Customer -> Order -> OrderItem + Carpet details created on Device A, pushed to Supabase, and converged on Device B',
        () async {
          final now = DateTime.now();

          // 1. Create Customer on Device A
          final customerA = Customer(
            id: testCustomerId,
            name: 'عميل تجريبي E2E $runId',
            phone: testCustomerPhone,
            notes: 'Customer created on Device A',
            createdAt: now,
            updatedAt: now,
          );
          await deviceA.customerRepository.createCustomer(customerA);

          // 2. Create Order on Device A with 1 Item and Carpet Metadata
          final orderItemA = OrderItem(
            id: testOrderItemId,
            orderId: testOrderId,
            itemTypeId: '00000000-0000-0000-0001-000000000003',
            serviceId: testServiceId,
            itemTypeNameSnapshot: 'سجاد-carpet',
            serviceNameSnapshot: 'خدمة سجاد E2E $runId',
            pricingType: PricingType.perSquareMeter,
            quantity: 6.0,
            unitPrice: const Money.fromPiastres(4000),
            calculatedTotal: const Money.fromPiastres(24000),
            carpetData: CarpetItemData(
              id: testCarpetId,
              orderItemId: testOrderItemId,
              carpetSizeId: '00000000-0000-0000-0007-000000000001',
              length: 3.0,
              width: 2.0,
              area: 6.0,
              createdAt: now,
              updatedAt: now,
            ),
            createdAt: now,
            updatedAt: now,
          );

          final orderA = Order(
            id: testOrderId,
            orderNumber: testOrderNumber,
            customerId: testCustomerId,
            customerNameSnapshot: 'عميل تجريبي E2E $runId',
            customerPhoneSnapshot: testCustomerPhone,
            status: OrderStatus.processing,
            expectedPickupDate: OrderDate.fromDate(
              now.add(const Duration(days: 2)),
            ),
            subtotal: const Money.fromPiastres(24000),
            total: const Money.fromPiastres(24000),
            createdAt: now,
            updatedAt: now,
          );

          await deviceA.orderRepository.createOrder(
            order: orderA,
            items: [orderItemA],
          );

          // 3. Verify local state on Device A
          final localCustOnA = await deviceA.customerRepository.getCustomerById(
            testCustomerId,
          );
          expect(localCustOnA, isNotNull);
          expect(localCustOnA!.id, equals(testCustomerId));

          final localOrdOnA = await deviceA.orderRepository.getOrderById(
            testOrderId,
          );
          expect(localOrdOnA, isNotNull);
          expect(localOrdOnA!.id, equals(testOrderId));
          expect(localOrdOnA.customerId, equals(testCustomerId));
          expect(localOrdOnA.orderNumber, equals(testOrderNumber));

          final pendingOpsA = await deviceA.syncOperationsDao
              .getPendingOperations();
          expect(pendingOpsA.length, greaterThanOrEqualTo(2));
          final custOp = pendingOpsA.firstWhere(
            (o) => o.entityId == testCustomerId,
          );
          final ordOp = pendingOpsA.firstWhere(
            (o) => o.entityId == testOrderId,
          );
          expect(custOp.status, equals('pending'));
          expect(ordOp.status, equals('pending'));

          // 4. Push through real SyncEngine from Device A
          final syncResultA = await deviceA.syncEngine.sync();
          expect(syncResultA.status, equals(SyncEngineStatus.completed));

          // Verify outbox operations marked synced
          final allOpsA =
              await (deviceA.db.select(deviceA.db.syncOperations)..where(
                    (tbl) => tbl.entityId.isIn([testCustomerId, testOrderId]),
                  ))
                  .get();
          for (final op in allOpsA) {
            expect(op.status, equals('synced'));
          }

          // 5. Verify remote backend state via HTTP GET
          final remoteCustRes = await probeDio.get(
            '/customers/$testCustomerId',
          );
          expect(remoteCustRes.statusCode, equals(200));
          expect(remoteCustRes.data['id'], equals(testCustomerId));
          expect(remoteCustRes.data['phone'], equals(testCustomerPhone));

          final remoteOrdRes = await probeDio.get('/orders/$testOrderId');
          expect(remoteOrdRes.statusCode, equals(200));
          expect(remoteOrdRes.data['id'], equals(testOrderId));
          expect(remoteOrdRes.data['customer_id'], equals(testCustomerId));
          expect(remoteOrdRes.data['total'], equals(24000));
          final remoteItems =
              (remoteOrdRes.data['order_items'] ?? remoteOrdRes.data['items'])
                  as List;
          expect(remoteItems, hasLength(1));
          expect(remoteItems.first['id'], equals(testOrderItemId));

          // 6. Pull changes into Device B via real SyncEngine
          final syncResultB = await deviceB.syncEngine.sync();
          expect(syncResultB.status, equals(SyncEngineStatus.completed));

          // 7. Verify Device B contains identical logical records
          final localCustOnB = await deviceB.customerRepository.getCustomerById(
            testCustomerId,
          );
          expect(localCustOnB, isNotNull);
          expect(localCustOnB!.id, equals(testCustomerId));
          expect(localCustOnB.name, equals('عميل تجريبي E2E $runId'));
          expect(localCustOnB.phone, equals(testCustomerPhone));

          final localOrdOnB = await deviceB.orderRepository.getOrderById(
            testOrderId,
          );
          expect(localOrdOnB, isNotNull);
          expect(localOrdOnB!.id, equals(testOrderId));
          expect(localOrdOnB.orderNumber, equals(testOrderNumber));
          expect(localOrdOnB.customerId, equals(testCustomerId));
          expect(localOrdOnB.total.piastres, equals(24000));

          final localItemsOnB = await (deviceB.db.select(
            deviceB.db.orderItems,
          )..where((tbl) => tbl.orderId.equals(testOrderId))).get();
          expect(localItemsOnB, hasLength(1));
          expect(localItemsOnB.first.id, equals(testOrderItemId));
          expect(localItemsOnB.first.calculatedTotal, equals(24000));

          final localCarpetsOnB = await (deviceB.db.select(
            deviceB.db.orderItemCarpets,
          )..where((tbl) => tbl.orderItemId.equals(testOrderItemId))).get();
          expect(localCarpetsOnB, hasLength(1));
          expect(localCarpetsOnB.first.id, equals(testCarpetId));
          expect(localCarpetsOnB.first.area, equals(6.0));

          // Zero echo check: Device B must NOT queue sync operations for pulled records
          final opsOnB =
              await (deviceB.db.select(deviceB.db.syncOperations)..where(
                    (tbl) => tbl.entityId.isIn([testCustomerId, testOrderId]),
                  ))
                  .get();
          expect(opsOnB, isEmpty);
        },
      );

      // =========================================================================
      // SCENARIO B — STORAGE & STORAGE MOVE
      // =========================================================================
      test(
        'Scenario B: Item storage in Location 1 followed by move to Location 2 maintains exactly 1 active StorageRecord and converges on Device B',
        () async {
          const loc1 = '00000000-0000-0000-0006-000000000001'; // Rack 1
          const loc2 = '00000000-0000-0000-0006-000000000002'; // Rack 2

          // 1. Store item on Device A
          final storedRecord = await deviceA.storageRepository.storeItem(
            orderItemId: testOrderItemId,
            storageLocationId: loc1,
          );
          expect(storedRecord.isActive, isTrue);
          expect(storedRecord.storageLocationId, equals(loc1));

          // 2. Push from Device A & Pull to Device B
          await deviceA.syncEngine.sync();
          await deviceB.syncEngine.sync();

          // 3. Verify Device B has the active storage record at Location 1
          final activeOnB1 = await deviceB.storageRecordsDao
              .getActiveRecordForOrderItem(testOrderItemId);
          expect(activeOnB1, isNotNull);
          expect(activeOnB1!.storageLocationId, equals(loc1));
          expect(activeOnB1.isActive, isTrue);

          // 4. Move item on Device A from Location 1 to Location 2
          final movedRecord = await deviceA.storageRepository.moveItem(
            orderItemId: testOrderItemId,
            newStorageLocationId: loc2,
          );
          expect(movedRecord.isActive, isTrue);
          expect(movedRecord.storageLocationId, equals(loc2));

          // Verify outbox operation on Device A captured previous_storage_location_id
          final moveOps =
              await (deviceA.db.select(deviceA.db.syncOperations)..where(
                    (tbl) =>
                        tbl.entityId.equals(movedRecord.id) &
                        tbl.operationType.equals('move'),
                  ))
                  .get();
          expect(moveOps, hasLength(1));
          final movePayload =
              jsonDecode(moveOps.first.payload!) as Map<String, dynamic>;
          expect(movePayload['previous_storage_location_id'], equals(loc1));

          // 5. Push move from Device A & Pull to Device B
          await deviceA.syncEngine.sync();
          await deviceB.syncEngine.sync();

          // 6. Verify Device B storage convergence & invariants:
          // - Old StorageRecord is deactivated
          // - New StorageRecord is active at Location 2
          // - Exactly ONE active StorageRecord exists for the item
          final allRecordsOnB = await (deviceB.db.select(
            deviceB.db.storageRecords,
          )..where((tbl) => tbl.orderItemId.equals(testOrderItemId))).get();
          final activeRecordsOnB = allRecordsOnB
              .where((r) => r.isActive)
              .toList();
          final inactiveRecordsOnB = allRecordsOnB
              .where((r) => !r.isActive)
              .toList();

          expect(
            activeRecordsOnB,
            hasLength(1),
            reason: 'OrderItem must have exactly 1 active storage record',
          );
          expect(activeRecordsOnB.first.storageLocationId, equals(loc2));
          expect(activeRecordsOnB.first.id, equals(movedRecord.id));

          expect(inactiveRecordsOnB, hasLength(1));
          expect(inactiveRecordsOnB.first.storageLocationId, equals(loc1));
          expect(inactiveRecordsOnB.first.id, equals(storedRecord.id));
        },
      );

      // =========================================================================
      // SCENARIO C — PAYMENTS & REMAINING BALANCE
      // =========================================================================
      test(
        'Scenario C: Multi-installment payments: 1st installment leaves remaining balance, 2nd installment settles order total, idempotent replay creates zero duplicates',
        () async {
          final payment1Id = 'a0000001-0001-4001-8001-$runId';
          final payment2Id = 'a0000002-0002-4002-8002-$runId';
          final now = DateTime.now();

          // 1. First installment: 10,000 piastres (Total is 24,000)
          final payment1 = Payment(
            id: payment1Id,
            orderId: testOrderId,
            amount: const Money.fromPiastres(10000),
            paymentMethod: PaymentMethod.cash,
            paidAt: now,
            createdAt: now,
            updatedAt: now,
          );
          await deviceA.paymentRepository.recordPayment(payment1);

          // Push from Device A & Pull to Device B
          await deviceA.syncEngine.sync();
          await deviceB.syncEngine.sync();

          // Verify Device B after 1st installment
          final totalPaidB1 = await deviceB.paymentRepository
              .getTotalPaidForOrder(testOrderId);
          final remainingB1 = await deviceB.paymentRepository
              .getRemainingAmountForOrder(testOrderId);
          expect(totalPaidB1.piastres, equals(10000));
          expect(remainingB1.piastres, equals(14000)); // 24000 - 10000

          final paymentsB1 = await deviceB.paymentRepository
              .getPaymentsForOrder(testOrderId);
          expect(paymentsB1, hasLength(1));
          expect(paymentsB1.first.id, equals(payment1Id));
          expect(paymentsB1.first.amount.piastres, equals(10000));

          // 2. Second installment: 14,000 piastres (Settles remaining balance to 0)
          final payment2 = Payment(
            id: payment2Id,
            orderId: testOrderId,
            amount: const Money.fromPiastres(14000),
            paymentMethod: PaymentMethod.instapay,
            paidAt: now,
            createdAt: now,
            updatedAt: now,
          );
          await deviceA.paymentRepository.recordPayment(payment2);

          // Push from Device A & Pull to Device B
          await deviceA.syncEngine.sync();
          await deviceB.syncEngine.sync();

          // Verify Device B after 2nd installment
          final totalPaidB2 = await deviceB.paymentRepository
              .getTotalPaidForOrder(testOrderId);
          final remainingB2 = await deviceB.paymentRepository
              .getRemainingAmountForOrder(testOrderId);
          expect(totalPaidB2.piastres, equals(24000));
          expect(remainingB2.piastres, equals(0));

          final paymentsB2 = await deviceB.paymentRepository
              .getPaymentsForOrder(testOrderId);
          expect(paymentsB2, hasLength(2));
          final idsOnB = paymentsB2.map((p) => p.id).toSet();
          expect(idsOnB, containsAll([payment1Id, payment2Id]));

          // 3. Idempotent replay: dispatching payment2 operation again directly
          final payment2Op = await (deviceA.db.select(
            deviceA.db.syncOperations,
          )..where((tbl) => tbl.entityId.equals(payment2Id))).getSingle();
          final replayRes = await deviceA.remoteApiDispatcher.dispatch(
            payment2Op,
          );
          expect(replayRes, isNotNull);

          // Pull again on Device B
          await deviceB.syncEngine.sync();

          // Assert zero duplicate payments created
          final paymentsAfterReplay = await deviceB.paymentRepository
              .getPaymentsForOrder(testOrderId);
          expect(
            paymentsAfterReplay,
            hasLength(2),
            reason:
                'Idempotent replay must NOT create duplicate payment records',
          );
        },
      );

      // =========================================================================
      // SCENARIO D — EXPENSE CATEGORY -> EXPENSE DEPENDENCY ORDERING
      // =========================================================================
      test(
        'Scenario D: Expense Category created locally followed by Expense referencing it synchronizes in correct dependency order without FK violations',
        () async {
          final catId = '00000000-0000-0000-0002-000000000009'; // Test category
          final expId = '90000000-0000-0000-0003-000000000001';
          final now = DateTime.now();

          // 1. Create Expense Category on Device A
          final categoryA = ExpenseCategory(
            id: catId,
            name: 'صيانة ومعدات $runId',
            isActive: true,
            createdAt: now,
            updatedAt: now,
          );
          await deviceA.expenseCategoryRepository.createCategory(categoryA);

          // 2. Create Expense referencing the newly created category
          final expenseA = Expense(
            id: expId,
            expenseCategoryId: catId,
            amount: const Money.fromPiastres(15000), // 150.00 EGP
            expenseName: 'شراء قطع غيار $runId',
            expenseDate: OrderDate.fromDate(now),
            notes: 'Expense referencing newly created category',
            categoryNameSnapshot: 'صيانة ومعدات $runId',
            createdAt: now,
            updatedAt: now,
          );
          await deviceA.expenseRepository.createExpense(expenseA);

          // Verify outbox ordering on Device A: category op must precede expense op
          final pendingOps = await deviceA.syncOperationsDao
              .getPendingOperations();
          final catOpIndex = pendingOps.indexWhere((o) => o.entityId == catId);
          final expOpIndex = pendingOps.indexWhere((o) => o.entityId == expId);
          expect(catOpIndex, isNot(equals(-1)));
          expect(expOpIndex, isNot(equals(-1)));
          expect(
            catOpIndex,
            lessThan(expOpIndex),
            reason:
                'Expense Category creation must precede Expense in sync outbox',
          );

          // 3. Push through Device A & Pull into Device B
          await deviceA.syncEngine.sync();
          await deviceB.syncEngine.sync();

          // 4. Verify Device B received both entities without FK violation
          final catOnB = await deviceB.expenseCategoryRepository
              .getCategoryById(catId);
          expect(catOnB, isNotNull);
          expect(catOnB!.id, equals(catId));
          expect(catOnB.name, equals('صيانة ومعدات $runId'));

          final expOnB = await deviceB.expenseRepository.getExpenseById(expId);
          expect(expOnB, isNotNull);
          expect(expOnB!.id, equals(expId));
          expect(expOnB.expenseCategoryId, equals(catId));
          expect(expOnB.amount.piastres, equals(15000));

          // Foreign Key Integrity Check on Device B SQLite
          final fkErrors = await deviceB.db
              .customSelect('PRAGMA foreign_key_check(expenses)')
              .get();
          expect(
            fkErrors,
            isEmpty,
            reason: 'No foreign key violations must exist in expenses table',
          );
        },
      );

      // =========================================================================
      // SCENARIO E — SERVICE + HISTORICAL PRICE IMMUTABILITY
      // =========================================================================
      test(
        'Scenario E: Modifying a Service price remotely updates the service catalog on Device B without mutating historical OrderItem prices',
        () async {
          // Read historical order item on Device B before service price update
          final itemBefore = await (deviceB.db.select(
            deviceB.db.orderItems,
          )..where((tbl) => tbl.id.equals(testOrderItemId))).getSingle();
          expect(itemBefore.unitPrice, equals(4000));
          expect(itemBefore.calculatedTotal, equals(24000));

          // Update the Service price on Supabase from 4000 to 8500 piastres
          final updateSrvRes = await probeDio.patch(
            '/services/$testServiceId',
            data: {
              'name': 'خدمة سجاد E2E $runId (Updated Price)',
              'price': 8500,
              'pricing_type': 'per_square_meter',
              'item_type_ids': ['00000000-0000-0000-0001-000000000003'],
              'service_item_types': [
                {
                  'item_type_id': '00000000-0000-0000-0001-000000000003',
                  'pricing_type': 'per_square_meter',
                  'price': 8500,
                },
              ],
            },
            options: Options(
              headers: {'X-Operation-ID': 'op-e2e-srv-update-$runId'},
              validateStatus: (_) => true,
            ),
          );
          expect(updateSrvRes.statusCode, isIn([200, 204]));

          // Device B pulls the updated service catalog
          final syncRes = await deviceB.syncEngine.sync();
          expect(syncRes.status, equals(SyncEngineStatus.completed));

          // Verify Device B has the updated service item type price
          final sitsOnB = await deviceB.servicesDao.getServiceItemTypes(
            testServiceId,
          );
          expect(sitsOnB, isNotEmpty);
          expect(sitsOnB.first.price, equals(8500));

          // CRITICAL INVARIANT: The historical OrderItem pricing MUST remain 4000
          final itemAfter = await (deviceB.db.select(
            deviceB.db.orderItems,
          )..where((tbl) => tbl.id.equals(testOrderItemId))).getSingle();
          expect(
            itemAfter.unitPrice,
            equals(4000),
            reason: 'Historical OrderItem unit_price must NOT be mutated',
          );
          expect(
            itemAfter.calculatedTotal,
            equals(24000),
            reason: 'Historical OrderItem calculated_total must NOT be mutated',
          );
        },
      );

      // =========================================================================
      // SCENARIO F — OFFLINE -> COLD RESTART -> RESTORE CONNECTIVITY -> SYNC
      // =========================================================================
      test(
        'Scenario F: Offline mutation survives application/database cold restart and synchronizes successfully upon network restoration',
        () async {
          final tempDir = Directory.systemTemp.createTempSync(
            'e2e_restart_test_',
          );
          final dbFile = File('${tempDir.path}/cold_restart.db');
          final custFId = 'c000000f-000f-400f-800f-$runId';
          final custFPhone =
              '011${(DateTime.now().microsecondsSinceEpoch % 100000000).toString().padLeft(8, '0')}';
          final now = DateTime.now();
          TestDevice? deviceF;
          TestDevice? deviceF2;

          try {
            // 1. Create Device F backed by a real SQLite file, starting offline
            deviceF = await TestDevice.create(
              name: 'Device F',
              baseUrl: apiBaseUrl,
              executor: NativeDatabase(dbFile),
              initialConnected: false,
            );

            // Seed local master data so foreign key constraints are met
            await seedLocalMasterData(
              deviceF,
              serviceId: testServiceId,
              servicePrice: 4000,
            );

            // Fast-forward sequence to current sequence to isolate from earlier scenario test changes
            final currentHead = await deviceA.syncStateDao
                .getLastAppliedSequence();
            await deviceF.syncStateDao.updateLastAppliedSequence(currentHead);

            // 2. Perform business mutation while offline
            final custF = Customer(
              id: custFId,
              name: 'عميل أوفلاين $runId',
              phone: custFPhone,
              notes: 'Created while strictly offline',
              createdAt: now,
              updatedAt: now,
            );
            await deviceF.customerRepository.createCustomer(custF);

            // Verify pending outbox operation exists
            final pendingBeforeRestart = await deviceF.syncOperationsDao
                .getPendingOperations();
            expect(pendingBeforeRestart, hasLength(1));
            expect(pendingBeforeRestart.first.entityId, equals(custFId));
            expect(pendingBeforeRestart.first.status, equals('pending'));

            // 3. Attempt sync while offline -> operation remains pending
            final offlineSyncState = await deviceF.syncEngine.sync();
            expect(offlineSyncState.pendingOperationsCount, equals(1));

            // 4. Simulate cold application restart: completely dispose deviceF and close SQLite connection
            await deviceF.dispose();
            deviceF = null;

            // 5. Re-open new TestDevice with the SAME SQLite file
            deviceF2 = await TestDevice.create(
              name: 'Device F (Restarted)',
              baseUrl: apiBaseUrl,
              executor: NativeDatabase(dbFile),
              initialConnected: false,
            );

            // Verify pending mutation SURVIVED cold restart
            final pendingAfterRestart = await deviceF2.syncOperationsDao
                .getPendingOperations();
            expect(
              pendingAfterRestart,
              hasLength(1),
              reason:
                  'Pending SyncOperation must survive application cold restart',
            );
            expect(pendingAfterRestart.first.entityId, equals(custFId));
            expect(pendingAfterRestart.first.status, equals('pending'));

            // 6. Restore connectivity
            deviceF2.networkInfo.setConnected(true);

            // 7. Run SyncEngine on the restarted device
            final onlineSyncState = await deviceF2.syncEngine.sync();
            expect(onlineSyncState.status, equals(SyncEngineStatus.completed));
            expect(onlineSyncState.pendingOperationsCount, equals(0));

            // Verify operation reached synced state
            final opFinalState = await (deviceF2.db.select(
              deviceF2.db.syncOperations,
            )..where((tbl) => tbl.entityId.equals(custFId))).getSingle();
            expect(opFinalState.status, equals('synced'));

            // Verify entity exists on live Supabase
            final remoteCustF = await probeDio.get('/customers/$custFId');
            expect(remoteCustF.statusCode, equals(200));
            expect(remoteCustF.data['name'], equals('عميل أوفلاين $runId'));

            await deviceF2.dispose();
            deviceF2 = null;
          } finally {
            await deviceF?.dispose();
            await deviceF2?.dispose();
            if (tempDir.existsSync()) {
              try {
                tempDir.deleteSync(recursive: true);
              } catch (_) {}
            }
          }
        },
      );

      // =========================================================================
      // SCENARIO G — IDEMPOTENCY / RETRY
      // =========================================================================
      test(
        'Scenario G: Replaying the identical operation ID against live Supabase returns cached response without duplicate records',
        () async {
          final idemCustId = 'c0000007-0007-4007-8007-$runId';
          final idemPhone =
              '012${(DateTime.now().microsecondsSinceEpoch % 100000000).toString().padLeft(8, '0')}';
          final idemOpId = 'op-e2e-idem-test-$runId';

          // First attempt: create customer
          final res1 = await probeDio.post(
            '/customers',
            data: {
              'id': idemCustId,
              'name': 'Idempotent Customer Test',
              'phone': idemPhone,
              'notes': 'Initial attempt',
            },
            options: Options(
              headers: {'X-Operation-ID': idemOpId},
              validateStatus: (_) => true,
            ),
          );
          expect(res1.statusCode, isIn([200, 201]));

          // Second attempt: replay with exact same X-Operation-ID
          final res2 = await probeDio.post(
            '/customers',
            data: {
              'id': idemCustId,
              'name': 'Idempotent Customer Test',
              'phone': idemPhone,
              'notes': 'Initial attempt',
            },
            options: Options(
              headers: {'X-Operation-ID': idemOpId},
              validateStatus: (_) => true,
            ),
          );
          expect(
            res2.statusCode,
            isIn([200, 201]),
            reason: 'Idempotent replay must succeed with cached status code',
          );

          // Verify remote database contains exactly ONE customer with this ID
          final checkRes = await probeDio.get('/customers/$idemCustId');
          expect(checkRes.statusCode, equals(200));
          expect(checkRes.data['id'], equals(idemCustId));
        },
      );

      // =========================================================================
      // SCENARIO H & I — DEVICE A -> SUPABASE -> DEVICE B & UPDATE PROPAGATION
      // =========================================================================
      test(
        'Scenario H & I: Full synchronization chain Device A -> Supabase -> Device B converges business state across customer and order updates',
        () async {
          // 1. Device A updates Customer
          final existingCustA = (await deviceA.customerRepository
              .getCustomerById(testCustomerId))!;
          final updatedCustA = existingCustA.copyWith(
            notes: 'Updated notes from Device A after convergence',
          );
          await deviceA.customerRepository.updateCustomer(updatedCustA);

          // 2. Device A updates Order Notes via Drift direct update (or status transition)
          await (deviceA.db.update(
            deviceA.db.orders,
          )..where((tbl) => tbl.id.equals(testOrderId))).write(
            const app_db.OrdersCompanion(
              notes: drift.Value('Special delivery instructions added on A'),
            ),
          );
          // Record sync operation for order update
          await deviceA.syncOperationsDao.recordOperation(
            entityType: 'order',
            entityId: testOrderId,
            operationType: 'update',
            payload: jsonEncode({
              'id': testOrderId,
              'notes': 'Special delivery instructions added on A',
              'updated_at': DateTime.now().toIso8601String(),
            }),
          );

          // 3. Push from Device A & Pull to Device B
          await deviceA.syncEngine.sync();
          await deviceB.syncEngine.sync();

          // 4. Assert Business State Convergence across Device A, Supabase, and Device B
          final custOnA = (await deviceA.customerRepository.getCustomerById(
            testCustomerId,
          ))!;
          final custOnB = (await deviceB.customerRepository.getCustomerById(
            testCustomerId,
          ))!;
          final remoteCust = (await probeDio.get(
            '/customers/$testCustomerId',
          )).data;

          expect(
            custOnB.notes,
            equals('Updated notes from Device A after convergence'),
          );
          expect(custOnA.notes, equals(custOnB.notes));
          expect(remoteCust['notes'], equals(custOnB.notes));

          final ordOnA = (await deviceA.orderRepository.getOrderById(
            testOrderId,
          ))!;
          final ordOnB = (await deviceB.orderRepository.getOrderById(
            testOrderId,
          ))!;
          final remoteOrd = (await probeDio.get('/orders/$testOrderId')).data;

          expect(
            ordOnB.notes,
            equals('Special delivery instructions added on A'),
          );
          expect(ordOnA.notes, equals(ordOnB.notes));
          expect(remoteOrd['notes'], equals(ordOnB.notes));

          // Foreign keys and IDs remain strictly stable
          expect(ordOnB.customerId, equals(testCustomerId));
          expect(ordOnB.orderNumber, equals(testOrderNumber));
        },
      );

      // =========================================================================
      // SCENARIO J — OPTIMISTIC CONCURRENCY CONTROL (OCC Integration)
      // =========================================================================
      test(
        'Scenario J: Concurrent updates on same server_version allows exactly one winner; stale base_version receives 409 CONCURRENCY_CONFLICT',
        () async {
          final occCustId = 'c000000a-000a-400a-800a-$runId';
          final occPhone =
              '010${(DateTime.now().microsecondsSinceEpoch % 100000000).toString().padLeft(8, '0')}';

          // 1. Create baseline customer on remote Supabase (server_version = 1)
          final initRes = await probeDio.post(
            '/customers',
            data: {
              'id': occCustId,
              'name': 'OCC Baseline Customer',
              'phone': occPhone,
            },
            options: Options(
              headers: {'X-Operation-ID': 'op-occ-init-$runId'},
              validateStatus: (_) => true,
            ),
          );
          expect(initRes.statusCode, isIn([200, 201]));

          // Read server_version
          final checkRes = await probeDio.get('/customers/$occCustId');
          final currentVersion = checkRes.data['server_version'] as int;

          // 2. Client A updates with matching base_version -> Succeeds
          final winnerRes = await probeDio.patch(
            '/customers/$occCustId',
            data: {'name': 'OCC Client A Update (Winner)'},
            options: Options(
              headers: {
                'X-Operation-ID': 'op-occ-winner-$runId',
                'X-Base-Version': currentVersion,
              },
              validateStatus: (_) => true,
            ),
          );
          expect(winnerRes.statusCode, equals(200));
          expect(winnerRes.data['server_version'], equals(currentVersion + 1));

          // 3. Client B updates with stale base_version (original version) -> Rejected with 409
          final staleRes = await probeDio.patch(
            '/customers/$occCustId',
            data: {'name': 'OCC Client B Update (Stale)'},
            options: Options(
              headers: {
                'X-Operation-ID': 'op-occ-stale-$runId',
                'X-Base-Version': currentVersion, // Stale!
              },
              validateStatus: (_) => true,
            ),
          );
          expect(staleRes.statusCode, equals(409));
          expect(staleRes.data['code'], equals('CONCURRENCY_CONFLICT'));

          // 4. Verify stale write did NOT overwrite server state
          final finalRemote = await probeDio.get('/customers/$occCustId');
          expect(
            finalRemote.data['name'],
            equals('OCC Client A Update (Winner)'),
            reason:
                'Authoritative server state must reflect the winning update',
          );

          // 5. Device B pulls changes and converges to the winning state
          await deviceB.syncEngine.sync();
          final custOnB = await deviceB.customerRepository.getCustomerById(
            occCustId,
          );
          expect(custOnB, isNotNull);
          expect(custOnB!.name, equals('OCC Client A Update (Winner)'));
        },
      );

      // =========================================================================
      // SCENARIO K & INITIAL SNAPSHOT — CURSOR_TOO_OLD RECOVERY & BOOTSTRAP
      // =========================================================================
      test(
        'Scenario K & Initial Snapshot: Empty device hydrates complete authoritative baseline across all tiers, and snapshot recovery preserves pending outbox operations',
        () async {
          // 1. Initial Snapshot Bootstrap for a new device
          final deviceNew = await TestDevice.create(
            name: 'Device New Bootstrap',
            baseUrl: apiBaseUrl,
          );

          // Fetch live authoritative snapshot from Supabase
          final snapshot = await deviceNew.remoteDataSource.getSnapshot();
          expect(snapshot.latestSequence, greaterThan(0));
          expect(snapshot.changes, isNotEmpty);

          // Apply snapshot to empty database
          await deviceNew.changeApplier.applySnapshot(snapshot);

          // Verify baseline cursor established
          final baselineCursor = await deviceNew.syncStateDao
              .getLastAppliedSequence();
          expect(baselineCursor, equals(snapshot.latestSequence));

          // Verify all tiers populated in local Drift
          final masterServices = await deviceNew.servicesDao.getAllServices();
          expect(masterServices, isNotEmpty, reason: 'Services tier hydrated');

          final itemTypes = await (deviceNew.db.select(
            deviceNew.db.itemTypes,
          )).get();
          expect(itemTypes, isNotEmpty, reason: 'Item types tier hydrated');

          final customers = await (deviceNew.db.select(
            deviceNew.db.customers,
          )).get();
          expect(customers, isNotEmpty, reason: 'Customers tier hydrated');

          final orders = await (deviceNew.db.select(deviceNew.db.orders)).get();
          expect(orders, isNotEmpty, reason: 'Orders tier hydrated');

          // 2. CURSOR_TOO_OLD Recovery with Outbox Preservation
          // Create an unpushed pending local mutation on deviceNew
          final pendingCustId = 'c000000b-000b-400b-800b-$runId';
          final pendingCustPhone =
              '015${(DateTime.now().microsecondsSinceEpoch % 100000000).toString().padLeft(8, '0')}';
          final now = DateTime.now();

          final pendingCust = Customer(
            id: pendingCustId,
            name: 'عميل معلق أثناء ريكفري $runId',
            phone: pendingCustPhone,
            notes: 'Must not be overwritten by snapshot recovery',
            createdAt: now,
            updatedAt: now,
          );
          await deviceNew.customerRepository.createCustomer(pendingCust);

          // Verify outbox has 1 pending operation
          final pendingBeforeSnapshot = await deviceNew.syncOperationsDao
              .getPendingOperations();
          expect(
            pendingBeforeSnapshot.any((o) => o.entityId == pendingCustId),
            isTrue,
          );

          // Simulate snapshot recovery re-execution
          await deviceNew.changeApplier.applySnapshot(snapshot);

          // CRITICAL INVARIANT: Pending outbox operation must be PRESERVED
          final pendingAfterSnapshot = await deviceNew.syncOperationsDao
              .getPendingOperations();
          expect(
            pendingAfterSnapshot.any((o) => o.entityId == pendingCustId),
            isTrue,
            reason:
                'Outbox operations must NEVER be dropped or overwritten by snapshot recovery',
          );

          // Verify local unpushed customer still exists intact
          final preservedCust = await deviceNew.customerRepository
              .getCustomerById(pendingCustId);
          expect(preservedCust, isNotNull);
          expect(preservedCust!.name, equals('عميل معلق أثناء ريكفري $runId'));

          // Preserved mutation can now be pushed
          await deviceNew.syncEngine.sync();
          final finalPending = await deviceNew.syncOperationsDao
              .getPendingOperations();
          expect(
            finalPending.any((o) => o.entityId == pendingCustId),
            isFalse,
            reason: 'Preserved mutation successfully synced after recovery',
          );

          await deviceNew.dispose();
        },
      );

      // =========================================================================
      // NEGATIVE & SAFETY INVARIANTS
      // =========================================================================
      test(
        'Negative & Safety Invariants: Order number immutability (BR-018), zero duplicate active storage records, and total database FK integrity',
        () async {
          // 1. Order Number Immutability (BR-018)
          // Attempting to apply a remote change with a mutated order number for an existing order
          final existingOrder = (await deviceB.orderRepository.getOrderById(
            testOrderId,
          ))!;
          final originalOrderNumber = existingOrder.orderNumber;

          final maliciousChange = SyncChangeDto(
            sequence: (await deviceB.syncStateDao.getLastAppliedSequence()) + 1,
            operationId: 'op-malicious-ord-num-$runId',
            entityType: 'order',
            entityId: testOrderId,
            operationType: 'update',
            payload: {
              'id': testOrderId,
              'order_number': 'ORD-MUTATED-ILLEGALLY-999',
              'notes': 'Attempting order number mutation',
            },
            serverVersion: 10,
            createdAt: DateTime.now(),
          );

          await deviceB.changeApplier.applyBatch([maliciousChange]);

          final orderAfterMaliciousChange = (await deviceB.orderRepository
              .getOrderById(testOrderId))!;
          expect(
            orderAfterMaliciousChange.orderNumber,
            equals(originalOrderNumber),
            reason:
                'BR-018: Order number must remain immutable even across updates',
          );

          // 2. Storage Record Invariant: Exactly 1 active record per order item
          final storageRecords = await (deviceB.db.select(
            deviceB.db.storageRecords,
          )..where((tbl) => tbl.orderItemId.equals(testOrderItemId))).get();
          final activeRecords = storageRecords
              .where((r) => r.isActive)
              .toList();
          expect(
            activeRecords,
            hasLength(1),
            reason: 'There must be at most one active storage record per item',
          );

          // 3. Database-wide Foreign Key Integrity Verification
          final deviceAFkErrors = await deviceA.db
              .customSelect('PRAGMA foreign_key_check')
              .get();
          final deviceBFkErrors = await deviceB.db
              .customSelect('PRAGMA foreign_key_check')
              .get();
          expect(
            deviceAFkErrors,
            isEmpty,
            reason: 'Device A SQLite database must have zero FK violations',
          );
          expect(
            deviceBFkErrors,
            isEmpty,
            reason: 'Device B SQLite database must have zero FK violations',
          );
        },
      );
    },
    skip: _mutationE2eSkipReason(),
  );
}
