import 'package:drift/drift.dart';

import '../database/app_database.dart' as app_db;

typedef StorageItemRow = ({
  app_db.OrderItem item,
  app_db.Order order,
  app_db.OrderItemCarpet? carpet,
  app_db.StorageRecord? record,
  app_db.StorageLocation? location,
});

class StorageRecordsDao extends DatabaseAccessor<app_db.AppDatabase> {
  StorageRecordsDao(super.attachedDatabase);

  app_db.AppDatabase get db => attachedDatabase;

  Future<void> insertRecord(app_db.StorageRecordsCompanion record) async {
    await into(db.storageRecords).insert(record);
  }

  Future<void> deactivateActiveRecord(String orderItemId, DateTime updatedAt) async {
    await (update(db.storageRecords)
          ..where((t) => t.orderItemId.equals(orderItemId) & t.isActive.equals(true)))
        .write(
      app_db.StorageRecordsCompanion(
        isActive: const Value(false),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  Future<app_db.StorageRecord?> getActiveRecordForOrderItem(String orderItemId) async {
    return (select(db.storageRecords)
          ..where((t) => t.orderItemId.equals(orderItemId) & t.isActive.equals(true)))
        .getSingleOrNull();
  }

  Future<List<app_db.StorageRecord>> getActiveRecordsForLocation(String storageLocationId) async {
    return (select(db.storageRecords)
          ..where(
            (t) => t.storageLocationId.equals(storageLocationId) & t.isActive.equals(true),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Stream<List<app_db.StorageRecord>> watchActiveRecordsForLocation(String storageLocationId) {
    return (select(db.storageRecords)
          ..where(
            (t) => t.storageLocationId.equals(storageLocationId) & t.isActive.equals(true),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<bool> areAllOrderItemsStored(String orderId) async {
    // Total items for order
    final totalQuery = selectOnly(db.orderItems)
      ..where(db.orderItems.orderId.equals(orderId))
      ..addColumns([db.orderItems.id.count()]);
    final totalCount = await totalQuery.map((row) => row.read(db.orderItems.id.count())).getSingle() ?? 0;

    if (totalCount == 0) return false;

    // Stored active items for order
    final activeJoin = select(db.orderItems).join([
      innerJoin(
        db.storageRecords,
        db.storageRecords.orderItemId.equalsExp(db.orderItems.id) &
            db.storageRecords.isActive.equals(true),
      ),
    ])..where(db.orderItems.orderId.equals(orderId));

    final activeRows = await activeJoin.get();
    return activeRows.length == totalCount;
  }

  Future<List<({app_db.OrderItem item, app_db.OrderItemCarpet? carpet})>> getItemsRequiringStorage({
    int limit = 50,
    int offset = 0,
  }) async {
    final activeStorageSubquery = selectOnly(db.storageRecords)
      ..where(
        db.storageRecords.orderItemId.equalsExp(db.orderItems.id) &
            db.storageRecords.isActive.equals(true),
      )
      ..addColumns([db.storageRecords.id]);

    final query = select(db.orderItems).join([
      innerJoin(db.orders, db.orders.id.equalsExp(db.orderItems.orderId)),
      leftOuterJoin(
        db.orderItemCarpets,
        db.orderItemCarpets.orderItemId.equalsExp(db.orderItems.id),
      ),
    ])
      ..where(
        (db.orders.status.equals('processing') | db.orders.status.equals('ready')) &
            notExistsQuery(activeStorageSubquery),
      )
      ..orderBy([OrderingTerm.asc(db.orders.createdAt)])
      ..limit(limit, offset: offset);

    final rows = await query.get();
    return rows.map((row) {
      return (
        item: row.readTable(db.orderItems),
        carpet: row.readTableOrNull(db.orderItemCarpets),
      );
    }).toList();
  }

  Expression<bool> _buildRequiringStoragePredicate({
    String? query,
    String? orderId,
    String? itemTypeId,
    String? serviceId,
    DateTime? expectedPickupDate,
    DateTime? orderReceivedDate,
  }) {
    final activeStorageSubquery = selectOnly(db.storageRecords)
      ..where(
        db.storageRecords.orderItemId.equalsExp(db.orderItems.id) &
            db.storageRecords.isActive.equals(true),
      )
      ..addColumns([db.storageRecords.id]);

    Expression<bool> predicate =
        (db.orders.status.equals('processing') | db.orders.status.equals('ready')) &
        notExistsQuery(activeStorageSubquery);

    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim()}%';
      predicate = predicate &
          (db.orders.orderNumber.like(q) |
              db.orders.customerNameSnapshot.like(q) |
              db.orders.customerPhoneSnapshot.like(q));
    }

    if (orderId != null && orderId.trim().isNotEmpty) {
      predicate = predicate & db.orders.id.equals(orderId);
    }

    if (itemTypeId != null && itemTypeId.trim().isNotEmpty) {
      predicate = predicate & db.orderItems.itemTypeId.equals(itemTypeId);
    }

    if (serviceId != null && serviceId.trim().isNotEmpty) {
      predicate = predicate & db.orderItems.serviceId.equals(serviceId);
    }

    if (expectedPickupDate != null) {
      final start = DateTime(expectedPickupDate.year, expectedPickupDate.month, expectedPickupDate.day);
      final end = DateTime(expectedPickupDate.year, expectedPickupDate.month, expectedPickupDate.day, 23, 59, 59, 999);
      predicate = predicate &
          db.orders.expectedPickupDate.isBiggerOrEqualValue(start) &
          db.orders.expectedPickupDate.isSmallerOrEqualValue(end);
    }

    if (orderReceivedDate != null) {
      final start = DateTime(orderReceivedDate.year, orderReceivedDate.month, orderReceivedDate.day);
      final end = DateTime(orderReceivedDate.year, orderReceivedDate.month, orderReceivedDate.day, 23, 59, 59, 999);
      predicate = predicate &
          db.orders.createdAt.isBiggerOrEqualValue(start) &
          db.orders.createdAt.isSmallerOrEqualValue(end);
    }

    return predicate;
  }

  Future<List<StorageItemRow>> getItemsRequiringStorageWithDetails({
    String? query,
    String? orderId,
    String? itemTypeId,
    String? serviceId,
    DateTime? expectedPickupDate,
    DateTime? orderReceivedDate,
    int limit = 50,
    int offset = 0,
  }) async {
    final predicate = _buildRequiringStoragePredicate(
      query: query,
      orderId: orderId,
      itemTypeId: itemTypeId,
      serviceId: serviceId,
      expectedPickupDate: expectedPickupDate,
      orderReceivedDate: orderReceivedDate,
    );

    final dbQuery = select(db.orderItems).join([
      innerJoin(db.orders, db.orders.id.equalsExp(db.orderItems.orderId)),
      leftOuterJoin(
        db.orderItemCarpets,
        db.orderItemCarpets.orderItemId.equalsExp(db.orderItems.id),
      ),
    ])
      ..where(predicate)
      ..orderBy([
        OrderingTerm.asc(db.orders.createdAt),
        OrderingTerm.asc(db.orderItems.id),
      ])
      ..limit(limit, offset: offset);

    final rows = await dbQuery.get();
    return rows.map((row) {
      return (
        item: row.readTable(db.orderItems),
        order: row.readTable(db.orders),
        carpet: row.readTableOrNull(db.orderItemCarpets),
        record: null,
        location: null,
      );
    }).toList();
  }

  Future<int> countItemsRequiringStorageWithDetails({
    String? query,
    String? orderId,
    String? itemTypeId,
    String? serviceId,
    DateTime? expectedPickupDate,
    DateTime? orderReceivedDate,
  }) async {
    final predicate = _buildRequiringStoragePredicate(
      query: query,
      orderId: orderId,
      itemTypeId: itemTypeId,
      serviceId: serviceId,
      expectedPickupDate: expectedPickupDate,
      orderReceivedDate: orderReceivedDate,
    );

    final countCol = db.orderItems.id.count();
    final countQuery = selectOnly(db.orderItems).join([
      innerJoin(db.orders, db.orders.id.equalsExp(db.orderItems.orderId)),
    ])
      ..where(predicate)
      ..addColumns([countCol]);

    final result = await countQuery.map((row) => row.read(countCol)).getSingle();
    return result ?? 0;
  }

  Expression<bool> _buildCurrentStoragePredicate({
    String? query,
    String? orderId,
    String? storageLocationId,
    String? itemTypeId,
    String? serviceId,
    DateTime? expectedPickupDate,
    DateTime? orderReceivedDate,
  }) {
    Expression<bool> predicate =
        (db.orders.status.equals('processing') | db.orders.status.equals('ready')) &
        db.storageRecords.isActive.equals(true);

    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim()}%';
      predicate = predicate &
          (db.orders.orderNumber.like(q) |
              db.orders.customerNameSnapshot.like(q) |
              db.orders.customerPhoneSnapshot.like(q));
    }

    if (orderId != null && orderId.trim().isNotEmpty) {
      predicate = predicate & db.orders.id.equals(orderId);
    }

    if (storageLocationId != null && storageLocationId.trim().isNotEmpty) {
      predicate = predicate & db.storageRecords.storageLocationId.equals(storageLocationId);
    }

    if (itemTypeId != null && itemTypeId.trim().isNotEmpty) {
      predicate = predicate & db.orderItems.itemTypeId.equals(itemTypeId);
    }

    if (serviceId != null && serviceId.trim().isNotEmpty) {
      predicate = predicate & db.orderItems.serviceId.equals(serviceId);
    }

    if (expectedPickupDate != null) {
      final start = DateTime(expectedPickupDate.year, expectedPickupDate.month, expectedPickupDate.day);
      final end = DateTime(expectedPickupDate.year, expectedPickupDate.month, expectedPickupDate.day, 23, 59, 59, 999);
      predicate = predicate &
          db.orders.expectedPickupDate.isBiggerOrEqualValue(start) &
          db.orders.expectedPickupDate.isSmallerOrEqualValue(end);
    }

    if (orderReceivedDate != null) {
      final start = DateTime(orderReceivedDate.year, orderReceivedDate.month, orderReceivedDate.day);
      final end = DateTime(orderReceivedDate.year, orderReceivedDate.month, orderReceivedDate.day, 23, 59, 59, 999);
      predicate = predicate &
          db.orders.createdAt.isBiggerOrEqualValue(start) &
          db.orders.createdAt.isSmallerOrEqualValue(end);
    }

    return predicate;
  }

  Future<List<StorageItemRow>> getCurrentStorageItemsWithDetails({
    String? query,
    String? orderId,
    String? storageLocationId,
    String? itemTypeId,
    String? serviceId,
    DateTime? expectedPickupDate,
    DateTime? orderReceivedDate,
    int limit = 50,
    int offset = 0,
  }) async {
    final predicate = _buildCurrentStoragePredicate(
      query: query,
      orderId: orderId,
      storageLocationId: storageLocationId,
      itemTypeId: itemTypeId,
      serviceId: serviceId,
      expectedPickupDate: expectedPickupDate,
      orderReceivedDate: orderReceivedDate,
    );

    final dbQuery = select(db.orderItems).join([
      innerJoin(db.orders, db.orders.id.equalsExp(db.orderItems.orderId)),
      innerJoin(
        db.storageRecords,
        db.storageRecords.orderItemId.equalsExp(db.orderItems.id) &
            db.storageRecords.isActive.equals(true),
      ),
      innerJoin(
        db.storageLocations,
        db.storageLocations.id.equalsExp(db.storageRecords.storageLocationId),
      ),
      leftOuterJoin(
        db.orderItemCarpets,
        db.orderItemCarpets.orderItemId.equalsExp(db.orderItems.id),
      ),
    ])
      ..where(predicate)
      ..orderBy([
        OrderingTerm.desc(db.storageRecords.updatedAt),
        OrderingTerm.asc(db.orderItems.id),
      ])
      ..limit(limit, offset: offset);

    final rows = await dbQuery.get();
    return rows.map((row) {
      return (
        item: row.readTable(db.orderItems),
        order: row.readTable(db.orders),
        carpet: row.readTableOrNull(db.orderItemCarpets),
        record: row.readTable(db.storageRecords),
        location: row.readTable(db.storageLocations),
      );
    }).toList();
  }

  Future<int> countCurrentStorageItemsWithDetails({
    String? query,
    String? orderId,
    String? storageLocationId,
    String? itemTypeId,
    String? serviceId,
    DateTime? expectedPickupDate,
    DateTime? orderReceivedDate,
  }) async {
    final predicate = _buildCurrentStoragePredicate(
      query: query,
      orderId: orderId,
      storageLocationId: storageLocationId,
      itemTypeId: itemTypeId,
      serviceId: serviceId,
      expectedPickupDate: expectedPickupDate,
      orderReceivedDate: orderReceivedDate,
    );

    final countCol = db.orderItems.id.count();
    final countQuery = selectOnly(db.orderItems).join([
      innerJoin(db.orders, db.orders.id.equalsExp(db.orderItems.orderId)),
      innerJoin(
        db.storageRecords,
        db.storageRecords.orderItemId.equalsExp(db.orderItems.id) &
            db.storageRecords.isActive.equals(true),
      ),
    ])
      ..where(predicate)
      ..addColumns([countCol]);

    final result = await countQuery.map((row) => row.read(countCol)).getSingle();
    return result ?? 0;
  }
}
