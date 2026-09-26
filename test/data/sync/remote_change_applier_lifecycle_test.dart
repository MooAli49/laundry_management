import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/daos/sync_state_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart'
    as app_db;
import 'package:laundry_management/data/remote/dto/sync_change_dto.dart';
import 'package:laundry_management/data/sync/remote_change_applier.dart';

void main() {
  group('RemoteChangeApplier Lifecycle Storage Reconciliation Tests', () {
    late app_db.AppDatabase db;
    late SyncStateDao syncStateDao;
    late SyncOperationsDao syncOperationsDao;
    late OrdersDao ordersDao;
    late PaymentsDao paymentsDao;
    late StorageRecordsDao storageRecordsDao;
    late RemoteChangeApplier applier;

    const testCustomerId = 'cust-life-1';
    const testServiceId = '00000000-0000-0000-0002-000000000001';
    const testItemTypeId = '00000000-0000-0000-0001-000000000001';
    const testLocation1Id = '00000000-0000-0000-0006-000000000001';
    const testLocation2Id = '00000000-0000-0000-0006-000000000002';

    setUp(() async {
      db = app_db.AppDatabase(NativeDatabase.memory());
      syncStateDao = SyncStateDao(db);
      syncOperationsDao = SyncOperationsDao(db);
      ordersDao = OrdersDao(db);
      paymentsDao = PaymentsDao(db);
      storageRecordsDao = StorageRecordsDao(db);

      applier = RemoteChangeApplier(
        db: db,
        syncStateDao: syncStateDao,
      );

      final now = DateTime.now();

      // Seed baseline master data
      await db.into(db.customers).insert(
            app_db.CustomersCompanion.insert(
              id: testCustomerId,
              name: 'عميل دورة الحياة',
              phone: '01011223344',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db.into(db.services).insert(
            app_db.ServicesCompanion.insert(
              id: testServiceId,
              name: 'تنظيف',
              pricingType: 'per_piece',
              price: 2500,
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db.customStatement(
        'INSERT OR REPLACE INTO item_types (id, name, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
        [
          testItemTypeId,
          'ملابس',
          1,
          now.millisecondsSinceEpoch ~/ 1000,
          now.millisecondsSinceEpoch ~/ 1000,
        ],
      );

      await db.into(db.storageLocations).insert(
            app_db.StorageLocationsCompanion.insert(
              id: testLocation1Id,
              name: 'رف 1',
              isActive: const Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db.into(db.storageLocations).insert(
            app_db.StorageLocationsCompanion.insert(
              id: testLocation2Id,
              name: 'رف 2',
              isActive: const Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> seedOrderWithItems({
      required String orderId,
      required String status,
      required List<String> itemIds,
      bool storeActive = true,
      String locationId = testLocation1Id,
      int totalPiastres = 5000,
    }) async {
      final now = DateTime.now();

      await db.into(db.orders).insert(
            app_db.OrdersCompanion.insert(
              id: orderId,
              orderNumber: 'ORD-$orderId',
              customerId: testCustomerId,
              customerNameSnapshot: const Value('عميل دورة الحياة'),
              customerPhoneSnapshot: const Value('01011223344'),
              status: Value(status),
              expectedPickupDate: now.add(const Duration(days: 2)),
              subtotal: totalPiastres,
              total: totalPiastres,
              createdAt: now,
              updatedAt: now,
            ),
          );

      for (final itemId in itemIds) {
        await db.into(db.orderItems).insert(
              app_db.OrderItemsCompanion.insert(
                id: itemId,
                orderId: orderId,
                itemTypeId: testItemTypeId,
                serviceId: testServiceId,
                itemTypeNameSnapshot: 'ملابس',
                serviceNameSnapshot: 'تنظيف',
                pricingType: 'per_piece',
                quantity: 1.0,
                unitPrice: 2500,
                calculatedTotal: 2500,
                createdAt: now,
                updatedAt: now,
              ),
            );

        if (storeActive) {
          await db.into(db.storageRecords).insert(
                app_db.StorageRecordsCompanion.insert(
                  id: 'rec-$itemId',
                  orderItemId: itemId,
                  storageLocationId: locationId,
                  isActive: const Value(true),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }
      }
    }

    test(
      'A. Remote completed: status completed, active storage deactivated, payments unchanged, zero outbox',
      () async {
        const orderId = 'ord-comp-A';
        const itemId = 'item-comp-A';
        await seedOrderWithItems(
          orderId: orderId,
          status: 'ready',
          itemIds: [itemId],
          totalPiastres: 5000,
        );

        // Record a payment of 5000
        final now = DateTime.now();
        await db.into(db.payments).insert(
              app_db.PaymentsCompanion.insert(
                id: 'pay-comp-A',
                orderId: orderId,
                amount: 5000,
                paymentMethod: 'cash',
                paidAt: now,
                createdAt: now,
                updatedAt: now,
              ),
            );

        // Active storage exists before sync
        final storageBefore =
            await storageRecordsDao.getActiveRecordForOrderItem(itemId);
        expect(storageBefore, isNotNull);
        expect(storageBefore!.isActive, isTrue);

        // Remote completed update
        final change = SyncChangeDto(
          sequence: 1,
          operationId: 'op-remote-complete',
          entityType: 'order',
          entityId: orderId,
          operationType: 'update',
          payload: {
            'id': orderId,
            'status': 'completed',
            'completed_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          },
          serverVersion: 2,
          createdAt: now,
        );

        await applier.applyBatch([change]);

        // Verify order status completed and completedAt set
        final orderAfter = await ordersDao.getOrderById(orderId);
        expect(orderAfter!.status, equals('completed'));
        expect(orderAfter.completedAt, isNotNull);

        // Active storage MUST be deactivated
        final storageAfter =
            await storageRecordsDao.getActiveRecordForOrderItem(itemId);
        expect(storageAfter, isNull);

        final allRecords = await (db.select(db.storageRecords)
              ..where((t) => t.orderItemId.equals(itemId)))
            .get();
        expect(allRecords.length, equals(1));
        expect(allRecords.first.isActive, isFalse);

        // Payments intact
        final payments = await paymentsDao.getPaymentsForOrder(orderId);
        expect(payments.length, equals(1));
        expect(payments.first.amount, equals(5000));

        // ZERO outbox operations generated
        final outboxOps = await syncOperationsDao.getPendingOperations();
        expect(outboxOps, isEmpty);
      },
    );

    test(
      'B. Remote cancelled: status cancelled, active storage deactivated, payments unchanged, zero outbox',
      () async {
        const orderId = 'ord-canc-B';
        const itemId = 'item-canc-B';
        await seedOrderWithItems(
          orderId: orderId,
          status: 'processing',
          itemIds: [itemId],
          totalPiastres: 3000,
        );

        // Partial payment
        final now = DateTime.now();
        await db.into(db.payments).insert(
              app_db.PaymentsCompanion.insert(
                id: 'pay-canc-B',
                orderId: orderId,
                amount: 1500,
                paymentMethod: 'cash',
                paidAt: now,
                createdAt: now,
                updatedAt: now,
              ),
            );

        final change = SyncChangeDto(
          sequence: 2,
          operationId: 'op-remote-cancel',
          entityType: 'order',
          entityId: orderId,
          operationType: 'update',
          payload: {
            'id': orderId,
            'status': 'cancelled',
            'cancelled_at': now.toIso8601String(),
            'cancellation_reason': 'العميل يرغب بالإلغاء',
            'updated_at': now.toIso8601String(),
          },
          serverVersion: 2,
          createdAt: now,
        );

        await applier.applyBatch([change]);

        final orderAfter = await ordersDao.getOrderById(orderId);
        expect(orderAfter!.status, equals('cancelled'));
        expect(orderAfter.cancelledAt, isNotNull);
        expect(orderAfter.cancellationReason, equals('العميل يرغب بالإلغاء'));

        // Storage deactivated
        final storageAfter =
            await storageRecordsDao.getActiveRecordForOrderItem(itemId);
        expect(storageAfter, isNull);

        // Payment preserved
        final payments = await paymentsDao.getPaymentsForOrder(orderId);
        expect(payments.length, equals(1));
        expect(payments.first.amount, equals(1500));

        // ZERO outbox operations
        final outboxOps = await syncOperationsDao.getPendingOperations();
        expect(outboxOps, isEmpty);
      },
    );

    test(
      'C. Remote Ready -> Processing: status processing, active storage deactivated, zero outbox',
      () async {
        const orderId = 'ord-r2p-C';
        const itemId = 'item-r2p-C';
        await seedOrderWithItems(
          orderId: orderId,
          status: 'ready',
          itemIds: [itemId],
        );

        final now = DateTime.now();
        final change = SyncChangeDto(
          sequence: 3,
          operationId: 'op-remote-r2p',
          entityType: 'order',
          entityId: orderId,
          operationType: 'update',
          payload: {
            'id': orderId,
            'status': 'processing',
            'updated_at': now.toIso8601String(),
          },
          serverVersion: 2,
          createdAt: now,
        );

        await applier.applyBatch([change]);

        final orderAfter = await ordersDao.getOrderById(orderId);
        expect(orderAfter!.status, equals('processing'));

        // Active storage deactivated
        final storageAfter =
            await storageRecordsDao.getActiveRecordForOrderItem(itemId);
        expect(storageAfter, isNull);

        // ZERO outbox
        final outboxOps = await syncOperationsDao.getPendingOperations();
        expect(outboxOps, isEmpty);
      },
    );

    test(
      'D. Remote Processing -> Ready: status ready, active storage REMAINS ACTIVE, zero outbox',
      () async {
        const orderId = 'ord-p2r-D';
        const itemId = 'item-p2r-D';
        await seedOrderWithItems(
          orderId: orderId,
          status: 'processing',
          itemIds: [itemId],
          storeActive: true,
        );

        final now = DateTime.now();
        final change = SyncChangeDto(
          sequence: 4,
          operationId: 'op-remote-p2r',
          entityType: 'order',
          entityId: orderId,
          operationType: 'update',
          payload: {
            'id': orderId,
            'status': 'ready',
            'updated_at': now.toIso8601String(),
          },
          serverVersion: 2,
          createdAt: now,
        );

        await applier.applyBatch([change]);

        final orderAfter = await ordersDao.getOrderById(orderId);
        expect(orderAfter!.status, equals('ready'));

        // Active storage MUST REMAIN ACTIVE
        final storageAfter =
            await storageRecordsDao.getActiveRecordForOrderItem(itemId);
        expect(storageAfter, isNotNull);
        expect(storageAfter!.isActive, isTrue);

        // ZERO outbox
        final outboxOps = await syncOperationsDao.getPendingOperations();
        expect(outboxOps, isEmpty);
      },
    );

    test(
      'E. Unrelated order: lifecycle change for Order A does not affect Order B storage',
      () async {
        const orderA = 'ord-unrelated-A';
        const itemA = 'item-unrelated-A';
        const orderB = 'ord-unrelated-B';
        const itemB = 'item-unrelated-B';

        await seedOrderWithItems(
          orderId: orderA,
          status: 'ready',
          itemIds: [itemA],
          locationId: testLocation1Id,
        );
        await seedOrderWithItems(
          orderId: orderB,
          status: 'ready',
          itemIds: [itemB],
          locationId: testLocation2Id,
        );

        final now = DateTime.now();
        final changeA = SyncChangeDto(
          sequence: 5,
          operationId: 'op-comp-A',
          entityType: 'order',
          entityId: orderA,
          operationType: 'update',
          payload: {
            'id': orderA,
            'status': 'completed',
            'completed_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          },
          serverVersion: 2,
          createdAt: now,
        );

        await applier.applyBatch([changeA]);

        // Order A storage deactivated
        final storageA =
            await storageRecordsDao.getActiveRecordForOrderItem(itemA);
        expect(storageA, isNull);

        // Order B storage MUST REMAIN ACTIVE
        final storageB =
            await storageRecordsDao.getActiveRecordForOrderItem(itemB);
        expect(storageB, isNotNull);
        expect(storageB!.isActive, isTrue);
        expect(storageB.storageLocationId, equals(testLocation2Id));

        // ZERO outbox
        final outboxOps = await syncOperationsDao.getPendingOperations();
        expect(outboxOps, isEmpty);
      },
    );

    test(
      'F. Multiple items: all active storage records belonging to affected order are deactivated',
      () async {
        const orderId = 'ord-multi-F';
        const items = ['item-F1', 'item-F2', 'item-F3'];

        await seedOrderWithItems(
          orderId: orderId,
          status: 'ready',
          itemIds: items,
          storeActive: true,
        );

        // Verify all 3 are active
        for (final itemId in items) {
          final rec =
              await storageRecordsDao.getActiveRecordForOrderItem(itemId);
          expect(rec, isNotNull);
          expect(rec!.isActive, isTrue);
        }

        final now = DateTime.now();
        final change = SyncChangeDto(
          sequence: 6,
          operationId: 'op-cancel-multi',
          entityType: 'order',
          entityId: orderId,
          operationType: 'update',
          payload: {
            'id': orderId,
            'status': 'cancelled',
            'cancelled_at': now.toIso8601String(),
            'cancellation_reason': 'إلغاء متعدد العناصر',
            'updated_at': now.toIso8601String(),
          },
          serverVersion: 2,
          createdAt: now,
        );

        await applier.applyBatch([change]);

        // All 3 storage records must be deactivated
        for (final itemId in items) {
          final rec =
              await storageRecordsDao.getActiveRecordForOrderItem(itemId);
          expect(rec, isNull, reason: 'Item $itemId storage should be deactivated');
        }

        // ZERO outbox
        final outboxOps = await syncOperationsDao.getPendingOperations();
        expect(outboxOps, isEmpty);
      },
    );

    test(
      'G. Repeated remote application: safe, idempotent, and zero outbox operations',
      () async {
        const orderId = 'ord-idempotent-G';
        const itemId = 'item-idempotent-G';

        await seedOrderWithItems(
          orderId: orderId,
          status: 'ready',
          itemIds: [itemId],
          storeActive: true,
        );

        final now = DateTime.now();
        final change = SyncChangeDto(
          sequence: 7,
          operationId: 'op-idem-1',
          entityType: 'order',
          entityId: orderId,
          operationType: 'update',
          payload: {
            'id': orderId,
            'status': 'completed',
            'completed_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          },
          serverVersion: 2,
          createdAt: now,
        );

        // Apply first time
        await applier.applyBatch([change]);

        var order = await ordersDao.getOrderById(orderId);
        expect(order!.status, equals('completed'));
        var storage = await storageRecordsDao.getActiveRecordForOrderItem(itemId);
        expect(storage, isNull);

        // Apply second time (same or higher sequence)
        final change2 = SyncChangeDto(
          sequence: 8,
          operationId: 'op-idem-2',
          entityType: 'order',
          entityId: orderId,
          operationType: 'update',
          payload: {
            'id': orderId,
            'status': 'completed',
            'completed_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          },
          serverVersion: 2,
          createdAt: now,
        );

        await applier.applyBatch([change2]);

        order = await ordersDao.getOrderById(orderId);
        expect(order!.status, equals('completed'));
        storage = await storageRecordsDao.getActiveRecordForOrderItem(itemId);
        expect(storage, isNull);

        // Sequence advanced to 8
        final lastSeq = await syncStateDao.getLastAppliedSequence();
        expect(lastSeq, equals(8));

        // ZERO outbox operations throughout
        final outboxOps = await syncOperationsDao.getPendingOperations();
        expect(outboxOps, isEmpty);
      },
    );
  });
}
