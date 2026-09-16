import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/core/network/dio_client.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart'
    hide Payment;
import 'package:laundry_management/data/repositories/payment_repository_impl.dart';
import 'package:laundry_management/data/sync/sync_payload_builder.dart';
import 'package:laundry_management/domain/entities/payment.dart';
import 'package:laundry_management/domain/enums/payment_method.dart';
import 'package:laundry_management/domain/value_objects/money.dart';

class _FailingSyncOperationsDao extends SyncOperationsDao {
  _FailingSyncOperationsDao(super.attachedDatabase);

  @override
  Future<void> recordOperation({
    required String entityType,
    required String entityId,
    required String operationType,
    String? payload,
    DateTime? nextRetryAt,
  }) async {
    throw Exception('Simulated sync enqueue database error');
  }
}

void main() {
  group('Step 10 — Payment Payload Builder & Domain Contract Tests', () {
    test(
      'PaymentMethod.fromValue resolves standard, snake_case, and camelCase representations',
      () {
        expect(PaymentMethod.fromValue('cash'), equals(PaymentMethod.cash));
        expect(
          PaymentMethod.fromValue('instapay'),
          equals(PaymentMethod.instapay),
        );
        expect(
          PaymentMethod.fromValue('insta_pay'),
          equals(PaymentMethod.instapay),
        );
        expect(
          PaymentMethod.fromValue('instaPay'),
          equals(PaymentMethod.instapay),
        );
        expect(
          PaymentMethod.fromValue('ewallet'),
          equals(PaymentMethod.ewallet),
        );
        expect(
          PaymentMethod.fromValue('e_wallet'),
          equals(PaymentMethod.ewallet),
        );
        expect(
          PaymentMethod.fromValue('eWallet'),
          equals(PaymentMethod.ewallet),
        );

        expect(
          () => PaymentMethod.fromValue('credit_card'),
          throwsArgumentError,
        );
      },
    );

    test(
      'SyncPayloadBuilder.buildPaymentPayload produces self-contained JSON with normalized snake_case methods and minor units',
      () {
        final now = DateTime.utc(2026, 9, 16, 10, 30, 0);

        final paymentCash = Payment(
          id: 'pay-001',
          orderId: 'ord-001',
          amount: const Money.fromPiastres(15000),
          paymentMethod: PaymentMethod.cash,
          paidAt: now,
          createdAt: now,
          updatedAt: now,
        );

        final payloadCashStr = SyncPayloadBuilder.buildPaymentPayload(
          paymentCash,
        );
        final payloadCash = jsonDecode(payloadCashStr) as Map<String, dynamic>;

        expect(payloadCash['id'], equals('pay-001'));
        expect(payloadCash['order_id'], equals('ord-001'));
        expect(payloadCash['amount'], equals(15000));
        expect(payloadCash['payment_method'], equals('cash'));
        expect(payloadCash['paid_at'], equals('2026-09-16T10:30:00.000Z'));
        expect(payloadCash['created_at'], equals('2026-09-16T10:30:00.000Z'));
        expect(payloadCash['updated_at'], equals('2026-09-16T10:30:00.000Z'));

        final paymentInsta = paymentCash.copyWith(
          id: 'pay-002',
          paymentMethod: PaymentMethod.instapay,
        );
        final payloadInsta =
            jsonDecode(SyncPayloadBuilder.buildPaymentPayload(paymentInsta))
                as Map<String, dynamic>;
        expect(payloadInsta['payment_method'], equals('insta_pay'));

        final paymentWallet = paymentCash.copyWith(
          id: 'pay-003',
          paymentMethod: PaymentMethod.ewallet,
        );
        final payloadWallet =
            jsonDecode(SyncPayloadBuilder.buildPaymentPayload(paymentWallet))
                as Map<String, dynamic>;
        expect(payloadWallet['payment_method'], equals('e_wallet'));
      },
    );
  });

  group(
    'Step 10 — Payment Repository Sync Operation Enqueue & Transaction Rollback',
    () {
      late AppDatabase db;
      late PaymentsDao paymentsDao;
      late OrdersDao ordersDao;
      late SyncOperationsDao syncOperationsDao;
      late PaymentRepositoryImpl repository;

      setUp(() async {
        db = AppDatabase(NativeDatabase.memory());
        paymentsDao = PaymentsDao(db);
        ordersDao = OrdersDao(db);
        syncOperationsDao = SyncOperationsDao(db);
        repository = PaymentRepositoryImpl(
          paymentsDao: paymentsDao,
          ordersDao: ordersDao,
          syncOperationsDao: syncOperationsDao,
          db: db,
        );

        final nowTimestamp =
            DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

        // Insert customer & order in local test database via customStatement
        await db.customStatement(
          'INSERT INTO customers (id, name, phone, created_at, updated_at) VALUES (?, ?, ?, ?, ?);',
          [
            'cust-local-1',
            'Local Customer',
            '01000000001',
            nowTimestamp,
            nowTimestamp,
          ],
        );

        await db.customStatement(
          'INSERT INTO orders (id, order_number, customer_id, customer_name_snapshot, customer_phone_snapshot, status, expected_pickup_date, subtotal, total, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
          [
            'ord-local-1',
            'ORD-LOC-01',
            'cust-local-1',
            'Local Customer',
            '01000000001',
            'processing',
            nowTimestamp,
            10000,
            10000,
            nowTimestamp,
            nowTimestamp,
          ],
        );
      });

      tearDown(() async {
        await db.close();
      });

      test(
        'recordPayment inserts local payment and enqueues sync operation with non-null self-contained payload',
        () async {
          final now = DateTime.now().toUtc();
          final payment = Payment(
            id: 'pay-loc-01',
            orderId: 'ord-local-1',
            amount: const Money.fromPiastres(5000),
            paymentMethod: PaymentMethod.instapay,
            paidAt: now,
            createdAt: now,
            updatedAt: now,
          );

          final result = await repository.recordPayment(payment);
          expect(result.id, equals('pay-loc-01'));

          // Verify local payment row
          final payments = await paymentsDao.getPaymentsForOrder('ord-local-1');
          expect(payments.length, equals(1));
          expect(payments.first.amount, equals(5000));

          // Verify sync operation
          final pendingOps = await syncOperationsDao.getPendingOperations();
          expect(pendingOps.length, equals(1));
          final op = pendingOps.first;
          expect(op.entityType, equals('payment'));
          expect(op.entityId, equals('pay-loc-01'));
          expect(op.operationType, equals('create'));
          expect(op.payload, isNotNull);

          final decoded = jsonDecode(op.payload!) as Map<String, dynamic>;
          expect(decoded['id'], equals('pay-loc-01'));
          expect(decoded['order_id'], equals('ord-local-1'));
          expect(decoded['amount'], equals(5000));
          expect(decoded['payment_method'], equals('insta_pay'));
        },
      );

      test(
        'recordPayment rolls back payment insertion when sync enqueue fails',
        () async {
          final failingSyncDao = _FailingSyncOperationsDao(db);
          final failingRepository = PaymentRepositoryImpl(
            paymentsDao: paymentsDao,
            ordersDao: ordersDao,
            syncOperationsDao: failingSyncDao,
            db: db,
          );

          final payment = Payment(
            id: 'pay-fail-01',
            orderId: 'ord-local-1',
            amount: const Money.fromPiastres(4000),
            paymentMethod: PaymentMethod.cash,
            paidAt: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          expect(
            () => failingRepository.recordPayment(payment),
            throwsA(isA<DatabaseFailure>()),
          );

          // Verify transaction rolled back: no payments exist in database
          final payments = await paymentsDao.getPaymentsForOrder('ord-local-1');
          expect(payments, isEmpty);

          // Verify no sync operations recorded
          final ops = await syncOperationsDao.getPendingOperations();
          expect(ops, isEmpty);
        },
      );
    },
  );

  group('Step 10 — Live Supabase Payment Backend Integration Tests', () {
    late DioClient client;
    late Dio dio;
    bool isNetworkAvailable = true;

    // Unique per-run UUID generator to guarantee test idempotency and isolation
    final runId = DateTime.now().millisecondsSinceEpoch
        .toRadixString(16)
        .padLeft(12, '0');
    late final String testCustomerId;
    late final String testServiceId;
    late final String testActiveOrderId;
    late final String testCancelledOrderId;
    late final String testPaymentId;
    late final String testOpId;

    setUpAll(() async {
      client = DioClient();
      dio = client.dio;

      testCustomerId = 'c1000000-0000-4000-8000-$runId';
      testServiceId = 'b1000000-0000-4000-8000-$runId';
      testActiveOrderId = 'd1000000-0000-4000-8000-$runId';
      testCancelledOrderId = 'd2000000-0000-4000-8000-$runId';
      testPaymentId = 'a1000000-0000-4000-8000-$runId';
      testOpId = 'op-step10-pay-$runId';

      try {
        final res = await dio.get('/customers', queryParameters: {'limit': 1});
        if (res.statusCode != 200) {
          isNetworkAvailable = false;
        }
      } catch (_) {
        isNetworkAvailable = false;
      }

      if (isNetworkAvailable) {
        final phone = '010${DateTime.now().millisecondsSinceEpoch % 100000000}'
            .padRight(11, '7');
        // Seed customer
        await dio.post(
          '/customers',
          data: {
            'id': testCustomerId,
            'name': 'Step 10 Live Payment Tester $runId',
            'phone': phone,
            'notes': 'Test customer for Step 10 live payment verification',
          },
          options: Options(
            headers: {'X-Operation-ID': 'op-step10-seed-cust-$runId'},
            validateStatus: (_) => true,
          ),
        );

        // Seed service
        await dio.post(
          '/services',
          data: {
            'id': testServiceId,
            'name': 'خدمة اختبار دفع $runId',
            'pricing_type': 'fixed_price',
            'price': 10000,
            'is_active': true,
          },
          options: Options(
            headers: {'X-Operation-ID': 'op-step10-seed-srv-$runId'},
            validateStatus: (_) => true,
          ),
        );

        // Seed active order (Total: 20000 piastres = 200 EGP)
        await dio.post(
          '/orders',
          data: {
            'id': testActiveOrderId,
            'order_number': 'ORD-PAY-$runId',
            'customer_id': testCustomerId,
            'customer_name_snapshot': 'Step 10 Live Payment Tester',
            'customer_phone_snapshot': phone,
            'status': 'processing',
            'expected_pickup_date': '2026-09-30T00:00:00.000',
            'subtotal': 20000,
            'total': 20000,
            'items': [
              {
                'id': 'e1000000-0000-4000-8000-$runId',
                'item_type_id': 'it-test',
                'service_id': testServiceId,
                'pricing_type': 'fixed_price',
                'quantity': 2.0,
                'unit_price': 10000,
                'calculated_total': 20000,
              },
            ],
          },
          options: Options(
            headers: {'X-Operation-ID': 'op-step10-seed-order-$runId'},
            validateStatus: (_) => true,
          ),
        );

        // Seed cancelled order
        await dio.post(
          '/orders',
          data: {
            'id': testCancelledOrderId,
            'order_number': 'ORD-CAN-$runId',
            'customer_id': testCustomerId,
            'customer_name_snapshot': 'Step 10 Live Payment Tester',
            'customer_phone_snapshot': phone,
            'status': 'cancelled',
            'cancellation_reason': 'Customer request',
            'expected_pickup_date': '2026-09-30T00:00:00.000',
            'subtotal': 10000,
            'total': 10000,
            'items': [],
          },
          options: Options(
            headers: {'X-Operation-ID': 'op-step10-seed-cancel-$runId'},
            validateStatus: (_) => true,
          ),
        );
      }
    });

    test(
      '1. Valid payment creation: returns 201, records payment, and increments order paid_amount atomically',
      () async {
        if (!isNetworkAvailable) return;

        final res = await dio.post(
          '/payments',
          data: {
            'id': testPaymentId,
            'order_id': testActiveOrderId,
            'amount': 8000, // 80 EGP
            'payment_method': 'cash',
            'paid_at': DateTime.now().toUtc().toIso8601String(),
          },
          options: Options(
            headers: {'X-Operation-ID': testOpId},
            validateStatus: (_) => true,
          ),
        );

        expect(res.statusCode, equals(201));
        expect(res.data['id'], equals(testPaymentId));
        expect(res.data['order_id'], equals(testActiveOrderId));
        expect(res.data['amount'], equals(8000));
        expect(res.data['payment_method'], equals('cash'));

        // Verify order paid_amount updated atomically
        final orderRes = await dio.get('/orders/$testActiveOrderId');
        expect(orderRes.statusCode, equals(200));
        expect(orderRes.data['paid_amount'], equals(8000));
      },
    );

    test(
      '2. Idempotency: exact duplicate replay returns cached response without duplicate payment or balance increment',
      () async {
        if (!isNetworkAvailable) return;

        final replayRes = await dio.post(
          '/payments',
          data: {
            'id': testPaymentId,
            'order_id': testActiveOrderId,
            'amount': 8000,
            'payment_method': 'cash',
          },
          options: Options(
            headers: {'X-Operation-ID': testOpId},
            validateStatus: (_) => true,
          ),
        );

        expect(replayRes.statusCode, isIn([200, 201]));
        expect(replayRes.data['id'], equals(testPaymentId));
        expect(replayRes.data['amount'], equals(8000));

        // Verify paid_amount is still 8000 (not 16000)
        final orderRes = await dio.get('/orders/$testActiveOrderId');
        expect(orderRes.statusCode, equals(200));
        expect(orderRes.data['paid_amount'], equals(8000));
      },
    );

    test(
      '3. Overpayment rejection: payment exceeding remaining balance is rejected with 409 CONFLICT',
      () async {
        if (!isNetworkAvailable) return;

        // Order total = 20000, paid_amount = 8000, remaining = 12000.
        // Attempting to pay 15000 -> exceeds 12000 remaining.
        final overpayId = 'a1000000-0000-4000-8000-000000000099';
        final opId = 'op-step10-overpay-reject-1';

        final res = await dio.post(
          '/payments',
          data: {
            'id': overpayId,
            'order_id': testActiveOrderId,
            'amount': 15000,
            'payment_method': 'insta_pay',
          },
          options: Options(
            headers: {'X-Operation-ID': opId},
            validateStatus: (_) => true,
          ),
        );

        expect(res.statusCode, equals(409));
        expect(res.data['code'], equals('CONFLICT'));
        expect(res.data['message'], contains('exceeds'));

        // Verify order paid_amount remained at 8000
        final orderRes = await dio.get('/orders/$testActiveOrderId');
        expect(orderRes.data['paid_amount'], equals(8000));
      },
    );

    test(
      '4. Cancelled order rejection: payment on cancelled order is rejected with 409 CONFLICT',
      () async {
        if (!isNetworkAvailable) return;

        final res = await dio.post(
          '/payments',
          data: {
            'id': 'a1000000-0000-4000-8000-000000000088',
            'order_id': testCancelledOrderId,
            'amount': 5000,
            'payment_method': 'cash',
          },
          options: Options(
            headers: {'X-Operation-ID': 'op-step10-cancelled-pay-1'},
            validateStatus: (_) => true,
          ),
        );

        expect(res.statusCode, equals(409));
        expect(res.data['code'], equals('CONFLICT'));
        expect(res.data['message'], contains('cancelled'));
      },
    );

    test(
      '5. Zero and negative amount rejection: rejected with 422 VALIDATION_ERROR',
      () async {
        if (!isNetworkAvailable) return;

        // Zero
        final zeroRes = await dio.post(
          '/payments',
          data: {
            'id': 'a1000000-0000-4000-8000-000000000077',
            'order_id': testActiveOrderId,
            'amount': 0,
            'payment_method': 'cash',
          },
          options: Options(
            headers: {'X-Operation-ID': 'op-step10-zero-pay-1'},
            validateStatus: (_) => true,
          ),
        );
        expect(zeroRes.statusCode, equals(422));
        expect(zeroRes.data['code'], equals('VALIDATION_ERROR'));

        // Negative
        final negRes = await dio.post(
          '/payments',
          data: {
            'id': 'a1000000-0000-4000-8000-000000000076',
            'order_id': testActiveOrderId,
            'amount': -500,
            'payment_method': 'cash',
          },
          options: Options(
            headers: {'X-Operation-ID': 'op-step10-neg-pay-1'},
            validateStatus: (_) => true,
          ),
        );
        expect(negRes.statusCode, equals(422));
        expect(negRes.data['code'], equals('VALIDATION_ERROR'));
      },
    );

    test(
      '6. Invalid payment method rejection: rejected with 422 VALIDATION_ERROR',
      () async {
        if (!isNetworkAvailable) return;

        final res = await dio.post(
          '/payments',
          data: {
            'id': 'a1000000-0000-4000-8000-000000000066',
            'order_id': testActiveOrderId,
            'amount': 1000,
            'payment_method': 'bitcoin',
          },
          options: Options(
            headers: {'X-Operation-ID': 'op-step10-invalid-method-1'},
            validateStatus: (_) => true,
          ),
        );

        expect(res.statusCode, equals(422));
        expect(res.data['code'], equals('VALIDATION_ERROR'));
      },
    );

    test('7. Missing order rejection: returns 404 NOT_FOUND', () async {
      if (!isNetworkAvailable) return;

      final res = await dio.post(
        '/payments',
        data: {
          'id': 'a1000000-0000-4000-8000-000000000055',
          'order_id': '00000000-0000-0000-0000-000000000000',
          'amount': 1000,
          'payment_method': 'cash',
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step10-missing-order-1'},
          validateStatus: (_) => true,
        ),
      );

      expect(res.statusCode, equals(404));
      expect(res.data['code'], equals('NOT_FOUND'));
    });

    test(
      '8. GET /payments/:id and GET /payments?order_id=... return persisted payments',
      () async {
        if (!isNetworkAvailable) return;

        // GET by ID
        final getByIdRes = await dio.get('/payments/$testPaymentId');
        expect(getByIdRes.statusCode, equals(200));
        expect(getByIdRes.data['id'], equals(testPaymentId));
        expect(getByIdRes.data['order_id'], equals(testActiveOrderId));
        expect(getByIdRes.data['amount'], equals(8000));

        // GET by order ID
        final getByOrderRes = await dio.get(
          '/payments',
          queryParameters: {'order_id': testActiveOrderId},
        );
        expect(getByOrderRes.statusCode, equals(200));
        expect(getByOrderRes.data, isA<List>());
        final list = getByOrderRes.data as List;
        expect(list.any((p) => p['id'] == testPaymentId), isTrue);
      },
    );

    test(
      '9. Immutability: PATCH/DELETE /payments returns 404 NOT_FOUND',
      () async {
        if (!isNetworkAvailable) return;

        final patchRes = await dio.patch(
          '/payments/$testPaymentId',
          data: {'amount': 9000},
          options: Options(validateStatus: (_) => true),
        );
        expect(patchRes.statusCode, equals(404));

        final deleteRes = await dio.delete(
          '/payments/$testPaymentId',
          options: Options(validateStatus: (_) => true),
        );
        expect(deleteRes.statusCode, equals(404));
      },
    );
  });
}
