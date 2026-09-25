import 'package:drift/drift.dart';

import '../database/app_database.dart' as app_db;

class RefundsDao extends DatabaseAccessor<app_db.AppDatabase> {
  RefundsDao(super.attachedDatabase);

  app_db.AppDatabase get db => attachedDatabase;

  Future<void> insertRefund(app_db.RefundsCompanion refund) async {
    await into(db.refunds).insert(refund);
  }

  Future<app_db.Refund?> getRefundById(String id) async {
    return (select(db.refunds)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<app_db.Refund>> getRefundsForOrder(String orderId) async {
    return (select(db.refunds)
          ..where((t) => t.orderId.equals(orderId))
          ..orderBy([(t) => OrderingTerm.desc(t.refundedAt)]))
        .get();
  }

  Stream<List<app_db.Refund>> watchRefundsForOrder(String orderId) {
    return (select(db.refunds)
          ..where((t) => t.orderId.equals(orderId))
          ..orderBy([(t) => OrderingTerm.desc(t.refundedAt)]))
        .watch();
  }

  Future<int> getTotalRefundedForOrder(String orderId) async {
    final sumExp = db.refunds.amount.sum();
    final query = selectOnly(db.refunds)
      ..where(db.refunds.orderId.equals(orderId))
      ..addColumns([sumExp]);
    final result = await query.map((row) => row.read(sumExp)).getSingle();
    return result ?? 0;
  }

  Future<Map<String, int>> getTotalRefundedForOrders(
    List<String> orderIds,
  ) async {
    if (orderIds.isEmpty) return {};
    final sumExp = db.refunds.amount.sum();
    final query = selectOnly(db.refunds)
      ..where(db.refunds.orderId.isIn(orderIds))
      ..addColumns([db.refunds.orderId, sumExp])
      ..groupBy([db.refunds.orderId]);
    final rows = await query.get();
    return {
      for (final row in rows)
        if (row.read(db.refunds.orderId) != null)
          row.read(db.refunds.orderId)!: row.read(sumExp) ?? 0,
    };
  }

  Future<int> getTotalRefunds({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final sumExp = db.refunds.amount.sum();
    final query = selectOnly(db.refunds)
      ..where(
        db.refunds.refundedAt.isBiggerOrEqualValue(startDate) &
            db.refunds.refundedAt.isSmallerOrEqualValue(endDate),
      )
      ..addColumns([sumExp]);
    final result = await query.map((row) => row.read(sumExp)).getSingle();
    return result ?? 0;
  }
}
