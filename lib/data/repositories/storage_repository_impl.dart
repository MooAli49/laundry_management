import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/carpet_item_data.dart';
import '../../domain/entities/order_item.dart';
import '../../domain/entities/storage_item.dart';
import '../../domain/entities/storage_location.dart';
import '../../domain/entities/storage_record.dart';
import '../../domain/enums/order_status.dart';
import '../../domain/enums/pricing_type.dart';
import '../../domain/repositories/storage_repository.dart';
import '../../domain/value_objects/money.dart';
import '../../domain/value_objects/order_date.dart';
import '../local/daos/storage_locations_dao.dart';
import '../local/daos/storage_records_dao.dart';
import '../local/daos/sync_operations_dao.dart';
import '../local/database/app_database.dart' as app_db;

class StorageRepositoryImpl implements StorageRepository {
  final StorageRecordsDao _storageRecordsDao;
  final StorageLocationsDao _storageLocationsDao;
  final SyncOperationsDao _syncOperationsDao;
  final app_db.AppDatabase _db;

  StorageRepositoryImpl({
    required StorageRecordsDao storageRecordsDao,
    required StorageLocationsDao storageLocationsDao,
    required SyncOperationsDao syncOperationsDao,
    required app_db.AppDatabase db,
  })  : _storageRecordsDao = storageRecordsDao,
        _storageLocationsDao = storageLocationsDao,
        _syncOperationsDao = syncOperationsDao,
        _db = db;

  @override
  Future<StorageRecord> storeItem({
    required String orderItemId,
    required String storageLocationId,
  }) async {
    try {
      return await _db.transaction(() async {
        final location = await _storageLocationsDao.getLocationById(storageLocationId);
        if (location == null) {
          throw const ValidationFailure('Storage location not found');
        }
        if (!location.isActive) {
          throw const BusinessRuleFailure('Cannot store item in an inactive storage location');
        }

        final activeRecord = await _storageRecordsDao.getActiveRecordForOrderItem(orderItemId);
        if (activeRecord != null) {
          throw const BusinessRuleFailure(
            'Item already has an active storage record. Use moveItem to change locations.',
          );
        }

        final orderItem = await (_db.select(_db.orderItems)..where((t) => t.id.equals(orderItemId))).getSingleOrNull();
        if (orderItem != null) {
          final compatibleLocations = await _storageLocationsDao.getCompatibleLocationsForItemType(orderItem.itemTypeId);
          final isCompatible = compatibleLocations.any((loc) => loc.id == storageLocationId);
          if (!isCompatible) {
            throw IncompatibleStorageLocationFailure(
              storageLocationId: storageLocationId,
              itemTypeId: orderItem.itemTypeId,
            );
          }
        }

        final now = DateTime.now();
        final newId = const Uuid().v4();
        await _storageRecordsDao.insertRecord(
          app_db.StorageRecordsCompanion(
            id: Value(newId),
            orderItemId: Value(orderItemId),
            storageLocationId: Value(storageLocationId),
            isActive: const Value(true),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

        await _syncOperationsDao.recordOperation(
          entityType: 'storage_record',
          entityId: newId,
          operationType: 'create',
        );

        return StorageRecord(
          id: newId,
          orderItemId: orderItemId,
          storageLocationId: storageLocationId,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );
      });
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<StorageRecord> moveItem({
    required String orderItemId,
    required String newStorageLocationId,
  }) async {
    try {
      return await _db.transaction(() async {
        final newLocation = await _storageLocationsDao.getLocationById(newStorageLocationId);
        if (newLocation == null) {
          throw const ValidationFailure('New storage location not found');
        }
        if (!newLocation.isActive) {
          throw const BusinessRuleFailure('Cannot move item to an inactive storage location');
        }

        final activeRecord = await _storageRecordsDao.getActiveRecordForOrderItem(orderItemId);
        if (activeRecord == null) {
          throw const BusinessRuleFailure('Item has no active storage location to move from');
        }

        if (activeRecord.storageLocationId == newStorageLocationId) {
          throw const BusinessRuleFailure('Cannot move item to the same storage location');
        }

        final orderItem = await (_db.select(_db.orderItems)..where((t) => t.id.equals(orderItemId))).getSingleOrNull();
        if (orderItem != null) {
          final compatibleLocations = await _storageLocationsDao.getCompatibleLocationsForItemType(orderItem.itemTypeId);
          final isCompatible = compatibleLocations.any((loc) => loc.id == newStorageLocationId);
          if (!isCompatible) {
            throw IncompatibleStorageLocationFailure(
              storageLocationId: newStorageLocationId,
              itemTypeId: orderItem.itemTypeId,
            );
          }
        }

        final now = DateTime.now();
        // Deactivate old active record
        await _storageRecordsDao.deactivateActiveRecord(orderItemId, now);

        // Insert new active record
        final newId = const Uuid().v4();
        await _storageRecordsDao.insertRecord(
          app_db.StorageRecordsCompanion(
            id: Value(newId),
            orderItemId: Value(orderItemId),
            storageLocationId: Value(newStorageLocationId),
            isActive: const Value(true),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

        await _syncOperationsDao.recordOperation(
          entityType: 'storage_record',
          entityId: newId,
          operationType: 'move',
        );

        return StorageRecord(
          id: newId,
          orderItemId: orderItemId,
          storageLocationId: newStorageLocationId,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );
      });
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<void> bulkStoreItems({
    required List<String> orderItemIds,
    required String storageLocationId,
  }) async {
    try {
      await _db.transaction(() async {
        for (final itemId in orderItemIds) {
          await storeItem(
            orderItemId: itemId,
            storageLocationId: storageLocationId,
          );
        }
      });
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<void> unstoreItem(String orderItemId) async {
    try {
      await _db.transaction(() async {
        final item = await (_db.select(_db.orderItems)..where((t) => t.id.equals(orderItemId))).getSingleOrNull();
        if (item == null) {
          throw const ValidationFailure('Order item not found');
        }

        final activeRecord = await _storageRecordsDao.getActiveRecordForOrderItem(orderItemId);
        if (activeRecord == null) {
          throw const BusinessRuleFailure('Item has no active storage record to unstore');
        }

        final now = DateTime.now();
        await _storageRecordsDao.deactivateActiveRecord(orderItemId, now);

        await _syncOperationsDao.recordOperation(
          entityType: 'storage_record',
          entityId: activeRecord.id,
          operationType: 'unstore',
        );
      });
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<StorageRecord?> getActiveRecordForOrderItem(String orderItemId) async {
    try {
      final row = await _storageRecordsDao.getActiveRecordForOrderItem(orderItemId);
      return row != null ? _mapToDomain(row) : null;
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<List<StorageRecord>> getActiveRecordsForLocation(String storageLocationId) async {
    try {
      final rows = await _storageRecordsDao.getActiveRecordsForLocation(storageLocationId);
      return rows.map(_mapToDomain).toList();
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<List<OrderItem>> getItemsRequiringStorage({int limit = 50, int offset = 0}) async {
    try {
      final rows = await _storageRecordsDao.getItemsRequiringStorage(
        limit: limit,
        offset: offset,
      );
      return rows.map((r) => _mapOrderItemToDomain(r.item, r.carpet)).toList();
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<List<StorageItem>> getItemsRequiringStorageWithDetails({
    String? query,
    String? orderId,
    String? itemTypeId,
    String? serviceId,
    OrderDate? expectedPickupDate,
    DateTime? orderReceivedDate,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final rows = await _storageRecordsDao.getItemsRequiringStorageWithDetails(
        query: query,
        orderId: orderId,
        itemTypeId: itemTypeId,
        serviceId: serviceId,
        expectedPickupDate: expectedPickupDate?.toDateTime(),
        orderReceivedDate: orderReceivedDate,
        limit: limit,
        offset: offset,
      );
      return rows.map(_mapRowToStorageItem).toList();
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<int> countItemsRequiringStorage({
    String? query,
    String? orderId,
    String? itemTypeId,
    String? serviceId,
    OrderDate? expectedPickupDate,
    DateTime? orderReceivedDate,
  }) async {
    try {
      return await _storageRecordsDao.countItemsRequiringStorageWithDetails(
        query: query,
        orderId: orderId,
        itemTypeId: itemTypeId,
        serviceId: serviceId,
        expectedPickupDate: expectedPickupDate?.toDateTime(),
        orderReceivedDate: orderReceivedDate,
      );
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<List<StorageItem>> getCurrentStorageItems({
    String? query,
    String? orderId,
    String? storageLocationId,
    String? itemTypeId,
    String? serviceId,
    OrderDate? expectedPickupDate,
    DateTime? orderReceivedDate,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final rows = await _storageRecordsDao.getCurrentStorageItemsWithDetails(
        query: query,
        orderId: orderId,
        storageLocationId: storageLocationId,
        itemTypeId: itemTypeId,
        serviceId: serviceId,
        expectedPickupDate: expectedPickupDate?.toDateTime(),
        orderReceivedDate: orderReceivedDate,
        limit: limit,
        offset: offset,
      );
      return rows.map(_mapRowToStorageItem).toList();
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<int> countCurrentStorageItems({
    String? query,
    String? orderId,
    String? storageLocationId,
    String? itemTypeId,
    String? serviceId,
    OrderDate? expectedPickupDate,
    DateTime? orderReceivedDate,
  }) async {
    try {
      return await _storageRecordsDao.countCurrentStorageItemsWithDetails(
        query: query,
        orderId: orderId,
        storageLocationId: storageLocationId,
        itemTypeId: itemTypeId,
        serviceId: serviceId,
        expectedPickupDate: expectedPickupDate?.toDateTime(),
        orderReceivedDate: orderReceivedDate,
      );
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Stream<List<StorageRecord>> watchActiveRecordsForLocation(String storageLocationId) {
    try {
      return _storageRecordsDao.watchActiveRecordsForLocation(storageLocationId).map(
            (rows) => rows.map(_mapToDomain).toList(),
          );
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<bool> areAllOrderItemsStored(String orderId) async {
    try {
      return await _storageRecordsDao.areAllOrderItemsStored(orderId);
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  StorageItem _mapRowToStorageItem(StorageItemRow row) {
    return StorageItem(
      orderItem: _mapOrderItemToDomain(row.item, row.carpet),
      orderId: row.order.id,
      orderNumber: row.order.orderNumber,
      customerName: row.order.customerNameSnapshot,
      customerPhone: row.order.customerPhoneSnapshot,
      orderStatus: OrderStatus.values.byName(row.order.status),
      expectedPickupDate: OrderDate.fromDate(row.order.expectedPickupDate),
      orderCreatedAt: row.order.createdAt,
      activeRecord: row.record != null ? _mapToDomain(row.record!) : null,
      storageLocation: row.location != null ? _mapLocationToDomain(row.location!) : null,
    );
  }

  StorageLocation _mapLocationToDomain(app_db.StorageLocation row) {
    return StorageLocation(
      id: row.id,
      name: row.name,
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  StorageRecord _mapToDomain(app_db.StorageRecord row) {
    return StorageRecord(
      id: row.id,
      orderItemId: row.orderItemId,
      storageLocationId: row.storageLocationId,
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  OrderItem _mapOrderItemToDomain(
    app_db.OrderItem item,
    app_db.OrderItemCarpet? carpet,
  ) {
    CarpetItemData? carpetData;
    if (carpet != null) {
      carpetData = CarpetItemData(
        id: carpet.id,
        orderItemId: carpet.orderItemId,
        carpetSizeId: carpet.carpetSizeId,
        length: carpet.length,
        width: carpet.width,
        area: carpet.area,
        createdAt: carpet.createdAt,
        updatedAt: carpet.updatedAt,
      );
    }

    return OrderItem(
      id: item.id,
      orderId: item.orderId,
      itemTypeId: item.itemTypeId,
      itemDefinitionId: item.itemDefinitionId,
      serviceId: item.serviceId,
      itemTypeNameSnapshot: item.itemTypeNameSnapshot,
      itemDefinitionNameSnapshot: item.itemDefinitionNameSnapshot,
      serviceNameSnapshot: item.serviceNameSnapshot,
      pricingType: PricingType.values.byName(item.pricingType),
      quantity: item.quantity,
      unitPrice: Money.fromPiastres(item.unitPrice),
      calculatedTotal: Money.fromPiastres(item.calculatedTotal),
      notes: item.notes,
      carpetData: carpetData,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );
  }
}
