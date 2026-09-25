import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/daos/sync_state_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart'
    as app_db;
import 'package:laundry_management/data/remote/dto/sync_change_dto.dart';
import 'package:laundry_management/data/sync/remote_change_applier.dart';

void main() {
  group('RemoteChangeApplier._applyOrderEdit Comprehensive Tests', () {
    late app_db.AppDatabase db;
    late SyncStateDao syncStateDao;
    late SyncOperationsDao syncOperationsDao;
    late OrdersDao ordersDao;
    late StorageRecordsDao storageRecordsDao;
    late RemoteChangeApplier applier;

    const testCustomerId = 'cust-100';
    const testOrderId = 'order-edit-100';
    const testItem1Id = 'item-1';
    const testItem2Id = 'item-2';
    const testItem3Id = 'item-3';
    const testCarpet1Id = 'carpet-1';
    const testServiceId = '00000000-0000-0000-0002-000000000001';
    const testCarpetServiceId = '00000000-0000-0000-0002-000000000003';
    const testItemTypeId = '00000000-0000-0000-0001-000000000001';
    const testCarpetItemTypeId = '00000000-0000-0000-0001-000000000003';

    setUp(() async {
      db = app_db.AppDatabase(NativeDatabase.memory());
      syncStateDao = SyncStateDao(db);
      syncOperationsDao = SyncOperationsDao(db);
      ordersDao = OrdersDao(db);
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
              name: 'عميل تجريبي',
              phone: '01012345678',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db.into(db.services).insert(
            app_db.ServicesCompanion.insert(
              id: testServiceId,
              name: 'غسيل وكوي',
              pricingType: 'per_piece',
              price: 1500,
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db.into(db.services).insert(
            app_db.ServicesCompanion.insert(
              id: testCarpetServiceId,
              name: 'غسيل سجاد',
              pricingType: 'per_square_meter',
              price: 4000,
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

      await db.customStatement(
        'INSERT OR REPLACE INTO item_types (id, name, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
        [
          testCarpetItemTypeId,
          'سجاد-carpet',
          1,
          now.millisecondsSinceEpoch ~/ 1000,
          now.millisecondsSinceEpoch ~/ 1000,
        ],
      );

      // Create initial local order aggregate on device (Item 1 & Item 2)
      await db.into(db.orders).insert(
            app_db.OrdersCompanion.insert(
              id: testOrderId,
              orderNumber: 'ORD-001',
              customerId: testCustomerId,
              customerNameSnapshot: const Value('عميل تجريبي'),
              customerPhoneSnapshot: const Value('01012345678'),
              status: const Value('processing'),
              expectedPickupDate: now.add(const Duration(days: 2)),
              subtotal: 5500,
              discount: const Value(0),
              tax: const Value(0),
              total: 5500,
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db.into(db.orderItems).insert(
            app_db.OrderItemsCompanion.insert(
              id: testItem1Id,
              orderId: testOrderId,
              itemTypeId: testItemTypeId,
              serviceId: testServiceId,
              itemTypeNameSnapshot: 'ملابس',
              serviceNameSnapshot: 'غسيل وكوي',
              pricingType: 'per_piece',
              quantity: 1.0,
              unitPrice: 1500,
              calculatedTotal: 1500,
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db.into(db.orderItems).insert(
            app_db.OrderItemsCompanion.insert(
              id: testItem2Id,
              orderId: testOrderId,
              itemTypeId: testCarpetItemTypeId,
              serviceId: testCarpetServiceId,
              itemTypeNameSnapshot: 'سجاد-carpet',
              serviceNameSnapshot: 'غسيل سجاد',
              pricingType: 'per_square_meter',
              quantity: 1.0,
              unitPrice: 4000,
              calculatedTotal: 4000,
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db.into(db.orderItemCarpets).insert(
            app_db.OrderItemCarpetsCompanion.insert(
              id: testCarpet1Id,
              orderItemId: testItem2Id,
              length: 1.0,
              width: 1.0,
              area: 1.0,
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    tearDown(() async {
      await db.close();
    });

    test('A. Full aggregate replacement: absent item is removed from local DB', () async {
      // Remote edit removes item-2, keeps item-1
      final editChange = SyncChangeDto(
        sequence: 10,
        operationId: 'op-edit-001',
        entityType: 'order',
        entityId: testOrderId,
        operationType: 'edit',
        payload: {
          'id': testOrderId,
          'order_number': 'ORD-001',
          'customer_id': testCustomerId,
          'status': 'processing',
          'subtotal': 1500,
          'discount': 0,
          'tax': 0,
          'total': 1500,
          'items': [
            {
              'id': testItem1Id,
              'order_id': testOrderId,
              'item_type_id': testItemTypeId,
              'service_id': testServiceId,
              'item_type_name_snapshot': 'ملابس',
              'service_name_snapshot': 'غسيل وكوي',
              'pricing_type': 'per_piece',
              'quantity': 1.0,
              'unit_price': 1500,
              'calculated_total': 1500,
            }
          ],
        },
        serverVersion: 2,
        createdAt: DateTime.now(),
      );

      await applier.applyBatch([editChange]);

      final localItems = await (db.select(db.orderItems)
            ..where((t) => t.orderId.equals(testOrderId)))
          .get();
      expect(localItems.length, equals(1));
      expect(localItems.first.id, equals(testItem1Id));

      // Carpet metadata for item-2 must be removed as well
      final localCarpets = await db.select(db.orderItemCarpets).get();
      expect(localCarpets, isEmpty);

      // Order total updated
      final updatedOrder = await ordersDao.getOrderById(testOrderId);
      expect(updatedOrder!.total, equals(1500));
    });

    test('B. New item replication: newly added item is inserted cleanly', () async {
      final editChange = SyncChangeDto(
        sequence: 11,
        operationId: 'op-edit-002',
        entityType: 'order',
        entityId: testOrderId,
        operationType: 'edit',
        payload: {
          'id': testOrderId,
          'order_number': 'ORD-001',
          'customer_id': testCustomerId,
          'status': 'processing',
          'subtotal': 3000,
          'discount': 0,
          'tax': 0,
          'total': 3000,
          'items': [
            {
              'id': testItem1Id,
              'order_id': testOrderId,
              'item_type_id': testItemTypeId,
              'service_id': testServiceId,
              'item_type_name_snapshot': 'ملابس',
              'service_name_snapshot': 'غسيل وكوي',
              'pricing_type': 'per_piece',
              'quantity': 1.0,
              'unit_price': 1500,
              'calculated_total': 1500,
            },
            {
              'id': testItem3Id,
              'order_id': testOrderId,
              'item_type_id': testItemTypeId,
              'service_id': testServiceId,
              'item_type_name_snapshot': 'ملابس',
              'service_name_snapshot': 'غسيل وكوي',
              'pricing_type': 'per_piece',
              'quantity': 1.0,
              'unit_price': 1500,
              'calculated_total': 1500,
              'notes': 'قطعة جديدة',
            },
          ],
        },
        serverVersion: 2,
        createdAt: DateTime.now(),
      );

      await applier.applyBatch([editChange]);

      final localItems = await (db.select(db.orderItems)
            ..where((t) => t.orderId.equals(testOrderId)))
          .get();
      expect(localItems.length, equals(2));
      final item3 = localItems.firstWhere((i) => i.id == testItem3Id);
      expect(item3.notes, equals('قطعة جديدة'));
      expect(item3.calculatedTotal, equals(1500));
    });

    test('C. Existing item update: modified values are updated in local DB', () async {
      final editChange = SyncChangeDto(
        sequence: 12,
        operationId: 'op-edit-003',
        entityType: 'order',
        entityId: testOrderId,
        operationType: 'edit',
        payload: {
          'id': testOrderId,
          'order_number': 'ORD-001',
          'customer_id': testCustomerId,
          'status': 'processing',
          'subtotal': 2500,
          'discount': 0,
          'tax': 0,
          'total': 2500,
          'items': [
            {
              'id': testItem1Id,
              'order_id': testOrderId,
              'item_type_id': testItemTypeId,
              'service_id': testServiceId,
              'item_type_name_snapshot': 'ملابس',
              'service_name_snapshot': 'غسيل وكوي',
              'pricing_type': 'per_piece',
              'quantity': 1.0,
              'unit_price': 2500,
              'calculated_total': 2500,
              'notes': 'تعديل السعر',
            },
          ],
        },
        serverVersion: 2,
        createdAt: DateTime.now(),
      );

      await applier.applyBatch([editChange]);

      final localItem1 = await (db.select(db.orderItems)
            ..where((t) => t.id.equals(testItem1Id)))
          .getSingle();
      expect(localItem1.unitPrice, equals(2500));
      expect(localItem1.calculatedTotal, equals(2500));
      expect(localItem1.notes, equals('تعديل السعر'));
    });

    test('D. Carpet metadata: reconciles updated carpet dimensions and carpet removal', () async {
      // 1. Update carpet dimensions on item-2
      final editChangeUpdateCarpet = SyncChangeDto(
        sequence: 13,
        operationId: 'op-edit-004',
        entityType: 'order',
        entityId: testOrderId,
        operationType: 'edit',
        payload: {
          'id': testOrderId,
          'items': [
            {
              'id': testItem2Id,
              'order_id': testOrderId,
              'item_type_id': testCarpetItemTypeId,
              'service_id': testCarpetServiceId,
              'pricing_type': 'per_square_meter',
              'quantity': 6.0,
              'unit_price': 4000,
              'calculated_total': 24000,
              'carpet_data': {
                'id': testCarpet1Id,
                'order_item_id': testItem2Id,
                'length': 2.0,
                'width': 3.0,
                'area': 6.0,
              },
            }
          ],
        },
        serverVersion: 2,
        createdAt: DateTime.now(),
      );

      await applier.applyBatch([editChangeUpdateCarpet]);

      final carpetRow = await (db.select(db.orderItemCarpets)
            ..where((t) => t.id.equals(testCarpet1Id)))
          .getSingle();
      expect(carpetRow.length, equals(2.0));
      expect(carpetRow.width, equals(3.0));
      expect(carpetRow.area, equals(6.0));

      // 2. Remove carpet metadata from item-2 (e.g. converted to non-carpet)
      final editChangeRemoveCarpet = SyncChangeDto(
        sequence: 14,
        operationId: 'op-edit-005',
        entityType: 'order',
        entityId: testOrderId,
        operationType: 'edit',
        payload: {
          'id': testOrderId,
          'items': [
            {
              'id': testItem2Id,
              'order_id': testOrderId,
              'item_type_id': testItemTypeId,
              'service_id': testServiceId,
              'pricing_type': 'per_piece',
              'quantity': 1.0,
              'unit_price': 1500,
              'calculated_total': 1500,
              'carpet_data': null,
            }
          ],
        },
        serverVersion: 3,
        createdAt: DateTime.now(),
      );

      await applier.applyBatch([editChangeRemoveCarpet]);

      final carpetsAfterRemoval = await (db.select(db.orderItemCarpets)
            ..where((t) => t.orderItemId.equals(testItem2Id)))
          .get();
      expect(carpetsAfterRemoval, isEmpty);
    });

    test('E. Zero duplicate items: idempotent re-application produces exactly 1 row per item', () async {
      final editChange = SyncChangeDto(
        sequence: 15,
        operationId: 'op-edit-006',
        entityType: 'order',
        entityId: testOrderId,
        operationType: 'edit',
        payload: {
          'id': testOrderId,
          'order_number': 'ORD-001',
          'items': [
            {
              'id': testItem1Id,
              'order_id': testOrderId,
              'item_type_id': testItemTypeId,
              'service_id': testServiceId,
              'pricing_type': 'per_piece',
              'quantity': 1.0,
              'unit_price': 1500,
              'calculated_total': 1500,
            }
          ],
        },
        serverVersion: 2,
        createdAt: DateTime.now(),
      );

      // Apply first time
      await applier.applyBatch([editChange]);
      final countFirst = (await (db.select(db.orderItems)
                ..where((t) => t.orderId.equals(testOrderId)))
              .get())
          .length;
      expect(countFirst, equals(1));

      // Re-apply same change
      await applier.applyBatch([editChange]);
      final countSecond = (await (db.select(db.orderItems)
                ..where((t) => t.orderId.equals(testOrderId)))
              .get())
          .length;
      expect(countSecond, equals(1));
    });

    test('F. Zero outbox on remote apply: Device B must have 0 newly-created outbox operations', () async {
      // 1. Verify initial outbox is empty
      final outboxBefore = await syncOperationsDao.getPendingOperations();
      expect(outboxBefore, isEmpty);

      // 2. Apply remote edit
      final editChange = SyncChangeDto(
        sequence: 16,
        operationId: 'op-edit-007',
        entityType: 'order',
        entityId: testOrderId,
        operationType: 'edit',
        payload: {
          'id': testOrderId,
          'order_number': 'ORD-001',
          'items': [
            {
              'id': testItem1Id,
              'order_id': testOrderId,
              'item_type_id': testItemTypeId,
              'service_id': testServiceId,
              'pricing_type': 'per_piece',
              'quantity': 2.0,
              'unit_price': 1500,
              'calculated_total': 3000,
            }
          ],
        },
        serverVersion: 2,
        createdAt: DateTime.now(),
      );

      await applier.applyBatch([editChange]);

      // 3. Verify outbox remains strictly empty
      final outboxAfter = await syncOperationsDao.getPendingOperations();
      expect(outboxAfter, isEmpty, reason: 'Remote reconciliation must NEVER enqueue outbox operations');
    });

    test('G. Storage semantics: deactivates active local storage records for removed items', () async {
      final now = DateTime.now();

      // Seed a storage location
      await db.into(db.storageLocations).insert(
            app_db.StorageLocationsCompanion.insert(
              id: 'loc-1',
              name: 'رف 1',
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Seed an active storage record for item-2 (removed item)
      await db.into(db.storageRecords).insert(
            app_db.StorageRecordsCompanion.insert(
              id: 'sr-1',
              orderItemId: testItem2Id,
              storageLocationId: 'loc-1',
              isActive: const Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Seed an active storage record for item-1 (unrelated surviving item)
      await db.into(db.storageRecords).insert(
            app_db.StorageRecordsCompanion.insert(
              id: 'sr-unrelated-1',
              orderItemId: testItem1Id,
              storageLocationId: 'loc-1',
              isActive: const Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final activeBefore = await storageRecordsDao.getActiveRecordForOrderItem(testItem2Id);
      expect(activeBefore, isNotNull);

      // Incoming edit removes item-2, retains item-1
      final editChange = SyncChangeDto(
        sequence: 17,
        operationId: 'op-edit-008',
        entityType: 'order',
        entityId: testOrderId,
        operationType: 'edit',
        payload: {
          'id': testOrderId,
          'status': 'processing',
          'items': [
            {
              'id': testItem1Id,
              'order_id': testOrderId,
              'item_type_id': testItemTypeId,
              'service_id': testServiceId,
              'pricing_type': 'per_piece',
              'quantity': 1.0,
              'unit_price': 1500,
              'calculated_total': 1500,
            }
          ],
        },
        serverVersion: 2,
        createdAt: now,
      );

      await applier.applyBatch([editChange]);

      // Removed item-2 must no longer have active storage record
      final activeAfter = await storageRecordsDao.getActiveRecordForOrderItem(testItem2Id);
      expect(activeAfter, isNull);

      // Removed item-2 itself must be removed
      final item2InDb = await (db.select(db.orderItems)
            ..where((t) => t.id.equals(testItem2Id)))
          .getSingleOrNull();
      expect(item2InDb, isNull);

      // Unrelated storage record for item-1 MUST be completely preserved and remain active
      final unrelatedInDb = await (db.select(db.storageRecords)
            ..where((t) => t.id.equals('sr-unrelated-1')))
          .getSingle();
      expect(unrelatedInDb.isActive, isTrue, reason: 'Unrelated storage records must not be deleted or deactivated');
    });

    test('H. Status/readiness: authoritative incoming status is persisted accurately', () async {
      final editChange = SyncChangeDto(
        sequence: 18,
        operationId: 'op-edit-009',
        entityType: 'order',
        entityId: testOrderId,
        operationType: 'edit',
        payload: {
          'id': testOrderId,
          'status': 'ready',
          'items': [
            {
              'id': testItem1Id,
              'order_id': testOrderId,
              'item_type_id': testItemTypeId,
              'service_id': testServiceId,
              'pricing_type': 'per_piece',
              'quantity': 1.0,
              'unit_price': 1500,
              'calculated_total': 1500,
            }
          ],
        },
        serverVersion: 2,
        createdAt: DateTime.now(),
      );

      await applier.applyBatch([editChange]);

      final updatedOrder = await ordersDao.getOrderById(testOrderId);
      expect(updatedOrder!.status, equals('ready'));
    });

    test('I. Customer change sync: edited customer reaches Device B correctly and produces NO duplicate outbox operations', () async {
      const newCustId = 'cust-200-device-b';
      final now = DateTime.now();

      // Seed new customer on Device B
      await db.into(db.customers).insert(
            app_db.CustomersCompanion.insert(
              id: newCustId,
              name: 'عميل منقول له الطلب',
              phone: '01055554444',
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Verify no outbox operations exist before sync
      final opsBefore = await syncOperationsDao.getPendingOperations();
      expect(opsBefore, isEmpty);

      final editCustChange = SyncChangeDto(
        sequence: 19,
        operationId: 'op-edit-cust-010',
        entityType: 'order',
        entityId: testOrderId,
        operationType: 'edit',
        payload: {
          'id': testOrderId,
          'customer_id': newCustId,
          'customer_name_snapshot': 'عميل منقول له الطلب',
          'customer_phone_snapshot': '01055554444',
          'items': [
            {
              'id': testItem1Id,
              'order_id': testOrderId,
              'item_type_id': testItemTypeId,
              'service_id': testServiceId,
              'pricing_type': 'per_piece',
              'quantity': 1.0,
              'unit_price': 1500,
              'calculated_total': 1500,
            }
          ],
        },
        serverVersion: 3,
        createdAt: now,
      );

      await applier.applyBatch([editCustChange]);

      final orderOnB = await ordersDao.getOrderById(testOrderId);
      expect(orderOnB!.customerId, equals(newCustId));
      expect(orderOnB.customerNameSnapshot, equals('عميل منقول له الطلب'));
      expect(orderOnB.customerPhoneSnapshot, equals('01055554444'));

      // Invariant: Remote changes must NEVER generate local outbox operations on Device B
      final opsAfter = await syncOperationsDao.getPendingOperations();
      expect(opsAfter, isEmpty);
    });
  });
}
