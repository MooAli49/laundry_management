import 'package:drift/drift.dart';

import '../database/app_database.dart' as app_db;

class PaymentsDao extends DatabaseAccessor<app_db.AppDatabase> {
  PaymentsDao(super.attachedDatabase);

  app_db.AppDatabase get db => attachedDatabase;

  Future<void> insertPayment(app_db.PaymentsCompanion payment) async {
    await into(db.payments).insert(payment);
  }

  Future<List<app_db.Payment>> getPaymentsForOrder(String orderId) async {
    return (select(db.payments)
          ..where((t) => t.orderId.equals(orderId))
          ..orderBy([(t) => OrderingTerm.desc(t.paidAt)]))
        .get();
  }

  Stream<List<app_db.Payment>> watchPaymentsForOrder(String orderId) {
    return (select(db.payments)
          ..where((t) => t.orderId.equals(orderId))
          ..orderBy([(t) => OrderingTerm.desc(t.paidAt)]))
        .watch();
  }

  Future<int> getTotalPaidForOrder(String orderId) async {
    final sumExp = db.payments.amount.sum();
    final query = selectOnly(db.payments)
      ..where(db.payments.orderId.equals(orderId))
      ..addColumns([sumExp]);
    final result = await query.map((row) => row.read(sumExp)).getSingle();
    return result ?? 0;
  }

  Future<Map<String, int>> getTotalPaidForOrders(List<String> orderIds) async {
    if (orderIds.isEmpty) return {};
    final sumExp = db.payments.amount.sum();
    final query = selectOnly(db.payments)
      ..where(db.payments.orderId.isIn(orderIds))
      ..addColumns([db.payments.orderId, sumExp])
      ..groupBy([db.payments.orderId]);
    final rows = await query.get();
    return {
      for (final row in rows)
        if (row.read(db.payments.orderId) != null)
          row.read(db.payments.orderId)!: row.read(sumExp) ?? 0,
    };
  }
}
