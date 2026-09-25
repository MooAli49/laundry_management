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
import 'package:laundry_management/application/use_cases/create_order_use_case.dart';
import 'package:laundry_management/application/use_cases/edit_processing_order_use_case.dart';
import 'package:laundry_management/domain/entities/carpet_item_data.dart';
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
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
  group('Phase 3 — Edit Order End-to-End Multi-Device Integration Tests', () {
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
    late final String testOrderId;
    late final String testOrderNumber;
    late final String testItem1Id;
    late final String testItem2Id;
    late final String testCarpet1Id;

    const pieceItemTypeId = '00000000-0000-0000-0001-000000000001';
    const carpetItemTypeId = '00000000-0000-0000-0001-000000000003';
    const pieceServiceId = '00000000-0000-0000-0002-000000000001';
    const carpetServiceId = '00000000-0000-0000-0002-000000000003';
    const carpetSizeId = '00000000-0000-0000-0007-000000000001';

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

      testCustomerId = 'c3000001-0001-4001-8001-$runId';
      testCustomerPhone =
          '015${(DateTime.now().microsecondsSinceEpoch % 100000000).toString().padLeft(8, '0')}';
      testOrderId = 'd3000001-0001-4001-8001-$runId';
      testOrderNumber = 'ORD-P3-$runId';
      testItem1Id = 'e3000001-0001-4001-8001-$runId';
      testItem2Id = 'e3000002-0002-4002-8002-$runId';
      testCarpet1Id = 'f3000001-0001-4001-8001-$runId';

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

      // Seed local master data in both devices
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

        await device.db.into(device.db.services).insertOnConflictUpdate(
              app_db.ServicesCompanion.insert(
                id: carpetServiceId,
                name: 'غسيل سجاد',
                pricingType: 'per_square_meter',
                price: 4000,
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

        await device.db.customStatement(
          'INSERT OR REPLACE INTO item_types (id, name, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
          [
            carpetItemTypeId,
            'سجاد-carpet',
            1,
            now.millisecondsSinceEpoch ~/ 1000,
            now.millisecondsSinceEpoch ~/ 1000,
          ],
        );

        await device.db.into(device.db.carpetSizes).insertOnConflictUpdate(
              app_db.CarpetSizesCompanion.insert(
                id: carpetSizeId,
                length: 3.0,
                width: 2.0,
                area: 6.0,
                createdAt: now,
                updatedAt: now,
              ),
            );

        await device.db.customStatement(
          'INSERT OR REPLACE INTO service_item_types (id, service_id, item_type_id, created_at) VALUES (?, ?, ?, ?)',
          [
            'sit-1-$runId-${device.name}',
            pieceServiceId,
            pieceItemTypeId,
            now.millisecondsSinceEpoch ~/ 1000,
          ],
        );

        await device.db.customStatement(
          'INSERT OR REPLACE INTO service_item_types (id, service_id, item_type_id, created_at) VALUES (?, ?, ?, ?)',
          [
            'sit-2-$runId-${device.name}',
            carpetServiceId,
            carpetItemTypeId,
            now.millisecondsSinceEpoch ~/ 1000,
          ],
        );
      }

      // Fast-forward local cursors for both devices to current remote head
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
      'Two-Device Full Edit Order Flow: Device A local edit -> remote push -> Device B pull -> authoritative aggregate & zero outbox on Device B',
      () async {
        if (!isLiveBackendAvailable) return;

        // ---------------------------------------------------------------------
        // STEP 1: Create and replicate Customer to Device A and Device B
        // ---------------------------------------------------------------------
        final customer = Customer(
          id: testCustomerId,
          name: 'عميل Phase 3 $runId',
          phone: testCustomerPhone,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await deviceA.customerRepository.createCustomer(customer);
        await deviceA.syncEngine.sync();

        // Device B pulls customer with polling loop
        Customer? custOnB;
        final custDeadline = DateTime.now().add(const Duration(seconds: 15));
        while (DateTime.now().isBefore(custDeadline)) {
          await deviceB.syncEngine.sync();
          custOnB = await deviceB.customerRepository.getCustomerById(testCustomerId);
          if (custOnB != null) break;
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
        expect(custOnB, isNotNull, reason: 'Customer must replicate from Device A to Device B');

        // ---------------------------------------------------------------------
        // STEP 2: Device A creates initial Order with Item 1 (piece) and Item 2 (carpet)
        // ---------------------------------------------------------------------
        final initialOrder = Order(
          id: testOrderId,
          orderNumber: testOrderNumber,
          customerId: testCustomerId,
          customerNameSnapshot: 'عميل Phase 3 $runId',
          customerPhoneSnapshot: testCustomerPhone,
          status: OrderStatus.processing,
          expectedPickupDate: OrderDate.fromDate(
            DateTime.now().add(const Duration(days: 3)),
          ),
          notes: 'طلب مبدئي',
          customerPickupRequested: false,
          customerPickupFee: Money.zero,
          customerDeliveryRequested: false,
          customerDeliveryFee: Money.zero,
          subtotal: Money.fromPiastres(1500 + (4000 * 6)), // 1500 + 24000 = 25500
          discount: Money.zero,
          tax: Money.zero,
          total: Money.fromPiastres(25500),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final item1 = OrderItem(
          id: testItem1Id,
          orderId: testOrderId,
          itemTypeId: pieceItemTypeId,
          serviceId: pieceServiceId,
          itemTypeNameSnapshot: 'ملابس',
          serviceNameSnapshot: 'غسيل وكوي',
          pricingType: PricingType.perPiece,
          quantity: 1.0,
          unitPrice: Money.fromPiastres(1500),
          calculatedTotal: Money.fromPiastres(1500),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final item2 = OrderItem(
          id: testItem2Id,
          orderId: testOrderId,
          itemTypeId: carpetItemTypeId,
          serviceId: carpetServiceId,
          itemTypeNameSnapshot: 'سجاد-carpet',
          serviceNameSnapshot: 'غسيل سجاد',
          pricingType: PricingType.perSquareMeter,
          quantity: 6.0,
          unitPrice: Money.fromPiastres(4000),
          calculatedTotal: Money.fromPiastres(24000),
          carpetData: CarpetItemData(
            id: testCarpet1Id,
            orderItemId: testItem2Id,
            carpetSizeId: carpetSizeId,
            length: 3.0,
            width: 2.0,
            area: 6.0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await deviceA.orderRepository.createOrder(
          order: initialOrder,
          items: [item1, item2],
        );

        // Push order create from Device A to Supabase
        await deviceA.syncEngine.sync();

        // Device B pulls order create from Supabase with polling loop
        Order? orderOnB;
        final orderDeadline = DateTime.now().add(const Duration(seconds: 15));
        while (DateTime.now().isBefore(orderDeadline)) {
          await deviceB.syncEngine.sync();
          orderOnB = await deviceB.orderRepository.getOrderById(testOrderId);
          if (orderOnB != null) break;
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }

        // Assert Device B has initial aggregate
        expect(orderOnB, isNotNull, reason: 'Order must replicate from Device A to Device B');
        expect(orderOnB!.total, equals(Money.fromPiastres(25500)));

        final itemsOnB = await deviceB.ordersDao.getOrderItemsWithCarpets(testOrderId);
        expect(itemsOnB.length, equals(2));

        // ---------------------------------------------------------------------
        // STEP 3: Device A performs local edit:
        // - Removes Item 1 (piece)
        // - Updates Item 2 (carpet: custom unit price 5000)
        // - Adds Item 3 (piece: new item)
        // ---------------------------------------------------------------------
        final editInput = EditProcessingOrderInput(
          orderId: testOrderId,
          customerId: testCustomerId,
          expectedPickupDate: OrderDate.fromDate(
            DateTime.now().add(const Duration(days: 4)),
          ),
          notes: 'تم التعديل على جهاز A',
          customerPickupRequested: false,
          customerPickupFee: Money.zero,
          customerDeliveryRequested: false,
          customerDeliveryFee: Money.zero,
          discount: Money.zero,
          deletedItemIds: [testItem1Id], // Item 1 removed!
          modifiedItems: [
            OrderItemEditInput(
              id: testItem2Id,
              serviceId: carpetServiceId,
              customUnitPrice: Money.fromPiastres(5000), // Updated unit price
              carpetData: const CarpetItemInput(
                carpetSizeId: carpetSizeId,
                length: 3.0,
                width: 2.0,
              ),
              notes: 'تعديل سعر السجاد',
            ),
          ],
          newItems: [
            CreateOrderItemInput(
              itemTypeId: pieceItemTypeId,
              serviceId: pieceServiceId,
              physicalQuantity: 1,
              customUnitPrice: Money.fromPiastres(2000),
              notes: 'قطعة جديدة مضافة',
            ),
          ],
        );

        // Perform local edit on Device A
        final editedOrderA = await deviceA.orderRepository.editProcessingOrder(editInput);
        expect(editedOrderA.status, equals(OrderStatus.processing));
        // Subtotal: 5000*6 (30000) + 2000 = 32000
        expect(editedOrderA.total, equals(Money.fromPiastres(32000)));

        // Device A has outbox entry for edit
        final pendingOpsA = await deviceA.syncOperationsDao.getPendingOperations();
        final editOpA = pendingOpsA.firstWhere(
          (o) => o.entityId == testOrderId && o.operationType == 'edit',
        );
        expect(editOpA, isNotNull);

        // ---------------------------------------------------------------------
        // STEP 4: Device A pushes edit to Supabase
        // ---------------------------------------------------------------------
        await deviceA.syncEngine.sync();

        final pendingOpsAAfter = await deviceA.syncOperationsDao.getPendingOperations();
        expect(pendingOpsAAfter, isEmpty, reason: 'Device A outbox should be empty after sync');

        // ---------------------------------------------------------------------
        // STEP 5: Device B checks outbox BEFORE pulling
        // ---------------------------------------------------------------------
        final pendingOpsBBefore = await deviceB.syncOperationsDao.getPendingOperations();
        expect(pendingOpsBBefore, isEmpty, reason: 'Device B outbox must be 0 before pulling');

        // ---------------------------------------------------------------------
        // STEP 6: Device B pulls remote sync_changes and applies _applyOrderEdit
        // ---------------------------------------------------------------------
        Order? editedOnB;
        final editDeadline = DateTime.now().add(const Duration(seconds: 15));
        while (DateTime.now().isBefore(editDeadline)) {
          await deviceB.syncEngine.sync();
          final bOrder = await deviceB.orderRepository.getOrderById(testOrderId);
          if (bOrder != null && bOrder.notes == 'تم التعديل على جهاز A') {
            editedOnB = bOrder;
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
        expect(editedOnB, isNotNull, reason: 'Edited order must replicate from Device A to Device B');

        // ---------------------------------------------------------------------
        // STEP 7: Verify Device B authoritative aggregate reconciliation
        // ---------------------------------------------------------------------
        // A. Full aggregate replacement: Item 1 must NO LONGER exist on Device B
        final localItem1OnB = await (deviceB.db.select(deviceB.db.orderItems)
              ..where((t) => t.id.equals(testItem1Id)))
            .getSingleOrNull();
        expect(localItem1OnB, isNull, reason: 'Item 1 was removed on Device A; must be deleted on Device B');

        // B & C. Existing item update: Item 2 must have updated price on Device B
        final localItem2OnB = await (deviceB.db.select(deviceB.db.orderItems)
              ..where((t) => t.id.equals(testItem2Id)))
            .getSingleOrNull();
        expect(localItem2OnB, isNotNull);
        expect(localItem2OnB!.unitPrice, equals(5000));
        expect(localItem2OnB.calculatedTotal, equals(30000));
        expect(localItem2OnB.notes, equals('تعديل سعر السجاد'));

        // D. Carpet metadata: Item 2 carpet is intact with area 6.0
        final carpetOnB = await (deviceB.db.select(deviceB.db.orderItemCarpets)
              ..where((t) => t.orderItemId.equals(testItem2Id)))
            .getSingleOrNull();
        expect(carpetOnB, isNotNull);
        expect(carpetOnB!.area, equals(6.0));

        // B. New item replication: Exactly 2 items total on Device B (Item 2 and the newly added item)
        final allItemsOnB = await (deviceB.db.select(deviceB.db.orderItems)
              ..where((t) => t.orderId.equals(testOrderId)))
            .get();
        expect(allItemsOnB.length, equals(2), reason: 'Device B must have exactly surviving item + new item');

        // G. Status and order header on Device B
        final localOrderB = await deviceB.orderRepository.getOrderById(testOrderId);
        expect(localOrderB!.status, equals(OrderStatus.processing));
        expect(localOrderB.total, equals(Money.fromPiastres(32000)));
        expect(localOrderB.notes, equals('تم التعديل على جهاز A'));

        // ---------------------------------------------------------------------
        // STEP 8: STRICT CONSTRAINT 3 & 6F: ZERO NEW OUTBOX OPERATIONS ON DEVICE B!
        // ---------------------------------------------------------------------
        final pendingOpsBAfter = await deviceB.syncOperationsDao.getPendingOperations();
        expect(
          pendingOpsBAfter,
          isEmpty,
          reason: 'Remote reconciliation on Device B must NEVER create outbox operations (zero echo)',
        );

        // ---------------------------------------------------------------------
        // STEP 9: CONSTRAINT 6E: Idempotent re-sync produces ZERO duplicates
        // ---------------------------------------------------------------------
        await deviceB.syncEngine.sync();

        final allItemsOnBAfter = await (deviceB.db.select(deviceB.db.orderItems)
              ..where((t) => t.orderId.equals(testOrderId)))
            .get();
        expect(allItemsOnBAfter.length, equals(2), reason: 'Re-sync must not duplicate items');

        final pendingOpsBFinal = await deviceB.syncOperationsDao.getPendingOperations();
        expect(pendingOpsBFinal, isEmpty);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
