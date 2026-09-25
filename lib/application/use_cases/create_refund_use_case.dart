import 'package:uuid/uuid.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/refund.dart';
import '../../domain/enums/refund_method.dart';
import '../../domain/repositories/refund_repository.dart';
import '../../domain/value_objects/money.dart';

class CreateRefundInput {
  final String? id;
  final String orderId;
  final Money amount;
  final RefundMethod refundMethod;
  final String? reason;
  final DateTime? refundedAt;

  const CreateRefundInput({
    this.id,
    required this.orderId,
    required this.amount,
    required this.refundMethod,
    this.reason,
    this.refundedAt,
  });
}

class CreateRefundUseCase {
  final RefundRepository _refundRepository;

  CreateRefundUseCase(this._refundRepository);

  Future<Refund> execute(CreateRefundInput input) async {
    if (input.orderId.trim().isEmpty) {
      throw const ValidationFailure('Order id cannot be empty');
    }
    if (!input.amount.isPositive) {
      throw const ValidationFailure('Refund amount must be greater than zero');
    }

    final now = DateTime.now();
    final refund = Refund(
      id: input.id ?? const Uuid().v4(),
      orderId: input.orderId,
      amount: input.amount,
      refundMethod: input.refundMethod,
      reason: input.reason?.trim().isEmpty ?? true ? null : input.reason!.trim(),
      refundedAt: input.refundedAt ?? now,
      createdAt: now,
      updatedAt: now,
    );

    return await _refundRepository.createRefund(refund);
  }
}
