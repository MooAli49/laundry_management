import 'dart:async';

import 'package:dio/dio.dart';
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
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/daos/sync_state_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart'
    hide Customer;
import 'package:laundry_management/data/local/database/seed_data.dart';
import 'package:laundry_management/data/repositories/customer_repository_impl.dart';
import 'package:laundry_management/data/sync/remote_change_applier.dart';
import 'package:laundry_management/data/sync/sync_engine.dart';
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/domain/sync/sync_error_classifier.dart';
import 'package:laundry_management/domain/sync/sync_retry_policy.dart';

class MockableNetworkInfo implements NetworkInfo {
  bool _isConnected;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  MockableNetworkInfo({bool initialConnected = true})
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

void main() {
  group('Objective 7 — Canonical Seed & Offline Sync Regression Test', () {
    late AppDatabase db;
    late MockableNetworkInfo networkInfo;
    late SyncOperationsDao syncOperationsDao;
    late SyncStateDao syncStateDao;
    late CustomersDao customersDao;
    late CustomerRepositoryImpl customerRepository;
    late RemoteChangeApplier changeApplier;
    late SyncRemoteDataSource remoteDataSource;
    late RemoteApiDispatcher remoteApiDispatcher;
    late SyncEngine syncEngine;
    late Dio probeDio;
    late String apiBaseUrl;

    final runHex = (DateTime.now().microsecondsSinceEpoch % 0xFFFFFFFFFFFF)
        .toRadixString(16)
        .padLeft(12, '0');
    final testCustomerId = 'c7000001-0001-4001-8001-$runHex';
    final testCustomerPhone =
        '015${(DateTime.now().microsecondsSinceEpoch % 100000000).toString().padLeft(8, '0')}';

    setUpAll(() async {
      final config = SupabaseConfig.resolve();
      apiBaseUrl = config.apiUrl;

      final probeClient = DioClient(baseUrl: apiBaseUrl);
      probeDio = probeClient.dio;

      // Verify reachability to Development Supabase
      try {
        final probeRes = await probeDio.get(
          '/api/v1/customers',
          queryParameters: {'limit': 1},
        );
        if (probeRes.statusCode != 200) {
          fail(
            'Development Supabase probe returned status ${probeRes.statusCode}',
          );
        }
      } catch (e) {
        fail(
          'Live development Supabase backend at $apiBaseUrl is unreachable: $e. Ensure development Supabase is reachable before running integration tests.',
        );
      }
    });

    tearDown(() async {
      syncEngine.dispose();
      networkInfo.dispose();
      await db.close();
    });

    test(
      '14-Step Exact Scenario: Fresh terminal canonical seed, zero outbox ops, remote pull convergence, offline mutation, network failure retry, exactly-once push, zero duplicates',
      () async {
        // ---------------------------------------------------------------------
        // Step 1: Empty local SQLite database
        // ---------------------------------------------------------------------
        // Canonical seeding is opt-in; enable it explicitly for this scenario.
        db = AppDatabase(NativeDatabase.memory(), true);
        syncOperationsDao = SyncOperationsDao(db);
        syncStateDao = SyncStateDao(db);
        customersDao = CustomersDao(db);
        customerRepository = CustomerRepositoryImpl(
          customersDao: customersDao,
          syncOperationsDao: syncOperationsDao,
          db: db,
        );

        changeApplier = RemoteChangeApplier(
          db: db,
          syncStateDao: syncStateDao,
          syncOperationsDao: syncOperationsDao,
        );

        networkInfo = MockableNetworkInfo(initialConnected: true);

        final client = DioClient(
          baseUrl: apiBaseUrl,
          receiveTimeout: const Duration(seconds: 30),
          connectTimeout: const Duration(seconds: 30),
        );
        final dio = client.dio;

        remoteDataSource = SyncRemoteDataSourceImpl(SyncRemoteApi(dio));
        remoteApiDispatcher = RemoteApiDispatcher(
          customerApi: CustomerRemoteApi(dio),
          orderApi: OrderRemoteApi(dio),
          paymentApi: PaymentRemoteApi(dio),
          refundApi: RefundRemoteApi(dio),
          storageApi: StorageRemoteApi(dio),
          expenseApi: ExpenseRemoteApi(dio),
          masterDataApi: MasterDataRemoteApi(dio),
        );

        syncEngine = SyncEngine(
          syncOperationsDao: syncOperationsDao,
          remoteApiDispatcher: remoteApiDispatcher,
          networkInfo: networkInfo,
          retryPolicy: SyncRetryPolicy(),
          errorClassifier: const SyncErrorClassifier(),
          syncRemoteDataSource: remoteDataSource,
          remoteChangeApplier: changeApplier,
          syncStateDao: syncStateDao,
        );

        // ---------------------------------------------------------------------
        // Step 2: Initialize canonical local seed
        // ---------------------------------------------------------------------
        // AppDatabase already triggered seedInitialData via beforeOpen.
        // We verify the canonical catalog exists locally offline.
        final itemTypes = await db.select(db.itemTypes).get();
        final expenseCategories = await db.select(db.expenseCategories).get();
        final services = await db.select(db.services).get();
        final serviceItemTypes = await db.select(db.serviceItemTypes).get();
        final carpetSizes = await db.select(db.carpetSizes).get();
        final storageLocations = await db.select(db.storageLocations).get();
        final storageLocationItemTypes = await db
            .select(db.storageLocationItemTypes)
            .get();
        final itemDefinitions = await db.select(db.itemDefinitions).get();
        final businessSettings = await db.select(db.businessSettings).get();

        expect(itemTypes.length, equals(4), reason: '4 canonical item_types');
        expect(
          expenseCategories.length,
          equals(7),
          reason: '7 canonical expense_categories',
        );
        expect(services.length, equals(5), reason: '5 canonical services');
        expect(
          serviceItemTypes.length,
          equals(5),
          reason: '5 canonical service_item_types',
        );
        expect(
          carpetSizes.length,
          equals(3),
          reason: '3 canonical carpet_sizes',
        );
        expect(
          storageLocations.length,
          equals(5),
          reason: '5 canonical storage_locations',
        );
        expect(
          storageLocationItemTypes.length,
          equals(9),
          reason: '9 canonical storage_location_item_types',
        );
        expect(
          itemDefinitions.length,
          equals(10),
          reason: '10 canonical item_definitions',
        );
        expect(
          businessSettings.length,
          equals(1),
          reason: '1 canonical business_settings',
        );

        // ---------------------------------------------------------------------
        // Step 3: Confirm zero pending outbox operations from seed
        // ---------------------------------------------------------------------
        final seedOutboxOps = await syncOperationsDao.getPendingOperations();
        expect(
          seedOutboxOps,
          isEmpty,
          reason:
              'Canonical local seed must be strictly outbox-free (zero sync_operations)',
        );

        final allOps = await db.select(db.syncOperations).get();
        expect(
          allOps,
          isEmpty,
          reason:
              'No sync_operations table rows must exist after canonical seed',
        );
        expect(
          await syncStateDao.getLastAppliedSequence(),
          SeedData.canonicalBaselineSequence,
          reason: 'Canonical seed must start at the remote baseline cursor',
        );

        // ---------------------------------------------------------------------
        // Step 4: Connect to development Supabase
        // ---------------------------------------------------------------------
        final probeResponse = await probeDio.get(
          '/api/v1/sync/changes',
          queryParameters: {'after': 0, 'limit': 100},
        );
        expect(probeResponse.statusCode, equals(200));
        final changes = probeResponse.data['changes'] as List;
        expect(
          changes.length,
          greaterThanOrEqualTo(35),
          reason:
              'Development Supabase should have at least the 35 canonical baseline changes',
        );
        final latestSeq = (probeResponse.data['latest_sequence'] as num)
            .toInt();
        expect(
          latestSeq,
          greaterThanOrEqualTo(35),
          reason: 'Latest sequence must be at least 35',
        );

        // ---------------------------------------------------------------------
        // Step 5: Pull canonical remote state
        // ---------------------------------------------------------------------
        await syncEngine.pull();

        // ---------------------------------------------------------------------
        // Step 6: Confirm local master data converges correctly
        // ---------------------------------------------------------------------
        final itemTypesAfterPull = await db.select(db.itemTypes).get();
        final servicesAfterPull = await db.select(db.services).get();
        final categoriesAfterPull = await db.select(db.expenseCategories).get();
        final definitionsAfterPull = await db.select(db.itemDefinitions).get();

        // Master data should NOT be duplicated upon convergence
        expect(
          itemTypesAfterPull.map((e) => e.id).toSet().length,
          equals(itemTypesAfterPull.length),
          reason: 'Item types must contain no duplicates',
        );
        expect(
          servicesAfterPull.map((e) => e.id).toSet().length,
          equals(servicesAfterPull.length),
          reason: 'Services must contain no duplicates',
        );
        expect(
          categoriesAfterPull.map((e) => e.id).toSet().length,
          equals(categoriesAfterPull.length),
          reason: 'Expense categories must contain no duplicates',
        );
        expect(
          definitionsAfterPull.map((e) => e.id).toSet().length,
          equals(definitionsAfterPull.length),
          reason: 'Item definitions must contain no duplicates',
        );
        expect(
          definitionsAfterPull.length,
          greaterThanOrEqualTo(10),
          reason: 'Item definitions must include at least canonical items',
        );

        // Pulling remote state must NEVER create outbox operations
        final outboxAfterPull = await syncOperationsDao.getPendingOperations();
        expect(
          outboxAfterPull,
          isEmpty,
          reason: 'Applying remote changes must not generate outbox operations',
        );

        // Cursor must be updated
        final syncState = await syncStateDao.getSyncState();
        expect(
          syncState.lastAppliedSequence,
          greaterThanOrEqualTo(35),
          reason: 'Pull cursor must advance to the remote sequence',
        );

        // ---------------------------------------------------------------------
        // Step 7: Create one legitimate offline business mutation
        // ---------------------------------------------------------------------
        final now = DateTime.now().toUtc();
        final newCustomer = Customer(
          id: testCustomerId,
          name: 'عميل اختبار التزامن $runHex',
          phone: testCustomerPhone,
          createdAt: now,
          updatedAt: now,
        );

        final createdCustomer = await customerRepository.createCustomer(
          newCustomer,
        );
        expect(
          createdCustomer.id,
          equals(testCustomerId),
          reason: 'Customer creation must succeed locally',
        );

        // ---------------------------------------------------------------------
        // Step 8: Confirm exactly the expected outbox operation exists
        // ---------------------------------------------------------------------
        final pendingAfterMutation = await syncOperationsDao
            .getPendingOperations();
        expect(
          pendingAfterMutation.length,
          equals(1),
          reason:
              'Exactly 1 outbox operation must be created for the new customer',
        );
        final mutationOp = pendingAfterMutation.first;
        expect(mutationOp.entityType, equals('customer'));
        expect(mutationOp.entityId, equals(testCustomerId));
        expect(mutationOp.operationType, equals('create'));
        expect(mutationOp.status, equals('pending'));

        // ---------------------------------------------------------------------
        // Step 9: Simulate network failure
        // ---------------------------------------------------------------------
        networkInfo.setConnected(false);
        expect(await networkInfo.isConnected, isFalse);

        // Trigger sync while disconnected
        await syncEngine.sync();

        // ---------------------------------------------------------------------
        // Step 10: Confirm the mutation remains locally persisted and pending
        // ---------------------------------------------------------------------
        final localCustomer = await customersDao.getCustomerById(
          testCustomerId,
        );
        expect(
          localCustomer,
          isNotNull,
          reason: 'Customer must remain locally persisted during offline state',
        );
        expect(localCustomer!.name, equals(newCustomer.name));

        final pendingDuringOffline = await syncOperationsDao
            .getPendingOperations();
        expect(
          pendingDuringOffline.length,
          equals(1),
          reason:
              'Mutation outbox operation must remain pending during network outage',
        );
        expect(pendingDuringOffline.first.id, equals(mutationOp.id));

        // Verify remote Supabase does NOT have the customer yet
        try {
          final remoteCheckBeforePush = await probeDio.get(
            '/api/v1/customers/$testCustomerId',
          );
          fail(
            'Customer must not exist on remote Supabase before push, but got 200: ${remoteCheckBeforePush.data}',
          );
        } on DioException catch (e) {
          expect(
            e.response?.statusCode,
            equals(404),
            reason: 'Customer must return 404 on remote Supabase before push',
          );
        }

        // ---------------------------------------------------------------------
        // Step 11: Restore connectivity
        // ---------------------------------------------------------------------
        networkInfo.setConnected(true);
        expect(await networkInfo.isConnected, isTrue);

        // ---------------------------------------------------------------------
        // Step 12: Push again
        // ---------------------------------------------------------------------
        await syncEngine.sync();

        // ---------------------------------------------------------------------
        // Step 13: Confirm the server receives it exactly once
        // ---------------------------------------------------------------------
        final pendingAfterPush = await syncOperationsDao.getPendingOperations();
        expect(
          pendingAfterPush,
          isEmpty,
          reason:
              'Outbox operation must be completed/cleared after successful push',
        );

        final remoteCheckAfterPush = await probeDio.get(
          '/api/v1/customers/$testCustomerId',
        );
        expect(remoteCheckAfterPush.statusCode, equals(200));
        final customerAfterPush =
            remoteCheckAfterPush.data as Map<String, dynamic>;
        expect(
          customerAfterPush['id'],
          equals(testCustomerId),
          reason: 'Server must receive and persist the customer exactly once',
        );
        expect(customerAfterPush['name'], equals(newCustomer.name));

        // ---------------------------------------------------------------------
        // Step 14: Confirm no duplicate record is created
        // ---------------------------------------------------------------------
        // A) Confirm local table has exactly 1 record
        final localCustomersWithId = await (db.select(
          db.customers,
        )..where((t) => t.id.equals(testCustomerId))).get();
        expect(
          localCustomersWithId.length,
          equals(1),
          reason: 'Local database must contain exactly 1 customer record',
        );

        // B) Run another sync cycle to verify idempotency
        await syncEngine.sync();
        final pendingAfterSecondSync = await syncOperationsDao
            .getPendingOperations();
        expect(pendingAfterSecondSync, isEmpty);

        final remoteCheckSecondSync = await probeDio.get(
          '/api/v1/customers/$testCustomerId',
        );
        expect(remoteCheckSecondSync.statusCode, equals(200));
        final customerSecondSync =
            remoteCheckSecondSync.data as Map<String, dynamic>;
        expect(
          customerSecondSync['id'],
          equals(testCustomerId),
          reason:
              'Server must still have the customer record after second sync',
        );

        // C) Verify canonical seed records were never treated as mutations
        final allSyncOpsHistory = await db.select(db.syncOperations).get();
        final seedEntityTypes = {
          'item_types',
          'expense_categories',
          'services',
          'service_item_types',
          'carpet_sizes',
          'storage_locations',
          'storage_location_item_types',
          'item_definitions',
          'business_settings',
        };
        for (final op in allSyncOpsHistory) {
          expect(
            seedEntityTypes.contains(op.entityType),
            isFalse,
            reason:
                'Canonical seed entities (${op.entityType}) must NEVER create sync operations!',
          );
        }
      },
    );
  });
}
