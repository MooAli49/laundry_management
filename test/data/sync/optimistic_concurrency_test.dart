import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/local/daos/customers_dao.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/storage_locations_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/daos/sync_state_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart';
import 'package:laundry_management/data/remote/dto/sync_change_dto.dart';
import 'package:laundry_management/data/repositories/storage_repository_impl.dart';
import 'package:laundry_management/data/sync/remote_change_applier.dart';
import 'package:laundry_management/data/sync/sync_payload_builder.dart';
import 'package:laundry_management/domain/entities/storage_record.dart' as domain_storage;
import 'package:laundry_management/domain/sync/sync_error_classifier.dart';

void main() {
  group('SUSP-02 — Optimistic Concurrency Unit & Orchestration Tests', () {
    late AppDatabase db;
    late CustomersDao customersDao;
    late OrdersDao ordersDao;
    late StorageRecordsDao storageRecordsDao;
    late StorageLocationsDao storageLocationsDao;
    late SyncOperationsDao syncOperationsDao;
    late SyncStateDao syncStateDao;
    late RemoteChangeApplier changeApplier;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      customersDao = CustomersDao(db);
      ordersDao = OrdersDao(db);
      storageRecordsDao = StorageRecordsDao(db);
      storageLocationsDao = StorageLocationsDao(db);
      syncOperationsDao = SyncOperationsDao(db);
      syncStateDao = SyncStateDao(db);
      changeApplier = RemoteChangeApplier(
        db: db,
        syncStateDao: syncStateDao,
        syncOperationsDao: syncOperationsDao,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      '1. SyncErrorClassifier classifies HTTP 409 Conflict as permanent failure',
      () {
        const classifier = SyncErrorClassifier();
        final conflictDetails = SyncErrorDetails.http(
          409,
          message: 'CONCURRENCY_CONFLICT: base_version mismatch',
        );

        final kind = classifier.classify(conflictDetails);
        expect(kind, equals(SyncFailureKind.permanent));
      },
    );

    test(
      '2. SyncPayloadBuilder serializes previous_storage_location_id when moving item',
      () {
        final now = DateTime.utc(2026, 10, 2, 10, 0);
        final record = domain_storage.StorageRecord(
          id: 'rec-move-1',
          orderItemId: 'item-1',
          storageLocationId: 'loc-new-rack-2',
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );

        final payloadJson = SyncPayloadBuilder.buildStorageRecordPayload(
          record,
          previousStorageLocationId: 'loc-old-rack-1',
        );

        final map = jsonDecode(payloadJson) as Map<String, dynamic>;
        expect(map['id'], equals('rec-move-1'));
        expect(map['order_item_id'], equals('item-1'));
        expect(map['storage_location_id'], equals('loc-new-rack-2'));
        expect(map['previous_storage_location_id'], equals('loc-old-rack-1'));
      },
    );

    test(
      '3. StorageRepositoryImpl.moveItem captures active location as previous_storage_location_id in sync operation',
      () async {
        final storageRepo = StorageRepositoryImpl(
          storageRecordsDao: storageRecordsDao,
          storageLocationsDao: storageLocationsDao,
          syncOperationsDao: syncOperationsDao,
          ordersDao: ordersDao,
          db: db,
        );

        final now = DateTime.utc(2026, 10, 2, 10, 0);
        // Seed master data for foreign keys
        await db.into(db.services).insert(ServicesCompanion.insert(
          id: 'srv-1',
          name: 'Dry Clean',
          createdAt: now,
          updatedAt: now,
        ));
        await db.into(db.itemTypes).insert(ItemTypesCompanion.insert(
          id: 'type-1',
          name: 'Suit',
          createdAt: now,
          updatedAt: now,
        ));
        await db.into(db.storageLocations).insert(StorageLocationsCompanion.insert(
          id: 'loc-rack-1',
          name: 'Rack 1',
          createdAt: now,
          updatedAt: now,
        ));
        await db.into(db.storageLocations).insert(StorageLocationsCompanion.insert(
          id: 'loc-rack-2',
          name: 'Rack 2',
          createdAt: now,
          updatedAt: now,
        ));
        await db.into(db.storageLocationItemTypes).insert(
          StorageLocationItemTypesCompanion.insert(
            id: 'slit-1',
            storageLocationId: 'loc-rack-1',
            itemTypeId: 'type-1',
            createdAt: now,
          ),
        );
        await db.into(db.storageLocationItemTypes).insert(
          StorageLocationItemTypesCompanion.insert(
            id: 'slit-2',
            storageLocationId: 'loc-rack-2',
            itemTypeId: 'type-1',
            createdAt: now,
          ),
        );

        // Seed customer and order so orderItem is valid
        await customersDao.insertCustomer(CustomersCompanion.insert(
          id: 'cust-1',
          name: 'Test Customer',
          phone: '01000000001',
          createdAt: now,
          updatedAt: now,
        ));
        await ordersDao.insertOrder(OrdersCompanion.insert(
          id: 'ord-1',
          orderNumber: '26-001',
          customerId: 'cust-1',
          customerNameSnapshot: const Value('Test Customer'),
          customerPhoneSnapshot: const Value('01000000001'),
          expectedPickupDate: now,
          subtotal: 1000,
          total: 1000,
          createdAt: now,
          updatedAt: now,
        ));
        await db.into(db.orderItems).insert(OrderItemsCompanion.insert(
          id: 'item-1',
          orderId: 'ord-1',
          itemTypeId: 'type-1',
          serviceId: 'srv-1',
          itemTypeNameSnapshot: 'Suit',
          serviceNameSnapshot: 'Dry Clean',
          pricingType: 'per_piece',
          quantity: 1.0,
          unitPrice: 1000,
          calculatedTotal: 1000,
          createdAt: now,
          updatedAt: now,
        ));

        // 1. Initially store at Rack 1
        await storageRepo.storeItem(
          orderItemId: 'item-1',
          storageLocationId: 'loc-rack-1',
        );

        // 2. Move item to Rack 2
        await storageRepo.moveItem(
          orderItemId: 'item-1',
          newStorageLocationId: 'loc-rack-2',
        );

        // 3. Verify sync operation contains previous_storage_location_id = loc-rack-1
        final pendingOps = await syncOperationsDao.getPendingOperations();
        expect(pendingOps.length, equals(2)); // 1 create, 1 move

        final moveOp = pendingOps.firstWhere((op) => op.operationType == 'move');
        expect(moveOp.entityType, equals('storage_record'));
        final movePayload = jsonDecode(moveOp.payload!) as Map<String, dynamic>;
        expect(movePayload['storage_location_id'], equals('loc-rack-2'));
        expect(movePayload['previous_storage_location_id'], equals('loc-rack-1'));
      },
    );

    test(
      '4. Pull after conflict converges local state (Server Wins): RemoteChangeApplier overwrites failed local state',
      () async {
        final now = DateTime.utc(2026, 10, 2, 10, 0);

        // 1. Initial customer locally
        await customersDao.insertCustomer(CustomersCompanion.insert(
          id: 'cust-conflict-1',
          name: 'Local Conflicted Name',
          phone: '01000000002',
          createdAt: now,
          updatedAt: now,
        ));

        // 2. Operation encountered conflict and was marked failed in sync_operations
        await syncOperationsDao.recordOperation(
          entityType: 'customer',
          entityId: 'cust-conflict-1',
          operationType: 'update',
          payload: jsonEncode({'name': 'Local Conflicted Name'}),
        );
        final ops = await syncOperationsDao.getPendingOperations();
        await syncOperationsDao.markOperationFailed(
          ops.first.id,
          'CONCURRENCY_CONFLICT: base_version mismatch',
          nextRetryAt: null,
        );

        // 3. Winning remote change arrives via pull with sequence 100
        final winningChange = SyncChangeDto(
          sequence: 100,
          operationId: 'op-remote-win-100',
          entityType: 'customer',
          entityId: 'cust-conflict-1',
          operationType: 'update',
          payload: {
            'id': 'cust-conflict-1',
            'name': 'Authoritative Server Winning Name',
            'phone': '01000000002',
            'created_at': now.toIso8601String(),
            'updated_at': now.add(const Duration(minutes: 5)).toIso8601String(),
          },
          serverVersion: 3,
          createdAt: now.add(const Duration(minutes: 5)),
        );

        await changeApplier.applyBatch([winningChange]);

        // 4. Verify local database converged to winning server state
        final updatedCustomer = await customersDao.getCustomerById('cust-conflict-1');
        expect(updatedCustomer, isNotNull);
        expect(updatedCustomer!.name, equals('Authoritative Server Winning Name'));

        // 5. Verify sync cursor advanced atomically
        final cursor = await syncStateDao.getLastAppliedSequence();
        expect(cursor, equals(100));
      },
    );

    test(
      '5. BR-018 Order Number Invariance: Remote conflict application never changes order_number',
      () async {
        final now = DateTime.utc(2026, 10, 2, 10, 0);

        // 1. Local order with canonical order number 26-001
        await customersDao.insertCustomer(CustomersCompanion.insert(
          id: 'cust-order-1',
          name: 'Order Customer',
          phone: '01000000003',
          createdAt: now,
          updatedAt: now,
        ));
        await ordersDao.insertOrder(OrdersCompanion.insert(
          id: 'ord-immutable-1',
          orderNumber: '26-001',
          customerId: 'cust-order-1',
          customerNameSnapshot: const Value('Order Customer'),
          customerPhoneSnapshot: const Value('01000000003'),
          expectedPickupDate: now,
          subtotal: 2500,
          total: 2500,
          status: const Value('processing'),
          createdAt: now,
          updatedAt: now,
        ));

        // 2. Incoming remote update has different status or amounts, but attempts or preserves 26-001
        final orderUpdate = SyncChangeDto(
          sequence: 101,
          operationId: 'op-order-update-101',
          entityType: 'order',
          entityId: 'ord-immutable-1',
          operationType: 'update',
          payload: {
            'id': 'ord-immutable-1',
            'order_number': '26-001',
            'customer_id': 'cust-order-1',
            'customer_name_snapshot': 'Order Customer',
            'customer_phone_snapshot': '01000000003',
            'status': 'ready',
            'expected_pickup_date': now.toIso8601String(),
            'subtotal': 2500,
            'total': 2500,
            'updated_at': now.add(const Duration(minutes: 10)).toIso8601String(),
          },
          serverVersion: 2,
          createdAt: now.add(const Duration(minutes: 10)),
        );

        await changeApplier.applyBatch([orderUpdate]);

        final order = await ordersDao.getOrderById('ord-immutable-1');
        expect(order, isNotNull);
        expect(order!.orderNumber, equals('26-001'));
        expect(order.status, equals('ready'));

        // Next generated order number remains consecutive
        final nextNum = await ordersDao.generateNextOrderNumber();
        expect(nextNum, equals('26-002'));
      },
    );
  });
}
