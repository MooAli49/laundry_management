import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/local/daos/customers_dao.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/daos/sync_state_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart' as app_db;
import 'package:laundry_management/data/remote/dto/sync_change_dto.dart';
import 'package:laundry_management/data/sync/remote_change_applier.dart';

void main() {
  group('RemoteChangeApplier Ingestion & Atomicity Tests', () {
    late app_db.AppDatabase db;
    late SyncStateDao syncStateDao;
    late SyncOperationsDao syncOperationsDao;
    late CustomersDao customersDao;
    late OrdersDao ordersDao;
    late PaymentsDao paymentsDao;
    late StorageRecordsDao storageRecordsDao;
    late RemoteChangeApplier applier;

    setUp(() async {
      db = app_db.AppDatabase(NativeDatabase.memory());
      syncStateDao = SyncStateDao(db);
      syncOperationsDao = SyncOperationsDao(db);
      customersDao = CustomersDao(db);
      ordersDao = OrdersDao(db);
      paymentsDao = PaymentsDao(db);
      storageRecordsDao = StorageRecordsDao(db);

      applier = RemoteChangeApplier(
        db: db,
        syncStateDao: syncStateDao,
      );

      // Verify clean initial state
      final initialSeq = await syncStateDao.getLastAppliedSequence();
      expect(initialSeq, equals(0));
    });

    tearDown(() async {
      await db.close();
    });

    // -------------------------------------------------------------------------
    // 1. Customer Ingestion
    // -------------------------------------------------------------------------
    test('1. Applying a single remote customer change persists to Drift', () async {
      final change = SyncChangeDto(
        sequence: 1,
        operationId: 'op-c1',
        entityType: 'customer',
        entityId: 'c-100',
        operationType: 'create',
        payload: {
          'id': 'c-100',
          'name': 'Customer One',
          'phone': '01011112222',
          'notes': 'VIP Customer',
          'created_at': '2026-09-17T10:00:00.000Z',
          'updated_at': '2026-09-17T10:00:00.000Z',
        },
        serverVersion: 1,
        createdAt: DateTime.parse('2026-09-17T10:00:00.000Z'),
      );

      await applier.applyBatch([change]);

      final customer = await customersDao.getCustomerById('c-100');
      expect(customer, isNotNull);
      expect(customer!.name, equals('Customer One'));
      expect(customer.phone, equals('01011112222'));
      expect(customer.notes, equals('VIP Customer'));

      final seq = await syncStateDao.getLastAppliedSequence();
      expect(seq, equals(1));
    });

    // -------------------------------------------------------------------------
    // 2. Versioned Entity Update
    // -------------------------------------------------------------------------
    test('2. Applying a versioned entity update updates existing record', () async {
      final change1 = SyncChangeDto(
        sequence: 1,
        operationId: 'op-c1',
        entityType: 'customer',
        entityId: 'c-200',
        operationType: 'create',
        payload: {
          'id': 'c-200',
          'name': 'Original Name',
          'phone': '01022223333',
          'created_at': '2026-09-17T10:00:00.000Z',
          'updated_at': '2026-09-17T10:00:00.000Z',
        },
        serverVersion: 1,
        createdAt: DateTime.parse('2026-09-17T10:00:00.000Z'),
      );
      await applier.applyBatch([change1]);

      final change2 = SyncChangeDto(
        sequence: 2,
        operationId: 'op-c2',
        entityType: 'customer',
        entityId: 'c-200',
        operationType: 'update',
        payload: {
          'id': 'c-200',
          'name': 'Updated Name',
          'phone': '01022223333',
          'notes': 'New note added',
          'created_at': '2026-09-17T10:00:00.000Z',
          'updated_at': '2026-09-17T11:00:00.000Z',
        },
        serverVersion: 2,
        createdAt: DateTime.parse('2026-09-17T11:00:00.000Z'),
      );
      await applier.applyBatch([change2]);

      final customer = await customersDao.getCustomerById('c-200');
      expect(customer, isNotNull);
      expect(customer!.name, equals('Updated Name'));
      expect(customer.notes, equals('New note added'));

      final seq = await syncStateDao.getLastAppliedSequence();
      expect(seq, equals(2));
    });

    // -------------------------------------------------------------------------
    // 3. Order Creation Aggregate (Customer -> Order -> Items -> Carpet)
    // -------------------------------------------------------------------------
    test('3. Applying an Order Creation aggregate snapshot unpacks full hierarchy', () async {
      // 1. Create parent Customer first
      final custChange = SyncChangeDto(
        sequence: 5,
        operationId: 'op-cust',
        entityType: 'customer',
        entityId: 'c-order-cust',
        operationType: 'create',
        payload: {
          'id': 'c-order-cust',
          'name': 'Order Customer',
          'phone': '01033334444',
          'created_at': '2026-09-17T12:00:00.000Z',
          'updated_at': '2026-09-17T12:00:00.000Z',
        },
        serverVersion: 1,
        createdAt: DateTime.parse('2026-09-17T12:00:00.000Z'),
      );

      // Seed service and item type for valid foreign keys
      final serviceId = '00000000-0000-0000-0003-000000000001';
      await db.into(db.services).insert(
        app_db.ServicesCompanion(
          id: Value(serviceId),
          name: const Value('غسيل'),
          pricingType: const Value('per_square_meter'),
          price: const Value(5000),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final itemTypeId = '00000000-0000-0000-0001-000000000003'; // default carpet type seeded

      final orderChange = SyncChangeDto(
        sequence: 6,
        operationId: 'op-order-create',
        entityType: 'order',
        entityId: 'ord-agg-1',
        operationType: 'create',
        payload: {
          'id': 'ord-agg-1',
          'order_number': '26-001',
          'customer_id': 'c-order-cust',
          'customer_name_snapshot': 'Order Customer',
          'customer_phone_snapshot': '01033334444',
          'status': 'processing',
          'expected_pickup_date': '2026-09-20T12:00:00.000Z',
          'notes': 'Handle with care',
          'subtotal': 30000,
          'discount': 0,
          'tax': 0,
          'total': 30000,
          'created_at': '2026-09-17T12:00:00.000Z',
          'updated_at': '2026-09-17T12:00:00.000Z',
          'items': [
            {
              'id': 'item-agg-1',
              'order_id': 'ord-agg-1',
              'item_type_id': itemTypeId,
              'service_id': serviceId,
              'item_type_name_snapshot': 'سجاد',
              'service_name_snapshot': 'غسيل',
              'pricing_type': 'per_square_meter',
              'quantity': 6.0,
              'unit_price': 5000,
              'calculated_total': 30000,
              'created_at': '2026-09-17T12:00:00.000Z',
              'updated_at': '2026-09-17T12:00:00.000Z',
              'carpet_data': {
                'id': 'carpet-agg-1',
                'order_item_id': 'item-agg-1',
                'length': 3.0,
                'width': 2.0,
                'area': 6.0,
                'created_at': '2026-09-17T12:00:00.000Z',
                'updated_at': '2026-09-17T12:00:00.000Z',
              },
            }
          ],
        },
        serverVersion: 1,
        createdAt: DateTime.parse('2026-09-17T12:00:00.000Z'),
      );

      // Apply batch containing Customer then Order aggregate
      await applier.applyBatch([custChange, orderChange]);

      // Verify Order header
      final order = await ordersDao.getOrderById('ord-agg-1');
      expect(order, isNotNull);
      expect(order!.orderNumber, equals('26-001'));
      expect(order.total, equals(30000));
      expect(order.customerNameSnapshot, equals('Order Customer'));

      // Verify nested items and carpet data
      final itemsWithCarpets = await ordersDao.getOrderItemsWithCarpets('ord-agg-1');
      expect(itemsWithCarpets.length, equals(1));
      expect(itemsWithCarpets.first.item.id, equals('item-agg-1'));
      expect(itemsWithCarpets.first.item.calculatedTotal, equals(30000));
      expect(itemsWithCarpets.first.carpet, isNotNull);
      expect(itemsWithCarpets.first.carpet!.area, equals(6.0));

      final seq = await syncStateDao.getLastAppliedSequence();
      expect(seq, equals(6));
    });

    test('4. Applying subsequent Order update modifies Order without touching items', () async {
      // First create order via aggregate as in test 3
      final custChange = SyncChangeDto(
        sequence: 7,
        operationId: 'op-cust-7',
        entityType: 'customer',
        entityId: 'c-order-7',
        operationType: 'create',
        payload: {
          'id': 'c-order-7',
          'name': 'Cust 7',
          'phone': '01077777777',
          'created_at': '2026-09-17T12:00:00.000Z',
          'updated_at': '2026-09-17T12:00:00.000Z',
        },
        serverVersion: 1,
        createdAt: DateTime.parse('2026-09-17T12:00:00.000Z'),
      );

      final serviceId = '00000000-0000-0000-0003-000000000002';
      await db.into(db.services).insert(
        app_db.ServicesCompanion(
          id: Value(serviceId),
          name: const Value('تنظيف'),
          pricingType: const Value('per_piece'),
          price: const Value(2000),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );
      final itemTypeId = '00000000-0000-0000-0001-000000000001';

      final orderCreate = SyncChangeDto(
        sequence: 8,
        operationId: 'op-ord-create-8',
        entityType: 'order',
        entityId: 'ord-8',
        operationType: 'create',
        payload: {
          'id': 'ord-8',
          'order_number': '26-008',
          'customer_id': 'c-order-7',
          'status': 'processing',
          'expected_pickup_date': '2026-09-21T12:00:00.000Z',
          'subtotal': 2000,
          'total': 2000,
          'created_at': '2026-09-17T12:00:00.000Z',
          'updated_at': '2026-09-17T12:00:00.000Z',
          'items': [
            {
              'id': 'item-8',
              'order_id': 'ord-8',
              'item_type_id': itemTypeId,
              'service_id': serviceId,
              'item_type_name_snapshot': 'ملابس',
              'service_name_snapshot': 'تنظيف',
              'pricing_type': 'per_piece',
              'quantity': 1.0,
              'unit_price': 2000,
              'calculated_total': 2000,
              'created_at': '2026-09-17T12:00:00.000Z',
              'updated_at': '2026-09-17T12:00:00.000Z',
            }
          ],
        },
        serverVersion: 1,
        createdAt: DateTime.parse('2026-09-17T12:00:00.000Z'),
      );

      await applier.applyBatch([custChange, orderCreate]);

      // Subsequent update: status ready
      final orderUpdate = SyncChangeDto(
        sequence: 9,
        operationId: 'op-ord-ready-9',
        entityType: 'order',
        entityId: 'ord-8',
        operationType: 'update',
        payload: {
          'id': 'ord-8',
          'status': 'ready',
          'updated_at': '2026-09-17T13:00:00.000Z',
        },
        serverVersion: 2,
        createdAt: DateTime.parse('2026-09-17T13:00:00.000Z'),
      );

      await applier.applyBatch([orderUpdate]);

      final order = await ordersDao.getOrderById('ord-8');
      expect(order!.status, equals('ready'));

      // Verify items remain intact
      final items = await ordersDao.getOrderItemsRaw('ord-8');
      expect(items.length, equals(1));
      expect(items.first.id, equals('item-8'));
    });

    // -------------------------------------------------------------------------
    // 5. Payment Ingestion (Append-only)
    // -------------------------------------------------------------------------
    test('5. Applying a Payment snapshot persists into payments table', () async {
      // Need an order to link payment to
      await db.into(db.customers).insert(
        app_db.CustomersCompanion(
          id: const Value('cust-pay'),
          name: const Value('Cust Pay'),
          phone: const Value('01099998888'),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await db.into(db.orders).insert(
        app_db.OrdersCompanion(
          id: const Value('ord-pay-1'),
          orderNumber: const Value('26-099'),
          customerId: const Value('cust-pay'),
          status: const Value('processing'),
          expectedPickupDate: Value(DateTime.now()),
          subtotal: const Value(10000),
          total: const Value(10000),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final paymentChange = SyncChangeDto(
        sequence: 15,
        operationId: 'op-pay-1',
        entityType: 'payment',
        entityId: 'pay-1',
        operationType: 'create',
        payload: {
          'id': 'pay-1',
          'order_id': 'ord-pay-1',
          'amount': 5000,
          'payment_method': 'cash',
          'paid_at': '2026-09-17T14:00:00.000Z',
          'created_at': '2026-09-17T14:00:00.000Z',
          'updated_at': '2026-09-17T14:00:00.000Z',
        },
        serverVersion: null,
        createdAt: DateTime.parse('2026-09-17T14:00:00.000Z'),
      );

      await applier.applyBatch([paymentChange]);

      final payments = await paymentsDao.getPaymentsForOrder('ord-pay-1');
      expect(payments.length, equals(1));
      expect(payments.first.id, equals('pay-1'));
      expect(payments.first.amount, equals(5000));
      expect(payments.first.paymentMethod, equals('cash'));

      final totalPaid = await paymentsDao.getTotalPaidForOrder('ord-pay-1');
      expect(totalPaid, equals(5000));
    });

    // -------------------------------------------------------------------------
    // 6. Critical Storage Apply Rules (Scenarios 1 through 5)
    // -------------------------------------------------------------------------
    group('Storage Apply Rules', () {
      final orderItemId = 'item-storage-test';

      setUp(() async {
        // Setup parent customer, order, item, and storage locations
        await db.into(db.customers).insert(
          app_db.CustomersCompanion(
            id: const Value('cust-storage'),
            name: const Value('Cust Storage'),
            phone: const Value('01055556666'),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await db.into(db.orders).insert(
          app_db.OrdersCompanion(
            id: const Value('ord-storage'),
            orderNumber: const Value('26-050'),
            customerId: const Value('cust-storage'),
            status: const Value('processing'),
            expectedPickupDate: Value(DateTime.now()),
            subtotal: const Value(5000),
            total: const Value(5000),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
        final serviceId = '00000000-0000-0000-0003-000000000003';
        await db.into(db.services).insert(
          app_db.ServicesCompanion(
            id: Value(serviceId),
            name: const Value('Service Storage'),
            pricingType: const Value('per_piece'),
            price: const Value(5000),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await db.into(db.orderItems).insert(
          app_db.OrderItemsCompanion(
            id: Value(orderItemId),
            orderId: const Value('ord-storage'),
            itemTypeId: const Value('00000000-0000-0000-0001-000000000001'),
            serviceId: Value(serviceId),
            itemTypeNameSnapshot: const Value('ملابس'),
            serviceNameSnapshot: const Value('Service Storage'),
            pricingType: const Value('per_piece'),
            quantity: const Value(1.0),
            unitPrice: const Value(5000),
            calculatedTotal: const Value(5000),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await db.into(db.storageLocations).insert(
          app_db.StorageLocationsCompanion(
            id: const Value('loc-A'),
            name: const Value('رف A'),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await db.into(db.storageLocations).insert(
          app_db.StorageLocationsCompanion(
            id: const Value('loc-B'),
            name: const Value('رف B'),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
      });

      test('Case 1: StorageRecord create (active) stores new active record', () async {
        final change = SyncChangeDto(
          sequence: 20,
          operationId: 'op-store-1',
          entityType: 'storage_record',
          entityId: 'sr-1',
          operationType: 'create',
          payload: {
            'id': 'sr-1',
            'order_item_id': orderItemId,
            'storage_location_id': 'loc-A',
            'is_active': true,
            'created_at': '2026-09-17T15:00:00.000Z',
            'updated_at': '2026-09-17T15:00:00.000Z',
          },
          serverVersion: null,
          createdAt: DateTime.parse('2026-09-17T15:00:00.000Z'),
        );

        await applier.applyBatch([change]);

        final active = await storageRecordsDao.getActiveRecordForOrderItem(orderItemId);
        expect(active, isNotNull);
        expect(active!.id, equals('sr-1'));
        expect(active.storageLocationId, equals('loc-A'));
        expect(active.isActive, isTrue);
      });

      test('Case 2: StorageRecord update/move snapshot to new location', () async {
        // Initial store at loc-A
        final initialChange = SyncChangeDto(
          sequence: 21,
          operationId: 'op-store-init',
          entityType: 'storage_record',
          entityId: 'sr-init',
          operationType: 'create',
          payload: {
            'id': 'sr-init',
            'order_item_id': orderItemId,
            'storage_location_id': 'loc-A',
            'is_active': true,
            'created_at': '2026-09-17T15:00:00.000Z',
            'updated_at': '2026-09-17T15:00:00.000Z',
          },
          serverVersion: null,
          createdAt: DateTime.parse('2026-09-17T15:00:00.000Z'),
        );
        await applier.applyBatch([initialChange]);

        // Move to loc-B (new active record sr-move)
        final moveChange = SyncChangeDto(
          sequence: 22,
          operationId: 'op-store-move',
          entityType: 'storage_record',
          entityId: 'sr-move',
          operationType: 'move',
          payload: {
            'id': 'sr-move',
            'order_item_id': orderItemId,
            'storage_location_id': 'loc-B',
            'is_active': true,
            'created_at': '2026-09-17T15:30:00.000Z',
            'updated_at': '2026-09-17T15:30:00.000Z',
          },
          serverVersion: null,
          createdAt: DateTime.parse('2026-09-17T15:30:00.000Z'),
        );
        await applier.applyBatch([moveChange]);

        final active = await storageRecordsDao.getActiveRecordForOrderItem(orderItemId);
        expect(active, isNotNull);
        expect(active!.id, equals('sr-move'));
        expect(active.storageLocationId, equals('loc-B'));
        expect(active.isActive, isTrue);

        // Verify previous record is deactivated
        final oldRecord = await (db.select(db.storageRecords)..where((t) => t.id.equals('sr-init'))).getSingle();
        expect(oldRecord.isActive, isFalse);
      });

      test('Case 3: Replaying the same StorageRecord change is completely idempotent', () async {
        final change = SyncChangeDto(
          sequence: 23,
          operationId: 'op-store-replay',
          entityType: 'storage_record',
          entityId: 'sr-replay',
          operationType: 'create',
          payload: {
            'id': 'sr-replay',
            'order_item_id': orderItemId,
            'storage_location_id': 'loc-A',
            'is_active': true,
            'created_at': '2026-09-17T15:00:00.000Z',
            'updated_at': '2026-09-17T15:00:00.000Z',
          },
          serverVersion: null,
          createdAt: DateTime.parse('2026-09-17T15:00:00.000Z'),
        );

        // Apply once
        await applier.applyBatch([change]);

        // Replay again
        await applier.applyBatch([change]);

        final allRecords = await (db.select(db.storageRecords)..where((t) => t.orderItemId.equals(orderItemId))).get();
        expect(allRecords.length, equals(1));
        expect(allRecords.first.id, equals('sr-replay'));
        expect(allRecords.first.isActive, isTrue);
      });

      test('Case 4: Remote StorageRecord arriving when another local active record exists deactivates the old one explicitly', () async {
        // Local record already active
        await db.into(db.storageRecords).insert(
          app_db.StorageRecordsCompanion(
            id: const Value('local-active-sr'),
            orderItemId: Value(orderItemId),
            storageLocationId: const Value('loc-A'),
            isActive: const Value(true),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );

        // Remote active record arrives from another device
        final remoteChange = SyncChangeDto(
          sequence: 24,
          operationId: 'op-remote-move-arrives',
          entityType: 'storage_record',
          entityId: 'remote-sr-2',
          operationType: 'move',
          payload: {
            'id': 'remote-sr-2',
            'order_item_id': orderItemId,
            'storage_location_id': 'loc-B',
            'is_active': true,
            'created_at': '2026-09-17T16:00:00.000Z',
            'updated_at': '2026-09-17T16:00:00.000Z',
          },
          serverVersion: null,
          createdAt: DateTime.parse('2026-09-17T16:00:00.000Z'),
        );

        await applier.applyBatch([remoteChange]);

        // Verify local-active-sr is deactivated and remote-sr-2 is the ONLY active record
        final active = await storageRecordsDao.getActiveRecordForOrderItem(orderItemId);
        expect(active, isNotNull);
        expect(active!.id, equals('remote-sr-2'));
        expect(active.storageLocationId, equals('loc-B'));

        final oldLocal = await (db.select(db.storageRecords)..where((t) => t.id.equals('local-active-sr'))).getSingle();
        expect(oldLocal.isActive, isFalse);
      });

      test('Case 5: Preservation of partial unique index invariant under all conditions', () async {
        // Query database to ensure no two active records exist for the same order item
        final countActive = await (db.selectOnly(db.storageRecords)
              ..where(db.storageRecords.orderItemId.equals(orderItemId) & db.storageRecords.isActive.equals(true))
              ..addColumns([db.storageRecords.id.count()]))
            .map((row) => row.read(db.storageRecords.id.count()))
            .getSingle();

        expect(countActive, lessThanOrEqualTo(1));
      });
    });

    // -------------------------------------------------------------------------
    // 7. Sequence Ordering Enforcement
    // -------------------------------------------------------------------------
    test('7. Multiple changes are applied in strict sequence order; non-ascending throws', () async {
      final changeA = SyncChangeDto(
        sequence: 30,
        operationId: 'op-seq-30',
        entityType: 'customer',
        entityId: 'c-seq-30',
        operationType: 'create',
        payload: {'id': 'c-seq-30', 'name': 'Thirty', 'phone': '01030303030'},
        serverVersion: 1,
        createdAt: DateTime.now(),
      );

      final changeB = SyncChangeDto(
        sequence: 25, // Invalid: smaller sequence
        operationId: 'op-seq-25',
        entityType: 'customer',
        entityId: 'c-seq-25',
        operationType: 'create',
        payload: {'id': 'c-seq-25', 'name': 'TwentyFive', 'phone': '01025252525'},
        serverVersion: 1,
        createdAt: DateTime.now(),
      );

      expect(
        () => applier.applyBatch([changeA, changeB]),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('strict ascending sequence order'))),
      );

      // Verify no changes were applied and cursor unchanged
      final c30 = await customersDao.getCustomerById('c-seq-30');
      expect(c30, isNull);
      final seq = await syncStateDao.getLastAppliedSequence();
      expect(seq, equals(0));
    });

    // -------------------------------------------------------------------------
    // 8. Multi-Change Transaction Rollback
    // -------------------------------------------------------------------------
    test('8. Multi-change failure mid-batch rolls back earlier in-memory changes and cursor', () async {
      final initialSeq = await syncStateDao.getLastAppliedSequence();

      final validChange1 = SyncChangeDto(
        sequence: 51,
        operationId: 'op-rb-1',
        entityType: 'customer',
        entityId: 'cust-rb-1',
        operationType: 'create',
        payload: {
          'id': 'cust-rb-1',
          'name': 'Rollback Customer 1',
          'phone': '01051515151',
          'created_at': '2026-09-17T18:00:00.000Z',
          'updated_at': '2026-09-17T18:00:00.000Z',
        },
        serverVersion: 1,
        createdAt: DateTime.parse('2026-09-17T18:00:00.000Z'),
      );

      // Failing change 2: unsupported entity type or foreign key violation
      final failingChange2 = SyncChangeDto(
        sequence: 52,
        operationId: 'op-rb-2',
        entityType: 'unknown_invalid_entity_type',
        entityId: 'bad-entity-2',
        operationType: 'create',
        payload: {'id': 'bad-entity-2'},
        serverVersion: 1,
        createdAt: DateTime.parse('2026-09-17T18:01:00.000Z'),
      );

      final validChange3 = SyncChangeDto(
        sequence: 53,
        operationId: 'op-rb-3',
        entityType: 'customer',
        entityId: 'cust-rb-3',
        operationType: 'create',
        payload: {
          'id': 'cust-rb-3',
          'name': 'Rollback Customer 3',
          'phone': '01053535353',
          'created_at': '2026-09-17T18:02:00.000Z',
          'updated_at': '2026-09-17T18:02:00.000Z',
        },
        serverVersion: 1,
        createdAt: DateTime.parse('2026-09-17T18:02:00.000Z'),
      );

      // Attempt to apply the 3-change batch
      expect(
        () => applier.applyBatch([validChange1, failingChange2, validChange3]),
        throwsA(isA<UnsupportedError>()),
      );

      // Invariant checks:
      // 1. Earlier change 1 was rolled back completely
      final cust1 = await customersDao.getCustomerById('cust-rb-1');
      expect(cust1, isNull);

      // 2. Later change 3 was never committed
      final cust3 = await customersDao.getCustomerById('cust-rb-3');
      expect(cust3, isNull);

      // 3. Cursor remains at its pre-batch position
      final postSeq = await syncStateDao.getLastAppliedSequence();
      expect(postSeq, equals(initialSeq));
    });

    // -------------------------------------------------------------------------
    // 9. Echo Loop Prevention
    // -------------------------------------------------------------------------
    test('9. Remote apply does NOT create SyncOperation rows (zero echo loop)', () async {
      final change = SyncChangeDto(
        sequence: 60,
        operationId: 'op-no-echo',
        entityType: 'customer',
        entityId: 'cust-no-echo',
        operationType: 'create',
        payload: {
          'id': 'cust-no-echo',
          'name': 'No Echo Customer',
          'phone': '01060606060',
          'created_at': '2026-09-17T19:00:00.000Z',
          'updated_at': '2026-09-17T19:00:00.000Z',
        },
        serverVersion: 1,
        createdAt: DateTime.parse('2026-09-17T19:00:00.000Z'),
      );

      await applier.applyBatch([change]);

      final pending = await syncOperationsDao.getPendingOperations();
      expect(pending, isEmpty);

      final count = await (db.selectOnly(db.syncOperations)..addColumns([db.syncOperations.id.count()])).map((row) => row.read(db.syncOperations.id.count())).getSingle();
      expect(count, equals(0));
    });

    // -------------------------------------------------------------------------
    // 10. Expenses, Categories, and Business Settings Ingestion
    // -------------------------------------------------------------------------
    test('10. Applying Expense, Category, and Settings updates persists accurately', () async {
      final catChange = SyncChangeDto(
        sequence: 70,
        operationId: 'op-cat-70',
        entityType: 'expense_category',
        entityId: 'cat-70',
        operationType: 'create',
        payload: {
          'id': 'cat-70',
          'name': 'منظفات خاصة',
          'is_active': true,
          'created_at': '2026-09-17T20:00:00.000Z',
          'updated_at': '2026-09-17T20:00:00.000Z',
        },
        serverVersion: 1,
        createdAt: DateTime.parse('2026-09-17T20:00:00.000Z'),
      );

      final expChange = SyncChangeDto(
        sequence: 71,
        operationId: 'op-exp-71',
        entityType: 'expense',
        entityId: 'exp-71',
        operationType: 'create',
        payload: {
          'id': 'exp-71',
          'expense_category_id': 'cat-70',
          'amount': 15000,
          'notes': 'شراء مساحيق',
          'expense_date': '2026-09-17T20:05:00.000Z',
          'created_at': '2026-09-17T20:05:00.000Z',
          'updated_at': '2026-09-17T20:05:00.000Z',
        },
        serverVersion: 1,
        createdAt: DateTime.parse('2026-09-17T20:05:00.000Z'),
      );

      final settingsChange = SyncChangeDto(
        sequence: 72,
        operationId: 'op-set-72',
        entityType: 'business_settings',
        entityId: '00000000-0000-0000-0000-000000000001',
        operationType: 'update',
        payload: {
          'id': '00000000-0000-0000-0000-000000000001',
          'business_name': 'مغسلة النور والبركة',
          'phone': '01012345678',
          'tax_enabled': true,
          'tax_rate': 14.0,
          'created_at': '2026-09-17T00:00:00.000Z',
          'updated_at': '2026-09-17T20:10:00.000Z',
        },
        serverVersion: 3,
        createdAt: DateTime.parse('2026-09-17T20:10:00.000Z'),
      );

      await applier.applyBatch([catChange, expChange, settingsChange]);

      final category = await (db.select(db.expenseCategories)..where((t) => t.id.equals('cat-70'))).getSingle();
      expect(category.name, equals('منظفات خاصة'));

      final expense = await (db.select(db.expenses)..where((t) => t.id.equals('exp-71'))).getSingle();
      expect(expense.amount, equals(15000));
      expect(expense.notes, equals('شراء مساحيق'));

      final settings = await (db.select(db.businessSettings)..where((t) => t.id.equals('00000000-0000-0000-0000-000000000001'))).getSingle();
      expect(settings.businessName, equals('مغسلة النور والبركة'));
      expect(settings.taxEnabled, isTrue);
      expect(settings.taxRate, equals(14.0));

      final seq = await syncStateDao.getLastAppliedSequence();
      expect(seq, equals(72));
    });

    // -------------------------------------------------------------------------
    // 11. Master Data Ingestion with Junction Relations (BUG-001 Regression)
    // -------------------------------------------------------------------------
    group('11. BUG-001: Master Data Junction Table UUID & Atomicity', () {
      final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );

      test('A. Service remote change with item_type_ids persists junction rows with valid UUIDs', () async {
        // Seed two item types first
        final itemType1 = SyncChangeDto(
          sequence: 80,
          operationId: 'op-it-1',
          entityType: 'item_type',
          entityId: 'it-srv-1',
          operationType: 'create',
          payload: {
            'id': 'it-srv-1',
            'name': 'قمصان',
            'is_active': true,
            'created_at': '2026-09-17T21:00:00.000Z',
            'updated_at': '2026-09-17T21:00:00.000Z',
          },
          serverVersion: 1,
          createdAt: DateTime.parse('2026-09-17T21:00:00.000Z'),
        );
        final itemType2 = SyncChangeDto(
          sequence: 81,
          operationId: 'op-it-2',
          entityType: 'item_type',
          entityId: 'it-srv-2',
          operationType: 'create',
          payload: {
            'id': 'it-srv-2',
            'name': 'بنطلونات',
            'is_active': true,
            'created_at': '2026-09-17T21:00:00.000Z',
            'updated_at': '2026-09-17T21:00:00.000Z',
          },
          serverVersion: 1,
          createdAt: DateTime.parse('2026-09-17T21:00:00.000Z'),
        );

        final serviceChange = SyncChangeDto(
          sequence: 82,
          operationId: 'op-srv-82',
          entityType: 'service',
          entityId: 'srv-82',
          operationType: 'create',
          payload: {
            'id': 'srv-82',
            'name': 'غسيل وكوي ممتاز',
            'description': 'خدمة غسيل وكوي متكاملة للملابس',
            'pricing_type': 'per_piece',
            'price': 3500,
            'is_active': true,
            'item_type_ids': ['it-srv-1', 'it-srv-2'],
            'created_at': '2026-09-17T21:05:00.000Z',
            'updated_at': '2026-09-17T21:05:00.000Z',
          },
          serverVersion: 1,
          createdAt: DateTime.parse('2026-09-17T21:05:00.000Z'),
        );

        // Act: apply batch with items and service
        await applier.applyBatch([itemType1, itemType2, serviceChange]);

        // 1. Verify service exists locally
        final service = await (db.select(db.services)..where((t) => t.id.equals('srv-82'))).getSingle();
        expect(service.name, equals('غسيل وكوي ممتاز'));
        expect(service.price, equals(3500));
        expect(service.pricingType, equals('per_piece'));

        // 2. Verify both junction rows exist in service_item_types
        final junctionRows = await (db.select(db.serviceItemTypes)
              ..where((t) => t.serviceId.equals('srv-82')))
            .get();
        expect(junctionRows.length, equals(2));

        // 3. Verify each junction row has a non-empty valid UUID id
        for (final row in junctionRows) {
          expect(row.id, isNotEmpty);
          expect(uuidRegex.hasMatch(row.id), isTrue, reason: 'id "${row.id}" must be a valid UUID');
          expect(row.serviceId, equals('srv-82'));
        }
        final linkedItemTypeIds = junctionRows.map((r) => r.itemTypeId).toSet();
        expect(linkedItemTypeIds, containsAll(['it-srv-1', 'it-srv-2']));

        // 4. Verify cursor advances
        final seq = await syncStateDao.getLastAppliedSequence();
        expect(seq, equals(82));

        // 5. Verify zero echo (no SyncOperations created)
        final syncOpCount = await (db.selectOnly(db.syncOperations)..addColumns([db.syncOperations.id.count()])).map((row) => row.read(db.syncOperations.id.count())).getSingle();
        expect(syncOpCount, equals(0));
      });

      test('B. Storage Location remote change with supported_item_type_ids persists junction rows with valid UUIDs', () async {
        // Seed two item types first
        final itemType1 = SyncChangeDto(
          sequence: 83,
          operationId: 'op-it-3',
          entityType: 'item_type',
          entityId: 'it-loc-1',
          operationType: 'create',
          payload: {
            'id': 'it-loc-1',
            'name': 'فساتين',
            'is_active': true,
            'created_at': '2026-09-17T21:10:00.000Z',
            'updated_at': '2026-09-17T21:10:00.000Z',
          },
          serverVersion: 1,
          createdAt: DateTime.parse('2026-09-17T21:10:00.000Z'),
        );
        final itemType2 = SyncChangeDto(
          sequence: 84,
          operationId: 'op-it-4',
          entityType: 'item_type',
          entityId: 'it-loc-2',
          operationType: 'create',
          payload: {
            'id': 'it-loc-2',
            'name': 'بدل رجالي',
            'is_active': true,
            'created_at': '2026-09-17T21:10:00.000Z',
            'updated_at': '2026-09-17T21:10:00.000Z',
          },
          serverVersion: 1,
          createdAt: DateTime.parse('2026-09-17T21:10:00.000Z'),
        );

        final locationChange = SyncChangeDto(
          sequence: 85,
          operationId: 'op-loc-85',
          entityType: 'storage_location',
          entityId: 'loc-85',
          operationType: 'create',
          payload: {
            'id': 'loc-85',
            'name': 'شماعة الملابس الرسمية',
            'is_active': true,
            'supported_item_type_ids': ['it-loc-1', 'it-loc-2'],
            'created_at': '2026-09-17T21:15:00.000Z',
            'updated_at': '2026-09-17T21:15:00.000Z',
          },
          serverVersion: 1,
          createdAt: DateTime.parse('2026-09-17T21:15:00.000Z'),
        );

        // Act: apply batch with items and storage location
        await applier.applyBatch([itemType1, itemType2, locationChange]);

        // 1. Verify storage location exists locally
        final location = await (db.select(db.storageLocations)..where((t) => t.id.equals('loc-85'))).getSingle();
        expect(location.name, equals('شماعة الملابس الرسمية'));
        expect(location.isActive, isTrue);

        // 2. Verify both junction rows exist in storage_location_item_types
        final junctionRows = await (db.select(db.storageLocationItemTypes)
              ..where((t) => t.storageLocationId.equals('loc-85')))
            .get();
        expect(junctionRows.length, equals(2));

        // 3. Verify each junction row has a non-empty valid UUID id
        for (final row in junctionRows) {
          expect(row.id, isNotEmpty);
          expect(uuidRegex.hasMatch(row.id), isTrue, reason: 'id "${row.id}" must be a valid UUID');
          expect(row.storageLocationId, equals('loc-85'));
        }
        final linkedItemTypeIds = junctionRows.map((r) => r.itemTypeId).toSet();
        expect(linkedItemTypeIds, containsAll(['it-loc-1', 'it-loc-2']));

        // 4. Verify cursor advances
        final seq = await syncStateDao.getLastAppliedSequence();
        expect(seq, equals(85));

        // 5. Verify zero echo (no SyncOperations created)
        final syncOpCount = await (db.selectOnly(db.syncOperations)..addColumns([db.syncOperations.id.count()])).map((row) => row.read(db.syncOperations.id.count())).getSingle();
        expect(syncOpCount, equals(0));
      });

      test('C. Atomic batch rollback: failure within batch rolls back all changes and keeps cursor unchanged', () async {
        final initialSeq = await syncStateDao.getLastAppliedSequence();

        // Change 1: valid item type
        final validItemType = SyncChangeDto(
          sequence: initialSeq + 1,
          operationId: 'op-valid-it',
          entityType: 'item_type',
          entityId: 'it-atomic-rollback',
          operationType: 'create',
          payload: {
            'id': 'it-atomic-rollback',
            'name': 'عنصر للاختبار الذري',
            'is_active': true,
            'created_at': '2026-09-17T22:00:00.000Z',
            'updated_at': '2026-09-17T22:00:00.000Z',
          },
          serverVersion: 1,
          createdAt: DateTime.parse('2026-09-17T22:00:00.000Z'),
        );

        // Change 2: invalid storage record with non-existent order_item_id and invalid payload that violates foreign key
        final invalidStorageChange = SyncChangeDto(
          sequence: initialSeq + 2,
          operationId: 'op-invalid-storage',
          entityType: 'storage_record',
          entityId: 'sr-invalid-fk',
          operationType: 'create',
          payload: {
            'id': 'sr-invalid-fk',
            'order_item_id': 'non-existent-order-item-id-999',
            'storage_location_id': 'non-existent-location-id-999',
            'is_active': true,
            'created_at': '2026-09-17T22:01:00.000Z',
            'updated_at': '2026-09-17T22:01:00.000Z',
          },
          serverVersion: 1,
          createdAt: DateTime.parse('2026-09-17T22:01:00.000Z'),
        );

        // Act & Assert: batch application should fail due to foreign key restriction
        expect(
          () => applier.applyBatch([validItemType, invalidStorageChange]),
          throwsA(anything),
        );

        // Verify rollback: validItemType was NOT committed
        final itemType = await (db.select(db.itemTypes)..where((t) => t.id.equals('it-atomic-rollback'))).getSingleOrNull();
        expect(itemType, isNull);

        // Verify cursor did not advance
        final finalSeq = await syncStateDao.getLastAppliedSequence();
        expect(finalSeq, equals(initialSeq));
      });
    });

    // -------------------------------------------------------------------------
    // 12. Phase 3A — Canonical Baseline Contract
    // -------------------------------------------------------------------------
    group('12. Phase 3A — Canonical Baseline Contract', () {
      // ---- Service payload contract ------------------------------------------

      test(
          'A. Service with canonical supported_item_type_ids populates junction rows',
          () async {
        final itemType = SyncChangeDto(
          sequence: 90,
          operationId: 'op-canonical-it-1',
          entityType: 'item_type',
          entityId: '00000000-0000-0000-0001-000000000001',
          operationType: 'create',
          payload: {
            'id': '00000000-0000-0000-0001-000000000001',
            'name': 'ملابس',
            'is_active': true,
            'created_at': '2026-09-19T00:00:00.000Z',
            'updated_at': '2026-09-19T00:00:00.000Z',
          },
          serverVersion: 1,
          createdAt: DateTime.parse('2026-09-19T00:00:00.000Z'),
        );

        // Canonical service payload: uses supported_item_type_ids (not item_type_ids)
        final serviceChange = SyncChangeDto(
          sequence: 91,
          operationId: 'op-canonical-srv-1',
          entityType: 'service',
          entityId: '00000000-0000-0000-0002-000000000001',
          operationType: 'create',
          payload: {
            'id': '00000000-0000-0000-0002-000000000001',
            'name': 'غسيل ومكوى',
            'description': 'خدمة تجريبية',
            'pricing_type': 'per_piece',
            'price': 2500,
            'is_active': true,
            'server_version': 1,
            'supported_item_type_ids': ['00000000-0000-0000-0001-000000000001'],
            'created_at': '2026-09-19T00:00:00.000Z',
            'updated_at': '2026-09-19T00:00:00.000Z',
          },
          serverVersion: 1,
          createdAt: DateTime.parse('2026-09-19T00:00:00.000Z'),
        );

        await applier.applyBatch([itemType, serviceChange]);

        // Service row persisted
        final svc = await (db.select(db.services)
              ..where(
                  (t) => t.id.equals('00000000-0000-0000-0002-000000000001')))
            .getSingle();
        expect(svc.name, equals('غسيل ومكوى'));
        expect(svc.price, equals(2500));
        expect(svc.pricingType, equals('per_piece'));

        // Junction row constructed from supported_item_type_ids
        final junctionRows = await (db.select(db.serviceItemTypes)
              ..where((t) =>
                  t.serviceId.equals('00000000-0000-0000-0002-000000000001')))
            .get();
        expect(junctionRows.length, equals(1));
        expect(junctionRows.first.itemTypeId,
            equals('00000000-0000-0000-0001-000000000001'));

        // Cursor advanced
        expect(await syncStateDao.getLastAppliedSequence(), equals(91));
      });

      test(
          'B. Service with legacy item_type_ids (backward compat) still populates junction rows',
          () async {
        final itemType = SyncChangeDto(
          sequence: 92,
          operationId: 'op-legacy-it-1',
          entityType: 'item_type',
          entityId: 'it-legacy-compat-1',
          operationType: 'create',
          payload: {
            'id': 'it-legacy-compat-1',
            'name': 'تجريبي',
            'is_active': true,
            'created_at': '2026-09-19T00:01:00.000Z',
            'updated_at': '2026-09-19T00:01:00.000Z',
          },
          serverVersion: 1,
          createdAt: DateTime.parse('2026-09-19T00:01:00.000Z'),
        );

        // Legacy payload: uses item_type_ids (old field name — backward compat)
        final serviceChange = SyncChangeDto(
          sequence: 93,
          operationId: 'op-legacy-srv-1',
          entityType: 'service',
          entityId: 'srv-legacy-compat',
          operationType: 'create',
          payload: {
            'id': 'srv-legacy-compat',
            'name': 'خدمة قديمة',
            'pricing_type': 'per_piece',
            'price': 1000,
            'is_active': true,
            // Legacy field name — must still work
            'item_type_ids': ['it-legacy-compat-1'],
            'created_at': '2026-09-19T00:01:00.000Z',
            'updated_at': '2026-09-19T00:01:00.000Z',
          },
          serverVersion: 1,
          createdAt: DateTime.parse('2026-09-19T00:01:00.000Z'),
        );

        await applier.applyBatch([itemType, serviceChange]);

        final junctionRows = await (db.select(db.serviceItemTypes)
              ..where((t) => t.serviceId.equals('srv-legacy-compat')))
            .get();
        expect(junctionRows.length, equals(1));
        expect(junctionRows.first.itemTypeId, equals('it-legacy-compat-1'));

        expect(await syncStateDao.getLastAppliedSequence(), equals(93));
      });

      test(
          'C. supported_item_type_ids takes precedence over item_type_ids when both present',
          () async {
        final itemTypeA = SyncChangeDto(
          sequence: 94,
          operationId: 'op-prio-it-a',
          entityType: 'item_type',
          entityId: 'it-prio-a',
          operationType: 'create',
          payload: {
            'id': 'it-prio-a',
            'name': 'أولوية أ',
            'is_active': true,
            'created_at': '2026-09-19T00:02:00.000Z',
            'updated_at': '2026-09-19T00:02:00.000Z',
          },
          serverVersion: 1,
          createdAt: DateTime.parse('2026-09-19T00:02:00.000Z'),
        );
        final itemTypeB = SyncChangeDto(
          sequence: 95,
          operationId: 'op-prio-it-b',
          entityType: 'item_type',
          entityId: 'it-prio-b',
          operationType: 'create',
          payload: {
            'id': 'it-prio-b',
            'name': 'أولوية ب',
            'is_active': true,
            'created_at': '2026-09-19T00:02:00.000Z',
            'updated_at': '2026-09-19T00:02:00.000Z',
          },
          serverVersion: 1,
          createdAt: DateTime.parse('2026-09-19T00:02:00.000Z'),
        );

        // Both fields present: supported_item_type_ids must win
        final serviceChange = SyncChangeDto(
          sequence: 96,
          operationId: 'op-prio-srv',
          entityType: 'service',
          entityId: 'srv-priority-test',
          operationType: 'create',
          payload: {
            'id': 'srv-priority-test',
            'name': 'اختبار أولوية',
            'pricing_type': 'per_piece',
            'price': 1000,
            'is_active': true,
            // Canonical key must win
            'supported_item_type_ids': ['it-prio-a'],
            // Legacy key must be ignored
            'item_type_ids': ['it-prio-b'],
            'created_at': '2026-09-19T00:02:00.000Z',
            'updated_at': '2026-09-19T00:02:00.000Z',
          },
          serverVersion: 1,
          createdAt: DateTime.parse('2026-09-19T00:02:00.000Z'),
        );

        await applier.applyBatch([itemTypeA, itemTypeB, serviceChange]);

        final junctionRows = await (db.select(db.serviceItemTypes)
              ..where((t) => t.serviceId.equals('srv-priority-test')))
            .get();
        expect(junctionRows.length, equals(1));
        // Must reference the canonical supported_item_type_ids entry (it-prio-a)
        expect(junctionRows.first.itemTypeId, equals('it-prio-a'));

        expect(await syncStateDao.getLastAppliedSequence(), equals(96));
      });

      test(
          'D. Storage location with supported_item_type_ids reconstructs junction rows',
          () async {
        final itemType1 = SyncChangeDto(
          sequence: 97,
          operationId: 'op-loc-it-1',
          entityType: 'item_type',
          entityId: '00000000-0000-0000-0001-000000000001',
          operationType: 'create',
          payload: {
            'id': '00000000-0000-0000-0001-000000000001',
            'name': 'ملابس',
            'is_active': true,
            'created_at': '2026-09-19T00:03:00.000Z',
            'updated_at': '2026-09-19T00:03:00.000Z',
          },
          serverVersion: 1,
          createdAt: DateTime.parse('2026-09-19T00:03:00.000Z'),
        );
        final itemType2 = SyncChangeDto(
          sequence: 98,
          operationId: 'op-loc-it-2',
          entityType: 'item_type',
          entityId: '00000000-0000-0000-0001-000000000004',
          operationType: 'create',
          payload: {
            'id': '00000000-0000-0000-0001-000000000004',
            'name': 'أغطية',
            'is_active': true,
            'created_at': '2026-09-19T00:03:00.000Z',
            'updated_at': '2026-09-19T00:03:00.000Z',
          },
          serverVersion: 1,
          createdAt: DateTime.parse('2026-09-19T00:03:00.000Z'),
        );

        // Canonical storage location payload (matches baseline script)
        final locChange = SyncChangeDto(
          sequence: 99,
          operationId: 'op-baseline-021',
          entityType: 'storage_location',
          entityId: '00000000-0000-0000-0006-000000000001',
          operationType: 'create',
          payload: {
            'id': '00000000-0000-0000-0006-000000000001',
            'name': 'رف أ-1',
            'is_active': true,
            'server_version': 1,
            'supported_item_type_ids': [
              '00000000-0000-0000-0001-000000000001',
              '00000000-0000-0000-0001-000000000004',
            ],
            'created_at': '2026-09-19T00:03:00.000Z',
            'updated_at': '2026-09-19T00:03:00.000Z',
          },
          serverVersion: 1,
          createdAt: DateTime.parse('2026-09-19T00:03:00.000Z'),
        );

        await applier.applyBatch([itemType1, itemType2, locChange]);

        // Storage location persisted
        final loc = await (db.select(db.storageLocations)
              ..where(
                  (t) => t.id.equals('00000000-0000-0000-0006-000000000001')))
            .getSingle();
        expect(loc.name, equals('رف أ-1'));

        // Both junction rows created
        final junctionRows = await (db.select(db.storageLocationItemTypes)
              ..where((t) => t.storageLocationId
                  .equals('00000000-0000-0000-0006-000000000001')))
            .get();
        expect(junctionRows.length, equals(2));
        final linkedTypeIds = junctionRows.map((r) => r.itemTypeId).toSet();
        expect(linkedTypeIds,
            containsAll(['00000000-0000-0000-0001-000000000001', '00000000-0000-0000-0001-000000000004']));

        expect(await syncStateDao.getLastAppliedSequence(), equals(99));
      });

      // ---- Canonical Baseline ID & Count assertions ---------------------------

      test(
          'E. Canonical baseline batch replay (35 changes) produces correct master state',
          () async {
        // Build all 35 canonical baseline changes matching the approved plan
        const t0 = '2026-09-19T00:00:00.000Z';
        final dt0 = DateTime.parse(t0);

        final batch = <SyncChangeDto>[
          // Seq 1: business_settings
          SyncChangeDto(sequence: 1, operationId: 'op-baseline-001', entityType: 'business_settings',
              entityId: '00000000-0000-0000-0000-000000000001', operationType: 'create',
              payload: {'id': '00000000-0000-0000-0000-000000000001', 'business_name': '', 'tax_enabled': false, 'tax_rate': 0.0, 'server_version': 1, 'created_at': t0, 'updated_at': t0},
              serverVersion: 1, createdAt: dt0),

          // Seq 2..5: item_types
          SyncChangeDto(sequence: 2, operationId: 'op-baseline-002', entityType: 'item_type',
              entityId: '00000000-0000-0000-0001-000000000001', operationType: 'create',
              payload: {'id': '00000000-0000-0000-0001-000000000001', 'name': 'ملابس', 'is_active': true, 'created_at': t0, 'updated_at': t0},
              serverVersion: 1, createdAt: dt0),
          SyncChangeDto(sequence: 3, operationId: 'op-baseline-003', entityType: 'item_type',
              entityId: '00000000-0000-0000-0001-000000000002', operationType: 'create',
              payload: {'id': '00000000-0000-0000-0001-000000000002', 'name': 'بطاطين', 'is_active': true, 'created_at': t0, 'updated_at': t0},
              serverVersion: 1, createdAt: dt0),
          SyncChangeDto(sequence: 4, operationId: 'op-baseline-004', entityType: 'item_type',
              entityId: '00000000-0000-0000-0001-000000000003', operationType: 'create',
              payload: {'id': '00000000-0000-0000-0001-000000000003', 'name': 'سجاد', 'is_active': true, 'created_at': t0, 'updated_at': t0},
              serverVersion: 1, createdAt: dt0),
          SyncChangeDto(sequence: 5, operationId: 'op-baseline-005', entityType: 'item_type',
              entityId: '00000000-0000-0000-0001-000000000004', operationType: 'create',
              payload: {'id': '00000000-0000-0000-0001-000000000004', 'name': 'أغطية', 'is_active': true, 'created_at': t0, 'updated_at': t0},
              serverVersion: 1, createdAt: dt0),

          // Seq 6..12: expense_categories
          SyncChangeDto(sequence: 6,  operationId: 'op-baseline-006', entityType: 'expense_category', entityId: '00000000-0000-0000-0002-000000000001', operationType: 'create', payload: {'id': '00000000-0000-0000-0002-000000000001', 'name': 'كهرباء', 'is_active': true, 'created_at': t0, 'updated_at': t0}, serverVersion: 1, createdAt: dt0),
          SyncChangeDto(sequence: 7,  operationId: 'op-baseline-007', entityType: 'expense_category', entityId: '00000000-0000-0000-0002-000000000002', operationType: 'create', payload: {'id': '00000000-0000-0000-0002-000000000002', 'name': 'مياه', 'is_active': true, 'created_at': t0, 'updated_at': t0}, serverVersion: 1, createdAt: dt0),
          SyncChangeDto(sequence: 8,  operationId: 'op-baseline-008', entityType: 'expense_category', entityId: '00000000-0000-0000-0002-000000000003', operationType: 'create', payload: {'id': '00000000-0000-0000-0002-000000000003', 'name': 'منظفات', 'is_active': true, 'created_at': t0, 'updated_at': t0}, serverVersion: 1, createdAt: dt0),
          SyncChangeDto(sequence: 9,  operationId: 'op-baseline-009', entityType: 'expense_category', entityId: '00000000-0000-0000-0002-000000000004', operationType: 'create', payload: {'id': '00000000-0000-0000-0002-000000000004', 'name': 'صيانة', 'is_active': true, 'created_at': t0, 'updated_at': t0}, serverVersion: 1, createdAt: dt0),
          SyncChangeDto(sequence: 10, operationId: 'op-baseline-010', entityType: 'expense_category', entityId: '00000000-0000-0000-0002-000000000005', operationType: 'create', payload: {'id': '00000000-0000-0000-0002-000000000005', 'name': 'مستلزمات', 'is_active': true, 'created_at': t0, 'updated_at': t0}, serverVersion: 1, createdAt: dt0),
          SyncChangeDto(sequence: 11, operationId: 'op-baseline-011', entityType: 'expense_category', entityId: '00000000-0000-0000-0002-000000000006', operationType: 'create', payload: {'id': '00000000-0000-0000-0002-000000000006', 'name': 'نقل', 'is_active': true, 'created_at': t0, 'updated_at': t0}, serverVersion: 1, createdAt: dt0),
          SyncChangeDto(sequence: 12, operationId: 'op-baseline-012', entityType: 'expense_category', entityId: '00000000-0000-0000-0002-000000000007', operationType: 'create', payload: {'id': '00000000-0000-0000-0002-000000000007', 'name': 'أخرى', 'is_active': true, 'created_at': t0, 'updated_at': t0}, serverVersion: 1, createdAt: dt0),

          // Seq 13..17: services (canonical supported_item_type_ids)
          SyncChangeDto(sequence: 13, operationId: 'op-baseline-013', entityType: 'service', entityId: '00000000-0000-0000-0002-000000000001', operationType: 'create', payload: {'id': '00000000-0000-0000-0002-000000000001', 'name': 'غسيل ومكوى', 'description': 'خدمة تجريبية', 'pricing_type': 'per_piece', 'price': 2500, 'is_active': true, 'server_version': 1, 'supported_item_type_ids': ['00000000-0000-0000-0001-000000000001'], 'created_at': t0, 'updated_at': t0}, serverVersion: 1, createdAt: dt0),
          SyncChangeDto(sequence: 14, operationId: 'op-baseline-014', entityType: 'service', entityId: '00000000-0000-0000-0002-000000000002', operationType: 'create', payload: {'id': '00000000-0000-0000-0002-000000000002', 'name': 'دراي كلين', 'description': 'خدمة تجريبية', 'pricing_type': 'per_piece', 'price': 4500, 'is_active': true, 'server_version': 1, 'supported_item_type_ids': ['00000000-0000-0000-0001-000000000001'], 'created_at': t0, 'updated_at': t0}, serverVersion: 1, createdAt: dt0),
          SyncChangeDto(sequence: 15, operationId: 'op-baseline-015', entityType: 'service', entityId: '00000000-0000-0000-0002-000000000003', operationType: 'create', payload: {'id': '00000000-0000-0000-0002-000000000003', 'name': 'غسيل سجاد', 'description': 'خدمة تجريبية', 'pricing_type': 'per_square_meter', 'price': 6000, 'is_active': true, 'server_version': 1, 'supported_item_type_ids': ['00000000-0000-0000-0001-000000000003'], 'created_at': t0, 'updated_at': t0}, serverVersion: 1, createdAt: dt0),
          SyncChangeDto(sequence: 16, operationId: 'op-baseline-016', entityType: 'service', entityId: '00000000-0000-0000-0002-000000000004', operationType: 'create', payload: {'id': '00000000-0000-0000-0002-000000000004', 'name': 'تنظيف بطاطين', 'description': 'خدمة تجريبية', 'pricing_type': 'fixed_price', 'price': 8000, 'is_active': true, 'server_version': 1, 'supported_item_type_ids': ['00000000-0000-0000-0001-000000000002'], 'created_at': t0, 'updated_at': t0}, serverVersion: 1, createdAt: dt0),
          SyncChangeDto(sequence: 17, operationId: 'op-baseline-017', entityType: 'service', entityId: '00000000-0000-0000-0002-000000000005', operationType: 'create', payload: {'id': '00000000-0000-0000-0002-000000000005', 'name': 'غسيل أغطية', 'description': 'خدمة تجريبية', 'pricing_type': 'fixed_price', 'price': 3500, 'is_active': true, 'server_version': 1, 'supported_item_type_ids': ['00000000-0000-0000-0001-000000000004'], 'created_at': t0, 'updated_at': t0}, serverVersion: 1, createdAt: dt0),

          // Seq 18..20: carpet_sizes
          SyncChangeDto(sequence: 18, operationId: 'op-baseline-018', entityType: 'carpet_size', entityId: '00000000-0000-0000-0007-000000000001', operationType: 'create', payload: {'id': '00000000-0000-0000-0007-000000000001', 'name': '2.0x3.0', 'length': 2.0, 'width': 3.0, 'area': 6.0, 'is_active': true, 'created_at': t0, 'updated_at': t0}, serverVersion: 1, createdAt: dt0),
          SyncChangeDto(sequence: 19, operationId: 'op-baseline-019', entityType: 'carpet_size', entityId: '00000000-0000-0000-0007-000000000002', operationType: 'create', payload: {'id': '00000000-0000-0000-0007-000000000002', 'name': '1.5x2.0', 'length': 1.5, 'width': 2.0, 'area': 3.0, 'is_active': true, 'created_at': t0, 'updated_at': t0}, serverVersion: 1, createdAt: dt0),
          SyncChangeDto(sequence: 20, operationId: 'op-baseline-020', entityType: 'carpet_size', entityId: '00000000-0000-0000-0007-000000000003', operationType: 'create', payload: {'id': '00000000-0000-0000-0007-000000000003', 'name': '1.0x4.0', 'length': 1.0, 'width': 4.0, 'area': 4.0, 'is_active': true, 'created_at': t0, 'updated_at': t0}, serverVersion: 1, createdAt: dt0),

          // Seq 21..25: storage_locations (canonical supported_item_type_ids)
          SyncChangeDto(sequence: 21, operationId: 'op-baseline-021', entityType: 'storage_location', entityId: '00000000-0000-0000-0006-000000000001', operationType: 'create', payload: {'id': '00000000-0000-0000-0006-000000000001', 'name': 'رف أ-1', 'is_active': true, 'server_version': 1, 'supported_item_type_ids': ['00000000-0000-0000-0001-000000000001', '00000000-0000-0000-0001-000000000004'], 'created_at': t0, 'updated_at': t0}, serverVersion: 1, createdAt: dt0),
          SyncChangeDto(sequence: 22, operationId: 'op-baseline-022', entityType: 'storage_location', entityId: '00000000-0000-0000-0006-000000000002', operationType: 'create', payload: {'id': '00000000-0000-0000-0006-000000000002', 'name': 'رف أ-2', 'is_active': true, 'server_version': 1, 'supported_item_type_ids': ['00000000-0000-0000-0001-000000000001', '00000000-0000-0000-0001-000000000004'], 'created_at': t0, 'updated_at': t0}, serverVersion: 1, createdAt: dt0),
          SyncChangeDto(sequence: 23, operationId: 'op-baseline-023', entityType: 'storage_location', entityId: '00000000-0000-0000-0006-000000000003', operationType: 'create', payload: {'id': '00000000-0000-0000-0006-000000000003', 'name': 'رف ب-1', 'is_active': true, 'server_version': 1, 'supported_item_type_ids': ['00000000-0000-0000-0001-000000000001', '00000000-0000-0000-0001-000000000004'], 'created_at': t0, 'updated_at': t0}, serverVersion: 1, createdAt: dt0),
          SyncChangeDto(sequence: 24, operationId: 'op-baseline-024', entityType: 'storage_location', entityId: '00000000-0000-0000-0006-000000000004', operationType: 'create', payload: {'id': '00000000-0000-0000-0006-000000000004', 'name': 'قسم السجاد 1', 'is_active': true, 'server_version': 1, 'supported_item_type_ids': ['00000000-0000-0000-0001-000000000003'], 'created_at': t0, 'updated_at': t0}, serverVersion: 1, createdAt: dt0),
          SyncChangeDto(sequence: 25, operationId: 'op-baseline-025', entityType: 'storage_location', entityId: '00000000-0000-0000-0006-000000000005', operationType: 'create', payload: {'id': '00000000-0000-0000-0006-000000000005', 'name': 'قسم البطاطين 1', 'is_active': true, 'server_version': 1, 'supported_item_type_ids': ['00000000-0000-0000-0001-000000000002', '00000000-0000-0000-0001-000000000004'], 'created_at': t0, 'updated_at': t0}, serverVersion: 1, createdAt: dt0),

          // Seq 26..35: item_definitions
          SyncChangeDto(sequence: 26, operationId: 'op-baseline-026', entityType: 'item_definition', entityId: '00000000-0000-0000-0005-000000000001', operationType: 'create', payload: {'id': '00000000-0000-0000-0005-000000000001', 'item_type_id': '00000000-0000-0000-0001-000000000001', 'name': 'قميص', 'is_active': true, 'created_at': t0, 'updated_at': t0}, serverVersion: 1, createdAt: dt0),
          SyncChangeDto(sequence: 27, operationId: 'op-baseline-027', entityType: 'item_definition', entityId: '00000000-0000-0000-0005-000000000002', operationType: 'create', payload: {'id': '00000000-0000-0000-0005-000000000002', 'item_type_id': '00000000-0000-0000-0001-000000000001', 'name': 'بنطلون', 'is_active': true, 'created_at': t0, 'updated_at': t0}, serverVersion: 1, createdAt: dt0),
          SyncChangeDto(sequence: 28, operationId: 'op-baseline-028', entityType: 'item_definition', entityId: '00000000-0000-0000-0005-000000000003', operationType: 'create', payload: {'id': '00000000-0000-0000-0005-000000000003', 'item_type_id': '00000000-0000-0000-0001-000000000001', 'name': 'بدلة', 'is_active': true, 'created_at': t0, 'updated_at': t0}, serverVersion: 1, createdAt: dt0),
          SyncChangeDto(sequence: 29, operationId: 'op-baseline-029', entityType: 'item_definition', entityId: '00000000-0000-0000-0005-000000000004', operationType: 'create', payload: {'id': '00000000-0000-0000-0005-000000000004', 'item_type_id': '00000000-0000-0000-0001-000000000002', 'name': 'بطانية مفرد', 'is_active': true, 'created_at': t0, 'updated_at': t0}, serverVersion: 1, createdAt: dt0),
          SyncChangeDto(sequence: 30, operationId: 'op-baseline-030', entityType: 'item_definition', entityId: '00000000-0000-0000-0005-000000000005', operationType: 'create', payload: {'id': '00000000-0000-0000-0005-000000000005', 'item_type_id': '00000000-0000-0000-0001-000000000002', 'name': 'بطانية دبل', 'is_active': true, 'created_at': t0, 'updated_at': t0}, serverVersion: 1, createdAt: dt0),
          SyncChangeDto(sequence: 31, operationId: 'op-baseline-031', entityType: 'item_definition', entityId: '00000000-0000-0000-0005-000000000006', operationType: 'create', payload: {'id': '00000000-0000-0000-0005-000000000006', 'item_type_id': '00000000-0000-0000-0001-000000000003', 'name': 'سجادة صوف', 'is_active': true, 'created_at': t0, 'updated_at': t0}, serverVersion: 1, createdAt: dt0),
          SyncChangeDto(sequence: 32, operationId: 'op-baseline-032', entityType: 'item_definition', entityId: '00000000-0000-0000-0005-000000000007', operationType: 'create', payload: {'id': '00000000-0000-0000-0005-000000000007', 'item_type_id': '00000000-0000-0000-0001-000000000003', 'name': 'مشاية', 'is_active': true, 'created_at': t0, 'updated_at': t0}, serverVersion: 1, createdAt: dt0),
          SyncChangeDto(sequence: 33, operationId: 'op-baseline-033', entityType: 'item_definition', entityId: '00000000-0000-0000-0005-000000000008', operationType: 'create', payload: {'id': '00000000-0000-0000-0005-000000000008', 'item_type_id': '00000000-0000-0000-0001-000000000004', 'name': 'غطاء لحاف', 'is_active': true, 'created_at': t0, 'updated_at': t0}, serverVersion: 1, createdAt: dt0),
          SyncChangeDto(sequence: 34, operationId: 'op-baseline-034', entityType: 'item_definition', entityId: '00000000-0000-0000-0005-000000000009', operationType: 'create', payload: {'id': '00000000-0000-0000-0005-000000000009', 'item_type_id': '00000000-0000-0000-0001-000000000004', 'name': 'كوفرتة', 'is_active': true, 'created_at': t0, 'updated_at': t0}, serverVersion: 1, createdAt: dt0),
          SyncChangeDto(sequence: 35, operationId: 'op-baseline-035', entityType: 'item_definition', entityId: '00000000-0000-0000-0005-000000000010', operationType: 'create', payload: {'id': '00000000-0000-0000-0005-000000000010', 'item_type_id': '00000000-0000-0000-0001-000000000003', 'name': 'سجادة حرير', 'is_active': true, 'created_at': t0, 'updated_at': t0}, serverVersion: 1, createdAt: dt0),
        ];

        // Apply the complete canonical baseline batch
        await applier.applyBatch(batch);

        // Cursor must be at exactly 35
        expect(await syncStateDao.getLastAppliedSequence(), equals(35));

        // --- Entity count assertions ---
        final itemTypeCount = await (db.selectOnly(db.itemTypes)
              ..addColumns([db.itemTypes.id.count()]))
            .map((r) => r.read(db.itemTypes.id.count()))
            .getSingle();
        expect(itemTypeCount, equals(4), reason: 'item_types must have 4 rows');

        final catCount = await (db.selectOnly(db.expenseCategories)
              ..addColumns([db.expenseCategories.id.count()]))
            .map((r) => r.read(db.expenseCategories.id.count()))
            .getSingle();
        expect(catCount, equals(7), reason: 'expense_categories must have 7 rows');

        final svcCount = await (db.selectOnly(db.services)
              ..addColumns([db.services.id.count()]))
            .map((r) => r.read(db.services.id.count()))
            .getSingle();
        expect(svcCount, equals(5), reason: 'services must have 5 rows');

        final csCount = await (db.selectOnly(db.carpetSizes)
              ..addColumns([db.carpetSizes.id.count()]))
            .map((r) => r.read(db.carpetSizes.id.count()))
            .getSingle();
        expect(csCount, equals(3), reason: 'carpet_sizes must have 3 rows');

        final locCount = await (db.selectOnly(db.storageLocations)
              ..addColumns([db.storageLocations.id.count()]))
            .map((r) => r.read(db.storageLocations.id.count()))
            .getSingle();
        expect(locCount, equals(5), reason: 'storage_locations must have 5 rows');

        final idefCount = await (db.selectOnly(db.itemDefinitions)
              ..addColumns([db.itemDefinitions.id.count()]))
            .map((r) => r.read(db.itemDefinitions.id.count()))
            .getSingle();
        expect(idefCount, equals(10), reason: 'item_definitions must have 10 rows');

        // --- Service junction assertions ---
        final srvJunctionCount = await (db.selectOnly(db.serviceItemTypes)
              ..addColumns([db.serviceItemTypes.serviceId.count()]))
            .map((r) => r.read(db.serviceItemTypes.serviceId.count()))
            .getSingle();
        expect(srvJunctionCount, equals(5), reason: 'service_item_types must have 5 rows');

        // --- Storage location junction assertions ---
        final locJunctionCount = await (db.selectOnly(db.storageLocationItemTypes)
              ..addColumns([db.storageLocationItemTypes.storageLocationId.count()]))
            .map((r) => r.read(db.storageLocationItemTypes.storageLocationId.count()))
            .getSingle();
        expect(locJunctionCount, equals(9), reason: 'storage_location_item_types must have 9 rows');

        // --- Canonical ID spot checks ---
        final clothingType = await (db.select(db.itemTypes)
              ..where((t) => t.id.equals('00000000-0000-0000-0001-000000000001')))
            .getSingleOrNull();
        expect(clothingType?.name, equals('ملابس'));

        final silkCarpetDef = await (db.select(db.itemDefinitions)
              ..where((t) => t.id.equals('00000000-0000-0000-0005-000000000010')))
            .getSingleOrNull();
        expect(silkCarpetDef?.name, equals('سجادة حرير'));
        expect(silkCarpetDef?.itemTypeId, equals('00000000-0000-0000-0001-000000000003'));

        final carpetWash = await (db.select(db.services)
              ..where((t) => t.id.equals('00000000-0000-0000-0002-000000000003')))
            .getSingleOrNull();
        expect(carpetWash?.name, equals('غسيل سجاد'));
        expect(carpetWash?.price, equals(6000));
        expect(carpetWash?.pricingType, equals('per_square_meter'));

        final carpetSection = await (db.select(db.storageLocations)
              ..where((t) => t.id.equals('00000000-0000-0000-0006-000000000004')))
            .getSingleOrNull();
        expect(carpetSection?.name, equals('قسم السجاد 1'));

        final size2x3 = await (db.select(db.carpetSizes)
              ..where((t) => t.id.equals('00000000-0000-0000-0007-000000000001')))
            .getSingleOrNull();
        expect(size2x3?.length, equals(2.0));
        expect(size2x3?.width, equals(3.0));
        expect(size2x3?.area, equals(6.0));
      });
    });
  });
}
