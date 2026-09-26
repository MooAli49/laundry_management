import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:laundry_management/data/datasources/remote/supabase_realtime_sync_adapter.dart';
import 'package:laundry_management/data/datasources/remote/sync_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/sync_remote_data_source.dart';
import 'package:laundry_management/data/local/daos/customers_dao.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/storage_locations_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/daos/sync_state_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart'
    as app_db;
import 'package:laundry_management/data/repositories/customer_repository_impl.dart';
import 'package:laundry_management/data/repositories/order_repository_impl.dart';
import 'package:laundry_management/data/repositories/payment_repository_impl.dart';
import 'package:laundry_management/data/repositories/storage_repository_impl.dart';
import 'package:laundry_management/data/sync/remote_change_applier.dart';
import 'package:laundry_management/data/sync/sync_engine.dart';
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/entities/payment.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/enums/payment_method.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/sync/sync_error_classifier.dart';
import 'package:laundry_management/domain/sync/sync_retry_policy.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _AlwaysConnectedNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<bool> get onConnectivityChanged => const Stream.empty();
}

class TestDevice {
  final String name;
  final app_db.AppDatabase db;
  final SyncOperationsDao syncOperationsDao;
  final SyncStateDao syncStateDao;
  final CustomersDao customersDao;
  final OrdersDao ordersDao;
  final PaymentsDao paymentsDao;
  final StorageRecordsDao storageRecordsDao;
  final StorageLocationsDao storageLocationsDao;
  final RemoteChangeApplier changeApplier;
  final SyncRemoteDataSource remoteDataSource;
  final SupabaseClient supabaseClient;
  final SupabaseRealtimeSyncAdapter realtimeAdapter;
  final RemoteApiDispatcher remoteApiDispatcher;
  final SyncEngine syncEngine;

  final Dio dio;

  final CustomerRepositoryImpl customerRepository;
  final OrderRepositoryImpl orderRepository;
  final PaymentRepositoryImpl paymentRepository;
  final StorageRepositoryImpl storageRepository;

  TestDevice({
    required this.name,
    required this.db,
    required this.dio,
    required this.syncOperationsDao,
    required this.syncStateDao,
    required this.customersDao,
    required this.ordersDao,
    required this.paymentsDao,
    required this.storageRecordsDao,
    required this.storageLocationsDao,
    required this.changeApplier,
    required this.remoteDataSource,
    required this.supabaseClient,
    required this.realtimeAdapter,
    required this.remoteApiDispatcher,
    required this.syncEngine,
    required this.customerRepository,
    required this.orderRepository,
    required this.paymentRepository,
    required this.storageRepository,
  });

  static Future<TestDevice> create({
    required String name,
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) async {
    final db = app_db.AppDatabase(NativeDatabase.memory());
    final syncOperationsDao = SyncOperationsDao(db);
    final syncStateDao = SyncStateDao(db);
    final customersDao = CustomersDao(db);
    final ordersDao = OrdersDao(db);
    final paymentsDao = PaymentsDao(db);
    final storageRecordsDao = StorageRecordsDao(db);
    final storageLocationsDao = StorageLocationsDao(db);

    final changeApplier = RemoteChangeApplier(
      db: db,
      syncStateDao: syncStateDao,
    );

    final dioClient = DioClient(
      receiveTimeout: const Duration(seconds: 30),
      connectTimeout: const Duration(seconds: 30),
    );
    final dio = dioClient.dio;

    final remoteDataSource = SyncRemoteDataSourceImpl(SyncRemoteApi(dio));
    final supabaseClient = SupabaseClient(supabaseUrl, supabaseAnonKey);
    final realtimeAdapter = SupabaseRealtimeSyncAdapter(client: supabaseClient);

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
      networkInfo: _AlwaysConnectedNetworkInfo(),
      retryPolicy: SyncRetryPolicy(),
      errorClassifier: const SyncErrorClassifier(),
      syncRemoteDataSource: remoteDataSource,
      remoteChangeApplier: changeApplier,
      syncStateDao: syncStateDao,
      realtimeAdapter: realtimeAdapter,
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

    return TestDevice(
      name: name,
      db: db,
      dio: dio,
      syncOperationsDao: syncOperationsDao,
      syncStateDao: syncStateDao,
      customersDao: customersDao,
      ordersDao: ordersDao,
      paymentsDao: paymentsDao,
      storageRecordsDao: storageRecordsDao,
      storageLocationsDao: storageLocationsDao,
      changeApplier: changeApplier,
      remoteDataSource: remoteDataSource,
      supabaseClient: supabaseClient,
      realtimeAdapter: realtimeAdapter,
      remoteApiDispatcher: remoteApiDispatcher,
      syncEngine: syncEngine,
      customerRepository: customerRepository,
      orderRepository: orderRepository,
      paymentRepository: paymentRepository,
      storageRepository: storageRepository,
    );
  }

  Future<void> dispose() async {
    await realtimeAdapter.unsubscribe();
    await realtimeAdapter.dispose();
    syncEngine.dispose();
    dio.close();
    await db.close();
  }
}

void main() {
  group('Phase 4 — Two-Device Lifecycle & Storage Sync Integration Tests', () {
    late DioClient dioClient;
    late Dio dio;
    late String supabaseUrl;
    late String supabaseAnonKey;
    late TestDevice deviceA;
    late TestDevice deviceB;
    bool isLiveBackendAvailable = true;

    final runId = (DateTime.now().microsecondsSinceEpoch % 0xFFFFFFFFFFFF)
        .toRadixString(16)
        .padLeft(12, '0');

    late final String testCustomerId;
    late final String testCustomerPhone;
    late final String testOrder1Id;
    late final String testOrder1Number;
    late final String testItem1Id;
    late final String testOrder2Id;
    late final String testOrder2Number;
    late final String testItem2Id;

    const pieceServiceId = '00000000-0000-0000-0002-000000000001';
    const pieceItemTypeId = '00000000-0000-0000-0001-000000000001';
    const rack1LocationId = '00000000-0000-0000-0006-000000000001';

    setUpAll(() async {
      dioClient = DioClient(
        receiveTimeout: const Duration(seconds: 30),
        connectTimeout: const Duration(seconds: 30),
      );
      dio = dioClient.dio;

      supabaseUrl = const String.fromEnvironment(
        'SUPABASE_URL_ROOT',
        defaultValue: 'https://dyhfgnbhijukbdptreto.supabase.co',
      );
      supabaseAnonKey = const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR5aGZnbmJoaWp1a2JkcHRyZXRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg0NjcxNDcsImV4cCI6MjEwNDA0MzE0N30.gInc0tuzZiWq8EeEqbNBYa_Ay4liCcB4iGGOjUMnOBw',
      );

      testCustomerId = 'c4000001-0001-4001-8001-$runId';
      testCustomerPhone =
          '015${(DateTime.now().microsecondsSinceEpoch % 100000000).toString().padLeft(8, '0')}';
      testOrder1Id = 'd4000001-0001-4001-8001-$runId';
      testOrder1Number = 'ORD-P4-1-$runId';
      testItem1Id = 'e4000001-0001-4001-8001-$runId';

      testOrder2Id = 'd4000002-0002-4002-8002-$runId';
      testOrder2Number = 'ORD-P4-2-$runId';
      testItem2Id = 'e4000002-0002-4002-8002-$runId';

      drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

      try {
        final res = await dio.get('/customers', queryParameters: {'limit': 1});
        if (res.statusCode != 200) {
          isLiveBackendAvailable = false;
        }
      } catch (_) {
        isLiveBackendAvailable = false;
      }
    });

    setUp(() async {
      if (!isLiveBackendAvailable) return;

      deviceA = await TestDevice.create(
        name: 'Device A',
        supabaseUrl: supabaseUrl,
        supabaseAnonKey: supabaseAnonKey,
      );

      deviceB = await TestDevice.create(
        name: 'Device B',
        supabaseUrl: supabaseUrl,
        supabaseAnonKey: supabaseAnonKey,
      );

      final now = DateTime.now();
      for (final device in [deviceA, deviceB]) {
        await device.db.into(device.db.services).insertOnConflictUpdate(
              app_db.ServicesCompanion.insert(
                id: pieceServiceId,
                name: 'غسيل وكوي',
                pricingType: 'per_piece',
                price: 1500,
                isActive: const drift.Value(true),
                createdAt: now,
                updatedAt: now,
              ),
            );

        await device.db.customStatement(
          'INSERT OR REPLACE INTO item_types (id, name, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
          [
            pieceItemTypeId,
            'ملابس',
            1,
            now.millisecondsSinceEpoch ~/ 1000,
            now.millisecondsSinceEpoch ~/ 1000,
          ],
        );

        await device.db.into(device.db.storageLocations).insertOnConflictUpdate(
              app_db.StorageLocationsCompanion.insert(
                id: rack1LocationId,
                name: 'Rack 1',
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
                storageLocationId: rack1LocationId,
                itemTypeId: pieceItemTypeId,
                createdAt: now,
              ),
            );
      }

      // Fast-forward cursors to remote head
      final probe = await deviceA.remoteDataSource.getChanges(
        after: 0,
        limit: 1,
      );
      final initialHead = probe.latestSequence;
      await deviceA.syncStateDao.updateLastAppliedSequence(initialHead);
      await deviceB.syncStateDao.updateLastAppliedSequence(initialHead);

      await deviceA.syncEngine.initialize(triggerInitialSync: false);
      await deviceB.syncEngine.initialize(triggerInitialSync: false);
    });

    tearDown(() async {
      if (!isLiveBackendAvailable) return;
      await deviceA.dispose();
      await deviceB.dispose();
    });

    test(
      'Two-Device Full Lifecycle: Scenario 1 (Ready preservation), Scenario 2 (Ready->Processing deactivation), Scenario 3 (Complete), Scenario 4 (Cancel)',
      () async {
        if (!isLiveBackendAvailable) return;

        // ---------------------------------------------------------------------
        // STEP 0: Create Customer on Device A and replicate to Device B
        // ---------------------------------------------------------------------
        final customer = Customer(
          id: testCustomerId,
          name: 'عميل Phase 4 $runId',
          phone: testCustomerPhone,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await deviceA.customerRepository.createCustomer(customer);
        await deviceA.syncEngine.sync();

        // Polling pull on Device B
        Customer? custOnB;
        final custDeadline = DateTime.now().add(const Duration(seconds: 15));
        while (DateTime.now().isBefore(custDeadline)) {
          await deviceB.syncEngine.sync();
          custOnB = await deviceB.customerRepository.getCustomerById(testCustomerId);
          if (custOnB != null) break;
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
        expect(custOnB, isNotNull, reason: 'Customer must replicate to Device B');

        // =====================================================================
        // SCENARIO 1: Device A stores item -> Ready -> Sync -> Device B receives Ready & active storage preserved
        // =====================================================================
        final now = DateTime.now();
        final order1 = Order(
          id: testOrder1Id,
          orderNumber: testOrder1Number,
          customerId: testCustomerId,
          customerNameSnapshot: 'عميل Phase 4 $runId',
          customerPhoneSnapshot: testCustomerPhone,
          status: OrderStatus.processing,
          expectedPickupDate: OrderDate.fromDate(now.add(const Duration(days: 2))),
          subtotal: const Money.fromPiastres(1500),
          total: const Money.fromPiastres(1500),
          createdAt: now,
          updatedAt: now,
        );

        final item1 = OrderItem(
          id: testItem1Id,
          orderId: testOrder1Id,
          itemTypeId: pieceItemTypeId,
          serviceId: pieceServiceId,
          itemTypeNameSnapshot: 'ملابس',
          serviceNameSnapshot: 'غسيل وكوي',
          pricingType: PricingType.perPiece,
          quantity: 1.0,
          unitPrice: const Money.fromPiastres(1500),
          calculatedTotal: const Money.fromPiastres(1500),
          createdAt: now,
          updatedAt: now,
        );

        await deviceA.orderRepository.createOrder(order: order1, items: [item1]);

        // Device A stores item and marks order Ready
        await deviceA.storageRepository.storeItem(
          orderItemId: testItem1Id,
          storageLocationId: rack1LocationId,
        );
        await deviceA.orderRepository.markOrderReady(testOrder1Id);

        // Device A syncs until all pending operations are pushed and applied
        final pollDeadlineA1 = DateTime.now().add(const Duration(seconds: 15));
        while (DateTime.now().isBefore(pollDeadlineA1)) {
          await deviceA.syncEngine.sync();
          final ordA = await deviceA.orderRepository.getOrderById(testOrder1Id);
          final pendingA = await deviceA.syncOperationsDao.getPendingOperations();
          if (ordA != null && ordA.status == OrderStatus.ready && pendingA.isEmpty) break;
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }

        // Verify Device A is Ready with active storage
        final order1A = await deviceA.orderRepository.getOrderById(testOrder1Id);
        expect(order1A!.status, equals(OrderStatus.ready));
        final storage1A = await deviceA.storageRecordsDao.getActiveRecordForOrderItem(testItem1Id);
        expect(storage1A, isNotNull);
        expect(storage1A!.isActive, isTrue);

        // Device B polls until Order 1 is replicated
        Order? order1B;
        final pollDeadline1 = DateTime.now().add(const Duration(seconds: 15));
        while (DateTime.now().isBefore(pollDeadline1)) {
          await deviceB.syncEngine.sync();
          order1B = await deviceB.orderRepository.getOrderById(testOrder1Id);
          if (order1B != null && order1B.status == OrderStatus.ready) break;
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }

        expect(order1B, isNotNull);
        expect(order1B!.status, equals(OrderStatus.ready),
            reason: 'Device B must receive Ready state');

        // Storage on Device B must be active
        final storage1B = await deviceB.storageRecordsDao.getActiveRecordForOrderItem(testItem1Id);
        expect(storage1B, isNotNull,
            reason: 'Device B must have an active storage record for stored item');
        expect(storage1B!.isActive, isTrue);

        // Zero outbox on Device B
        final outboxB1 = await deviceB.syncOperationsDao.getPendingOperations();
        expect(outboxB1, isEmpty, reason: 'Device B must have 0 outbox operations');

        // =====================================================================
        // SCENARIO 2: Device A Ready -> Processing with reason -> Sync -> Device B receives Processing & active storage deactivated
        // =====================================================================
        await deviceA.orderRepository.correctOrderStatus(
          orderId: testOrder1Id,
          newStatus: OrderStatus.processing,
          reason: 'تحتاج غسيل إضافي',
        );

        // Device A storage must be deactivated locally
        final storage1AfterR2PA =
            await deviceA.storageRecordsDao.getActiveRecordForOrderItem(testItem1Id);
        expect(storage1AfterR2PA, isNull);

        // Push from Device A
        await deviceA.syncEngine.sync();

        // Device B pulls until status is processing
        final pollDeadline2 = DateTime.now().add(const Duration(seconds: 15));
        while (DateTime.now().isBefore(pollDeadline2)) {
          await deviceB.syncEngine.sync();
          order1B = await deviceB.orderRepository.getOrderById(testOrder1Id);
          if (order1B != null && order1B.status == OrderStatus.processing) break;
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }

        expect(order1B!.status, equals(OrderStatus.processing));

        // Active storage on Device B MUST BE DEACTIVATED!
        final storage1BAfterR2P =
            await deviceB.storageRecordsDao.getActiveRecordForOrderItem(testItem1Id);
        expect(storage1BAfterR2P, isNull,
            reason: 'Device B active storage MUST be deactivated on remote Ready -> Processing');

        // Zero outbox on Device B
        final outboxB2 = await deviceB.syncOperationsDao.getPendingOperations();
        expect(outboxB2, isEmpty);

        // =====================================================================
        // SCENARIO 3: Device A re-readies and completes order -> Sync -> Device B receives Completed, active storage deactivated, payments intact
        // =====================================================================
        // Re-store item on Device A and mark Ready
        await deviceA.storageRepository.storeItem(
          orderItemId: testItem1Id,
          storageLocationId: rack1LocationId,
        );
        await deviceA.orderRepository.markOrderReady(testOrder1Id);

        // Record full payment on Device A
        final pay1Id = 'a4000001-0001-4001-8001-$runId';
        await deviceA.paymentRepository.recordPayment(
          Payment(
            id: pay1Id,
            orderId: testOrder1Id,
            amount: const Money.fromPiastres(1500),
            paymentMethod: PaymentMethod.cash,
            paidAt: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // Settle Device A push for re-readied order & payment
        final pollDeadlineA3 = DateTime.now().add(const Duration(seconds: 15));
        while (DateTime.now().isBefore(pollDeadlineA3)) {
          await deviceA.syncEngine.sync();
          final ordA = await deviceA.orderRepository.getOrderById(testOrder1Id);
          final pendingA = await deviceA.syncOperationsDao.getPendingOperations();
          if (ordA != null && ordA.status == OrderStatus.ready && pendingA.isEmpty) break;
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }

        // Complete order on Device A
        final completedOrderA = await deviceA.orderRepository.completeOrder(
          orderId: testOrder1Id,
          handoverConfirmed: true,
        );
        expect(completedOrderA.status, equals(OrderStatus.completed));

        // Push completion from Device A and wait until settled
        final pollDeadlineAComplete = DateTime.now().add(const Duration(seconds: 15));
        while (DateTime.now().isBefore(pollDeadlineAComplete)) {
          await deviceA.syncEngine.sync();
          final ordA = await deviceA.orderRepository.getOrderById(testOrder1Id);
          final pendingA = await deviceA.syncOperationsDao.getPendingOperations();
          if (ordA != null && ordA.status == OrderStatus.completed && pendingA.isEmpty) break;
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }

        // Device B pulls until Completed
        final pollDeadline3 = DateTime.now().add(const Duration(seconds: 15));
        while (DateTime.now().isBefore(pollDeadline3)) {
          await deviceB.syncEngine.sync();
          order1B = await deviceB.orderRepository.getOrderById(testOrder1Id);
          if (order1B != null && order1B.status == OrderStatus.completed) break;
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }

        expect(order1B!.status, equals(OrderStatus.completed));
        expect(order1B.completedAt, isNotNull);

        // Device B storage must be deactivated
        final storage1BAfterComplete =
            await deviceB.storageRecordsDao.getActiveRecordForOrderItem(testItem1Id);
        expect(storage1BAfterComplete, isNull);

        // Device B payments must remain intact
        final paymentsOnB = await deviceB.paymentRepository.getPaymentsForOrder(testOrder1Id);
        expect(paymentsOnB, isNotEmpty);
        expect(paymentsOnB.first.amount.piastres, equals(1500));

        // Zero outbox on Device B
        final outboxB3 = await deviceB.syncOperationsDao.getPendingOperations();
        expect(outboxB3, isEmpty);

        // =====================================================================
        // SCENARIO 3B: Completed -> Processing correction on Device A -> Sync -> Device B receives Processing, completed_at=null, storage inactive, payments intact, zero outbox
        // =====================================================================
        final correctedOrderA = await deviceA.orderRepository.correctOrderStatus(
          orderId: testOrder1Id,
          newStatus: OrderStatus.processing,
          reason: 'تصحيح إداري تشغيلي لإعادة فتح الطلب',
        );
        expect(correctedOrderA.status, equals(OrderStatus.processing));
        expect(correctedOrderA.completedAt, isNull);

        // Device A storage records must remain inactive
        final storage1AAfterCorrection =
            await deviceA.storageRecordsDao.getActiveRecordForOrderItem(testItem1Id);
        expect(storage1AAfterCorrection, isNull);

        // Push correction from Device A and wait until settled
        final pollDeadlineA3B = DateTime.now().add(const Duration(seconds: 15));
        while (DateTime.now().isBefore(pollDeadlineA3B)) {
          await deviceA.syncEngine.sync();
          final ordA = await deviceA.orderRepository.getOrderById(testOrder1Id);
          final pendingA = await deviceA.syncOperationsDao.getPendingOperations();
          if (ordA != null && ordA.status == OrderStatus.processing && pendingA.isEmpty) break;
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }

        // Device B pulls until Processing
        Order? order1BAfterCorrection;
        final pollDeadline3B = DateTime.now().add(const Duration(seconds: 15));
        while (DateTime.now().isBefore(pollDeadline3B)) {
          await deviceB.syncEngine.sync();
          order1BAfterCorrection =
              await deviceB.orderRepository.getOrderById(testOrder1Id);
          if (order1BAfterCorrection != null &&
              order1BAfterCorrection.status == OrderStatus.processing) {
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }

        expect(order1BAfterCorrection, isNotNull);
        expect(order1BAfterCorrection!.status, equals(OrderStatus.processing));
        expect(order1BAfterCorrection.completedAt, isNull);

        // Device B storage records must NOT be reactivated
        final storage1BAfterCorrection =
            await deviceB.storageRecordsDao.getActiveRecordForOrderItem(testItem1Id);
        expect(storage1BAfterCorrection, isNull);

        // Device B payments must remain intact
        final paymentsOnBAfterCorrection =
            await deviceB.paymentRepository.getPaymentsForOrder(testOrder1Id);
        expect(paymentsOnBAfterCorrection, isNotEmpty);
        expect(paymentsOnBAfterCorrection.first.amount.piastres, equals(1500));

        // Zero outbox on Device B (no sync echo)
        final outboxB3B = await deviceB.syncOperationsDao.getPendingOperations();
        expect(outboxB3B, isEmpty);

        // =====================================================================
        // SCENARIO 3C: Re-Store flow — explicitly store item again on processing order -> active storage record created -> can achieve ready status
        // =====================================================================
        await deviceA.storageRepository.storeItem(
          orderItemId: testItem1Id,
          storageLocationId: rack1LocationId,
        );
        final reStoredRecordA =
            await deviceA.storageRecordsDao.getActiveRecordForOrderItem(testItem1Id);
        expect(reStoredRecordA, isNotNull);
        expect(reStoredRecordA!.isActive, isTrue);

        await deviceA.orderRepository.markOrderReady(testOrder1Id);
        final reReadiedOrderA =
            await deviceA.orderRepository.getOrderById(testOrder1Id);
        expect(reReadiedOrderA!.status, equals(OrderStatus.ready));

        // Device A syncs to push storage and mark_ready
        final pollDeadlineA3C = DateTime.now().add(const Duration(seconds: 15));
        while (DateTime.now().isBefore(pollDeadlineA3C)) {
          await deviceA.syncEngine.sync();
          final pendingA = await deviceA.syncOperationsDao.getPendingOperations();
          if (pendingA.isEmpty) break;
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }

        // Device B pulls until Order 1 is Ready and active storage is replicated
        final pollDeadline3C = DateTime.now().add(const Duration(seconds: 15));
        while (DateTime.now().isBefore(pollDeadline3C)) {
          await deviceB.syncEngine.sync();
          final ordB = await deviceB.orderRepository.getOrderById(testOrder1Id);
          final storB =
              await deviceB.storageRecordsDao.getActiveRecordForOrderItem(testItem1Id);
          if (ordB != null &&
              ordB.status == OrderStatus.ready &&
              storB != null &&
              storB.isActive) {
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }

        final order1BReReadied =
            await deviceB.orderRepository.getOrderById(testOrder1Id);
        expect(order1BReReadied!.status, equals(OrderStatus.ready));
        final storage1BReStored =
            await deviceB.storageRecordsDao.getActiveRecordForOrderItem(testItem1Id);
        expect(storage1BReStored, isNotNull);
        expect(storage1BReStored!.isActive, isTrue);

        // =====================================================================
        // SCENARIO 4: Device A creates Order 2, stores item, records partial payment, then cancels -> Sync -> Device B receives Cancelled, active storage deactivated, payment intact
        // =====================================================================
        final order2 = Order(
          id: testOrder2Id,
          orderNumber: testOrder2Number,
          customerId: testCustomerId,
          customerNameSnapshot: 'عميل Phase 4 $runId',
          customerPhoneSnapshot: testCustomerPhone,
          status: OrderStatus.processing,
          expectedPickupDate: OrderDate.fromDate(now.add(const Duration(days: 3))),
          subtotal: const Money.fromPiastres(1500),
          total: const Money.fromPiastres(1500),
          createdAt: now,
          updatedAt: now,
        );

        final item2 = OrderItem(
          id: testItem2Id,
          orderId: testOrder2Id,
          itemTypeId: pieceItemTypeId,
          serviceId: pieceServiceId,
          itemTypeNameSnapshot: 'ملابس',
          serviceNameSnapshot: 'غسيل وكوي',
          pricingType: PricingType.perPiece,
          quantity: 1.0,
          unitPrice: const Money.fromPiastres(1500),
          calculatedTotal: const Money.fromPiastres(1500),
          createdAt: now,
          updatedAt: now,
        );

        await deviceA.orderRepository.createOrder(order: order2, items: [item2]);

        // Store item 2 on Device A
        await deviceA.storageRepository.storeItem(
          orderItemId: testItem2Id,
          storageLocationId: rack1LocationId,
        );

        // Record partial payment on Order 2 (500 piastres)
        final pay2Id = 'a4000002-0002-4002-8002-$runId';
        await deviceA.paymentRepository.recordPayment(
          Payment(
            id: pay2Id,
            orderId: testOrder2Id,
            amount: const Money.fromPiastres(500),
            paymentMethod: PaymentMethod.cash,
            paidAt: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // Settle Device A push for order 2 creation, storage, and payment
        final pollDeadlineA4 = DateTime.now().add(const Duration(seconds: 15));
        while (DateTime.now().isBefore(pollDeadlineA4)) {
          await deviceA.syncEngine.sync();
          final ordA2 = await deviceA.orderRepository.getOrderById(testOrder2Id);
          final pendingA2 = await deviceA.syncOperationsDao.getPendingOperations();
          if (ordA2 != null && pendingA2.isEmpty) break;
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }

        // Cancel Order 2 on Device A
        await deviceA.orderRepository.cancelOrder(
          orderId: testOrder2Id,
          cancellationReason: 'إلغاء بناء على طلب العميل',
        );

        // Push from Device A
        await deviceA.syncEngine.sync();

        // Device B pulls until Cancelled
        Order? order2B;
        final pollDeadline4 = DateTime.now().add(const Duration(seconds: 15));
        while (DateTime.now().isBefore(pollDeadline4)) {
          await deviceB.syncEngine.sync();
          order2B = await deviceB.orderRepository.getOrderById(testOrder2Id);
          if (order2B != null && order2B.status == OrderStatus.cancelled) break;
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }

        expect(order2B, isNotNull);
        expect(order2B!.status, equals(OrderStatus.cancelled));
        expect(order2B.cancellationReason, equals('إلغاء بناء على طلب العميل'));
        expect(order2B.cancelledAt, isNotNull);

        // Device B storage must be deactivated
        final storage2B =
            await deviceB.storageRecordsDao.getActiveRecordForOrderItem(testItem2Id);
        expect(storage2B, isNull);

        // Device B partial payment preserved intact
        final payments2OnB = await deviceB.paymentRepository.getPaymentsForOrder(testOrder2Id);
        expect(payments2OnB, isNotEmpty);
        expect(payments2OnB.first.amount.piastres, equals(500));

        // Zero outbox on Device B
        final outboxB4 = await deviceB.syncOperationsDao.getPendingOperations();
        expect(outboxB4, isEmpty);
      },
    );
  });
}
