import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/storage_locations_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart' as app_db;
import 'package:laundry_management/data/local/database/dev_test_data.dart';
import 'package:laundry_management/data/repositories/order_repository_impl.dart';
import 'package:laundry_management/data/repositories/storage_location_repository_impl.dart';
import 'package:laundry_management/data/repositories/storage_repository_impl.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/application/use_cases/store_order_items_use_case.dart';

void main() {
  late app_db.AppDatabase db;
  late StorageRecordsDao storageRecordsDao;
  late StorageLocationsDao storageLocationsDao;
  late SyncOperationsDao syncOperationsDao;
  late OrdersDao ordersDao;
  late StorageRepositoryImpl repository;

  setUp(() async {
    db = app_db.AppDatabase(NativeDatabase.memory());
    await DevTestData.seedDevData(db);

    storageRecordsDao = StorageRecordsDao(db);
    storageLocationsDao = StorageLocationsDao(db);
    syncOperationsDao = SyncOperationsDao(db);
    ordersDao = OrdersDao(db);

    repository = StorageRepositoryImpl(
      storageRecordsDao: storageRecordsDao,
      storageLocationsDao: storageLocationsDao,
      syncOperationsDao: syncOperationsDao,
      ordersDao: ordersDao,
      db: db,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('StorageRepositoryImpl — Queries, Search, Filters & Pagination', () {
    test('17. getItemsRequiringStorageWithDetails returns unstored items for active orders', () async {
      final items = await repository.getItemsRequiringStorageWithDetails(limit: 50, offset: 0);
      expect(items, isNotEmpty);
      for (final item in items) {
        expect(item.activeRecord, isNull);
        expect(item.storageLocation, isNull);
        expect(item.isStored, false);
      }
    });

    test('18. getCurrentStorageItems returns items with active storage records', () async {
      final items = await repository.getCurrentStorageItems(limit: 50, offset: 0);
      expect(items, isNotEmpty);
      for (final item in items) {
        expect(item.activeRecord, isNotNull);
        expect(item.activeRecord!.isActive, true);
        expect(item.storageLocation, isNotNull);
        expect(item.isStored, true);
      }
    });

    test('19. Search filters items by order number, customer name, and customer phone', () async {
      // Find an unstored item to test search
      final allUnstored = await repository.getItemsRequiringStorageWithDetails();
      final target = allUnstored.first;

      // Search by order number
      final byOrderNum = await repository.getItemsRequiringStorageWithDetails(
        query: target.orderNumber,
      );
      expect(byOrderNum.any((i) => i.orderItem.id == target.orderItem.id), true);

      // Search by customer name
      final byCustName = await repository.getItemsRequiringStorageWithDetails(
        query: target.customerName,
      );
      expect(byCustName.any((i) => i.orderItem.id == target.orderItem.id), true);

      // Search by customer phone
      final byCustPhone = await repository.getItemsRequiringStorageWithDetails(
        query: target.customerPhone,
      );
      expect(byCustPhone.any((i) => i.orderItem.id == target.orderItem.id), true);

      // Non-matching query returns empty
      final noMatches = await repository.getItemsRequiringStorageWithDetails(
        query: 'ZZZ_NON_EXISTENT_QUERY_999',
      );
      expect(noMatches, isEmpty);
    });

    test('20. Location filter returns only items in the specified location', () async {
      final currentItems = await repository.getCurrentStorageItems();
      expect(currentItems, isNotEmpty);
      final targetLocationId = currentItems.first.storageLocation!.id;

      final filtered = await repository.getCurrentStorageItems(
        storageLocationId: targetLocationId,
      );
      expect(filtered, isNotEmpty);
      for (final item in filtered) {
        expect(item.storageLocation!.id, targetLocationId);
      }
    });

    test('21. Pagination limit and offset work correctly', () async {
      final page1 = await repository.getItemsRequiringStorageWithDetails(limit: 2, offset: 0);
      final page2 = await repository.getItemsRequiringStorageWithDetails(limit: 2, offset: 2);

      expect(page1.length, lessThanOrEqualTo(2));
      if (page1.isNotEmpty && page2.isNotEmpty) {
        expect(page1.first.orderItem.id, isNot(equals(page2.first.orderItem.id)));
      }
    });

    test('22. Count queries accurately reflect total matching items', () async {
      final totalRequiring = await repository.countItemsRequiringStorage();
      final listRequiring = await repository.getItemsRequiringStorageWithDetails(limit: 500);
      expect(totalRequiring, listRequiring.length);

      final totalCurrent = await repository.countCurrentStorageItems();
      final listCurrent = await repository.getCurrentStorageItems(limit: 500);
      expect(totalCurrent, listCurrent.length);
    });

    test('Filter by expectedPickupDate and itemTypeId', () async {
      final all = await repository.getItemsRequiringStorageWithDetails();
      final target = all.first;

      final filtered = await repository.getItemsRequiringStorageWithDetails(
        itemTypeId: target.orderItem.itemTypeId,
        expectedPickupDate: target.expectedPickupDate,
      );
      expect(filtered, isNotEmpty);
      for (final item in filtered) {
        expect(item.orderItem.itemTypeId, target.orderItem.itemTypeId);
        expect(item.expectedPickupDate, target.expectedPickupDate);
      }
    });
  });

  group('StorageRepositoryImpl — Store, Move & Unstore Atomic Operations', () {
    test('Store valid item creates active StorageRecord and logs SyncOperation', () async {
      final unstored = await repository.getItemsRequiringStorageWithDetails();
      final target = unstored.first;

      // Find compatible location
      final compatible = await storageLocationsDao.getCompatibleLocationsForItemType(
        target.orderItem.itemTypeId,
      );
      final loc = compatible.first;

      final record = await repository.storeItem(
        orderItemId: target.orderItem.id,
        storageLocationId: loc.id,
      );

      expect(record.isActive, true);
      expect(record.orderItemId, target.orderItem.id);
      expect(record.storageLocationId, loc.id);

      // Verify sync operation was recorded
      final syncOps = await syncOperationsDao.getPendingOperations();
      expect(
        syncOps.any((op) => op.entityId == record.id && op.operationType == 'create'),
        true,
      );

      // Verify item now appears in current storage and not in requiring storage
      final active = await repository.getActiveRecordForOrderItem(target.orderItem.id);
      expect(active, isNotNull);
      expect(active!.storageLocationId, loc.id);

      final requiringAfter = await repository.getItemsRequiringStorageWithDetails();
      expect(requiringAfter.any((i) => i.orderItem.id == target.orderItem.id), false);
    });

    test('Store item rejects already stored item', () async {
      final current = await repository.getCurrentStorageItems();
      final target = current.first;

      expect(
        () => repository.storeItem(
          orderItemId: target.orderItem.id,
          storageLocationId: target.storageLocation!.id,
        ),
        throwsA(isA<BusinessRuleFailure>()),
      );
    });

    test('25. Atomic Move: moves item and deactivates previous active record', () async {
      final current = await repository.getCurrentStorageItems();
      final target = current.first;
      final oldLocationId = target.storageLocation!.id;

      // Find different compatible location
      final compatible = await storageLocationsDao.getCompatibleLocationsForItemType(
        target.orderItem.itemTypeId,
      );
      final newLoc = compatible.firstWhere((l) => l.id != oldLocationId);

      final newRecord = await repository.moveItem(
        orderItemId: target.orderItem.id,
        newStorageLocationId: newLoc.id,
      );

      expect(newRecord.isActive, true);
      expect(newRecord.storageLocationId, newLoc.id);

      // Verify old record is inactive
      final allRecordsForOldLoc = await storageRecordsDao.getActiveRecordsForLocation(oldLocationId);
      expect(allRecordsForOldLoc.any((r) => r.orderItemId == target.orderItem.id), false);

      // Verify only 1 active record exists for this item
      final active = await repository.getActiveRecordForOrderItem(target.orderItem.id);
      expect(active, isNotNull);
      expect(active!.storageLocationId, newLoc.id);
      expect(active.id, newRecord.id);
    });

    test('Move rejects moving to same storage location with BusinessRuleFailure', () async {
      final current = await repository.getCurrentStorageItems();
      final target = current.first;

      expect(
        () => repository.moveItem(
          orderItemId: target.orderItem.id,
          newStorageLocationId: target.storageLocation!.id,
        ),
        throwsA(
          isA<BusinessRuleFailure>().having(
            (e) => e.message,
            'message',
            contains('Cannot move item to the same storage location'),
          ),
        ),
      );
    });

    test('26. Atomic Bulk Storage stores multiple items atomically', () async {
      final unstored = await repository.getItemsRequiringStorageWithDetails();
      // Pick 2 unstored items of same type
      final item1 = unstored[0];
      final item2 = unstored.firstWhere(
        (i) => i.orderItem.itemTypeId == item1.orderItem.itemTypeId && i.orderItem.id != item1.orderItem.id,
        orElse: () => unstored[1],
      );

      final compatible = await storageLocationsDao.getCompatibleLocationsForItemType(
        item1.orderItem.itemTypeId,
      );
      final loc = compatible.first;

      await repository.bulkStoreItems(
        orderItemIds: [item1.orderItem.id, item2.orderItem.id],
        storageLocationId: loc.id,
      );

      final active1 = await repository.getActiveRecordForOrderItem(item1.orderItem.id);
      final active2 = await repository.getActiveRecordForOrderItem(item2.orderItem.id);

      expect(active1, isNotNull);
      expect(active2, isNotNull);
      expect(active1!.storageLocationId, loc.id);
      expect(active2!.storageLocationId, loc.id);
    });

    test('27. Unstore persistence: deactivates active record, item returns to requiring storage', () async {
      final current = await repository.getCurrentStorageItems();
      final target = current.first;

      await repository.unstoreItem(target.orderItem.id);

      // Verify active record is gone
      final activeAfter = await repository.getActiveRecordForOrderItem(target.orderItem.id);
      expect(activeAfter, isNull);

      // Verify item returned to requiring storage
      final requiring = await repository.getItemsRequiringStorageWithDetails();
      expect(requiring.any((i) => i.orderItem.id == target.orderItem.id), true);

      // Verify item left current storage
      final currentAfter = await repository.getCurrentStorageItems();
      expect(currentAfter.any((i) => i.orderItem.id == target.orderItem.id), false);

      // Verify sync operation logged
      final syncOps = await syncOperationsDao.getPendingOperations();
      expect(
        syncOps.any((op) => op.entityId == target.activeRecord!.id && op.operationType == 'unstore'),
        true,
      );
    });

    test('Unstore rejects already unstored item with BusinessRuleFailure', () async {
      final unstored = await repository.getItemsRequiringStorageWithDetails();
      final target = unstored.first;

      expect(
        () => repository.unstoreItem(target.orderItem.id),
        throwsA(
          isA<BusinessRuleFailure>().having(
            (e) => e.message,
            'message',
            contains('Item has no active storage record to unstore'),
          ),
        ),
      );
    });

    test('Unstore from Ready order automatically reverts Order to Processing, and storing it again makes Order Ready', () async {
      final orderRepo = OrderRepositoryImpl(
        ordersDao: ordersDao,
        syncOperationsDao: syncOperationsDao,
        storageRecordsDao: storageRecordsDao,
        db: db,
      );
      final storageLocationRepo = StorageLocationRepositoryImpl(
        storageLocationsDao: storageLocationsDao,
        storageRecordsDao: storageRecordsDao,
        syncOperationsDao: syncOperationsDao,
        db: db,
      );
      final storeUseCase = StoreOrderItemsUseCase(
        orderRepository: orderRepo,
        storageRepository: repository,
        storageLocationRepository: storageLocationRepo,
      );

      // Find a Ready order with all items stored in DevTestData (e.g. 26-004)
      final orders = await ordersDao.getOrders(status: OrderStatus.ready.name);
      expect(orders, isNotEmpty);
      final readyOrder = orders.first;
      final orderItems = await ordersDao.getOrderItemsRaw(readyOrder.id);
      expect(orderItems, isNotEmpty);

      // Ensure all items are stored initially
      final allInitiallyStored = await repository.areAllOrderItemsStored(readyOrder.id);
      expect(allInitiallyStored, isTrue);

      final firstItemId = orderItems.first.id;
      final activeRecord = await repository.getActiveRecordForOrderItem(firstItemId);
      expect(activeRecord, isNotNull);

      // 1. Unstore one item from the Ready order
      await repository.unstoreItem(firstItemId);

      // 2. StorageRecord becomes inactive
      final recordAfter = await repository.getActiveRecordForOrderItem(firstItemId);
      expect(recordAfter, isNull);

      // 3. Order status automatically transitions Ready -> Processing
      final orderAfterUnstore = await ordersDao.getOrderById(readyOrder.id);
      expect(orderAfterUnstore!.status, OrderStatus.processing.name);

      // 4. Sync operations recorded
      final syncOps = await syncOperationsDao.getPendingOperations();
      expect(
        syncOps.any((op) => op.entityId == activeRecord!.id && op.operationType == 'unstore'),
        isTrue,
      );
      expect(
        syncOps.any((op) => op.entityId == readyOrder.id && op.operationType == 'update' && op.payload == 'unstore'),
        isTrue,
      );

      // 5. Item appears in "Items Requiring Storage"
      final requiring = await repository.getItemsRequiringStorageWithDetails();
      expect(requiring.any((i) => i.orderItem.id == firstItemId), isTrue);

      // 6. Store the item again
      final compatibleLocs = await storageLocationRepo.getCompatibleLocationsForItemType(orderItems.first.itemTypeId);
      final storeResult = await storeUseCase.execute(StoreOrderItemsInput(
        orderId: readyOrder.id,
        orderItemIds: [firstItemId],
        storageLocationId: compatibleLocs.first.id,
      ));

      // 7. Order becomes Ready again!
      expect(storeResult.allStored, isTrue);
      expect(storeResult.order.status, OrderStatus.ready);

      final finalOrder = await ordersDao.getOrderById(readyOrder.id);
      expect(finalOrder!.status, OrderStatus.ready.name);
    });

    test('Unstore from Processing order preserves Processing status', () async {
      // Find a Processing order with at least one stored item
      final currentStored = await repository.getCurrentStorageItems();
      final processingItem = currentStored.firstWhere((i) => i.orderStatus == OrderStatus.processing);

      await repository.unstoreItem(processingItem.orderItem.id);

      // Record deactivated
      final recordAfter = await repository.getActiveRecordForOrderItem(processingItem.orderItem.id);
      expect(recordAfter, isNull);

      // Order status remains Processing
      final orderAfter = await ordersDao.getOrderById(processingItem.orderId);
      expect(orderAfter!.status, OrderStatus.processing.name);
    });

    test('Unstore from Completed or Cancelled order throws BusinessRuleFailure', () async {
      final currentStored = await repository.getCurrentStorageItems();
      final targetItem = currentStored.first;

      // Simulate order set to completed
      await ordersDao.updateOrderStatus(
        orderId: targetItem.orderId,
        status: OrderStatus.completed.name,
        updatedAt: DateTime.now(),
      );

      expect(
        () => repository.unstoreItem(targetItem.orderItem.id),
        throwsA(
          isA<BusinessRuleFailure>().having(
            (e) => e.message,
            'message',
            contains('Cannot unstore items from a completed order'),
          ),
        ),
      );

      // Simulate order set to cancelled
      await ordersDao.updateOrderStatus(
        orderId: targetItem.orderId,
        status: OrderStatus.cancelled.name,
        updatedAt: DateTime.now(),
      );

      expect(
        () => repository.unstoreItem(targetItem.orderItem.id),
        throwsA(
          isA<BusinessRuleFailure>().having(
            (e) => e.message,
            'message',
            contains('Cannot unstore items from a cancelled order'),
          ),
        ),
      );
    });
  });
}
