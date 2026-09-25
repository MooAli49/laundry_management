import '../../core/errors/failures.dart';
import '../../domain/entities/refund.dart';
import '../../domain/entities/refund_balance_summary.dart';
import '../../domain/repositories/refund_repository.dart';
import '../../domain/value_objects/money.dart';
import '../local/daos/orders_dao.dart';
import '../local/daos/payments_dao.dart';
import '../local/daos/refunds_dao.dart';
import '../local/daos/sync_operations_dao.dart';
import '../local/database/app_database.dart' as app_db;
import '../mappers/refund_mapper.dart';
import '../sync/sync_payload_builder.dart';

class RefundRepositoryImpl implements RefundRepository {
  final RefundsDao _refundsDao;
  final PaymentsDao _paymentsDao;
  final OrdersDao _ordersDao;
  final SyncOperationsDao _syncOperationsDao;
  final app_db.AppDatabase _db;

  RefundRepositoryImpl({
    required RefundsDao refundsDao,
    required PaymentsDao paymentsDao,
    required OrdersDao ordersDao,
    required SyncOperationsDao syncOperationsDao,
    required app_db.AppDatabase db,
  })  : _refundsDao = refundsDao,
        _paymentsDao = paymentsDao,
        _ordersDao = ordersDao,
        _syncOperationsDao = syncOperationsDao,
        _db = db;

  @override
  Future<Refund> createRefund(Refund refund) async {
    try {
      if (refund.amount.piastres <= 0) {
        throw const ValidationFailure(
          'Refund amount must be greater than zero',
        );
      }

      return await _db.transaction(() async {
        final order = await _ordersDao.getOrderById(refund.orderId);
        if (order == null) {
          throw const ValidationFailure('Order not found');
        }

        if (order.status != 'cancelled') {
          throw const BusinessRuleFailure(
            'Only cancelled orders can be refunded',
          );
        }

        final paidPiastres = await _paymentsDao.getTotalPaidForOrder(
          refund.orderId,
        );
        final refundedPiastres = await _refundsDao.getTotalRefundedForOrder(
          refund.orderId,
        );
        final remainingRefundable = paidPiastres - refundedPiastres;

        if (refund.amount.piastres > remainingRefundable) {
          throw const BusinessRuleFailure(
            'Refund amount exceeds refundable balance',
          );
        }

        await _refundsDao.insertRefund(
          RefundMapper.toCompanion(refund),
        );

        await _syncOperationsDao.recordOperation(
          entityType: 'refund',
          entityId: refund.id,
          operationType: 'create',
          payload: SyncPayloadBuilder.buildRefundPayload(refund),
        );

        return refund;
      });
    } on ArgumentError catch (e) {
      throw ValidationFailure(e.message.toString());
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<Refund?> getRefundById(String id) async {
    try {
      final row = await _refundsDao.getRefundById(id);
      return row != null ? RefundMapper.toDomain(row) : null;
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<List<Refund>> getRefundsForOrder(String orderId) async {
    try {
      final rows = await _refundsDao.getRefundsForOrder(orderId);
      return rows.map(RefundMapper.toDomain).toList();
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Stream<List<Refund>> watchRefundsForOrder(String orderId) {
    try {
      return _refundsDao
          .watchRefundsForOrder(orderId)
          .map((rows) => rows.map(RefundMapper.toDomain).toList());
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<Money> getTotalRefundedForOrder(String orderId) async {
    try {
      final piastres = await _refundsDao.getTotalRefundedForOrder(orderId);
      return Money.fromPiastres(piastres);
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<Money> getRemainingRefundableForOrder(String orderId) async {
    try {
      final order = await _ordersDao.getOrderById(orderId);
      if (order == null) {
        throw ValidationFailure('Order with id $orderId not found');
      }
      final paidPiastres = await _paymentsDao.getTotalPaidForOrder(orderId);
      final refundedPiastres =
          await _refundsDao.getTotalRefundedForOrder(orderId);
      final remaining = paidPiastres - refundedPiastres;
      return Money.fromPiastres(remaining > 0 ? remaining : 0);
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<RefundBalanceSummary> getRefundableBalanceSummary(
    String orderId,
  ) async {
    try {
      final order = await _ordersDao.getOrderById(orderId);
      if (order == null) {
        throw ValidationFailure('Order with id $orderId not found');
      }
      final paidPiastres = await _paymentsDao.getTotalPaidForOrder(orderId);
      final refundedPiastres =
          await _refundsDao.getTotalRefundedForOrder(orderId);
      final remaining = paidPiastres - refundedPiastres;
      return RefundBalanceSummary(
        totalPaid: Money.fromPiastres(paidPiastres),
        totalRefunded: Money.fromPiastres(refundedPiastres),
        remainingRefundable: Money.fromPiastres(remaining > 0 ? remaining : 0),
      );
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }
}
