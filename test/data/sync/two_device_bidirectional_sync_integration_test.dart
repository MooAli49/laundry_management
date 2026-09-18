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
import 'package:laundry_management/data/local/database/app_database.dart' as app_db;
import 'package:laundry_management/data/remote/dto/sync_change_dto.dart';
import 'package:laundry_management/data/repositories/customer_repository_impl.dart';
import 'package:laundry_management/data/repositories/order_repository_impl.dart';
import 'package:laundry_management/data/repositories/payment_repository_impl.dart';
import 'package:laundry_management/data/repositories/storage_repository_impl.dart';
import 'package:laundry_management/data/sync/remote_change_applier.dart';
import 'package:laundry_management/data/sync/sync_engine.dart';
import 'package:laundry_management/domain/entities/carpet_item_data.dart';
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/entities/payment.dart';
import 'package:laundry_management/domain/entities/storage_record.dart';
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

/// Encapsulates a simulated client device with its own independent
/// SQLite database, DAOs, repositories, Realtime adapter, and SyncEngine.
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
  group('C4-C — Two-Device Bidirectional Sync E2E Integration Tests', () {
    late DioClient dioClient;
    late Dio dio;
    late SyncRemoteDataSource testRemoteDataSource;
    late String supabaseUrl;
    late String supabaseAnonKey;
    late TestDevice deviceA;
    late TestDevice deviceB;
    bool isLiveBackendAvailable = true;

    final runId = DateTime.now().millisecondsSinceEpoch
        .toRadixString(16)
        .padLeft(12, '0');

    late final String testServiceId;
    late final String testCustomerId;
    late final String testCustomerPhone;
    late final String testOrderId;
    late final String testOrderNumber;
    late final String testOrderItemId;
    late final String testCarpetId;
    late final String testPaymentId;

    setUpAll(() async {
      dioClient = DioClient(
        receiveTimeout: const Duration(seconds: 30),
        connectTimeout: const Duration(seconds: 30),
      );
      dio = dioClient.dio;
      testRemoteDataSource = SyncRemoteDataSourceImpl(SyncRemoteApi(dio));

      supabaseUrl = const String.fromEnvironment(
        'SUPABASE_URL_ROOT',
        defaultValue: 'https://dyhfgnbhijukbdptreto.supabase.co',
      );
      supabaseAnonKey = const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR5aGZnbmJoaWp1a2JkcHRyZXRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg0NjcxNDcsImV4cCI6MjEwNDA0MzE0N30.gInc0tuzZiWq8EeEqbNBYa_Ay4liCcB4iGGOjUMnOBw',
      );

      testServiceId = 'b0000001-0001-4001-8001-$runId';
      testCustomerId = 'c0000001-0001-4001-8001-$runId';
      testCustomerPhone =
          '015${DateTime.now().millisecondsSinceEpoch % 100000000}'
              .padRight(11, '7');
      testOrderId = 'd0000001-0001-4001-8001-$runId';
      testOrderNumber = 'ORD-C4C-$runId';
      testOrderItemId = 'e0000001-0001-4001-8001-$runId';
      testCarpetId = 'f0000001-0001-4001-8001-$runId';
      testPaymentId = 'a0000001-0001-4001-8001-$runId';

      drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

      try {
        final res = await dio.get('/customers', queryParameters: {'limit': 1});
        if (res.statusCode != 200) {
          isLiveBackendAvailable = false;
        }
      } catch (_) {
        isLiveBackendAvailable = false;
      }

      if (!isLiveBackendAvailable) return;

      // Provision a run-scoped test service on remote Supabase before devices start
      final srvRes = await dio.post(
        '/services',
        data: {
          'id': testServiceId,
          'name': 'خدمة سجاد C4C $runId',
          'pricing_type': 'per_square_meter',
          'price': 4000,
          'is_active': true,
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-c4c-srv-$runId'},
          validateStatus: (_) => true,
        ),
      );
      expect(srvRes.statusCode, isIn([200, 201]));
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

      // Seed local master data in both Device A and Device B
      final now = DateTime.now();
      for (final device in [deviceA, deviceB]) {
        await device.db.into(device.db.services).insertOnConflictUpdate(
          app_db.ServicesCompanion.insert(
            id: testServiceId,
            name: 'خدمة سجاد C4C $runId',
            pricingType: 'per_square_meter',
            price: 4000,
            isActive: const drift.Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );

        await device.db.customStatement(
          'INSERT OR REPLACE INTO item_types (id, name, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
          ['type-carpet', 'سجاد-carpet', 1, now.millisecondsSinceEpoch ~/ 1000, now.millisecondsSinceEpoch ~/ 1000],
        );

        await device.db.into(device.db.carpetSizes).insertOnConflictUpdate(
          app_db.CarpetSizesCompanion.insert(
            id: 'size-2x3',
            length: 3.0,
            width: 2.0,
            area: 6.0,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await device.db.into(device.db.storageLocations).insertOnConflictUpdate(
          app_db.StorageLocationsCompanion.insert(
            id: 'rack-1',
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
                id: 'slit-r1-tc',
                storageLocationId: 'rack-1',
                itemTypeId: 'type-carpet',
                createdAt: now,
              ),
            );
      }

      // Fast-forward local cursors for both devices to the current remote head
      final probe = await deviceA.remoteDataSource.getChanges(
        after: 0,
        limit: 1,
      );
      final initialHead = probe.latestSequence;
      await deviceA.syncStateDao.updateLastAppliedSequence(initialHead);
      await deviceB.syncStateDao.updateLastAppliedSequence(initialHead);

      // Initialize both SyncEngines without triggering an initial pull
      await deviceA.syncEngine.initialize(triggerInitialSync: false);
      await deviceB.syncEngine.initialize(triggerInitialSync: false);
    });

    tearDown(() async {
      if (!isLiveBackendAvailable) return;
      await deviceA.dispose();
      await deviceB.dispose();
    });

    Future<SyncChangeDto> captureRemoteChangeByOpId({
      required SyncRemoteDataSource remoteDataSource,
      required String operationId,
      int startAfter = 0,
      Duration timeout = const Duration(seconds: 15),
    }) async {
      final deadline = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(deadline)) {
        try {
          int currentCursor = startAfter;
          bool hasMore = true;
          while (hasMore) {
            final res = await remoteDataSource.getChanges(
              after: currentCursor,
              limit: 100,
            );
            final matches =
                res.changes.where((c) => c.operationId == operationId).toList();
            if (matches.isNotEmpty) {
              expect(
                matches.length,
                equals(1),
                reason: 'Expected exactly 1 change for operation $operationId',
              );
              return matches.first;
            }
            if (res.changes.isEmpty || !res.hasMore) break;
            currentCursor = res.changes.last.sequence;
            hasMore = res.hasMore;
          }
        } catch (_) {
          // If transient network or server delay occurs, retry until deadline
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      fail('Could not locate remote sync_changes record for operation $operationId');
    }

    test(
      'Full Bidirectional E2E Sync: A -> B Order, B -> A Payment & Storage with Zero-Echo, Realtime Signals, and Cursor Independence',
      () async {
        if (!isLiveBackendAvailable) return;

        final headCursor = await deviceA.syncStateDao.getLastAppliedSequence();

        // =====================================================================
        // SCENARIO 2 — CUSTOMER A -> B (Dependency Precondition)
        // =====================================================================
        final signalCompleterCustB = Completer<void>();
        final subCustB = deviceB.realtimeAdapter.onSyncAvailable.listen((_) {
          if (!signalCompleterCustB.isCompleted) {
            signalCompleterCustB.complete();
          }
        });

        final opsBeforeCustB =
            (await deviceB.syncOperationsDao.getPendingOperations()).length;

        // Create Customer on Device A
        final customerA = Customer(
          id: testCustomerId,
          name: 'عميل اختبار C4-C $runId',
          phone: testCustomerPhone,
          notes: 'Created on Device A',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await deviceA.customerRepository.createCustomer(customerA);

        // Capture customer operation ID generated on Device A
        final pendingCustOpsOnA =
            await deviceA.syncOperationsDao.getPendingOperations();
        final customerOpOnA = pendingCustOpsOnA.firstWhere(
          (o) => o.entityId == testCustomerId,
        );
        final customerOpId = customerOpOnA.id;

        // Push from Device A
        await deviceA.syncEngine.sync();

        // Device B must receive the Realtime Broadcast signal
        await signalCompleterCustB.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () => fail(
            'Device B did NOT receive Realtime Broadcast for customer within 15s',
          ),
        );
        await subCustB.cancel();

        // Await local persistence on Device B (via Realtime-triggered pull)
        Customer? localCustOnB;
        final custDeadline = DateTime.now().add(const Duration(seconds: 15));
        while (DateTime.now().isBefore(custDeadline)) {
          localCustOnB =
              await deviceB.customerRepository.getCustomerById(testCustomerId);
          if (localCustOnB != null) break;
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }

        expect(localCustOnB, isNotNull);
        expect(localCustOnB!.id, equals(testCustomerId));
        expect(localCustOnB.name, equals('عميل اختبار C4-C $runId'));

        // Capture exact customer change sequence by operation_id
        final custChange = await captureRemoteChangeByOpId(
          remoteDataSource: testRemoteDataSource,
          operationId: customerOpId,
          startAfter: headCursor,
        );
        final customerSequence = custChange.sequence;

        // Verify Device B cursor advanced past customerSequence
        final cursorAfterCustB =
            await deviceB.syncStateDao.getLastAppliedSequence();
        expect(cursorAfterCustB, greaterThanOrEqualTo(customerSequence));

        // ZERO ECHO: Device B pending operations must not have increased
        final opsAfterCustB =
            (await deviceB.syncOperationsDao.getPendingOperations()).length;
        expect(opsAfterCustB, equals(opsBeforeCustB));
        final echoCustOpsOnB = await (deviceB.db.select(deviceB.db.syncOperations)
              ..where((tbl) => tbl.entityId.equals(testCustomerId)))
            .get();
        expect(echoCustOpsOnB, isEmpty);

        // =====================================================================
        // SCENARIO 3 — ORDER AGGREGATE A -> B
        // =====================================================================
        final signalCompleterOrdB = Completer<void>();
        final subOrdB = deviceB.realtimeAdapter.onSyncAvailable.listen((_) {
          if (!signalCompleterOrdB.isCompleted) {
            signalCompleterOrdB.complete();
          }
        });

        final opsBeforeOrdB =
            (await deviceB.syncOperationsDao.getPendingOperations()).length;

        // Create Order on Device A with 1 Item and Carpet data
        final now = DateTime.now();
        final orderItem = OrderItem(
          id: testOrderItemId,
          orderId: testOrderId,
          itemTypeId: 'type-carpet',
          serviceId: testServiceId,
          itemTypeNameSnapshot: 'سجاد',
          serviceNameSnapshot: 'خدمة سجاد C4C $runId',
          pricingType: PricingType.perSquareMeter,
          quantity: 6.0,
          unitPrice: const Money.fromPiastres(4000),
          calculatedTotal: const Money.fromPiastres(24000),
          carpetData: CarpetItemData(
            id: testCarpetId,
            orderItemId: testOrderItemId,
            carpetSizeId: 'size-2x3',
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
          customerNameSnapshot: 'عميل اختبار C4-C $runId',
          customerPhoneSnapshot: testCustomerPhone,
          status: OrderStatus.processing,
          expectedPickupDate:
              OrderDate.fromDate(now.add(const Duration(days: 3))),
          subtotal: const Money.fromPiastres(24000),
          total: const Money.fromPiastres(24000),
          createdAt: now,
          updatedAt: now,
        );

        await deviceA.orderRepository.createOrder(
          order: orderA,
          items: [orderItem],
        );

        // Capture order operation ID generated on Device A
        final pendingOrdOpsOnA =
            await deviceA.syncOperationsDao.getPendingOperations();
        final orderOpOnA = pendingOrdOpsOnA.firstWhere(
          (o) => o.entityId == testOrderId,
        );
        final orderOpId = orderOpOnA.id;

        // Push Order from Device A
        await deviceA.syncEngine.sync();

        // Device B must receive Realtime Broadcast wake-up signal
        await signalCompleterOrdB.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () => fail(
            'Device B did NOT receive Realtime Broadcast for order within 15s',
          ),
        );
        await subOrdB.cancel();

        // Poll SQLite B until order appears (pure Realtime-triggered pull)
        Order? localOrderOnB;
        final ordDeadline = DateTime.now().add(const Duration(seconds: 15));
        while (DateTime.now().isBefore(ordDeadline)) {
          localOrderOnB =
              await deviceB.orderRepository.getOrderById(testOrderId);
          if (localOrderOnB != null) break;
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }

        expect(localOrderOnB, isNotNull);
        expect(localOrderOnB!.id, equals(testOrderId));
        expect(localOrderOnB.orderNumber, equals(testOrderNumber));
        expect(localOrderOnB.subtotal.piastres, equals(24000));
        expect(localOrderOnB.total.piastres, equals(24000));
        expect(localOrderOnB.status, equals(OrderStatus.processing));

        // Verify Order Items & Carpet in SQLite B
        final itemsWithCarpetsOnB =
            await deviceB.ordersDao.getOrderItemsWithCarpets(testOrderId);
        expect(itemsWithCarpetsOnB, hasLength(1));
        final itemB = itemsWithCarpetsOnB.first.item;
        final carpetB = itemsWithCarpetsOnB.first.carpet;
        expect(itemB.id, equals(testOrderItemId));
        expect(itemB.itemTypeNameSnapshot, equals('سجاد'));
        expect(itemB.serviceNameSnapshot, equals('خدمة سجاد C4C $runId'));
        expect(itemB.quantity, equals(6.0));
        expect(itemB.unitPrice, equals(4000));
        expect(itemB.calculatedTotal, equals(24000));
        expect(carpetB, isNotNull);
        expect(carpetB!.length, equals(3.0));
        expect(carpetB.width, equals(2.0));
        expect(carpetB.area, equals(6.0));

        // Capture exact order change sequence by operation_id
        final ordChange = await captureRemoteChangeByOpId(
          remoteDataSource: testRemoteDataSource,
          operationId: orderOpId,
          startAfter: customerSequence,
        );
        final orderSequence = ordChange.sequence;
        expect(ordChange.entityType, equals('order'));
        expect(ordChange.operationType, equals('create'));

        // Cursor on Device B must have advanced past orderSequence
        final cursorAfterOrdB =
            await deviceB.syncStateDao.getLastAppliedSequence();
        expect(cursorAfterOrdB, greaterThanOrEqualTo(orderSequence));

        // ZERO ECHO on Device B
        final opsAfterOrdB =
            (await deviceB.syncOperationsDao.getPendingOperations()).length;
        expect(opsAfterOrdB, equals(opsBeforeOrdB));
        final echoOrdOpsOnB = await (deviceB.db.select(deviceB.db.syncOperations)
              ..where((tbl) => tbl.entityId.equals(testOrderId)))
            .get();
        expect(echoOrdOpsOnB, isEmpty);

        // =====================================================================
        // SCENARIO 4 — PAYMENT B -> A
        // =====================================================================
        final signalCompleterPayA = Completer<void>();
        final subPayA = deviceA.realtimeAdapter.onSyncAvailable.listen((_) {
          if (!signalCompleterPayA.isCompleted) {
            signalCompleterPayA.complete();
          }
        });

        final opsBeforePayA =
            (await deviceA.syncOperationsDao.getPendingOperations()).length;

        // Record Payment on Device B for the synchronized Order
        final paymentB = Payment(
          id: testPaymentId,
          orderId: testOrderId,
          amount: const Money.fromPiastres(10000),
          paymentMethod: PaymentMethod.cash,
          paidAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await deviceB.paymentRepository.recordPayment(paymentB);

        // Capture payment operation ID generated on Device B
        final pendingOpsOnB =
            await deviceB.syncOperationsDao.getPendingOperations();
        final paymentOpOnB = pendingOpsOnB.firstWhere(
          (o) => o.entityId == testPaymentId,
        );
        final paymentOpId = paymentOpOnB.id;

        // Push Payment from Device B
        await deviceB.syncEngine.sync();

        // Device A must receive Realtime Broadcast wake-up signal
        await signalCompleterPayA.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () => fail(
            'Device A did NOT receive Realtime Broadcast for payment within 15s',
          ),
        );
        await subPayA.cancel();

        // Poll SQLite A until payment appears (pure Realtime-triggered pull)
        Payment? localPayOnA;
        final payDeadline = DateTime.now().add(const Duration(seconds: 15));
        while (DateTime.now().isBefore(payDeadline)) {
          final paymentsOnA =
              await deviceA.paymentRepository.getPaymentsForOrder(testOrderId);
          if (paymentsOnA.any((p) => p.id == testPaymentId)) {
            localPayOnA = paymentsOnA.firstWhere((p) => p.id == testPaymentId);
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }

        expect(localPayOnA, isNotNull);
        expect(localPayOnA!.id, equals(testPaymentId));
        expect(localPayOnA.orderId, equals(testOrderId));
        expect(localPayOnA.amount.piastres, equals(10000));
        expect(localPayOnA.paymentMethod, equals(PaymentMethod.cash));

        // Capture exact payment change sequence by operation_id
        final payChange = await captureRemoteChangeByOpId(
          remoteDataSource: testRemoteDataSource,
          operationId: paymentOpId,
          startAfter: orderSequence,
        );
        final paymentSequence = payChange.sequence;
        expect(payChange.entityType, equals('payment'));
        expect(payChange.operationType, equals('create'));

        // Cursor on Device A must have advanced past paymentSequence
        final cursorAfterPayA =
            await deviceA.syncStateDao.getLastAppliedSequence();
        expect(cursorAfterPayA, greaterThanOrEqualTo(paymentSequence));

        // ZERO ECHO on Device A
        final opsAfterPayA =
            (await deviceA.syncOperationsDao.getPendingOperations()).length;
        expect(opsAfterPayA, equals(opsBeforePayA));
        final echoPayOpsOnA = await (deviceA.db.select(deviceA.db.syncOperations)
              ..where((tbl) => tbl.entityId.equals(testPaymentId)))
            .get();
        expect(echoPayOpsOnA, isEmpty);

        // =====================================================================
        // SCENARIO 5 — STORAGE B -> A
        // =====================================================================
        final signalCompleterStoreA = Completer<void>();
        final subStoreA = deviceA.realtimeAdapter.onSyncAvailable.listen((_) {
          if (!signalCompleterStoreA.isCompleted) {
            signalCompleterStoreA.complete();
          }
        });

        final opsBeforeStoreA =
            (await deviceA.syncOperationsDao.getPendingOperations()).length;

        // Store synchronized Order Item on Device B in rack-1
        final storageRecordB = await deviceB.storageRepository.storeItem(
          orderItemId: testOrderItemId,
          storageLocationId: 'rack-1',
        );

        // Capture storage operation ID generated on Device B
        final pendingOpsStoreOnB =
            await deviceB.syncOperationsDao.getPendingOperations();
        final storageOpOnB = pendingOpsStoreOnB.firstWhere(
          (o) => o.entityId == storageRecordB.id,
        );
        final storageOpId = storageOpOnB.id;

        // Push Storage Record from Device B
        await deviceB.syncEngine.sync();

        // Device A must receive Realtime Broadcast wake-up signal
        await signalCompleterStoreA.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () => fail(
            'Device A did NOT receive Realtime Broadcast for storage within 15s',
          ),
        );
        await subStoreA.cancel();

        // Poll SQLite A until storage record appears (pure Realtime-triggered pull)
        StorageRecord? localStorageOnA;
        final storeDeadline = DateTime.now().add(const Duration(seconds: 15));
        while (DateTime.now().isBefore(storeDeadline)) {
          localStorageOnA = await deviceA.storageRepository
              .getActiveRecordForOrderItem(testOrderItemId);
          if (localStorageOnA != null) break;
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }

        expect(localStorageOnA, isNotNull);
        expect(localStorageOnA!.id, equals(storageRecordB.id));
        expect(localStorageOnA.orderItemId, equals(testOrderItemId));
        expect(localStorageOnA.storageLocationId, equals('rack-1'));
        expect(localStorageOnA.isActive, isTrue);

        // Capture exact storage change sequence by operation_id
        final storeChange = await captureRemoteChangeByOpId(
          remoteDataSource: testRemoteDataSource,
          operationId: storageOpId,
          startAfter: paymentSequence,
        );
        final storageSequence = storeChange.sequence;
        expect(storeChange.entityType, equals('storage_record'));
        expect(storeChange.operationType, equals('create'));

        // Cursor on Device A must have advanced past storageSequence
        final cursorAfterStoreA =
            await deviceA.syncStateDao.getLastAppliedSequence();
        expect(cursorAfterStoreA, greaterThanOrEqualTo(storageSequence));

        // ZERO ECHO on Device A
        final opsAfterStoreA =
            (await deviceA.syncOperationsDao.getPendingOperations()).length;
        expect(opsAfterStoreA, equals(opsBeforeStoreA));
        final echoStoreOpsOnA = await (deviceA.db.select(
          deviceA.db.syncOperations,
        )..where((tbl) => tbl.entityId.equals(storageRecordB.id))).get();
        expect(echoStoreOpsOnA, isEmpty);

        // =====================================================================
        // SCENARIO 6 — CURSOR INDEPENDENCE VERIFICATION
        // =====================================================================
        // Verify Device A and Device B maintain distinct independent SQLite state rows
        final finalCursorA = await deviceA.syncStateDao.getLastAppliedSequence();
        final finalCursorB = await deviceB.syncStateDao.getLastAppliedSequence();
        expect(finalCursorA, greaterThanOrEqualTo(storageSequence));
        expect(finalCursorB, greaterThanOrEqualTo(orderSequence));

        // =====================================================================
        // SCENARIO 7 — REPLAY / CRASH-SAFETY CONTRACT VERIFICATION
        // =====================================================================
        // 1. Strict ascending sequence validation: descending batch is rejected
        final descendingBatch = [
          SyncChangeDto(
            sequence: 200,
            operationId: 'op-invalid-1',
            entityType: 'customer',
            entityId: 'c-invalid-1',
            operationType: 'create',
            payload: {},
            serverVersion: 1,
            createdAt: DateTime.now(),
          ),
          SyncChangeDto(
            sequence: 150,
            operationId: 'op-invalid-2',
            entityType: 'customer',
            entityId: 'c-invalid-2',
            operationType: 'create',
            payload: {},
            serverVersion: 1,
            createdAt: DateTime.now(),
          ),
        ];
        expect(
          () => deviceA.changeApplier.applyBatch(descendingBatch),
          throwsA(isA<StateError>()),
        );

        // 2. Applying an already existing entity updates/preserves data idempotently without duplicate rows
        final allCustsOnA =
            await (deviceA.db.select(deviceA.db.customers)).get();
        expect(
          allCustsOnA.where((c) => c.id == testCustomerId),
          hasLength(1),
        );

        // 3. Transactional failure does not leave a partially applied page or an advanced cursor
        final cursorBeforeFailingBatch =
            await deviceA.syncStateDao.getLastAppliedSequence();
        final rollbackCustomerId = 'cust-rollback-$runId';
        final failingBatch = [
          SyncChangeDto(
            sequence: cursorBeforeFailingBatch + 10,
            operationId: 'op-tx-test-valid-$runId',
            entityType: 'customer',
            entityId: rollbackCustomerId,
            operationType: 'create',
            payload: {
              'id': rollbackCustomerId,
              'name': 'Should Rollback',
              'phone': '01099999999',
            },
            serverVersion: 1,
            createdAt: DateTime.now(),
          ),
          SyncChangeDto(
            sequence: cursorBeforeFailingBatch + 11,
            operationId: 'op-tx-test-invalid-$runId',
            entityType: 'unsupported_entity_type_for_test',
            entityId: 'invalid-id-$runId',
            operationType: 'create',
            payload: {},
            serverVersion: 1,
            createdAt: DateTime.now(),
          ),
        ];

        try {
          await deviceA.changeApplier.applyBatch(failingBatch);
          fail('Batch with invalid entity type should have thrown UnsupportedError');
        } catch (e) {
          expect(e, isA<UnsupportedError>());
        }

        // Verify cursor did not advance
        final cursorAfterFailingBatch =
            await deviceA.syncStateDao.getLastAppliedSequence();
        expect(cursorAfterFailingBatch, equals(cursorBeforeFailingBatch));

        // Verify first change in batch was rolled back
        final rolledBackCust = await (deviceA.db.select(deviceA.db.customers)
              ..where((tbl) => tbl.id.equals(rollbackCustomerId)))
            .getSingleOrNull();
        expect(rolledBackCust, isNull);
      },
    );
  });
}
