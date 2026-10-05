// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/application/use_cases/create_order_use_case.dart';
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
import 'package:laundry_management/data/local/daos/item_definitions_dao.dart';
import 'package:laundry_management/data/local/daos/item_types_dao.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/services_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/daos/sync_state_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart'
    hide
        Customer,
        Order,
        OrderItem,
        Payment,
        Service,
        ServiceItemType,
        ItemType;
import 'package:laundry_management/data/repositories/customer_repository_impl.dart';
import 'package:laundry_management/data/repositories/item_definition_repository_impl.dart';
import 'package:laundry_management/data/repositories/item_type_repository_impl.dart';
import 'package:laundry_management/data/repositories/order_repository_impl.dart';
import 'package:laundry_management/data/repositories/service_repository_impl.dart';
import 'package:laundry_management/data/sync/remote_change_applier.dart';
import 'package:laundry_management/data/sync/sync_engine.dart';
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/domain/entities/item_type.dart';
import 'package:laundry_management/domain/entities/service.dart';
import 'package:laundry_management/domain/entities/service_item_type.dart';
import 'package:laundry_management/domain/enums/payment_method.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/sync/sync_error_classifier.dart';
import 'package:laundry_management/domain/sync/sync_retry_policy.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';
import 'package:uuid/uuid.dart';

class _E2ETestNetworkInfo implements NetworkInfo {
  bool isConnectedValue;
  _E2ETestNetworkInfo({this.isConnectedValue = true});

  @override
  Future<bool> get isConnected async => isConnectedValue;

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(isConnectedValue);
}

String? _mutationE2eSkipReason() {
  final url = Platform.environment['SUPABASE_E2E_URL']?.trim();
  final key = Platform.environment['SUPABASE_E2E_ANON_KEY']?.trim();
  if (url == null || url.isEmpty || key == null || key.isEmpty) {
    return 'Set SUPABASE_E2E_URL and SUPABASE_E2E_ANON_KEY for mutation E2E';
  }
  return null;
}

Future<void> seedHighestOrderNumber(
  Dio prodDio,
  CustomersDao customersDao,
  OrdersDao ordersDao,
) async {
  try {
    final res = await prodDio.get('/api/v1/orders');
    if (res.statusCode == 200 && res.data is List) {
      final list = res.data as List;
      final yearPrefix = (DateTime.now().year % 100).toString().padLeft(2, '0');
      final canonicalRegex = RegExp(
        '^${RegExp.escape(yearPrefix)}-(\\d{3,})\$',
      );
      var maxSeq = 0;
      for (final ord in list) {
        final numStr = ord['order_number'] as String?;
        if (numStr != null) {
          final m = canonicalRegex.firstMatch(numStr);
          if (m != null) {
            final s = int.tryParse(m.group(1)!);
            if (s != null && s > maxSeq) maxSeq = s;
          }
        }
      }
      if (maxSeq > 0) {
        final dummyCustId =
            'c0000000-0000-4000-8000-${DateTime.now().microsecondsSinceEpoch.toString().padLeft(12, '0').substring(0, 12)}';
        await customersDao.insertCustomer(
          CustomersCompanion(
            id: Value(dummyCustId),
            name: const Value('Seed Baseline Customer'),
            phone: Value(
              '010${DateTime.now().microsecondsSinceEpoch.toString().substring(5, 13)}',
            ),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await ordersDao.insertOrder(
          OrdersCompanion(
            id: Value(
              'd0000000-0000-4000-8000-${DateTime.now().microsecondsSinceEpoch.toString().padLeft(12, '0').substring(0, 12)}',
            ),
            orderNumber: Value(
              '$yearPrefix-${maxSeq.toString().padLeft(3, '0')}',
            ),
            customerId: Value(dummyCustId),
            status: const Value('processing'),
            expectedPickupDate: Value(DateTime.now()),
            subtotal: const Value(0),
            total: const Value(0),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    }
  } catch (e) {
    print('seedHighestOrderNumber warning: $e');
  }
}

void main() {
  group('Production E2E Sync Remediation Verification', () {
    const uuid = Uuid();
    late SupabaseConfig e2eConfig;
    late Dio e2eDio;
    var e2eConfigured = false;
    // Records every HTTP exchange (method, path, status, error message) so the
    // causal dispatch order and any 42883 / uuid = text / 422 failures are
    // asserted explicitly. Never records headers (no secrets).
    final httpLog = <Map<String, dynamic>>[];

    setUpAll(() {
      final e2eUrl = Platform.environment['SUPABASE_E2E_URL']?.trim();
      final e2eAnonKey = Platform.environment['SUPABASE_E2E_ANON_KEY']?.trim();
      final allowProductionMutation =
          Platform.environment['ALLOW_PRODUCTION_E2E_MUTATION'] == 'true';

      if (e2eUrl == null ||
          e2eUrl.isEmpty ||
          e2eAnonKey == null ||
          e2eAnonKey.isEmpty) {
        markTestSkipped(
          'Mutation E2E tests require SUPABASE_E2E_URL and '
          'SUPABASE_E2E_ANON_KEY for a dedicated test/dev project. '
          'They never read release_env.json or fall back to production.',
        );
        return;
      }

      e2eConfig = SupabaseConfig.resolve(
        customUrlRoot: e2eUrl,
        customAnonKey: e2eAnonKey,
        isRelease: false,
      );
      e2eConfigured = true;

      if (e2eConfig.urlRoot.contains(SupabaseConfig.prodProjectRef) &&
          !allowProductionMutation) {
        throw StateError(
          'Refusing mutation E2E against the production project. Set '
          'ALLOW_PRODUCTION_E2E_MUTATION=true only for an explicit dangerous run.',
        );
      }

      final client = DioClient(baseUrl: e2eConfig.apiUrl);
      e2eDio = client.dio;
      e2eDio.interceptors.add(
        InterceptorsWrapper(
          onResponse: (res, handler) {
            httpLog.add({
              'method': res.requestOptions.method,
              'path': res.requestOptions.path,
              'status': res.statusCode,
            });
            handler.next(res);
          },
          onError: (err, handler) {
            httpLog.add({
              'method': err.requestOptions.method,
              'path': err.requestOptions.path,
              'status': err.response?.statusCode,
              'error': err.response?.data?.toString() ?? err.message,
            });
            handler.next(err);
          },
        ),
      );
    });

    setUp(() {
      if (!e2eConfigured) {
        markTestSkipped(
          'Dedicated mutation E2E credentials are not configured.',
        );
      }
    });

    test(
      'PHASE 3 & 4: Full E2E chain (Customer -> Service -> ServiceItemPricing -> Order -> Payment) syncs to Production',
      () async {
        final runId = DateTime.now().millisecondsSinceEpoch
            .toString()
            .substring(6);
        final db = AppDatabase(NativeDatabase.memory(), false);
        final syncOpsDao = SyncOperationsDao(db);
        final syncStateDao = SyncStateDao(db);
        final customersDao = CustomersDao(db);
        final ordersDao = OrdersDao(db);
        final paymentsDao = PaymentsDao(db);
        final storageRecordsDao = StorageRecordsDao(db);
        final servicesDao = ServicesDao(db);
        final itemTypesDao = ItemTypesDao(db);
        final itemDefinitionsDao = ItemDefinitionsDao(db);

        final customerRepo = CustomerRepositoryImpl(
          customersDao: customersDao,
          syncOperationsDao: syncOpsDao,
          db: db,
        );
        final serviceRepo = ServiceRepositoryImpl(
          servicesDao: servicesDao,
          syncOperationsDao: syncOpsDao,
          db: db,
        );
        final itemTypeRepo = ItemTypeRepositoryImpl(
          itemTypesDao: itemTypesDao,
          syncOperationsDao: syncOpsDao,
          db: db,
        );
        final itemDefinitionRepo = ItemDefinitionRepositoryImpl(
          itemDefinitionsDao: itemDefinitionsDao,
          syncOperationsDao: syncOpsDao,
          db: db,
        );
        final orderRepo = OrderRepositoryImpl(
          ordersDao: ordersDao,
          paymentsDao: paymentsDao,
          storageRecordsDao: storageRecordsDao,
          syncOperationsDao: syncOpsDao,
          db: db,
        );

        final createOrderUseCase = CreateOrderUseCase(
          orderRepository: orderRepo,
          customerRepository: customerRepo,
          serviceRepository: serviceRepo,
          itemTypeRepository: itemTypeRepo,
          itemDefinitionRepository: itemDefinitionRepo,
        );

        final fakeNetwork = _E2ETestNetworkInfo(isConnectedValue: true);
        final remoteDispatcher = RemoteApiDispatcher(
          customerApi: CustomerRemoteApi(e2eDio),
          orderApi: OrderRemoteApi(e2eDio),
          paymentApi: PaymentRemoteApi(e2eDio),
          refundApi: RefundRemoteApi(e2eDio),
          storageApi: StorageRemoteApi(e2eDio),
          expenseApi: ExpenseRemoteApi(e2eDio),
          masterDataApi: MasterDataRemoteApi(e2eDio),
        );
        final remoteDataSource = SyncRemoteDataSourceImpl(
          SyncRemoteApi(e2eDio),
        );
        final changeApplier = RemoteChangeApplier(
          db: db,
          syncStateDao: syncStateDao,
        );

        final syncEngine = SyncEngine(
          syncOperationsDao: syncOpsDao,
          remoteApiDispatcher: remoteDispatcher,
          networkInfo: fakeNetwork,
          retryPolicy: SyncRetryPolicy(),
          errorClassifier: const SyncErrorClassifier(),
          syncRemoteDataSource: remoteDataSource,
          remoteChangeApplier: changeApplier,
          syncStateDao: syncStateDao,
        );

        await seedHighestOrderNumber(e2eDio, customersDao, ordersDao);
        final baseRes = await e2eDio.get(
          '/api/v1/sync/changes?after=0&limit=1',
        );
        final baselineSeq =
            (baseRes.data['latest_sequence'] as num?)?.toInt() ?? 0;
        await syncStateDao.updateLastAppliedSequence(baselineSeq);
        httpLog.clear();

        final now = DateTime.now();

        // 1. Create a NEW unique test ItemType ("بطانية زوجى $runId")
        final itemTypeId = uuid.v4();
        final itemType = ItemType(
          id: itemTypeId,
          name: 'بطانية زوجى $runId',
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );
        await itemTypeRepo.createItemType(itemType);

        // 2. Create a NEW Service ("غسيل $runId") with item pricing for "بطانية زوجى $runId"
        final serviceId = uuid.v4();
        final service = Service(
          id: serviceId,
          name: 'غسيل $runId',
          description: 'خدمة غسيل بطاطين تجربة الإنتاج',
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );
        final serviceItemType = ServiceItemType(
          id: uuid.v4(),
          serviceId: serviceId,
          itemTypeId: itemTypeId,
          pricingType: PricingType.perPiece,
          price: const Money.fromPiastres(5000), // 50 EGP
          createdAt: now,
          updatedAt: now,
        );
        await serviceRepo.createService(
          service,
          serviceItemTypes: [serviceItemType],
        );

        // 3. Create a NEW unique Customer
        final customerId = uuid.v4();
        final customerPhone =
            '010${DateTime.now().millisecondsSinceEpoch.toString().substring(5, 13)}';
        final customerName = 'عميل تجربة الإنتاج $runId';
        final customer = Customer(
          id: customerId,
          name: customerName,
          phone: customerPhone,
          createdAt: now,
          updatedAt: now,
        );
        await customerRepo.createCustomer(customer);

        // 4. Create Order: 2 x "بطانية زوجى $runId", Service "غسيل $runId", partial payment 50 EGP
        final createOrderInput = CreateOrderInput(
          customerId: customerId,
          expectedPickupDate: OrderDate.fromDate(
            now.add(const Duration(days: 2)),
          ),
          items: [
            CreateOrderItemInput(
              itemTypeId: itemTypeId,
              serviceId: serviceId,
              physicalQuantity: 2,
            ),
          ],
          initialPayment: const InitialPaymentInput(
            amount: Money.fromPiastres(5000), // 50 EGP
            paymentMethod: PaymentMethod.cash,
          ),
        );

        final order = await createOrderUseCase.execute(createOrderInput);
        expect(order.orderNumber, isNotEmpty);
        expect(order.total.piastres, equals(10000)); // 2 * 50 EGP = 100 EGP

        final localItems = await (db.select(
          db.orderItems,
        )..where((t) => t.orderId.equals(order.id))).get();
        expect(localItems.length, equals(2));
        expect(
          localItems.fold<double>(0, (sum, it) => sum + it.quantity),
          equals(2),
        );

        // 5. Inspect local outbox before sync
        final pendingBeforeSync = await syncOpsDao.getPendingOperations();
        expect(pendingBeforeSync.length, equals(5));
        expect(
          pendingBeforeSync.map((e) => e.entityType).toSet(),
          containsAll(['item_type', 'service', 'customer', 'order', 'payment']),
        );

        for (final op in pendingBeforeSync) {
          print('[OUTBOX OP] ${op.entityType} (${op.entityId}): ${op.payload}');
        }

        print('\n[Phase 3] Initiating SyncEngine push to Production...');
        // 6. Execute synchronization
        await syncEngine.sync();

        final allOps = await (db.select(
          db.syncOperations,
        )..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();
        for (final op in allOps) {
          print(
            '[DIAGNOSTIC] ${op.entityType}:${op.entityId} -> ${op.status} (error: ${op.lastError})',
          );
        }

        final pendingAfterSync = await syncOpsDao.getPendingOperations();
        expect(
          pendingAfterSync,
          isEmpty,
          reason:
              'All operations in the dependency chain must be marked synced without errors',
        );

        // G. Outbox: nothing pending/failed, no duplicates, no errors.
        expect(allOps.length, equals(5));
        expect(
          allOps.map((o) => '${o.entityType}:${o.entityId}').toSet().length,
          equals(5),
          reason: 'No duplicate operations may exist for this scenario',
        );
        for (final op in allOps) {
          expect(
            op.status,
            equals('synced'),
            reason: 'Op ${op.entityType}:${op.entityId} must be synced',
          );
          expect(op.lastError, equals(null));
        }
        print(
          '[Phase 3] Local outbox confirmed: all 5 operations marked synced.',
        );

        // A-E / F. Every mutation returned HTTP 201 with no 42883 / uuid = text / 422.
        final posts = httpLog.where((e) => e['method'] == 'POST').toList();
        for (final p in posts) {
          expect(
            p['status'],
            equals(201),
            reason: 'POST ${p['path']} failed: ${p['error']}',
          );
          expect('${p['error']}', isNot(contains('42883')));
          expect('${p['error']}', isNot(contains('uuid = text')));
        }
        expect(httpLog.where((e) => e['status'] == 422), isEmpty);
        final postPaths = posts.map((e) => e['path'] as String).toList();
        int idx(String suffix) =>
            postPaths.indexWhere((p) => p.endsWith(suffix));
        expect(idx('/item-types'), isNonNegative);
        expect(idx('/services'), isNonNegative);
        expect(idx('/customers'), isNonNegative);
        expect(idx('/orders'), isNonNegative);
        expect(idx('/payments'), isNonNegative);
        expect(
          postPaths.length,
          equals(5),
          reason: 'Exactly one POST per queued op (no duplicates)',
        );
        // F. Causal order: payment strictly after order; order after its parents.
        expect(idx('/payments'), greaterThan(idx('/orders')));
        expect(idx('/orders'), greaterThan(idx('/customers')));
        expect(idx('/orders'), greaterThan(idx('/services')));
        expect(idx('/services'), greaterThan(idx('/item-types')));
        print(
          '[Phase 3] HTTP 201 for all 5 POSTs; dispatch order: ${postPaths.join(' -> ')}',
        );

        // A. Verify remote item type.
        final itRes = await e2eDio.get('/api/v1/item-types/$itemTypeId');
        expect(itRes.statusCode, equals(200));
        expect(itRes.data['id'], equals(itemTypeId));
        expect(itRes.data['name'], equals('بطانية زوجى $runId'));
        print(' - Item Type in Production: OK (id: $itemTypeId)');

        // 8. PHASE 4: READ-ONLY Verification directly against Production Supabase
        print(
          '\n[Phase 4] Verifying created records in Production via read-only REST inspection...',
        );

        // Verify Customer on Production
        final custRes = await e2eDio.get('/api/v1/customers/$customerId');
        expect(custRes.statusCode, equals(200));
        expect(custRes.data['id'], equals(customerId));
        expect(custRes.data['name'], equals(customerName));
        expect(custRes.data['phone'], equals(customerPhone));
        print(
          ' - Customer in Production: OK (id: $customerId, phone: $customerPhone)',
        );

        // Verify Service and ServiceItemPricing relation on Production
        final srvRes = await e2eDio.get('/api/v1/services/$serviceId');
        expect(srvRes.statusCode, equals(200));
        expect(srvRes.data['id'], equals(serviceId));
        expect(srvRes.data['name'], equals('غسيل $runId'));
        final srvItemTypes = srvRes.data['service_item_types'] as List;
        expect(srvItemTypes.length, equals(1));
        expect(
          srvItemTypes.any(
            (it) =>
                it['service_id'] == serviceId &&
                it['item_type_id'] == itemTypeId &&
                it['pricing_type'] == 'per_piece' &&
                it['price'] == 5000,
          ),
          isTrue,
        );
        print(
          ' - Service & ServiceItemPricing in Production: OK (id: $serviceId, items: ${srvItemTypes.length})',
        );

        // Verify Order on Production (including order_items aggregate)
        final orderRes = await e2eDio.get('/api/v1/orders/${order.id}');
        expect(orderRes.statusCode, equals(200));
        expect(orderRes.data['id'], equals(order.id));
        expect(orderRes.data['customer_id'], equals(customerId));
        expect(orderRes.data['total'], equals(10000));
        final orderItems =
            (orderRes.data['order_items'] ?? orderRes.data['items']) as List;
        expect(orderItems.length, equals(2));
        expect(
          orderItems.every(
            (it) =>
                it['service_id'] == serviceId &&
                it['item_type_id'] == itemTypeId,
          ),
          isTrue,
        );
        expect(
          orderItems.fold<num>(0, (sum, it) => sum + (it['quantity'] as num)),
          equals(2),
        );
        print(
          ' - Order & OrderItems in Production: OK (id: ${order.id}, total: ${orderRes.data['total']}, items: ${orderItems.length})',
        );

        // Verify Payment on Production (must reference remote order)
        final payments = await paymentsDao.getPaymentsForOrder(order.id);
        expect(payments, isNotEmpty);
        final paymentId = payments.first.id;

        final payRes = await e2eDio.get('/api/v1/payments/$paymentId');
        expect(payRes.statusCode, equals(200));
        expect(payRes.data['id'], equals(paymentId));
        expect(payRes.data['order_id'], equals(order.id));
        expect(payRes.data['amount'], equals(5000));
        expect(payRes.data['payment_method'], equals('cash'));
        print(
          ' - Payment in Production: OK (id: $paymentId, order_id: ${payRes.data['order_id']}, amount: ${payRes.data['amount']})',
        );

        // Verify Sync Changes on Production
        // Read from the pre-test baseline so growth of the feed cannot hide entries.
        final changesRes = await e2eDio.get(
          '/api/v1/sync/changes?after=$baselineSeq&limit=100',
        );
        expect(changesRes.statusCode, equals(200));
        final changes = (changesRes.data['changes'] as List);
        final changedEntityIds = changes
            .map((c) => c['entity_id'] as String)
            .toSet();
        expect(changedEntityIds, contains(itemTypeId));
        expect(changedEntityIds, contains(customerId));
        expect(changedEntityIds, contains(serviceId));
        expect(changedEntityIds, contains(order.id));
        expect(changedEntityIds, contains(paymentId));
        print(
          ' - Sync Changes in Production: OK (contains customer, service, order, and payment sequence entries)',
        );

        await db.close();
      },
    );

    test(
      'PHASE 5: Offline outbox accumulation, connectivity restoration, and dependency barrier verification',
      () async {
        final runId =
            'off_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
        final db = AppDatabase(NativeDatabase.memory(), false);
        final syncOpsDao = SyncOperationsDao(db);
        final syncStateDao = SyncStateDao(db);
        final customersDao = CustomersDao(db);
        final ordersDao = OrdersDao(db);
        final paymentsDao = PaymentsDao(db);
        final storageRecordsDao = StorageRecordsDao(db);
        final servicesDao = ServicesDao(db);
        final itemTypesDao = ItemTypesDao(db);
        final itemDefinitionsDao = ItemDefinitionsDao(db);

        final customerRepo = CustomerRepositoryImpl(
          customersDao: customersDao,
          syncOperationsDao: syncOpsDao,
          db: db,
        );
        final serviceRepo = ServiceRepositoryImpl(
          servicesDao: servicesDao,
          syncOperationsDao: syncOpsDao,
          db: db,
        );
        final itemTypeRepo = ItemTypeRepositoryImpl(
          itemTypesDao: itemTypesDao,
          syncOperationsDao: syncOpsDao,
          db: db,
        );
        final itemDefinitionRepo = ItemDefinitionRepositoryImpl(
          itemDefinitionsDao: itemDefinitionsDao,
          syncOperationsDao: syncOpsDao,
          db: db,
        );
        final orderRepo = OrderRepositoryImpl(
          ordersDao: ordersDao,
          paymentsDao: paymentsDao,
          storageRecordsDao: storageRecordsDao,
          syncOperationsDao: syncOpsDao,
          db: db,
        );

        final createOrderUseCase = CreateOrderUseCase(
          orderRepository: orderRepo,
          customerRepository: customerRepo,
          serviceRepository: serviceRepo,
          itemTypeRepository: itemTypeRepo,
          itemDefinitionRepository: itemDefinitionRepo,
        );

        // 1. START OFFLINE
        final fakeNetwork = _E2ETestNetworkInfo(isConnectedValue: false);
        final remoteDispatcher = RemoteApiDispatcher(
          customerApi: CustomerRemoteApi(e2eDio),
          orderApi: OrderRemoteApi(e2eDio),
          paymentApi: PaymentRemoteApi(e2eDio),
          refundApi: RefundRemoteApi(e2eDio),
          storageApi: StorageRemoteApi(e2eDio),
          expenseApi: ExpenseRemoteApi(e2eDio),
          masterDataApi: MasterDataRemoteApi(e2eDio),
        );
        final remoteDataSource = SyncRemoteDataSourceImpl(
          SyncRemoteApi(e2eDio),
        );
        final changeApplier = RemoteChangeApplier(
          db: db,
          syncStateDao: syncStateDao,
        );

        final syncEngine = SyncEngine(
          syncOperationsDao: syncOpsDao,
          remoteApiDispatcher: remoteDispatcher,
          networkInfo: fakeNetwork,
          retryPolicy: SyncRetryPolicy(),
          errorClassifier: const SyncErrorClassifier(),
          syncRemoteDataSource: remoteDataSource,
          remoteChangeApplier: changeApplier,
          syncStateDao: syncStateDao,
        );
        final changesBaseline = await e2eDio.get(
          '/api/v1/sync/changes?after=0&limit=1',
        );
        final latestSeq =
            (changesBaseline.data['latest_sequence'] as num?)?.toInt() ?? 0;
        await syncStateDao.updateLastAppliedSequence(latestSeq);
        await seedHighestOrderNumber(e2eDio, customersDao, ordersDao);

        final now = DateTime.now();

        // Create ItemType & Service while OFFLINE
        final itemTypeId = uuid.v4();
        await itemTypeRepo.createItemType(
          ItemType(
            id: itemTypeId,
            name: 'بطانية أوفلاين $runId',
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ),
        );

        final serviceId = uuid.v4();
        await serviceRepo.createService(
          Service(
            id: serviceId,
            name: 'غسيل أوفلاين $runId',
            description: null,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ),
          serviceItemTypes: [
            ServiceItemType(
              id: uuid.v4(),
              serviceId: serviceId,
              itemTypeId: itemTypeId,
              pricingType: PricingType.perPiece,
              price: const Money.fromPiastres(6000),
              createdAt: now,
              updatedAt: now,
            ),
          ],
        );

        // Create Customer while OFFLINE
        final customerId = uuid.v4();
        final customerPhone =
            '011${DateTime.now().millisecondsSinceEpoch.toString().substring(5, 13)}';
        await customerRepo.createCustomer(
          Customer(
            id: customerId,
            name: 'عميل أوفلاين $runId',
            phone: customerPhone,
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Create Order while OFFLINE
        final order = await createOrderUseCase.execute(
          CreateOrderInput(
            customerId: customerId,
            expectedPickupDate: OrderDate.fromDate(
              now.add(const Duration(days: 3)),
            ),
            items: [
              CreateOrderItemInput(
                itemTypeId: itemTypeId,
                serviceId: serviceId,
                physicalQuantity: 1,
              ),
            ],
            initialPayment: const InitialPaymentInput(
              amount: Money.fromPiastres(6000),
              paymentMethod: PaymentMethod.cash,
            ),
          ),
        );

        // Verify outbox contains pending operations while offline
        final pendingOffline = await syncOpsDao.getPendingOperations();
        expect(pendingOffline.length, equals(5));

        // Attempting sync while offline must safely do zero network dispatches
        await syncEngine.sync();
        final pendingStillOffline = await syncOpsDao.getPendingOperations();
        expect(pendingStillOffline.length, equals(5));
        print(
          '[Phase 5] Offline accumulation confirmed: 5 operations pending in outbox.',
        );

        // 2. RESTORE CONNECTIVITY
        fakeNetwork.isConnectedValue = true;
        print('[Phase 5] Connectivity restored. Triggering sync...');
        await syncEngine.sync();

        // 3. Confirm all operations completed successfully
        final pendingOnline = await syncOpsDao.getPendingOperations();
        expect(
          pendingOnline,
          isEmpty,
          reason:
              'All offline queued operations must sync after connection restored',
        );

        // Confirm remote records in Production
        final remoteOrder = await e2eDio.get('/api/v1/orders/${order.id}');
        expect(remoteOrder.statusCode, equals(200));
        expect(remoteOrder.data['id'], equals(order.id));
        print(
          '[Phase 5] Offline resume confirmed: Order successfully created on Production.',
        );

        await db.close();
      },
    );

    test(
      'PHASE 6: Dependency barrier - failed order:create keeps payment:create pending (never dispatched) and does not block independent ops',
      () async {
        final runId =
            'bar_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
        final db = AppDatabase(NativeDatabase.memory(), false);
        final syncOpsDao = SyncOperationsDao(db);
        final syncStateDao = SyncStateDao(db);
        final customersDao = CustomersDao(db);
        final ordersDao = OrdersDao(db);
        final paymentsDao = PaymentsDao(db);
        final storageRecordsDao = StorageRecordsDao(db);
        final servicesDao = ServicesDao(db);
        final itemTypesDao = ItemTypesDao(db);
        final itemDefinitionsDao = ItemDefinitionsDao(db);

        final customerRepo = CustomerRepositoryImpl(
          customersDao: customersDao,
          syncOperationsDao: syncOpsDao,
          db: db,
        );
        final serviceRepo = ServiceRepositoryImpl(
          servicesDao: servicesDao,
          syncOperationsDao: syncOpsDao,
          db: db,
        );
        final itemTypeRepo = ItemTypeRepositoryImpl(
          itemTypesDao: itemTypesDao,
          syncOperationsDao: syncOpsDao,
          db: db,
        );
        final itemDefinitionRepo = ItemDefinitionRepositoryImpl(
          itemDefinitionsDao: itemDefinitionsDao,
          syncOperationsDao: syncOpsDao,
          db: db,
        );
        final orderRepo = OrderRepositoryImpl(
          ordersDao: ordersDao,
          paymentsDao: paymentsDao,
          storageRecordsDao: storageRecordsDao,
          syncOperationsDao: syncOpsDao,
          db: db,
        );
        final createOrderUseCase = CreateOrderUseCase(
          orderRepository: orderRepo,
          customerRepository: customerRepo,
          serviceRepository: serviceRepo,
          itemTypeRepository: itemTypeRepo,
          itemDefinitionRepository: itemDefinitionRepo,
        );
        final syncEngine = SyncEngine(
          syncOperationsDao: syncOpsDao,
          remoteApiDispatcher: RemoteApiDispatcher(
            customerApi: CustomerRemoteApi(e2eDio),
            orderApi: OrderRemoteApi(e2eDio),
            paymentApi: PaymentRemoteApi(e2eDio),
            refundApi: RefundRemoteApi(e2eDio),
            storageApi: StorageRemoteApi(e2eDio),
            expenseApi: ExpenseRemoteApi(e2eDio),
            masterDataApi: MasterDataRemoteApi(e2eDio),
          ),
          networkInfo: _E2ETestNetworkInfo(isConnectedValue: true),
          retryPolicy: SyncRetryPolicy(),
          errorClassifier: const SyncErrorClassifier(),
          syncRemoteDataSource: SyncRemoteDataSourceImpl(SyncRemoteApi(e2eDio)),
          remoteChangeApplier: RemoteChangeApplier(
            db: db,
            syncStateDao: syncStateDao,
          ),
          syncStateDao: syncStateDao,
        );

        final baseline = await e2eDio.get(
          '/api/v1/sync/changes?after=0&limit=1',
        );
        await syncStateDao.updateLastAppliedSequence(
          (baseline.data['latest_sequence'] as num?)?.toInt() ?? 0,
        );
        await seedHighestOrderNumber(e2eDio, customersDao, ordersDao);

        final now = DateTime.now();
        final itemTypeId = uuid.v4();
        await itemTypeRepo.createItemType(
          ItemType(
            id: itemTypeId,
            name: 'بطانية حاجز $runId',
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ),
        );
        final serviceId = uuid.v4();
        await serviceRepo.createService(
          Service(
            id: serviceId,
            name: 'غسيل حاجز $runId',
            description: null,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ),
          serviceItemTypes: [
            ServiceItemType(
              id: uuid.v4(),
              serviceId: serviceId,
              itemTypeId: itemTypeId,
              pricingType: PricingType.perPiece,
              price: const Money.fromPiastres(4000),
              createdAt: now,
              updatedAt: now,
            ),
          ],
        );
        // Simulate "parent catalog data never reached production": drop the
        // item_type/service ops from the local outbox as already-synced, so the
        // order references a service that does NOT exist remotely. The remote
        // RPC must reject the order (rolled back, nothing persisted) and the
        // payment must be held back by the dependency barrier.
        for (final op in await syncOpsDao.getPendingOperations()) {
          if (op.entityType == 'item_type' || op.entityType == 'service') {
            await syncOpsDao.markOperationSynced(op.id);
          }
        }

        final customerId = uuid.v4();
        await customerRepo.createCustomer(
          Customer(
            id: customerId,
            name: 'عميل حاجز $runId',
            phone:
                '012${DateTime.now().millisecondsSinceEpoch.toString().substring(5, 13)}',
            createdAt: now,
            updatedAt: now,
          ),
        );
        final order = await createOrderUseCase.execute(
          CreateOrderInput(
            customerId: customerId,
            expectedPickupDate: OrderDate.fromDate(
              now.add(const Duration(days: 2)),
            ),
            items: [
              CreateOrderItemInput(
                itemTypeId: itemTypeId,
                serviceId: serviceId,
                physicalQuantity: 1,
              ),
            ],
            initialPayment: const InitialPaymentInput(
              amount: Money.fromPiastres(4000),
              paymentMethod: PaymentMethod.cash,
            ),
          ),
        );
        // Independent operation queued BEHIND the failing order/payment.
        final independentCustomerId = uuid.v4();
        await customerRepo.createCustomer(
          Customer(
            id: independentCustomerId,
            name: 'عميل مستقل $runId',
            phone:
                '015${DateTime.now().millisecondsSinceEpoch.toString().substring(5, 13)}',
            createdAt: now,
            updatedAt: now,
          ),
        );

        httpLog.clear();
        await syncEngine.sync();
        await syncEngine
            .sync(); // second pass: barrier must hold, nothing re-dispatched for payment

        final ops = await db.select(db.syncOperations).get();
        SyncOperation opOf(String type, String id) =>
            ops.firstWhere((o) => o.entityType == type && o.entityId == id);

        final orderOp = opOf('order', order.id);
        final paymentId = (await paymentsDao.getPaymentsForOrder(
          order.id,
        )).first.id;
        final paymentOp = opOf('payment', paymentId);
        final parentCustomerOp = opOf('customer', customerId);
        final independentOp = opOf('customer', independentCustomerId);

        print(
          '[Phase 6] order op=${orderOp.id} status=${orderOp.status} error=${orderOp.lastError}',
        );
        print(
          '[Phase 6] payment op=${paymentOp.id} status=${paymentOp.status}',
        );

        expect(parentCustomerOp.status, equals('synced'));
        expect(orderOp.status, isNot(equals('synced')));
        expect(
          paymentOp.status,
          equals('pending'),
          reason:
              'payment:create must stay pending, not failed, while its parent order failed',
        );
        expect(paymentOp.lastError, equals(null));
        expect(
          httpLog.where(
            (e) =>
                e['method'] == 'POST' &&
                (e['path'] as String).endsWith('/payments'),
          ),
          isEmpty,
          reason:
              'payment:create must NEVER be dispatched when order:create failed',
        );
        final orderPosts = httpLog
            .where(
              (e) =>
                  e['method'] == 'POST' &&
                  (e['path'] as String).endsWith('/orders'),
            )
            .toList();
        expect(orderPosts, isNotEmpty);
        expect(orderPosts.first['status'], isNot(equals(201)));
        print(
          '[Phase 6] order POST rejected: status=${orderPosts.first['status']} error=${orderPosts.first['error']}',
        );
        expect(
          independentOp.status,
          equals('synced'),
          reason:
              'Independent customer op must not be blocked by the failed order chain',
        );

        // No orphan payment and no order persisted in production.
        for (final path in [
          '/api/v1/payments/$paymentId',
          '/api/v1/orders/${order.id}',
        ]) {
          final res = await e2eDio.get(
            path,
            options: Options(validateStatus: (_) => true),
          );
          expect(
            res.statusCode,
            equals(404),
            reason: '$path must not exist remotely',
          );
        }
        final indep = await e2eDio.get(
          '/api/v1/customers/$independentCustomerId',
        );
        expect(indep.statusCode, equals(200));

        await db.close();
      },
    );
  }, skip: _mutationE2eSkipReason());
}
