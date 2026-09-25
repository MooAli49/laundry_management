import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/errors/failures.dart';
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
import 'package:laundry_management/data/local/daos/refunds_dao.dart';
import 'package:laundry_management/data/local/daos/storage_locations_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/daos/sync_state_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart'
    as app_db;
import 'package:laundry_management/data/repositories/customer_repository_impl.dart';
import 'package:laundry_management/data/repositories/order_repository_impl.dart';
import 'package:laundry_management/data/repositories/payment_repository_impl.dart';
import 'package:laundry_management/data/repositories/refund_repository_impl.dart';
import 'package:laundry_management/data/sync/remote_change_applier.dart';
import 'package:laundry_management/data/sync/sync_engine.dart';
import 'package:laundry_management/domain/entities/refund.dart';
import 'package:laundry_management/domain/enums/refund_method.dart';
import 'package:laundry_management/domain/sync/sync_error_classifier.dart';
import 'package:laundry_management/domain/sync/sync_retry_policy.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
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
  final RefundsDao refundsDao;
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
  final RefundRepositoryImpl refundRepository;

  TestDevice({
    required this.name,
    required this.db,
    required this.dio,
    required this.syncOperationsDao,
    required this.syncStateDao,
    required this.customersDao,
    required this.ordersDao,
    required this.paymentsDao,
    required this.refundsDao,
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
    required this.refundRepository,
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
    final refundsDao = RefundsDao(db);
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

    final refundRepository = RefundRepositoryImpl(
      refundsDao: refundsDao,
      paymentsDao: paymentsDao,
      ordersDao: ordersDao,
      syncOperationsDao: syncOperationsDao,
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
      refundsDao: refundsDao,
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
      refundRepository: refundRepository,
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
  group('Refund Feature Phase 3 — Two-Device Bidirectional Sync Tests', () {
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

    Future<Response<dynamic>> postSafe(
      String path,
      Map<String, dynamic> data, {
      String? opId,
    }) async {
      return dio.post(
        path,
        data: data,
        options: Options(
          headers: opId != null ? {'X-Operation-ID': opId} : null,
          validateStatus: (_) => true,
        ),
      );
    }

    Future<Response<dynamic>> patchSafe(
      String path,
      Map<String, dynamic> data, {
      String? opId,
    }) async {
      return dio.patch(
        path,
        data: data,
        options: Options(
          headers: opId != null ? {'X-Operation-ID': opId} : null,
          validateStatus: (_) => true,
        ),
      );
    }

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

      testCustomerId = 'c3000001-0001-4001-8001-$runId';
      testCustomerPhone =
          '011${(DateTime.now().microsecondsSinceEpoch % 100000000).toString().padLeft(8, '0')}';

      // Seed customer on Supabase
      final custRes = await postSafe(
        '/customers',
        {
          'id': testCustomerId,
          'name': 'عميل استرجاع الجهازين $runId',
          'phone': testCustomerPhone,
        },
        opId: 'op-refund-c2d-cust-$runId',
      );
      expect(custRes.statusCode, isIn([200, 201]));
    });

    int testBaseSeq = 0;

    setUp(() async {
      if (!isLiveBackendAvailable) return;

      final probe = await dio.get('/sync/changes', queryParameters: {'limit': 1});
      if (probe.statusCode == 200 && probe.data is Map) {
        testBaseSeq = probe.data['latest_sequence'] as int? ?? 0;
      }

      deviceA = await TestDevice.create(
        name: 'Device-A',
        supabaseUrl: supabaseUrl,
        supabaseAnonKey: supabaseAnonKey,
      );
      deviceB = await TestDevice.create(
        name: 'Device-B',
        supabaseUrl: supabaseUrl,
        supabaseAnonKey: supabaseAnonKey,
      );

      // Fast-forward local cursors for both devices to the current remote head
      await deviceA.syncStateDao.updateLastAppliedSequence(testBaseSeq);
      await deviceB.syncStateDao.updateLastAppliedSequence(testBaseSeq);

      // Seed local customer and master data so foreign keys are satisfied
      final now = DateTime.now();
      for (final device in [deviceA, deviceB]) {
        await device.db.into(device.db.customers).insertOnConflictUpdate(
          app_db.CustomersCompanion.insert(
            id: testCustomerId,
            name: 'عميل استرجاع الجهازين $runId',
            phone: testCustomerPhone,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await device.db.customStatement(
          'INSERT OR REPLACE INTO item_types (id, name, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
          [
            '00000000-0000-0000-0001-000000000001',
            'ملابس',
            1,
            now.millisecondsSinceEpoch ~/ 1000,
            now.millisecondsSinceEpoch ~/ 1000,
          ],
        );
        await device.db.into(device.db.services).insertOnConflictUpdate(
          app_db.ServicesCompanion.insert(
            id: '00000000-0000-0000-0002-000000000001',
            name: 'غسيل',
            pricingType: 'per_piece',
            price: 1000,
            isActive: const drift.Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    });

    tearDown(() async {
      if (!isLiveBackendAvailable) return;
      await deviceA.dispose();
      await deviceB.dispose();
    });

    // Helper to seed a cancelled order with payment on Supabase
    Future<String> seedCancelledOrderWithPayment({
      required String orderSuffix,
      int total = 10000,
      int? paymentAmount,
    }) async {
      final effectivePayment = paymentAmount ?? total;
      final orderId = 'd300$orderSuffix-0001-4001-8001-$runId';
      final orderNumber = '26-$orderSuffix-$runId';

      final createRes = await postSafe(
        '/orders',
        {
          'id': orderId,
          'order_number': orderNumber,
          'customer_id': testCustomerId,
          'status': 'processing',
          'expected_pickup_date': DateTime.now()
              .add(const Duration(days: 2))
              .toUtc()
              .toIso8601String(),
          'subtotal': total,
          'discount': 0,
          'tax': 0,
          'total': total,
          'notes': 'Order for refund sync test',
          'items': [
            {
              'id': 'e300$orderSuffix-0001-4001-8001-$runId',
              'item_type_id': '00000000-0000-0000-0001-000000000001',
              'service_id': '00000000-0000-0000-0002-000000000001',
              'item_type_name_snapshot': 'ملابس',
              'service_name_snapshot': 'غسيل',
              'pricing_type': 'per_piece',
              'quantity': 1.0,
              'unit_price': total,
              'calculated_total': total,
            }
          ],
        },
        opId: 'op-seed-ord-$orderSuffix-$runId',
      );
      expect(createRes.statusCode, isIn([200, 201]));

      final payId = 'a300$orderSuffix-0001-4001-8001-$runId';
      final payRes = await postSafe(
        '/payments',
        {
          'id': payId,
          'order_id': orderId,
          'amount': effectivePayment,
          'payment_method': 'cash',
          'paid_at': DateTime.now().toUtc().toIso8601String(),
        },
        opId: 'op-seed-pay-$orderSuffix-$runId',
      );
      expect(payRes.statusCode, isIn([200, 201]));

      final cancelRes = await patchSafe(
        '/orders/$orderId',
        {
          'status': 'cancelled',
          'cancelled_at': DateTime.now().toUtc().toIso8601String(),
          'cancellation_reason': 'العميل يرغب في الإلغاء',
        },
        opId: 'op-canc-ord-$orderSuffix-$runId',
      );
      expect(cancelRes.statusCode, isIn([200, 204]));

      return orderId;
    }

    test(
      'PART H: End-to-End Two-Device Refund Sync (Device A creates → Syncs → Backend → Device B applies)',
      () async {
        if (!isLiveBackendAvailable) return;

        final orderId = await seedCancelledOrderWithPayment(orderSuffix: '0101');

        // Step 1: Both devices pull from Supabase to get the cancelled order and payment
        await deviceA.syncEngine.pull();
        await deviceB.syncEngine.pull();

        final orderOnA = await deviceA.ordersDao.getOrderById(orderId);
        expect(orderOnA, isNotNull);
        expect(orderOnA!.status, equals('cancelled'));

        final orderOnB = await deviceB.ordersDao.getOrderById(orderId);
        expect(orderOnB, isNotNull);
        expect(orderOnB!.status, equals('cancelled'));

        // Step 2: Device A creates a partial refund of 3000 piastres locally
        final refundId = 'b3000101-0001-4001-8001-$runId';
        final now = DateTime.now().toUtc();
        final localRefund = Refund(
          id: refundId,
          orderId: orderId,
          amount: Money.fromPiastres(3000),
          refundMethod: RefundMethod.cash,
          reason: 'استرجاع جزئي للعميل',
          refundedAt: now,
          createdAt: now,
          updatedAt: now,
        );

        final createdRefund = await deviceA.refundRepository.createRefund(localRefund);
        expect(createdRefund.id, equals(refundId));

        // Step 3: Verify local refund exists on Device A
        final refundA = await deviceA.refundsDao.getRefundById(refundId);
        expect(refundA, isNotNull);
        expect(refundA!.amount, equals(3000));
        expect(refundA.refundMethod, equals('cash'));

        // Step 4: Verify exactly ONE refund/create outbox operation exists on Device A
        final pendingOpsA = await deviceA.syncOperationsDao.getEligibleOperations(asOf: DateTime.now());
        expect(pendingOpsA.length, equals(1));
        expect(pendingOpsA.first.entityType, equals('refund'));
        expect(pendingOpsA.first.operationType, equals('create'));
        expect(pendingOpsA.first.entityId, equals(refundId));

        // Step 5: Device A synchronizes (pushes outbox)
        await deviceA.syncEngine.sync();

        // Verify outbox operation is synced
        final remainingOpsA = await deviceA.syncOperationsDao.getEligibleOperations(asOf: DateTime.now());
        expect(remainingOpsA, isEmpty);

        // Step 6: Verify Backend state via PostgREST / GET sync/changes
        final changesRes = await dio.get('/sync/changes', queryParameters: {'after': testBaseSeq, 'limit': 100});
        expect(changesRes.statusCode, equals(200));
        final changesList = changesRes.data['changes'] as List;
        final refundChanges = changesList.where(
          (c) => c['entity_type'] == 'refund' && c['entity_id'] == refundId,
        );
        expect(refundChanges.length, equals(1));
        final refundChange = refundChanges.first;
        expect(refundChange['operation_type'], equals('create'));
        expect(refundChange['payload']['amount'], equals(3000));
        expect(refundChange['payload']['refund_method'], equals('cash'));

        // Step 7: Verify backend Payment and Order invariants
        final paymentRes = await dio.get('/payments', queryParameters: {'order_id': orderId});
        expect(paymentRes.statusCode, equals(200));
        final paymentsList = paymentRes.data as List;
        expect(paymentsList.length, equals(1));
        expect(paymentsList.first['amount'], equals(10000)); // Payment row is untouched!

        final orderRes = await dio.get('/orders/$orderId');
        expect(orderRes.statusCode, equals(200));
        expect(orderRes.data['total'], equals(10000)); // Order total is untouched!
        expect(orderRes.data['status'], equals('cancelled'));

        // Step 8: Device B pulls sync changes
        await deviceB.syncEngine.pull();

        // Step 9: Verify Device B receives and applies the refund
        final refundB = await deviceB.refundsDao.getRefundById(refundId);
        expect(refundB, isNotNull);
        expect(refundB!.amount, equals(3000));
        expect(refundB.refundMethod, equals('cash'));
        expect(refundB.reason, equals('استرجاع جزئي للعميل'));

        // Step 10: Invariant — Device B created ZERO outbox operations from remote apply
        final pendingOpsB = await deviceB.syncOperationsDao.getEligibleOperations(asOf: DateTime.now());
        expect(pendingOpsB, isEmpty);

        // Step 11: Invariant — Device B payments and orders remain unchanged
        final paymentsB = await deviceB.paymentsDao.getPaymentsForOrder(orderId);
        expect(paymentsB.length, equals(1));
        expect(paymentsB.first.amount, equals(10000));

        final orderCheckB = await deviceB.ordersDao.getOrderById(orderId);
        expect(orderCheckB!.total, equals(10000));
        expect(orderCheckB.status, equals('cancelled'));

        // Step 12: Repeat sync on Device B to prove idempotent pull
        await deviceB.syncEngine.pull();
        final refundsBAfter = await deviceB.refundsDao.getRefundsForOrder(orderId);
        expect(refundsBAfter.length, equals(1));
        expect(refundsBAfter.first.id, equals(refundId));
      },
    );

    test(
      'PART I: Partial, Multiple, and Full Refunds Sync Correctly (30 + 20 + 50 = 100 max)',
      () async {
        if (!isLiveBackendAvailable) return;

        // Paid: 10000 piastres (100 EGP)
        final orderId = await seedCancelledOrderWithPayment(orderSuffix: '0201', total: 10000);

        // Pull initial order/payment into Device A
        await deviceA.syncEngine.pull();

        // 1. First partial refund: 3000 piastres (30 EGP)
        final ref1Id = 'b3000201-0001-4001-8001-$runId';
        final now1 = DateTime.now().toUtc();
        await deviceA.refundRepository.createRefund(
          Refund(
            id: ref1Id,
            orderId: orderId,
            amount: Money.fromPiastres(3000),
            refundMethod: RefundMethod.cash,
            refundedAt: now1,
            createdAt: now1,
            updatedAt: now1,
          ),
        );
        await deviceA.syncEngine.sync();

        var remaining = await deviceA.refundRepository.getRemainingRefundableForOrder(orderId);
        expect(remaining.piastres, equals(7000)); // 10000 - 3000 = 7000

        // 2. Second partial refund: 2000 piastres (20 EGP)
        final ref2Id = 'b3000202-0001-4001-8001-$runId';
        final now2 = DateTime.now().toUtc();
        await deviceA.refundRepository.createRefund(
          Refund(
            id: ref2Id,
            orderId: orderId,
            amount: Money.fromPiastres(2000),
            refundMethod: RefundMethod.instaPay,
            refundedAt: now2,
            createdAt: now2,
            updatedAt: now2,
          ),
        );
        await deviceA.syncEngine.sync();

        remaining = await deviceA.refundRepository.getRemainingRefundableForOrder(orderId);
        expect(remaining.piastres, equals(5000)); // 7000 - 2000 = 5000

        // 3. Final refund: remaining 5000 piastres (50 EGP)
        final ref3Id = 'b3000203-0001-4001-8001-$runId';
        final now3 = DateTime.now().toUtc();
        await deviceA.refundRepository.createRefund(
          Refund(
            id: ref3Id,
            orderId: orderId,
            amount: Money.fromPiastres(5000),
            refundMethod: RefundMethod.eWallet,
            refundedAt: now3,
            createdAt: now3,
            updatedAt: now3,
          ),
        );
        await deviceA.syncEngine.sync();

        remaining = await deviceA.refundRepository.getRemainingRefundableForOrder(orderId);
        expect(remaining.piastres, equals(0)); // 5000 - 5000 = 0

        final totalRefunded = await deviceA.refundRepository.getTotalRefundedForOrder(orderId);
        expect(totalRefunded.piastres, equals(10000));

        // 4. Attempt another refund locally: should fail validation
        final ref4Id = 'b3000204-0001-4001-8001-$runId';
        final now4 = DateTime.now().toUtc();
        expect(
          () => deviceA.refundRepository.createRefund(
            Refund(
              id: ref4Id,
              orderId: orderId,
              amount: Money.fromPiastres(500),
              refundMethod: RefundMethod.cash,
              refundedAt: now4,
              createdAt: now4,
              updatedAt: now4,
            ),
          ),
          throwsA(isA<BusinessRuleFailure>()),
        );

        // 5. Device B pulls and receives all three refunds accurately
        await deviceB.syncEngine.pull();

        final refundsOnB = await deviceB.refundsDao.getRefundsForOrder(orderId);
        expect(refundsOnB.length, equals(3));
        final totalB = await deviceB.refundsDao.getTotalRefundedForOrder(orderId);
        expect(totalB, equals(10000));

        // Invariant: zero outbox ops generated on Device B
        final outboxB = await deviceB.syncOperationsDao.getEligibleOperations(asOf: DateTime.now());
        expect(outboxB, isEmpty);
      },
    );

    test(
      'PART J: Dispatcher Retry & Idempotency (Retried operation ID does not duplicate refund)',
      () async {
        if (!isLiveBackendAvailable) return;

        final orderId = await seedCancelledOrderWithPayment(orderSuffix: '0301', total: 6000);

        final refundId = 'b3000301-0001-4001-8001-$runId';
        final opId = 'op-ref-idem-test-$runId';
        final now = DateTime.now().toUtc();

        final refundPayload = {
          'id': refundId,
          'order_id': orderId,
          'amount': 2500,
          'refund_method': 'cash',
          'reason': 'Idempotency test',
          'refunded_at': now.toIso8601String(),
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };

        // First dispatch via RemoteApiDispatcher
        final res1 = await deviceA.remoteApiDispatcher.dispatch(
          app_db.SyncOperation(
            id: opId,
            entityType: 'refund',
            entityId: refundId,
            operationType: 'create',
            payload: jsonEncode(refundPayload),
            status: 'pending',
            retryCount: 0,
            createdAt: now,
            updatedAt: now,
          ),
        );
        expect(res1, isNotNull);

        // Second dispatch (retry with identical opId)
        final res2 = await deviceA.remoteApiDispatcher.dispatch(
          app_db.SyncOperation(
            id: opId,
            entityType: 'refund',
            entityId: refundId,
            operationType: 'create',
            payload: jsonEncode(refundPayload),
            status: 'pending',
            retryCount: 1,
            createdAt: now,
            updatedAt: now,
          ),
        );
        expect(res2, isNotNull);

        // Verify sync_changes on backend contains exactly ONE change for this opId
        final changesRes = await dio.get('/sync/changes', queryParameters: {'after': testBaseSeq, 'limit': 100});
        final changesList = changesRes.data['changes'] as List;
        final matchingChanges = changesList.where((c) => c['operation_id'] == opId).toList();
        expect(matchingChanges.length, equals(1));
      },
    );
  });
}
