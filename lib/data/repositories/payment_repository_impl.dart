import 'package:drift/drift.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/payment.dart';
import '../../domain/enums/payment_method.dart';
import '../../domain/repositories/payment_repository.dart';
import '../../domain/value_objects/money.dart';
import '../local/daos/orders_dao.dart';
import '../local/daos/payments_dao.dart';
import '../local/daos/sync_operations_dao.dart';
import '../local/database/app_database.dart' as app_db;

class PaymentRepositoryImpl implements PaymentRepository {
  final PaymentsDao _paymentsDao;
  final OrdersDao _ordersDao;
  final SyncOperationsDao _syncOperationsDao;
  final app_db.AppDatabase _db;

  PaymentRepositoryImpl({
    required PaymentsDao paymentsDao,
    required OrdersDao ordersDao,
    required SyncOperationsDao syncOperationsDao,
    required app_db.AppDatabase db,
  })  : _paymentsDao = paymentsDao,
        _ordersDao = ordersDao,
        _syncOperationsDao = syncOperationsDao,
        _db = db;

  @override
  Future<Payment> recordPayment(Payment payment) async {
    try {
      return await _db.transaction(() async {
        final order = await _ordersDao.getOrderById(payment.orderId);
        if (order == null) {
          throw ValidationFailure('Order not found');
        }

        await _paymentsDao.insertPayment(
          app_db.PaymentsCompanion(
            id: Value(payment.id),
            orderId: Value(payment.orderId),
            amount: Value(payment.amount.piastres),
            paymentMethod: Value(payment.paymentMethod.name),
            paidAt: Value(payment.paidAt),
            createdAt: Value(payment.createdAt),
            updatedAt: Value(payment.updatedAt),
          ),
        );

        await _syncOperationsDao.recordOperation(
          entityType: 'payment',
          entityId: payment.id,
          operationType: 'create',
        );

        return payment;
      });
    } on ArgumentError catch (e) {
      throw ValidationFailure(e.message.toString());
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<List<Payment>> getPaymentsForOrder(String orderId) async {
    try {
      final rows = await _paymentsDao.getPaymentsForOrder(orderId);
      return rows.map(_mapToDomain).toList();
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Stream<List<Payment>> watchPaymentsForOrder(String orderId) {
    try {
      return _paymentsDao.watchPaymentsForOrder(orderId).map(
            (rows) => rows.map(_mapToDomain).toList(),
          );
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<Money> getTotalPaidForOrder(String orderId) async {
    try {
      final piastres = await _paymentsDao.getTotalPaidForOrder(orderId);
      return Money.fromPiastres(piastres);
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  @override
  Future<Money> getRemainingAmountForOrder(String orderId) async {
    try {
      final order = await _ordersDao.getOrderById(orderId);
      if (order == null) {
        throw ValidationFailure('Order with id $orderId not found');
      }
      final paidPiastres = await _paymentsDao.getTotalPaidForOrder(orderId);
      final remaining = order.total - paidPiastres;
      return Money.fromPiastres(remaining);
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure(e.toString());
    }
  }

  Payment _mapToDomain(app_db.Payment row) {
    return Payment(
      id: row.id,
      orderId: row.orderId,
      amount: Money.fromPiastres(row.amount),
      paymentMethod: PaymentMethod.values.byName(row.paymentMethod),
      paidAt: row.paidAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
