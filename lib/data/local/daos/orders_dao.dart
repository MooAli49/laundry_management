import 'package:drift/drift.dart';

import '../database/app_database.dart' as app_db;

class OrdersDao extends DatabaseAccessor<app_db.AppDatabase> {
  OrdersDao(super.attachedDatabase);

  app_db.AppDatabase get db => attachedDatabase;

  Future<String> generateNextOrderNumber() async {
    final now = DateTime.now();
    final yearPrefix = (now.year % 100).toString().padLeft(2, '0');
    final pattern = '$yearPrefix-%';

    final query = select(db.orders)
      ..where((t) => t.orderNumber.like(pattern))
      ..orderBy([
        (t) => OrderingTerm.desc(t.orderNumber.length),
        (t) => OrderingTerm.desc(t.orderNumber),
      ])
      ..limit(1);

    final latest = await query.getSingleOrNull();
    if (latest == null) {
      return '$yearPrefix-001';
    }

    final parts = latest.orderNumber.split('-');
    if (parts.length == 2) {
      final currentSeq = int.tryParse(parts[1]) ?? 0;
      final nextSeq = (currentSeq + 1).toString().padLeft(3, '0');
      return '$yearPrefix-$nextSeq';
    }
    return '$yearPrefix-001';
  }

  Future<void> insertOrder(app_db.OrdersCompanion order) async {
    await into(db.orders).insert(order);
  }

  Future<void> insertOrderItem(app_db.OrderItemsCompanion item) async {
    await into(db.orderItems).insert(item);
  }

  Future<void> insertOrderItemCarpet(app_db.OrderItemCarpetsCompanion carpet) async {
    await into(db.orderItemCarpets).insert(carpet);
  }

  Future<void> updateOrder(app_db.OrdersCompanion order) async {
    await (update(db.orders)..where((t) => t.id.equals(order.id.value))).write(order);
  }

  Future<app_db.Order?> getOrderById(String id) async {
    return (select(db.orders)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<app_db.Order?> getOrderByNumber(String orderNumber) async {
    return (select(db.orders)..where((t) => t.orderNumber.equals(orderNumber))).getSingleOrNull();
  }

  Future<List<app_db.OrderItem>> getOrderItemsRaw(String orderId) async {
    return (select(db.orderItems)..where((t) => t.orderId.equals(orderId))).get();
  }

  Future<List<({app_db.OrderItem item, app_db.OrderItemCarpet? carpet})>> getOrderItemsWithCarpets(
    String orderId,
  ) async {
    final query = select(db.orderItems).join([
      leftOuterJoin(
        db.orderItemCarpets,
        db.orderItemCarpets.orderItemId.equalsExp(db.orderItems.id),
      ),
    ])..where(db.orderItems.orderId.equals(orderId));

    final rows = await query.get();
    return rows.map((row) {
      return (
        item: row.readTable(db.orderItems),
        carpet: row.readTableOrNull(db.orderItemCarpets),
      );
    }).toList();
  }

  Future<({app_db.OrderItem item, app_db.OrderItemCarpet? carpet})?> getOrderItemWithCarpetById(
    String id,
  ) async {
    final query = select(db.orderItems).join([
      leftOuterJoin(
        db.orderItemCarpets,
        db.orderItemCarpets.orderItemId.equalsExp(db.orderItems.id),
      ),
    ])..where(db.orderItems.id.equals(id));

    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return (
      item: row.readTable(db.orderItems),
      carpet: row.readTableOrNull(db.orderItemCarpets),
    );
  }

  Future<List<app_db.Order>> getOrders({
    String? status,
    DateTime? expectedPickupDate,
    String? customerId,
    int limit = 20,
    int offset = 0,
  }) async {
    final query = select(db.orders);
    if (status != null) {
      query.where((t) => t.status.equals(status));
    }
    if (expectedPickupDate != null) {
      query.where((t) => t.expectedPickupDate.equals(expectedPickupDate));
    }
    if (customerId != null) {
      query.where((t) => t.customerId.equals(customerId));
    }

    query
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(limit, offset: offset);

    return query.get();
  }

  Future<List<app_db.Order>> searchOrders({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    final sanitized = query.trim();
    final selectQuery = select(db.orders).join([
      innerJoin(db.customers, db.customers.id.equalsExp(db.orders.customerId)),
    ]);

    selectQuery.where(
      db.orders.orderNumber.like('%$sanitized%') |
          db.customers.name.like('%$sanitized%') |
          db.customers.phone.like('%$sanitized%'),
    );

    selectQuery
      ..orderBy([OrderingTerm.desc(db.orders.createdAt)])
      ..limit(limit, offset: offset);

    final rows = await selectQuery.get();
    return rows.map((row) => row.readTable(db.orders)).toList();
  }

  Stream<List<app_db.Order>> watchRecentOrders({int limit = 20}) {
    return (select(db.orders)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .watch();
  }

  Stream<app_db.Order?> watchOrderById(String id) {
    return (select(db.orders)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? cancellationReason,
    required DateTime updatedAt,
  }) async {
    await (update(db.orders)..where((t) => t.id.equals(orderId))).write(
      app_db.OrdersCompanion(
        status: Value(status),
        completedAt: Value(completedAt),
        cancelledAt: Value(cancelledAt),
        cancellationReason: Value(cancellationReason),
        updatedAt: Value(updatedAt),
      ),
    );
  }
}
