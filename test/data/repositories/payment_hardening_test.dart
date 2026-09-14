import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart' hide Payment;
import 'package:laundry_management/data/repositories/payment_repository_impl.dart';
import 'package:laundry_management/domain/entities/payment.dart';
import 'package:laundry_management/domain/enums/payment_method.dart';
import 'package:laundry_management/domain/value_objects/money.dart';

class _TestZeroPayment implements Payment {
  @override
  final String id;
  @override
  final String orderId;
  @override
  final Money amount;
  @override
  final PaymentMethod paymentMethod;
  @override
  final DateTime paidAt;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  _TestZeroPayment({
    required this.id,
    required this.orderId,
    this.amount = Money.zero,
  })  : paymentMethod = PaymentMethod.cash,
        paidAt = DateTime.now(),
        createdAt = DateTime.now(),
        updatedAt = DateTime.now();

  @override
  Payment copyWith({
    String? id,
    String? orderId,
    Money? amount,
    PaymentMethod? paymentMethod,
    DateTime? paidAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late PaymentsDao paymentsDao;
  late OrdersDao ordersDao;
  late SyncOperationsDao syncOperationsDao;
  late PaymentRepositoryImpl paymentRepository;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    paymentsDao = PaymentsDao(db);
    ordersDao = OrdersDao(db);
    syncOperationsDao = SyncOperationsDao(db);
    paymentRepository = PaymentRepositoryImpl(
      paymentsDao: paymentsDao,
      ordersDao: ordersDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    final nowTimestamp = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    // Insert test customer
    await db.customStatement(
      'INSERT INTO customers (id, name, phone, created_at, updated_at) VALUES (?, ?, ?, ?, ?);',
      ['cust-pay', 'عميل الدفع', '01099998888', nowTimestamp, nowTimestamp],
    );

    // Insert orders for various states
    // 1. Normal active processing order, total = 10000 piastres (100 EGP)
    await db.customStatement(
      'INSERT INTO orders (id, order_number, customer_id, status, expected_pickup_date, '
      'subtotal, total, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);',
      ['ord-active', '26-001', 'cust-pay', 'processing', nowTimestamp, 10000, 10000, nowTimestamp, nowTimestamp],
    );

    // 2. Completed order
    await db.customStatement(
      'INSERT INTO orders (id, order_number, customer_id, status, expected_pickup_date, '
      'subtotal, total, completed_at, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
      ['ord-completed', '26-002', 'cust-pay', 'completed', nowTimestamp, 5000, 5000, nowTimestamp, nowTimestamp, nowTimestamp],
    );

    // 3. Cancelled order
    await db.customStatement(
      'INSERT INTO orders (id, order_number, customer_id, status, expected_pickup_date, '
      'subtotal, total, cancelled_at, cancellation_reason, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
      ['ord-cancelled', '26-003', 'cust-pay', 'cancelled', nowTimestamp, 5000, 5000, nowTimestamp, 'سبب الإلغاء', nowTimestamp, nowTimestamp],
    );
  });

  tearDown(() async {
    await db.close();
  });

  Payment createPayment({
    required String id,
    required String orderId,
    required int amountPiastres,
    PaymentMethod method = PaymentMethod.cash,
  }) {
    final now = DateTime.now();
    return Payment(
      id: id,
      orderId: orderId,
      amount: Money.fromPiastres(amountPiastres),
      paymentMethod: method,
      paidAt: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('PaymentRepositoryImpl Hardening Tests', () {
    test('payment on Completed order is rejected with BusinessRuleFailure', () async {
      expect(
        () => paymentRepository.recordPayment(
          createPayment(id: 'pay-comp', orderId: 'ord-completed', amountPiastres: 1000),
        ),
        throwsA(
          isA<BusinessRuleFailure>().having(
            (e) => e.message,
            'message',
            contains('completed order'),
          ),
        ),
      );
    });

    test('payment on Cancelled order is rejected with BusinessRuleFailure', () async {
      expect(
        () => paymentRepository.recordPayment(
          createPayment(id: 'pay-canc', orderId: 'ord-cancelled', amountPiastres: 1000),
        ),
        throwsA(
          isA<BusinessRuleFailure>().having(
            (e) => e.message,
            'message',
            contains('cancelled order'),
          ),
        ),
      );
    });

    test('amount <= 0 is rejected with ValidationFailure', () async {
      // amount = 0
      expect(
        () => paymentRepository.recordPayment(
          _TestZeroPayment(id: 'pay-zero', orderId: 'ord-active'),
        ),
        throwsA(
          isA<ValidationFailure>().having(
            (e) => e.message,
            'message',
            contains('greater than zero'),
          ),
        ),
      );

      // amount < 0 (negative)
      expect(
        () => paymentRepository.recordPayment(
          _TestZeroPayment(id: 'pay-neg', orderId: 'ord-active', amount: const Money.fromPiastres(-500)),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('amount > remaining is rejected with BusinessRuleFailure', () async {
      // Total is 10000 piastres. Trying to pay 10001
      expect(
        () => paymentRepository.recordPayment(
          createPayment(id: 'pay-over', orderId: 'ord-active', amountPiastres: 10001),
        ),
        throwsA(
          isA<BusinessRuleFailure>().having(
            (e) => e.message,
            'message',
            contains('exceeds remaining'),
          ),
        ),
      );
    });

    test('exact remaining amount is allowed and leaves remaining balance at 0', () async {
      final payment = await paymentRepository.recordPayment(
        createPayment(id: 'pay-exact', orderId: 'ord-active', amountPiastres: 10000),
      );

      expect(payment.amount.piastres, 10000);

      final totalPaid = await paymentsDao.getTotalPaidForOrder('ord-active');
      expect(totalPaid, 10000);
    });

    test('multiple payments allowed up to remaining and overpayment after previous payments is rejected', () async {
      // First partial payment: 4000
      await paymentRepository.recordPayment(
        createPayment(id: 'pay-part1', orderId: 'ord-active', amountPiastres: 4000),
      );

      // Second partial payment: 3000 (total paid = 7000, remaining = 3000)
      await paymentRepository.recordPayment(
        createPayment(id: 'pay-part2', orderId: 'ord-active', amountPiastres: 3000, method: PaymentMethod.instapay),
      );

      final paidSoFar = await paymentsDao.getTotalPaidForOrder('ord-active');
      expect(paidSoFar, 7000);

      // Attempt payment of 3500 (exceeds remaining of 3000) -> rejected
      expect(
        () => paymentRepository.recordPayment(
          createPayment(id: 'pay-over2', orderId: 'ord-active', amountPiastres: 3500),
        ),
        throwsA(
          isA<BusinessRuleFailure>().having(
            (e) => e.message,
            'message',
            contains('exceeds remaining'),
          ),
        ),
      );

      // Final payment of exact remaining 3000 -> allowed
      final finalPay = await paymentRepository.recordPayment(
        createPayment(id: 'pay-final', orderId: 'ord-active', amountPiastres: 3000, method: PaymentMethod.ewallet),
      );

      expect(finalPay.amount.piastres, 3000);
      final finalTotalPaid = await paymentsDao.getTotalPaidForOrder('ord-active');
      expect(finalTotalPaid, 10000);
    });

    test('getPaymentSummariesForOrders returns batch paid and remaining amounts accurately in a single grouped query', () async {
      await paymentRepository.recordPayment(
        createPayment(id: 'pay-batch-1', orderId: 'ord-active', amountPiastres: 4000),
      );

      final summaries = await paymentRepository.getPaymentSummariesForOrders(['ord-active', 'non-existent']);

      expect(summaries.containsKey('ord-active'), isTrue);
      expect(summaries['ord-active']!.totalPaid.piastres, equals(4000));
      expect(summaries['ord-active']!.remaining.piastres, equals(6000));
      expect(summaries.containsKey('non-existent'), isFalse);
    });
  });
}
