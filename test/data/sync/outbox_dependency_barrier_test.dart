import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/network/network_info.dart';
import 'package:laundry_management/data/datasources/remote/remote_api_dispatcher.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart'
    hide Customer, Order, OrderItem, Payment, Service, ServiceItemType, ItemType;
import 'package:laundry_management/data/sync/sync_engine.dart';
import 'package:laundry_management/data/sync/sync_payload_builder.dart';
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/domain/entities/order.dart' as domain;
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/entities/payment.dart';
import 'package:laundry_management/domain/entities/service.dart';
import 'package:laundry_management/domain/entities/service_item_type.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/enums/payment_method.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/sync/sync_error_classifier.dart';
import 'package:laundry_management/domain/sync/sync_retry_policy.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';
import 'package:uuid/uuid.dart';

class FakeNetworkInfo implements NetworkInfo {
  bool isConnectedValue = true;

  @override
  Future<bool> get isConnected async => isConnectedValue;

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(isConnectedValue);
}

class FakeRemoteApiDispatcher implements RemoteApiDispatcher {
  final List<SyncOperation> dispatchedOperations = [];
  Future<dynamic> Function(SyncOperation op)? onDispatch;

  @override
  Future<dynamic> dispatch(SyncOperation operation) async {
    dispatchedOperations.add(operation);
    if (onDispatch != null) {
      return await onDispatch!(operation);
    }
    return {'status': 'ok', 'id': operation.entityId};
  }
}

void main() {
  const uuid = Uuid();
  late AppDatabase db;
  late SyncOperationsDao syncDao;
  late FakeNetworkInfo networkInfo;
  late FakeRemoteApiDispatcher dispatcher;
  late SyncEngine syncEngine;
  final now = DateTime(2026, 10, 1, 10, 0, 0);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory(), false);
    syncDao = SyncOperationsDao(db);
    networkInfo = FakeNetworkInfo();
    dispatcher = FakeRemoteApiDispatcher();

    final retryPolicy = SyncRetryPolicy(
      initialDelay: const Duration(seconds: 1),
      maxDelay: const Duration(seconds: 10),
      maxRetries: 3,
      jitterGenerator: () => Duration.zero,
    );

    syncEngine = SyncEngine(
      syncOperationsDao: syncDao,
      remoteApiDispatcher: dispatcher,
      networkInfo: networkInfo,
      retryPolicy: retryPolicy,
      errorClassifier: const SyncErrorClassifier(),
      clock: () => now,
    );
  });

  tearDown(() async {
    syncEngine.dispose();
    await db.close();
  });

  group('TASK 7 Regression Tests (A through G)', () {
    // -------------------------------------------------------------------------
    // Test A: Service creation sync
    // -------------------------------------------------------------------------
    test('A. Service creation sync produces modern service_item_types payload', () async {
      final serviceId = uuid.v4();
      final itemTypeId = uuid.v4();
      final service = Service(
        id: serviceId,
        name: 'غسيل',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );
      final sit = ServiceItemType(
        id: uuid.v4(),
        serviceId: serviceId,
        itemTypeId: itemTypeId,
        pricingType: PricingType.perPiece,
        price: const Money.fromPiastres(5000),
        createdAt: now,
        updatedAt: now,
      );

      final payload = SyncPayloadBuilder.buildServicePayload(service, [sit]);
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      expect(decoded['id'], serviceId);
      expect(decoded['name'], 'غسيل');
      expect(decoded['service_item_types'], isA<List>());
      final sits = decoded['service_item_types'] as List;
      expect(sits.length, 1);
      expect(sits.first['item_type_id'], itemTypeId);
      expect(sits.first['pricing_type'], 'per_piece');
      expect(sits.first['price'], 5000);

      await syncDao.recordOperation(
        entityType: 'service',
        entityId: serviceId,
        operationType: 'create',
        payload: payload,
      );

      await syncEngine.sync();

      expect(dispatcher.dispatchedOperations.length, 1);
      expect(dispatcher.dispatchedOperations.first.entityType, 'service');
      expect(dispatcher.dispatchedOperations.first.entityId, serviceId);

      final ops = await syncDao.getPendingOperations();
      expect(ops, isEmpty);
    });

    // -------------------------------------------------------------------------
    // Test B: Customer creation
    // -------------------------------------------------------------------------
    test('B. Customer creation sync succeeds independently', () async {
      final customerId = uuid.v4();
      final customer = Customer(
        id: customerId,
        name: 'محمد على',
        phone: '01017480870',
        createdAt: now,
        updatedAt: now,
      );

      final payload = SyncPayloadBuilder.buildCustomerPayload(customer);
      await syncDao.recordOperation(
        entityType: 'customer',
        entityId: customerId,
        operationType: 'create',
        payload: payload,
      );

      await syncEngine.sync();

      expect(dispatcher.dispatchedOperations.length, 1);
      expect(dispatcher.dispatchedOperations.first.entityType, 'customer');
      expect(dispatcher.dispatchedOperations.first.entityId, customerId);

      final remaining = await syncDao.getPendingOperations();
      expect(remaining, isEmpty);
    });

    // -------------------------------------------------------------------------
    // Test C: Order creation with embedded items
    // -------------------------------------------------------------------------
    test('C. Order creation embeds items in aggregate payload and syncs successfully', () async {
      final customerId = uuid.v4();
      final serviceId = uuid.v4();
      final itemTypeId = uuid.v4();
      final orderId = uuid.v4();

      final order = domain.Order(
        id: orderId,
        orderNumber: '26-001',
        customerId: customerId,
        customerNameSnapshot: 'محمد على',
        customerPhoneSnapshot: '01017480870',
        status: OrderStatus.processing,
        expectedPickupDate: OrderDate.fromDate(now.add(const Duration(days: 2))),
        total: const Money.fromPiastres(10000),
        subtotal: const Money.fromPiastres(10000),
        discount: Money.zero,
        tax: Money.zero,
        createdAt: now,
        updatedAt: now,
      );

      final item = OrderItem(
        id: uuid.v4(),
        orderId: orderId,
        itemTypeId: itemTypeId,
        serviceId: serviceId,
        itemTypeNameSnapshot: 'بطانية زوجى',
        serviceNameSnapshot: 'غسيل',
        pricingType: PricingType.perPiece,
        quantity: 2,
        unitPrice: const Money.fromPiastres(5000),
        calculatedTotal: const Money.fromPiastres(10000),
        createdAt: now,
        updatedAt: now,
      );

      final payload = SyncPayloadBuilder.buildOrderCreatePayload(order, [item]);
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      expect(decoded['customer_id'], customerId);
      expect(decoded['items'], isA<List>());
      final items = decoded['items'] as List;
      expect(items.length, 1);
      expect(items.first['service_id'], serviceId);
      expect(items.first['quantity'], 2);

      await syncDao.recordOperation(
        entityType: 'order',
        entityId: orderId,
        operationType: 'create',
        payload: payload,
      );

      await syncEngine.sync();

      expect(dispatcher.dispatchedOperations.length, 1);
      expect(dispatcher.dispatchedOperations.first.entityType, 'order');
      expect(dispatcher.dispatchedOperations.first.entityId, orderId);
    });

    // -------------------------------------------------------------------------
    // Test D: Payment creation referencing synced order
    // -------------------------------------------------------------------------
    test('D. Payment creation referencing synced order dispatches successfully', () async {
      final orderId = uuid.v4();
      final paymentId = uuid.v4();

      final payment = Payment(
        id: paymentId,
        orderId: orderId,
        amount: const Money.fromPiastres(5000),
        paymentMethod: PaymentMethod.cash,
        paidAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final payload = SyncPayloadBuilder.buildPaymentPayload(payment);
      await syncDao.recordOperation(
        entityType: 'payment',
        entityId: paymentId,
        operationType: 'create',
        payload: payload,
      );

      await syncEngine.sync();

      expect(dispatcher.dispatchedOperations.length, 1);
      expect(dispatcher.dispatchedOperations.first.entityType, 'payment');
      expect(dispatcher.dispatchedOperations.first.entityId, paymentId);
    });

    // -------------------------------------------------------------------------
    // Test E: Dependency failure (Service permanently fails -> Order blocked)
    // -------------------------------------------------------------------------
    test('E. Permanent failure of service:create blocks dependent order:create, but allows unrelated customer:create', () async {
      final serviceId = uuid.v4();
      final customerId = uuid.v4();
      final orderId = uuid.v4();

      // 1. Service operation permanently fails
      await syncDao.recordOperation(
        entityType: 'service',
        entityId: serviceId,
        operationType: 'create',
        payload: jsonEncode({'id': serviceId, 'name': 'غسيل'}),
      );
      // Mark it permanently failed (nextRetryAt: null)
      await syncDao.markOperationFailed(
        (await syncDao.getPendingOperations()).first.id,
        'INVALID_REFERENCE: column "pricing_type" does not exist',
        nextRetryAt: null,
      );

      // 2. Unrelated customer operation is pending
      await syncDao.recordOperation(
        entityType: 'customer',
        entityId: customerId,
        operationType: 'create',
        payload: jsonEncode({'id': customerId, 'name': 'محمد على'}),
      );

      // 3. Order operation referencing failed service + customer is pending
      final order = domain.Order(
        id: orderId,
        orderNumber: '26-001',
        customerId: customerId,
        customerNameSnapshot: 'محمد على',
        customerPhoneSnapshot: '01017480870',
        status: OrderStatus.processing,
        expectedPickupDate: OrderDate.fromDate(now.add(const Duration(days: 2))),
        total: const Money.fromPiastres(10000),
        subtotal: const Money.fromPiastres(10000),
        discount: Money.zero,
        tax: Money.zero,
        createdAt: now,
        updatedAt: now,
      );
      final item = OrderItem(
        id: uuid.v4(),
        orderId: orderId,
        itemTypeId: uuid.v4(),
        serviceId: serviceId,
        itemTypeNameSnapshot: 'بطانية زوجى',
        serviceNameSnapshot: 'غسيل',
        pricingType: PricingType.perPiece,
        quantity: 2,
        unitPrice: const Money.fromPiastres(5000),
        calculatedTotal: const Money.fromPiastres(10000),
        createdAt: now,
        updatedAt: now,
      );
      await syncDao.recordOperation(
        entityType: 'order',
        entityId: orderId,
        operationType: 'create',
        payload: SyncPayloadBuilder.buildOrderCreatePayload(order, [item]),
      );

      // Check eligible operations
      final eligible = await syncDao.getEligibleOperations(asOf: now);
      // Customer is eligible, but service (failed) and order (blocked) are NOT
      expect(eligible.map((e) => e.entityType), ['customer']);

      // Execute sync
      await syncEngine.sync();

      // ONLY customer was dispatched remotely!
      expect(dispatcher.dispatchedOperations.length, 1);
      expect(dispatcher.dispatchedOperations.first.entityType, 'customer');

      // Order was NOT dispatched and remains locally in pending status
      final orderOp = (await db.select(db.syncOperations).get())
          .firstWhere((op) => op.entityType == 'order');
      expect(orderOp.status, 'pending');

      // 4. Now simulate repair of the service operation (marked synced)
      final failedServiceOp = (await db.select(db.syncOperations).get())
          .firstWhere((op) => op.entityType == 'service');
      await syncDao.markOperationSynced(failedServiceOp.id);

      // Now order becomes eligible!
      final eligibleAfterRepair = await syncDao.getEligibleOperations(asOf: now);
      expect(eligibleAfterRepair.map((e) => e.entityType), ['order']);

      // Sync again -> order is now dispatched successfully!
      await syncEngine.sync();
      expect(dispatcher.dispatchedOperations.length, 2);
      expect(dispatcher.dispatchedOperations.last.entityType, 'order');
    });

    // -------------------------------------------------------------------------
    // Test F: Order / Payment dependency (Order fails -> Payment blocked)
    // -------------------------------------------------------------------------
    test('F. Permanent failure of order:create blocks dependent payment:create', () async {
      final orderId = uuid.v4();
      final paymentId = uuid.v4();

      // 1. Order operation permanently fails
      await syncDao.recordOperation(
        entityType: 'order',
        entityId: orderId,
        operationType: 'create',
        payload: jsonEncode({'id': orderId}),
      );
      final orderOp = (await syncDao.getPendingOperations()).first;
      await syncDao.markOperationFailed(
        orderOp.id,
        'INVALID_REFERENCE: Service does not exist',
        nextRetryAt: null,
      );

      // 2. Payment operation referencing that order
      await syncDao.recordOperation(
        entityType: 'payment',
        entityId: paymentId,
        operationType: 'create',
        payload: jsonEncode({'id': paymentId, 'order_id': orderId, 'amount': 5000}),
      );

      // Check eligible operations
      final eligible = await syncDao.getEligibleOperations(asOf: now);
      // Payment is blocked because parent order permanently failed!
      expect(eligible, isEmpty);

      // Execute sync
      await syncEngine.sync();

      // Payment was NOT dispatched
      expect(dispatcher.dispatchedOperations, isEmpty);

      // Payment remains locally in pending status
      final paymentOp = (await db.select(db.syncOperations).get())
          .firstWhere((op) => op.entityType == 'payment');
      expect(paymentOp.status, 'pending');
    });

    // -------------------------------------------------------------------------
    // Test G: App restart survival
    // -------------------------------------------------------------------------
    test('G. Blocked and pending operations survive app restart with correct dependency barriers', () async {
      final tempDir = await Directory.systemTemp.createTemp('laundry_sync_restart_test');
      final dbFile = File('${tempDir.path}/test_restart.sqlite');

      try {
        final serviceId = uuid.v4();
        final customerId = uuid.v4();
        final orderId = uuid.v4();
        final paymentId = uuid.v4();

        // Phase 1: Open DB, record operations, simulate service permanent failure
        {
          final initialDb = AppDatabase(NativeDatabase(dbFile), false);
          final initialDao = SyncOperationsDao(initialDb);

          // 1. Service: failed permanently
          await initialDao.recordOperation(
            entityType: 'service',
            entityId: serviceId,
            operationType: 'create',
            payload: jsonEncode({'id': serviceId, 'name': 'غسيل'}),
          );
          final sOp = (await initialDao.getPendingOperations()).first;
          await initialDao.markOperationFailed(
            sOp.id,
            'INVALID_REFERENCE',
            nextRetryAt: null,
          );

          // 2. Customer: pending
          await initialDao.recordOperation(
            entityType: 'customer',
            entityId: customerId,
            operationType: 'create',
            payload: jsonEncode({'id': customerId, 'name': 'محمد'}),
          );

          // 3. Order: pending, references failed service
          await initialDao.recordOperation(
            entityType: 'order',
            entityId: orderId,
            operationType: 'create',
            payload: jsonEncode({
              'id': orderId,
              'customer_id': customerId,
              'items': [{'service_id': serviceId}],
            }),
          );

          // 4. Payment: pending, references order
          await initialDao.recordOperation(
            entityType: 'payment',
            entityId: paymentId,
            operationType: 'create',
            payload: jsonEncode({'id': paymentId, 'order_id': orderId}),
          );

          // Close DB (simulating app shutdown)
          await initialDb.close();
        }

        // Phase 2: App restart -> Open new DB instance on the same file
        {
          final restartedDb = AppDatabase(NativeDatabase(dbFile), false);
          final restartedDao = SyncOperationsDao(restartedDb);
          final restartedDispatcher = FakeRemoteApiDispatcher();
          final restartedSyncEngine = SyncEngine(
            syncOperationsDao: restartedDao,
            remoteApiDispatcher: restartedDispatcher,
            networkInfo: networkInfo,
            retryPolicy: SyncRetryPolicy(
              initialDelay: const Duration(seconds: 1),
              maxDelay: const Duration(seconds: 10),
              maxRetries: 3,
            ),
            errorClassifier: const SyncErrorClassifier(),
            clock: () => now,
          );

          // After restart, only customer is eligible; order and payment are blocked
          final eligible = await restartedDao.getEligibleOperations(asOf: now);
          expect(eligible.map((e) => e.entityType), ['customer']);

          // Sync
          await restartedSyncEngine.sync();

          // Only customer dispatched
          expect(restartedDispatcher.dispatchedOperations.length, 1);
          expect(restartedDispatcher.dispatchedOperations.first.entityType, 'customer');

          // Verify order and payment remain pending in database
          final opsAfterRestart = await restartedDb.select(restartedDb.syncOperations).get();
          final orderRecord = opsAfterRestart.firstWhere((o) => o.entityType == 'order');
          final paymentRecord = opsAfterRestart.firstWhere((o) => o.entityType == 'payment');
          expect(orderRecord.status, 'pending');
          expect(paymentRecord.status, 'pending');

          restartedSyncEngine.dispose();
          await restartedDb.close();
        }
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}
