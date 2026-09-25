import 'package:drift/drift.dart';

import '../../domain/entities/refund.dart';
import '../../domain/enums/refund_method.dart';
import '../../domain/value_objects/money.dart';
import '../local/database/app_database.dart' as app_db;

class RefundMapper {
  RefundMapper._();

  static Refund toDomain(app_db.Refund row) {
    return Refund(
      id: row.id,
      orderId: row.orderId,
      amount: Money.fromPiastres(row.amount),
      refundMethod: RefundMethod.fromValue(row.refundMethod),
      reason: row.reason,
      refundedAt: row.refundedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  static app_db.RefundsCompanion toCompanion(Refund domain) {
    return app_db.RefundsCompanion(
      id: Value(domain.id),
      orderId: Value(domain.orderId),
      amount: Value(domain.amount.piastres),
      refundMethod: Value(domain.refundMethod.value),
      reason: Value(domain.reason),
      refundedAt: Value(domain.refundedAt),
      createdAt: Value(domain.createdAt),
      updatedAt: Value(domain.updatedAt),
    );
  }
}
