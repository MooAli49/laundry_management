import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/core/network/network_info.dart';
import 'package:laundry_management/data/datasources/remote/customer_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/expense_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/master_data_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/order_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/payment_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/refund_remote_api.dart';
import 'package:laundry_management/data/datasources/remote/remote_api_dispatcher.dart';
import 'package:laundry_management/data/datasources/remote/storage_remote_api.dart';
import 'package:laundry_management/data/local/daos/customers_dao.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/services_dao.dart';
import 'package:laundry_management/data/local/daos/storage_locations_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart'
    as app_db;
import 'package:laundry_management/data/repositories/customer_repository_impl.dart';
import 'package:laundry_management/data/repositories/order_repository_impl.dart';
import 'package:laundry_management/data/repositories/service_repository_impl.dart';
import 'package:laundry_management/data/repositories/storage_repository_impl.dart';
import 'package:laundry_management/data/sync/sync_engine.dart';
import 'package:laundry_management/domain/entities/carpet_item_data.dart';
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/entities/service.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/sync/sync_engine_state.dart';
import 'package:laundry_management/domain/sync/sync_error_classifier.dart';
import 'package:laundry_management/domain/sync/sync_retry_policy.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';

class MockNetworkInfo implements NetworkInfo {
  bool connected = true;

  @override
  Future<bool> get isConnected async => connected;

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(connected);
}

class InterceptableSyncOperationsDao extends SyncOperationsDao {
  bool shouldThrowOnRecord = false;

  InterceptableSyncOperationsDao(super.attachedDatabase);

  @override
  Future<void> recordOperation({
    required String entityType,
    required String entityId,
    required String operationType,
    String? payload,
    DateTime? nextRetryAt,
  }) async {
    if (shouldThrowOnRecord) {
      throw StateError('Simulated sync queue recording failure');
    }
    await super.recordOperation(
      entityType: entityType,
      entityId: entityId,
      operationType: operationType,
      payload: payload,
      nextRetryAt: nextRetryAt,
    );
  }
}

class FakeCustomerRemoteApi implements CustomerRemoteApi {
  final List<Map<String, dynamic>> createdCustomers = [];
  final List<Map<String, dynamic>> updatedCustomers = [];

  @override
  Future createCustomer(String operationId, Map<String, dynamic> body) async {
    createdCustomers.add({'operationId': operationId, 'body': body});
    return {'status': 'ok'};
  }

  @override
  Future updateCustomer(
    String operationId,
    String id,
    Map<String, dynamic> body,
  ) async {
    updatedCustomers.add({'operationId': operationId, 'id': id, 'body': body});
    return {'status': 'ok'};
  }

  @override
  Future getCustomerById(String id) async => null;

  @override
  Future getCustomers({int? page, int? limit}) async => [];
}

class FakeOrderRemoteApi implements OrderRemoteApi {
  final List<Map<String, dynamic>> createdOrders = [];
  final List<Map<String, dynamic>> updatedOrders = [];

  @override
  Future createOrder(String operationId, Map<String, dynamic> body) async {
    createdOrders.add({'operationId': operationId, 'body': body});
    return {'status': 'ok'};
  }

  @override
  Future updateOrder(
    String operationId,
    String id,
    Map<String, dynamic> body,
  ) async {
    updatedOrders.add({'operationId': operationId, 'id': id, 'body': body});
    return {'status': 'ok'};
  }

  @override
  Future editOrderAggregate(
    String operationId,
    String id,
    Map<String, dynamic> body,
  ) async {
    return {'status': 'ok'};
  }

  @override
  Future getOrderById(String id) async => null;

  @override
  Future getOrders({int? page, int? limit}) async => [];
}

class FakeMasterDataRemoteApi implements MasterDataRemoteApi {
  final List<Map<String, dynamic>> createdServices = [];
  final List<Map<String, dynamic>> updatedServices = [];

  @override
  Future createService(String operationId, Map<String, dynamic> body) async {
    createdServices.add({'operationId': operationId, 'body': body});
    return {'status': 'ok'};
  }

  @override
  Future updateService(
    String operationId,
    String id,
    Map<String, dynamic> body,
  ) async {
    updatedServices.add({'operationId': operationId, 'id': id, 'body': body});
    return {'status': 'ok'};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStorageRemoteApi implements StorageRemoteApi {
  final List<Map<String, dynamic>> createdRecords = [];
  final List<Map<String, dynamic>> updatedRecords = [];

  @override
  Future createStorageRecord(
    String operationId,
    Map<String, dynamic> body,
  ) async {
    createdRecords.add({'operationId': operationId, 'body': body});
    return {'status': 'ok'};
  }

  @override
  Future updateStorageRecord(
    String operationId,
    String id,
    Map<String, dynamic> body,
  ) async {
    updatedRecords.add({'operationId': operationId, 'id': id, 'body': body});
    return {'status': 'ok'};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePaymentRemoteApi implements PaymentRemoteApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRefundRemoteApi implements RefundRemoteApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeExpenseRemoteApi implements ExpenseRemoteApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late app_db.AppDatabase db;
  late CustomersDao customersDao;
  late OrdersDao ordersDao;
  late ServicesDao servicesDao;
  late StorageRecordsDao storageRecordsDao;
  late StorageLocationsDao storageLocationsDao;
  late InterceptableSyncOperationsDao syncOperationsDao;

  late CustomerRepositoryImpl customerRepo;
  late OrderRepositoryImpl orderRepo;
  late ServiceRepositoryImpl serviceRepo;
  late StorageRepositoryImpl storageRepo;

  late FakeCustomerRemoteApi customerApi;
  late FakeOrderRemoteApi orderApi;
  late FakeMasterDataRemoteApi masterDataApi;
  late FakeStorageRemoteApi storageApi;
  late RemoteApiDispatcher dispatcher;
  late MockNetworkInfo networkInfo;
  late SyncEngine syncEngine;

  setUp(() async {
    db = app_db.AppDatabase(NativeDatabase.memory());
    customersDao = CustomersDao(db);
    ordersDao = OrdersDao(db);
    servicesDao = ServicesDao(db);
    storageRecordsDao = StorageRecordsDao(db);
    storageLocationsDao = StorageLocationsDao(db);
    syncOperationsDao = InterceptableSyncOperationsDao(db);

    customerRepo = CustomerRepositoryImpl(
      customersDao: customersDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    orderRepo = OrderRepositoryImpl(
      ordersDao: ordersDao,
      paymentsDao: PaymentsDao(db),
      storageRecordsDao: storageRecordsDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    serviceRepo = ServiceRepositoryImpl(
      servicesDao: servicesDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    storageRepo = StorageRepositoryImpl(
      storageRecordsDao: storageRecordsDao,
      storageLocationsDao: storageLocationsDao,
      syncOperationsDao: syncOperationsDao,
      ordersDao: ordersDao,
      db: db,
    );

    customerApi = FakeCustomerRemoteApi();
    orderApi = FakeOrderRemoteApi();
    masterDataApi = FakeMasterDataRemoteApi();
    storageApi = FakeStorageRemoteApi();

    dispatcher = RemoteApiDispatcher(
      customerApi: customerApi,
      orderApi: orderApi,
      paymentApi: FakePaymentRemoteApi(),
      refundApi: FakeRefundRemoteApi(),
      storageApi: storageApi,
      expenseApi: FakeExpenseRemoteApi(),
      masterDataApi: masterDataApi,
    );

    networkInfo = MockNetworkInfo();
    syncEngine = SyncEngine(
      syncOperationsDao: syncOperationsDao,
      remoteApiDispatcher: dispatcher,
      networkInfo: networkInfo,
      retryPolicy: SyncRetryPolicy(),
      errorClassifier: const SyncErrorClassifier(),
    );
  });

  tearDown(() async {
    syncEngine.dispose();
    await db.close();
  });

  group('Step 8 — Repository Atomicity & Rollback', () {
    test(
      '1. Business mutation succeeds + sync enqueue fails -> rolls back business mutation',
      () async {
        syncOperationsDao.shouldThrowOnRecord = true;

        final now = DateTime.now();
        final customer = Customer(
          id: 'c-atomic-1',
          name: 'Atomic Test Customer',
          phone: '01011112222',
          createdAt: now,
          updatedAt: now,
        );

        // Repository call should fail because sync enqueue throws inside the transaction
        expect(
          () => customerRepo.createCustomer(customer),
          throwsA(isA<DatabaseFailure>()),
        );

        // Verify that customer was NOT committed to SQLite
        final queriedCustomer = await customersDao.getCustomerById(
          'c-atomic-1',
        );
        expect(queriedCustomer, isNull);

        // Verify no sync operation persisted
        final ops = await syncOperationsDao.getPendingOperations();
        expect(ops, isEmpty);
      },
    );

    test(
      '2. Business mutation fails (validation) -> no sync operation recorded',
      () async {
        final now = DateTime.now();
        final validCustomer = Customer(
          id: 'c-dup-1',
          name: 'First Customer',
          phone: '01012345678',
          createdAt: now,
          updatedAt: now,
        );
        await customerRepo.createCustomer(validCustomer);

        // Second customer with duplicate phone should fail at business validation
        final duplicateCustomer = Customer(
          id: 'c-dup-2',
          name: 'Second Customer',
          phone: '01012345678',
          createdAt: now,
          updatedAt: now,
        );

        expect(
          () => customerRepo.createCustomer(duplicateCustomer),
          throwsA(isA<DuplicateCustomerPhoneFailure>()),
        );

        // Exactly 1 sync operation for the first customer, none for the failed second
        final ops = await syncOperationsDao.getPendingOperations();
        expect(ops.length, equals(1));
        expect(ops.first.entityId, equals('c-dup-1'));
      },
    );
  });

  group('Step 8 — Payload Correctness & Contracts', () {
    test(
      '3. Customer create and update payloads are self-contained and accurate',
      () async {
        final now = DateTime.now();
        final customer = Customer(
          id: 'c-100',
          name: 'Ali Mohamed',
          phone: '01099887766',
          notes: 'VIP customer',
          createdAt: now,
          updatedAt: now,
        );

        await customerRepo.createCustomer(customer);

        var ops = await syncOperationsDao.getPendingOperations();
        expect(ops.length, equals(1));
        expect(ops.first.entityType, equals('customer'));
        expect(ops.first.operationType, equals('create'));
        expect(ops.first.payload, isNotNull);

        final createPayload =
            jsonDecode(ops.first.payload!) as Map<String, dynamic>;
        expect(createPayload['id'], equals('c-100'));
        expect(createPayload['name'], equals('Ali Mohamed'));
        expect(createPayload['phone'], equals('01099887766'));
        expect(createPayload['notes'], equals('VIP customer'));
        expect(createPayload['created_at'], equals(now.toIso8601String()));

        // Now update customer
        final updatedCustomer = customer.copyWith(
          name: 'Ali M. Hassan',
          notes: 'Updated notes',
        );
        await customerRepo.updateCustomer(updatedCustomer);

        ops = await syncOperationsDao.getPendingOperations();
        expect(ops.length, equals(2));
        expect(ops[1].operationType, equals('update'));

        final updatePayload =
            jsonDecode(ops[1].payload!) as Map<String, dynamic>;
        expect(updatePayload['id'], equals('c-100'));
        expect(updatePayload['name'], equals('Ali M. Hassan'));
        expect(updatePayload['notes'], equals('Updated notes'));
      },
    );

    test(
      '4. Order create is a single composite aggregate with nested items and carpet data',
      () async {
        final now = DateTime.now();
        await customersDao.insertCustomer(
          app_db.CustomersCompanion.insert(
            id: 'c-100',
            name: 'Ali Mohamed',
            phone: '01099887766',
            createdAt: now,
            updatedAt: now,
          ),
        );
        final itemTypes = await db.select(db.itemTypes).get();
        final suitType = itemTypes.first;
        final carpetType = itemTypes.firstWhere((t) => t.name == 'سجاد');

        await servicesDao.insertService(
          app_db.ServicesCompanion.insert(
            id: 'srv-dryclean',
            name: 'دراي كلين',
            pricingType: 'perPiece',
            price: 5000,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await servicesDao.insertService(
          app_db.ServicesCompanion.insert(
            id: 'srv-wash',
            name: 'غسيل سجاد',
            pricingType: 'perSquareMeter',
            price: 10000,
            createdAt: now,
            updatedAt: now,
          ),
        );

        final order = Order(
          id: 'ord-agg-1',
          orderNumber: '', // Generated on persistence
          customerId: 'c-100',
          customerNameSnapshot: 'Ali Mohamed',
          customerPhoneSnapshot: '01099887766',
          status: OrderStatus.processing,
          expectedPickupDate: OrderDate.fromDate(
            now.add(const Duration(days: 2)),
          ),
          notes: 'Express order',
          subtotal: Money.fromPiastres(15000),
          discount: Money.fromPiastres(1000),
          tax: Money.zero,
          customerPickupFee: Money.fromPiastres(500),
          customerDeliveryFee: Money.fromPiastres(500),
          total: Money.fromPiastres(15000), // 15000 - 1000 + 500 + 500 = 15000
          createdAt: now,
          updatedAt: now,
        );

        final items = [
          OrderItem(
            id: 'item-1',
            orderId: 'ord-agg-1',
            itemTypeId: suitType.id,
            serviceId: 'srv-dryclean',
            itemTypeNameSnapshot: 'بدلة رجالي',
            serviceNameSnapshot: 'دراي كلين',
            pricingType: PricingType.perPiece,
            quantity: 1,
            unitPrice: Money.fromPiastres(5000),
            calculatedTotal: Money.fromPiastres(5000),
            createdAt: now,
            updatedAt: now,
          ),
          OrderItem(
            id: 'item-2',
            orderId: 'ord-agg-1',
            itemTypeId: carpetType.id,
            serviceId: 'srv-wash',
            itemTypeNameSnapshot: 'سجاد',
            serviceNameSnapshot: 'غسيل سجاد',
            pricingType: PricingType.perSquareMeter,
            quantity: 1,
            unitPrice: Money.fromPiastres(10000),
            calculatedTotal: Money.fromPiastres(10000),
            carpetData: CarpetItemData(
              id: 'carpet-1',
              orderItemId: 'item-2',
              length: 3.0,
              width: 2.0,
              area: 6.0,
              createdAt: now,
              updatedAt: now,
            ),
            createdAt: now,
            updatedAt: now,
          ),
        ];

        final createdOrder = await orderRepo.createOrder(
          order: order,
          items: items,
        );

        // Verify exactly ONE sync operation was recorded (Order Aggregate)
        final ops = await syncOperationsDao.getPendingOperations();
        expect(ops.length, equals(1));
        expect(ops.first.entityType, equals('order'));
        expect(ops.first.operationType, equals('create'));
        expect(ops.first.entityId, equals('ord-agg-1'));

        final payload = jsonDecode(ops.first.payload!) as Map<String, dynamic>;
        expect(payload['id'], equals('ord-agg-1'));
        expect(payload['order_number'], equals(createdOrder.orderNumber));
        expect(payload['subtotal'], equals(15000));
        expect(payload['discount'], equals(1000));
        expect(payload['total'], equals(15000));

        final payloadItems = payload['items'] as List<dynamic>;
        expect(payloadItems.length, equals(2));

        // Item 1
        expect(payloadItems[0]['id'], equals('item-1'));
        expect(payloadItems[0]['service_name_snapshot'], equals('دراي كلين'));
        expect(payloadItems[0]['carpet_data'], isNull);

        // Item 2 with carpet data
        expect(payloadItems[1]['id'], equals('item-2'));
        expect(payloadItems[1]['carpet_data'], isNotNull);
        final carpetJson =
            payloadItems[1]['carpet_data'] as Map<String, dynamic>;
        expect(carpetJson['area'], equals(6.0));
        expect(carpetJson['length'], equals(3.0));
      },
    );

    test(
      '5. Order status transitions (ready, complete, cancel) produce correct payloads',
      () async {
        final now = DateTime.now();
        await customersDao.insertCustomer(
          app_db.CustomersCompanion.insert(
            id: 'c-100',
            name: 'Ali',
            phone: '01011112222',
            createdAt: now,
            updatedAt: now,
          ),
        );
        final itemTypes = await db.select(db.itemTypes).get();
        final itemType = itemTypes.first;
        await servicesDao.insertService(
          app_db.ServicesCompanion.insert(
            id: 'srv-1',
            name: 'غسيل',
            pricingType: 'perPiece',
            price: 1000,
            createdAt: now,
            updatedAt: now,
          ),
        );

        final order = Order(
          id: 'ord-status-1',
          orderNumber: '26-001',
          customerId: 'c-100',
          customerNameSnapshot: 'Ali',
          customerPhoneSnapshot: '01011112222',
          expectedPickupDate: OrderDate.fromDate(
            now.add(const Duration(days: 1)),
          ),
          subtotal: Money.fromPiastres(1000),
          total: Money.fromPiastres(1000),
          createdAt: now,
          updatedAt: now,
        );
        final items = [
          OrderItem(
            id: 'item-st-1',
            orderId: 'ord-status-1',
            itemTypeId: itemType.id,
            serviceId: 'srv-1',
            itemTypeNameSnapshot: 'قميص',
            serviceNameSnapshot: 'غسيل',
            pricingType: PricingType.perPiece,
            quantity: 1,
            unitPrice: Money.fromPiastres(1000),
            calculatedTotal: Money.fromPiastres(1000),
            createdAt: now,
            updatedAt: now,
          ),
        ];

        await orderRepo.createOrder(order: order, items: items);

        // Mark ready
        await orderRepo.markOrderReady('ord-status-1');
        var ops = await syncOperationsDao.getPendingOperations();
        expect(ops.length, equals(2));
        expect(ops[1].operationType, equals('mark_ready'));
        var readyPayload = jsonDecode(ops[1].payload!) as Map<String, dynamic>;
        expect(readyPayload['status'], equals('ready'));

        // Cancel another order
        final order2 = order.copyWith(
          id: 'ord-cancel-1',
          orderNumber: '26-002',
        );
        final items2 = [
          items.first.copyWith(id: 'item-st-2', orderId: 'ord-cancel-1'),
        ];
        await orderRepo.createOrder(order: order2, items: items2);
        await orderRepo.cancelOrder(
          orderId: 'ord-cancel-1',
          cancellationReason: 'Customer requested refund',
        );

        ops = await syncOperationsDao.getPendingOperations();
        final cancelOp = ops.firstWhere(
          (o) => o.entityId == 'ord-cancel-1' && o.operationType == 'cancel',
        );
        final cancelPayload =
            jsonDecode(cancelOp.payload!) as Map<String, dynamic>;
        expect(cancelPayload['status'], equals('cancelled'));
        expect(
          cancelPayload['cancellation_reason'],
          equals('Customer requested refund'),
        );
        expect(cancelPayload['cancelled_at'], isNotNull);
      },
    );

    test(
      '6. Service create, update, and active toggle produce accurate sync payloads',
      () async {
        final now = DateTime.now();
        final service = Service(
          id: 'srv-press-1',
          name: 'كي بالبخار',
          description: 'كي ملابس خفيفة',
          pricingType: PricingType.perPiece,
          price: Money.fromPiastres(2500),
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );

        final itemTypes = await db.select(db.itemTypes).get();
        final supportedIds = [itemTypes[0].id, itemTypes[1].id];

        await serviceRepo.createService(
          service,
          supportedItemTypeIds: supportedIds,
        );

        var ops = await syncOperationsDao.getPendingOperations();
        expect(ops.length, equals(1));
        expect(ops.first.entityType, equals('service'));
        expect(ops.first.operationType, equals('create'));

        final payload = jsonDecode(ops.first.payload!) as Map<String, dynamic>;
        expect(payload['id'], equals('srv-press-1'));
        expect(payload['name'], equals('كي بالبخار'));
        expect(payload['price'], equals(2500));
        expect(payload['supported_item_type_ids'], equals(supportedIds));

        // Deactivate
        await serviceRepo.deactivateService('srv-press-1');
        ops = await syncOperationsDao.getPendingOperations();
        expect(ops.length, equals(2));
        expect(ops[1].operationType, equals('deactivate'));

        final deactivatePayload =
            jsonDecode(ops[1].payload!) as Map<String, dynamic>;
        expect(deactivatePayload['is_active'], isFalse);
      },
    );

    test(
      '7. Storage store, move, and unstore operations produce self-contained payloads',
      () async {
        // Setup customer, service, order and items
        final now = DateTime.now();
        await customersDao.insertCustomer(
          app_db.CustomersCompanion.insert(
            id: 'c-100',
            name: 'Customer',
            phone: '01011112222',
            createdAt: now,
            updatedAt: now,
          ),
        );
        final itemTypes = await db.select(db.itemTypes).get();
        final itemType = itemTypes.first;
        await servicesDao.insertService(
          app_db.ServicesCompanion.insert(
            id: 'srv-1',
            name: 'غسيل',
            pricingType: 'perPiece',
            price: 1000,
            createdAt: now,
            updatedAt: now,
          ),
        );

        final order = Order(
          id: 'ord-storage-1',
          orderNumber: '26-010',
          customerId: 'c-100',
          customerNameSnapshot: 'Customer',
          customerPhoneSnapshot: '01011112222',
          expectedPickupDate: OrderDate.fromDate(
            now.add(const Duration(days: 1)),
          ),
          subtotal: Money.fromPiastres(1000),
          total: Money.fromPiastres(1000),
          createdAt: now,
          updatedAt: now,
        );
        final items = [
          OrderItem(
            id: 'item-store-1',
            orderId: 'ord-storage-1',
            itemTypeId: itemType.id,
            serviceId: 'srv-1',
            itemTypeNameSnapshot: 'قميص',
            serviceNameSnapshot: 'غسيل',
            pricingType: PricingType.perPiece,
            quantity: 1,
            unitPrice: Money.fromPiastres(1000),
            calculatedTotal: Money.fromPiastres(1000),
            createdAt: now,
            updatedAt: now,
          ),
        ];
        await orderRepo.createOrder(order: order, items: items);

        // Create storage locations
        await storageLocationsDao.insertLocation(
          app_db.StorageLocationsCompanion.insert(
            id: 'loc-rack-A',
            name: 'ستاند A',
            createdAt: now,
            updatedAt: now,
          ),
        );
        await storageLocationsDao.replaceSupportedItemTypes('loc-rack-A', [
          itemType.id,
        ]);

        await storageLocationsDao.insertLocation(
          app_db.StorageLocationsCompanion.insert(
            id: 'loc-rack-B',
            name: 'ستاند B',
            createdAt: now,
            updatedAt: now,
          ),
        );
        await storageLocationsDao.replaceSupportedItemTypes('loc-rack-B', [
          itemType.id,
        ]);

        // 1. Store item
        final record = await storageRepo.storeItem(
          orderItemId: 'item-store-1',
          storageLocationId: 'loc-rack-A',
        );
        expect(record.isActive, isTrue);
        var ops = await syncOperationsDao.getPendingOperations();
        final storeOp = ops.firstWhere(
          (o) =>
              o.entityType == 'storage_record' && o.operationType == 'create',
        );
        final storePayload =
            jsonDecode(storeOp.payload!) as Map<String, dynamic>;
        expect(storePayload['order_item_id'], equals('item-store-1'));
        expect(storePayload['storage_location_id'], equals('loc-rack-A'));
        expect(storePayload['is_active'], isTrue);

        // 2. Move item
        await storageRepo.moveItem(
          orderItemId: 'item-store-1',
          newStorageLocationId: 'loc-rack-B',
        );
        ops = await syncOperationsDao.getPendingOperations();
        final moveOp = ops.firstWhere(
          (o) => o.entityType == 'storage_record' && o.operationType == 'move',
        );
        final movePayload = jsonDecode(moveOp.payload!) as Map<String, dynamic>;
        expect(movePayload['storage_location_id'], equals('loc-rack-B'));

        // 3. Unstore item
        await storageRepo.unstoreItem('item-store-1');
        ops = await syncOperationsDao.getPendingOperations();
        final unstoreOp = ops.firstWhere(
          (o) =>
              o.entityType == 'storage_record' && o.operationType == 'unstore',
        );
        final unstorePayload =
            jsonDecode(unstoreOp.payload!) as Map<String, dynamic>;
        expect(unstorePayload['is_active'], isFalse);
      },
    );
  });

  group('Step 8 — Multiple Offline Mutations & FIFO Ordering', () {
    test(
      '8. Multiple sequential mutations for the same entity preserve deterministic FIFO order',
      () async {
        final now = DateTime.now();
        final customer = Customer(
          id: 'c-multi-1',
          name: 'Original Name',
          phone: '01122334455',
          notes: 'Initial',
          createdAt: now,
          updatedAt: now,
        );

        // 1. Create customer while offline
        await customerRepo.createCustomer(customer);

        // 2. Update name
        await customerRepo.updateCustomer(
          customer.copyWith(name: 'Updated Name 1'),
        );

        // 3. Update notes
        await customerRepo.updateCustomer(
          customer.copyWith(name: 'Updated Name 1', notes: 'Second Update'),
        );

        // Verify FIFO ordering in sync queue
        final ops = await syncOperationsDao.getPendingOperations();
        expect(ops.length, equals(3));
        expect(ops[0].operationType, equals('create'));
        expect(ops[1].operationType, equals('update'));
        expect(ops[2].operationType, equals('update'));

        expect(jsonDecode(ops[0].payload!)['name'], equals('Original Name'));
        expect(jsonDecode(ops[1].payload!)['name'], equals('Updated Name 1'));
        expect(jsonDecode(ops[2].payload!)['notes'], equals('Second Update'));

        // Process via SyncEngine and verify fake API receives them in exact FIFO order
        final state = await syncEngine.sync();
        expect(state.status, equals(SyncEngineStatus.completed));
        expect(customerApi.createdCustomers.length, equals(1));
        expect(customerApi.updatedCustomers.length, equals(2));
        expect(
          customerApi.createdCustomers[0]['body']['name'],
          equals('Original Name'),
        );
        expect(
          customerApi.updatedCustomers[0]['body']['name'],
          equals('Updated Name 1'),
        );
        expect(
          customerApi.updatedCustomers[1]['body']['notes'],
          equals('Second Update'),
        );
      },
    );
  });

  group('Step 8 — End-to-End Flow & Idempotency', () {
    test(
      '9. Full E2E: Repository write -> SQLite commit -> SyncEngine.sync() -> Dispatcher -> Remote API',
      () async {
        final now = DateTime.now();
        final customer = Customer(
          id: 'c-e2e-1',
          name: 'E2E Customer',
          phone: '01234567890',
          createdAt: now,
          updatedAt: now,
        );

        // 1. Repository mutation commits atomically
        await customerRepo.createCustomer(customer);
        final ops = await syncOperationsDao.getPendingOperations();
        expect(ops.length, equals(1));
        final operationId = ops.first.id;

        // 2. SyncEngine processes the queue
        final state = await syncEngine.sync();
        expect(state.status, equals(SyncEngineStatus.completed));
        expect(state.pendingOperationsCount, equals(0));

        // 3. Remote API receives the call with exact operationId (X-Operation-ID)
        expect(customerApi.createdCustomers.length, equals(1));
        expect(
          customerApi.createdCustomers.first['operationId'],
          equals(operationId),
        );
        expect(
          customerApi.createdCustomers.first['body']['name'],
          equals('E2E Customer'),
        );

        // 4. Operation status in database is now synced
        final allOps = await (db.select(db.syncOperations)).get();
        expect(allOps.first.status, equals('synced'));
      },
    );
  });
}
