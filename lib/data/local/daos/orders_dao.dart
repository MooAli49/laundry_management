import 'package:drift/drift.dart';

import '../database/app_database.dart' as app_db;
import '../queries/customer_order_aggregate_query_result.dart';
import '../queries/orders_report_aggregate_query_result.dart';
import '../queries/outstanding_order_query_result.dart';

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
    bool? hasRemaining,
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    final sanitizedQuery = query?.trim();
    final hasSearchQuery = sanitizedQuery != null && sanitizedQuery.isNotEmpty;

    if (hasSearchQuery) {
      final selectQuery = select(db.orders).join([
        innerJoin(db.customers, db.customers.id.equalsExp(db.orders.customerId)),
      ]);

      selectQuery.where(
        db.orders.orderNumber.like('%$sanitizedQuery%') |
            db.customers.name.like('%$sanitizedQuery%') |
            db.customers.phone.like('%$sanitizedQuery%'),
      );

      if (status != null) {
        selectQuery.where(db.orders.status.equals(status));
      }
      if (expectedPickupDate != null) {
        selectQuery.where(db.orders.expectedPickupDate.equals(expectedPickupDate));
      }
      if (customerId != null) {
        selectQuery.where(db.orders.customerId.equals(customerId));
      }
      if (hasRemaining == true) {
        selectQuery.where(
          const CustomExpression<bool>(
            'orders.total > (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE payments.order_id = orders.id)',
          ),
        );
      } else if (hasRemaining == false) {
        selectQuery.where(
          const CustomExpression<bool>(
            'orders.total <= (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE payments.order_id = orders.id)',
          ),
        );
      }

      selectQuery
        ..orderBy([OrderingTerm.desc(db.orders.createdAt)])
        ..limit(limit, offset: offset);

      final rows = await selectQuery.get();
      return rows.map((row) => row.readTable(db.orders)).toList();
    } else {
      final selectQuery = select(db.orders);

      if (status != null) {
        selectQuery.where((t) => t.status.equals(status));
      }
      if (expectedPickupDate != null) {
        selectQuery.where((t) => t.expectedPickupDate.equals(expectedPickupDate));
      }
      if (customerId != null) {
        selectQuery.where((t) => t.customerId.equals(customerId));
      }
      if (hasRemaining == true) {
        selectQuery.where(
          (t) => const CustomExpression<bool>(
            'orders.total > (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE payments.order_id = orders.id)',
          ),
        );
      } else if (hasRemaining == false) {
        selectQuery.where(
          (t) => const CustomExpression<bool>(
            'orders.total <= (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE payments.order_id = orders.id)',
          ),
        );
      }

      selectQuery
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
        ..limit(limit, offset: offset);

      return selectQuery.get();
    }
  }

  Future<List<app_db.Order>> searchOrders({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    return getOrders(query: query, limit: limit, offset: offset);
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

  Future<int> getOrderCountByCustomerId(String customerId) async {
    final countExp = db.orders.id.count();
    final query = selectOnly(db.orders)
      ..where(db.orders.customerId.equals(customerId))
      ..addColumns([countExp]);
    final result = await query.map((row) => row.read(countExp)).getSingle();
    return result ?? 0;
  }

  Future<Map<String, int>> getOrderCountsGroupedByCustomer({List<String>? customerIds}) async {
    if (customerIds != null && customerIds.isEmpty) return {};
    final countExp = db.orders.id.count();
    final query = selectOnly(db.orders)
      ..addColumns([db.orders.customerId, countExp]);
    if (customerIds != null) {
      query.where(db.orders.customerId.isIn(customerIds));
    }
    query.groupBy([db.orders.customerId]);
    final rows = await query.get();
    return {
      for (final row in rows)
        if (row.read(db.orders.customerId) != null)
          row.read(db.orders.customerId)!: row.read(countExp) ?? 0,
    };
  }

  Future<Map<String, int>> getOrderCountsByCustomerIds(List<String> customerIds) async {
    if (customerIds.isEmpty) return {};
    return getOrderCountsGroupedByCustomer(customerIds: customerIds);
  }

  Future<List<app_db.Order>> getOrdersByIds(List<String> orderIds) async {
    if (orderIds.isEmpty) return [];
    return (select(db.orders)..where((t) => t.id.isIn(orderIds))).get();
  }

  Future<CustomerOrderAggregateQueryResult> getCustomerOrderAggregate(String customerId) async {
    final query = db.customSelect(
      '''
      SELECT 
        COUNT(o.id) AS total_count,
        COALESCE(SUM(CASE WHEN o.status = 'processing' THEN 1 ELSE 0 END), 0) AS processing_count,
        COALESCE(SUM(CASE WHEN o.status = 'ready' THEN 1 ELSE 0 END), 0) AS ready_count,
        COALESCE(SUM(CASE WHEN o.status = 'completed' THEN 1 ELSE 0 END), 0) AS completed_count,
        COALESCE(SUM(CASE WHEN o.status = 'cancelled' THEN 1 ELSE 0 END), 0) AS cancelled_count,
        COALESCE(SUM(COALESCE(p.paid_amount, 0)), 0) AS total_paid,
        COALESCE(SUM(CASE 
          WHEN o.total > COALESCE(p.paid_amount, 0) THEN o.total - COALESCE(p.paid_amount, 0) 
          ELSE 0 
        END), 0) AS total_remaining
      FROM orders o
      LEFT JOIN (
        SELECT order_id, SUM(amount) AS paid_amount
        FROM payments
        GROUP BY order_id
      ) p ON p.order_id = o.id
      WHERE o.customer_id = ?
      ''',
      variables: [Variable.withString(customerId)],
      readsFrom: {db.orders, db.payments},
    );

    final row = await query.getSingleOrNull();
    if (row == null) {
      return CustomerOrderAggregateQueryResult.empty;
    }

    final totalCount = row.read<int>('total_count');
    if (totalCount == 0) {
      return CustomerOrderAggregateQueryResult.empty;
    }

    return CustomerOrderAggregateQueryResult(
      totalOrders: totalCount,
      processingOrders: row.read<int>('processing_count'),
      readyOrders: row.read<int>('ready_count'),
      completedOrders: row.read<int>('completed_count'),
      cancelledOrders: row.read<int>('cancelled_count'),
      totalPaidPiastres: row.read<int>('total_paid'),
      totalRemainingPiastres: row.read<int>('total_remaining'),
    );
  }

  Future<OrdersReportAggregateQueryResult> getOrdersReportAggregate({
    required DateTime startDate,
    required DateTime endDate,
    required DateTime overdueCutoff,
  }) async {
    final query = db.customSelect(
      '''
      SELECT 
        COUNT(o.id) AS total_orders,
        COALESCE(SUM(o.total), 0) AS total_order_value,
        COALESCE(SUM(o.discount), 0) AS total_discounts,
        COALESCE(SUM(CASE WHEN o.status = 'processing' THEN 1 ELSE 0 END), 0) AS processing_count,
        COALESCE(SUM(CASE WHEN o.status = 'ready' THEN 1 ELSE 0 END), 0) AS ready_count,
        COALESCE(SUM(CASE WHEN o.status = 'completed' THEN 1 ELSE 0 END), 0) AS completed_count,
        COALESCE(SUM(CASE WHEN o.status = 'cancelled' THEN 1 ELSE 0 END), 0) AS cancelled_count,
        COALESCE(SUM(CASE 
          WHEN o.expected_pickup_date < ? 
           AND o.status != 'completed' 
           AND o.status != 'cancelled' 
          THEN 1 ELSE 0 END), 0) AS overdue_count
      FROM orders o
      WHERE o.created_at >= ? AND o.created_at <= ?
      ''',
      variables: [
        Variable.withDateTime(overdueCutoff),
        Variable.withDateTime(startDate),
        Variable.withDateTime(endDate),
      ],
      readsFrom: {db.orders},
    );

    final row = await query.getSingleOrNull();
    if (row == null) {
      return OrdersReportAggregateQueryResult.empty;
    }

    return OrdersReportAggregateQueryResult(
      totalOrders: row.read<int>('total_orders'),
      totalOrderValuePiastres: row.read<int>('total_order_value'),
      totalDiscountsPiastres: row.read<int>('total_discounts'),
      processingCount: row.read<int>('processing_count'),
      readyCount: row.read<int>('ready_count'),
      completedCount: row.read<int>('completed_count'),
      cancelledCount: row.read<int>('cancelled_count'),
      overdueCount: row.read<int>('overdue_count'),
    );
  }

  Future<List<OutstandingOrderQueryResult>> getOutstandingOrdersForPeriod({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final query = db.customSelect(
      '''
      SELECT 
        o.id AS order_id,
        o.order_number,
        o.created_at,
        o.customer_name_snapshot,
        o.customer_phone_snapshot,
        o.total AS total_piastres,
        COALESCE(p.paid_amount, 0) AS paid_piastres,
        (o.total - COALESCE(p.paid_amount, 0)) AS remaining_piastres
      FROM orders o
      LEFT JOIN (
        SELECT order_id, SUM(amount) AS paid_amount
        FROM payments
        GROUP BY order_id
      ) p ON p.order_id = o.id
      WHERE o.status != 'cancelled'
        AND (o.total - COALESCE(p.paid_amount, 0)) > 0
        AND o.created_at >= ? AND o.created_at <= ?
      ORDER BY o.created_at DESC
      ''',
      variables: [
        Variable.withDateTime(startDate),
        Variable.withDateTime(endDate),
      ],
      readsFrom: {db.orders, db.payments},
    );

    final rows = await query.get();
    return rows.map((row) {
      return OutstandingOrderQueryResult(
        orderId: row.read<String>('order_id'),
        orderNumber: row.read<String>('order_number'),
        createdAt: row.read<DateTime>('created_at'),
        customerName: row.read<String>('customer_name_snapshot'),
        customerPhone: row.read<String>('customer_phone_snapshot'),
        totalPiastres: row.read<int>('total_piastres'),
        paidPiastres: row.read<int>('paid_piastres'),
        remainingPiastres: row.read<int>('remaining_piastres'),
      );
    }).toList();
  }
}
