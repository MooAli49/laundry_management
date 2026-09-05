import 'package:drift/drift.dart';

import '../database/app_database.dart' as app_db;

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
    // Items belonging to active orders (processing or ready)
    // that have NO active storage record
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
}
