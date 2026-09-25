import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/network/dio_client.dart';

void main() {
  group('Refund Feature Phase 1 — Backend Integration & Business Rules Tests', () {
    late DioClient client;
    late Dio dio;
    bool isNetworkAvailable = true;

    final runId = (DateTime.now().microsecondsSinceEpoch % 0xFFFFFFFFFFFF)
        .toRadixString(16)
        .padLeft(12, '0');

    const clothesType = '00000000-0000-0000-0001-000000000001';
    const shirtDef = '00000000-0000-0000-0005-000000000001';
    const washService = '00000000-0000-0000-0002-000000000001';

    late final String customerId;
    late final String customerPhone;

    int baseSeq = 0;

    // Helper to send mutation requests without throwing on non-2xx
    Future<Response<dynamic>> postSafe(
      String path,
      Map<String, dynamic> data, {
      String? opId,
    }) async {
      return dio.post(
        path,
        data: data,
        options: Options(
          headers: opId != null ? {'X-Operation-ID': opId} : null,
          validateStatus: (status) => true,
        ),
      );
    }

    Future<Response<dynamic>> patchSafe(
      String path,
      Map<String, dynamic> data, {
      String? opId,
    }) async {
      return dio.patch(
        path,
        data: data,
        options: Options(
          headers: opId != null ? {'X-Operation-ID': opId} : null,
          validateStatus: (status) => true,
        ),
      );
    }

    setUpAll(() async {
      client = DioClient(
        receiveTimeout: const Duration(seconds: 30),
        connectTimeout: const Duration(seconds: 30),
      );
      dio = client.dio;

      try {
        final res = await dio.get('/customers', queryParameters: {'limit': 1});
        if (res.statusCode != 200) {
          isNetworkAvailable = false;
        }
      } catch (_) {
        isNetworkAvailable = false;
      }

      if (!isNetworkAvailable) return;

      final syncRes = await dio.get('/sync/changes', queryParameters: {'limit': 1});
      if (syncRes.statusCode == 200 && syncRes.data is Map) {
        baseSeq = syncRes.data['latest_sequence'] ?? 0;
      }

      customerId = 'c6000001-0001-4001-8001-$runId';
      customerPhone =
          '012${(DateTime.now().microsecondsSinceEpoch % 100000000).toString().padLeft(8, '0')}';

      // 1. Seed dedicated customer for this test run
      final custRes = await postSafe(
        '/customers',
        {
          'id': customerId,
          'name': 'عميل تجربة المرتجعات $runId',
          'phone': customerPhone,
        },
        opId: 'op-refund-cust-$runId',
      );
      expect(custRes.statusCode, isIn([200, 201]));
    });

    // Helper to seed an isolated order in specified status (non-cancelled)
    Future<String> seedOrder({
      required String orderSuffix,
      required String status,
      int total = 3000,
    }) async {
      final orderId = 'd600${orderSuffix.padLeft(4, '0')}-0001-4001-8001-$runId';
      final orderNum = 'ORD-TEST-REF-$orderSuffix-$runId';
      final itemId = 'e600${orderSuffix.padLeft(4, '0')}-0001-4001-8001-$runId';

      final res = await postSafe(
        '/orders',
        {
          'id': orderId,
          'order_number': orderNum,
          'customer_id': customerId,
          'status': 'processing',
          'expected_pickup_date': '2026-10-01T00:00:00.000Z',
          'subtotal': total,
          'discount': 0,
          'tax': 0,
          'total': total,
          'items': [
            {
              'id': itemId,
              'item_type_id': clothesType,
              'item_definition_id': shirtDef,
              'service_id': washService,
              'item_type_name_snapshot': 'ملابس',
              'service_name_snapshot': 'غسيل',
              'pricing_type': 'per_piece',
              'quantity': 1.0,
              'unit_price': total,
              'calculated_total': total,
            },
          ],
        },
        opId: 'op-seed-ord-$orderSuffix-$runId',
      );
      expect(res.statusCode, equals(201));

      if (status == 'ready' || status == 'completed') {
        await patchSafe(
          '/orders/$orderId',
          {'status': 'ready', 'updated_at': DateTime.now().toIso8601String()},
          opId: 'op-ready-ord-$orderSuffix-$runId',
        );
      }
      if (status == 'completed') {
        final now = DateTime.now().toIso8601String();
        await patchSafe(
          '/orders/$orderId',
          {'status': 'completed', 'completed_at': now, 'updated_at': now},
          opId: 'op-comp-ord-$orderSuffix-$runId',
        );
      }

      return orderId;
    }

    // Helper to seed a payment for an order while in processing/ready/completed
    Future<String> seedPayment({
      required String orderId,
      required int amount,
      String method = 'cash',
      String paymentSuffix = '0001',
    }) async {
      final paymentId = 'b600${paymentSuffix.padLeft(4, '0')}-0001-4001-8001-$runId';
      final res = await postSafe(
        '/payments',
        {
          'id': paymentId,
          'order_id': orderId,
          'amount': amount,
          'payment_method': method,
        },
        opId: 'op-seed-pay-$paymentSuffix-$runId',
      );
      expect(res.statusCode, equals(201));
      return paymentId;
    }

    // Helper to seed an order, optionally pay it while active, and then cancel it
    Future<String> createCancelledOrder({
      required String orderSuffix,
      int total = 3000,
      int? paymentAmount,
      String paymentMethod = 'cash',
    }) async {
      final orderId = await seedOrder(
        orderSuffix: orderSuffix,
        status: 'processing',
        total: total,
      );

      if (paymentAmount != null && paymentAmount > 0) {
        await seedPayment(
          orderId: orderId,
          amount: paymentAmount,
          method: paymentMethod,
          paymentSuffix: orderSuffix,
        );
      }

      final now = DateTime.now().toIso8601String();
      final cancRes = await patchSafe(
        '/orders/$orderId',
        {
          'status': 'cancelled',
          'cancelled_at': now,
          'cancellation_reason': 'إلغاء لاختبار الاسترداد',
          'updated_at': now,
        },
        opId: 'op-canc-ord-$orderSuffix-$runId',
      );
      expect(cancRes.statusCode, equals(200));

      return orderId;
    }

    // =========================================================================
    // 1. Refund succeeds for cancelled order
    // =========================================================================
    test('1. Refund succeeds for cancelled order', () async {
      if (!isNetworkAvailable) return;

      final orderId = await createCancelledOrder(
        orderSuffix: '0101',
        total: 2000,
        paymentAmount: 2000,
      );

      final refundId = 'f6000101-0001-4001-8001-$runId';
      final refundRes = await postSafe('/refunds', {
        'id': refundId,
        'order_id': orderId,
        'amount': 1000,
        'refund_method': 'cash',
        'reason': 'Customer requested refund',
      }, opId: 'op-ref-0101-$runId');

      expect(refundRes.statusCode, equals(201));
      final data = refundRes.data is Map ? refundRes.data : {};
      expect(data['id'], equals(refundId));
      expect(data['order_id'], equals(orderId));
      expect(data['amount'], equals(1000));
      expect(data['refund_method'], equals('cash'));
      expect(data['reason'], equals('Customer requested refund'));
    });

    // =========================================================================
    // 2. Refund rejected for processing order
    // =========================================================================
    test('2. Refund rejected for processing order', () async {
      if (!isNetworkAvailable) return;

      final orderId = await seedOrder(orderSuffix: '0201', status: 'processing', total: 1500);
      await seedPayment(orderId: orderId, amount: 1500, paymentSuffix: '0201');

      final refundRes = await postSafe('/refunds', {
        'id': 'f6000201-0001-4001-8001-$runId',
        'order_id': orderId,
        'amount': 1500,
        'refund_method': 'cash',
      }, opId: 'op-ref-0201-$runId');

      expect(refundRes.statusCode, equals(409));
      final error = refundRes.data['error'] ?? refundRes.data['code'];
      expect(error, equals('INVALID_LIFECYCLE_TRANSITION'));
    });

    // =========================================================================
    // 3. Refund rejected for ready order
    // =========================================================================
    test('3. Refund rejected for ready order', () async {
      if (!isNetworkAvailable) return;

      final orderId = await seedOrder(orderSuffix: '0301', status: 'ready', total: 1800);
      await seedPayment(orderId: orderId, amount: 1800, paymentSuffix: '0301');

      final refundRes = await postSafe('/refunds', {
        'id': 'f6000301-0001-4001-8001-$runId',
        'order_id': orderId,
        'amount': 1800,
        'refund_method': 'cash',
      }, opId: 'op-ref-0301-$runId');

      expect(refundRes.statusCode, equals(409));
      final error = refundRes.data['error'] ?? refundRes.data['code'];
      expect(error, equals('INVALID_LIFECYCLE_TRANSITION'));
    });

    // =========================================================================
    // 4. Refund rejected for completed order
    // =========================================================================
    test('4. Refund rejected for completed order', () async {
      if (!isNetworkAvailable) return;

      final orderId = await seedOrder(orderSuffix: '0401', status: 'completed', total: 2200);
      await seedPayment(orderId: orderId, amount: 2200, paymentSuffix: '0401');

      final refundRes = await postSafe('/refunds', {
        'id': 'f6000401-0001-4001-8001-$runId',
        'order_id': orderId,
        'amount': 2200,
        'refund_method': 'cash',
      }, opId: 'op-ref-0401-$runId');

      expect(refundRes.statusCode, equals(409));
      final error = refundRes.data['error'] ?? refundRes.data['code'];
      expect(error, equals('INVALID_LIFECYCLE_TRANSITION'));
    });

    // =========================================================================
    // 5. Refund amount <= 0 rejected
    // =========================================================================
    test('5. Refund amount <= 0 rejected', () async {
      if (!isNetworkAvailable) return;

      final orderId = await createCancelledOrder(
        orderSuffix: '0501',
        total: 2000,
        paymentAmount: 2000,
      );

      // Amount = 0
      final zeroRes = await postSafe('/refunds', {
        'id': 'f6000501-0001-4001-8001-$runId',
        'order_id': orderId,
        'amount': 0,
        'refund_method': 'cash',
      }, opId: 'op-ref-0501-zero-$runId');

      expect(zeroRes.statusCode, equals(422));
      final zeroError = zeroRes.data['error'] ?? zeroRes.data['code'];
      expect(zeroError, equals('BUSINESS_RULE_VIOLATION'));

      // Amount < 0
      final negRes = await postSafe('/refunds', {
        'id': 'f6000502-0001-4001-8001-$runId',
        'order_id': orderId,
        'amount': -500,
        'refund_method': 'cash',
      }, opId: 'op-ref-0501-neg-$runId');

      expect(negRes.statusCode, equals(422));
      final negError = negRes.data['error'] ?? negRes.data['code'];
      expect(negError, equals('BUSINESS_RULE_VIOLATION'));
    });

    // =========================================================================
    // 6. Refund greater than total paid rejected
    // =========================================================================
    test('6. Refund greater than total paid rejected', () async {
      if (!isNetworkAvailable) return;

      // Order paid 1000, attempt refund 1500
      final orderId = await createCancelledOrder(
        orderSuffix: '0601',
        total: 2000,
        paymentAmount: 1000,
      );

      final refundRes = await postSafe('/refunds', {
        'id': 'f6000601-0001-4001-8001-$runId',
        'order_id': orderId,
        'amount': 1500, // Exceeds total paid 1000
        'refund_method': 'cash',
      }, opId: 'op-ref-0601-$runId');

      expect(refundRes.statusCode, equals(409));
      final error = refundRes.data['error'] ?? refundRes.data['code'];
      expect(error, equals('REFUND_BALANCE_EXCEEDED'));
    });

    // =========================================================================
    // 7. Partial refund succeeds
    // =========================================================================
    late String partialOrderId;
    test('7. Partial refund succeeds', () async {
      if (!isNetworkAvailable) return;

      partialOrderId = await createCancelledOrder(
        orderSuffix: '0701',
        total: 3000,
        paymentAmount: 3000,
      );

      final refundRes = await postSafe('/refunds', {
        'id': 'f6000701-0001-4001-8001-$runId',
        'order_id': partialOrderId,
        'amount': 1000,
        'refund_method': 'cash',
      }, opId: 'op-ref-0701-$runId');

      expect(refundRes.statusCode, equals(201));
      expect(refundRes.data['amount'], equals(1000));
    });

    // =========================================================================
    // 8. Multiple partial refunds succeed until total paid
    // =========================================================================
    test('8. Multiple partial refunds succeed until total paid', () async {
      if (!isNetworkAvailable) return;

      // Order total paid is 3000. 1000 already refunded in test 7.
      // Second partial refund: 1000
      final res2 = await postSafe('/refunds', {
        'id': 'f6000801-0001-4001-8001-$runId',
        'order_id': partialOrderId,
        'amount': 1000,
        'refund_method': 'insta_pay',
      }, opId: 'op-ref-0801-$runId');
      expect(res2.statusCode, equals(201));
      expect(res2.data['amount'], equals(1000));

      // Third partial refund: 1000 (total refunded now = 3000 == total paid)
      final res3 = await postSafe('/refunds', {
        'id': 'f6000802-0001-4001-8001-$runId',
        'order_id': partialOrderId,
        'amount': 1000,
        'refund_method': 'e_wallet',
      }, opId: 'op-ref-0802-$runId');
      expect(res3.statusCode, equals(201));
      expect(res3.data['amount'], equals(1000));
    });

    // =========================================================================
    // 9. Refund exceeding remaining refundable rejected
    // =========================================================================
    test('9. Refund exceeding remaining refundable rejected', () async {
      if (!isNetworkAvailable) return;

      // partialOrderId now has 3000 paid and 3000 refunded (refundable = 0)
      final excessRes = await postSafe('/refunds', {
        'id': 'f6000901-0001-4001-8001-$runId',
        'order_id': partialOrderId,
        'amount': 100, // Exceeds 0
        'refund_method': 'cash',
      }, opId: 'op-ref-0901-$runId');

      expect(excessRes.statusCode, equals(409));
      final error = excessRes.data['error'] ?? excessRes.data['code'];
      expect(error, equals('REFUND_BALANCE_EXCEEDED'));
    });

    // =========================================================================
    // 10. Full refund succeeds
    // =========================================================================
    late String fullRefundOrderId;
    late String fullRefundId;
    test('10. Full refund succeeds', () async {
      if (!isNetworkAvailable) return;

      fullRefundOrderId = await createCancelledOrder(
        orderSuffix: '1001',
        total: 2500,
        paymentAmount: 2500,
      );

      fullRefundId = 'f6001001-0001-4001-8001-$runId';
      final res = await postSafe('/refunds', {
        'id': fullRefundId,
        'order_id': fullRefundOrderId,
        'amount': 2500,
        'refund_method': 'cash',
      }, opId: 'op-ref-1001-$runId');

      expect(res.statusCode, equals(201));
      expect(res.data['id'], equals(fullRefundId));
      expect(res.data['amount'], equals(2500));
    });

    // =========================================================================
    // 11. Refund after full refund rejected
    // =========================================================================
    test('11. Refund after full refund rejected', () async {
      if (!isNetworkAvailable) return;

      final res = await postSafe('/refunds', {
        'id': 'f6001101-0001-4001-8001-$runId',
        'order_id': fullRefundOrderId,
        'amount': 500,
        'refund_method': 'cash',
      }, opId: 'op-ref-1101-$runId');

      expect(res.statusCode, equals(409));
      final error = res.data['error'] ?? res.data['code'];
      expect(error, equals('REFUND_BALANCE_EXCEEDED'));
    });

    // =========================================================================
    // 12. Original payment remains unchanged
    // =========================================================================
    test('12. Original payment remains unchanged', () async {
      if (!isNetworkAvailable) return;

      // Query payments for fullRefundOrderId
      final payRes = await dio.get(
        '/payments',
        queryParameters: {'order_id': fullRefundOrderId},
      );
      expect(payRes.statusCode, equals(200));
      final List payments = payRes.data is List ? payRes.data : [];
      expect(payments.length, equals(1));
      expect(payments.first['amount'], equals(2500));
      expect(payments.first['order_id'], equals(fullRefundOrderId));
    });

    // =========================================================================
    // 13. Cancelled order remains cancelled
    // =========================================================================
    test('13. Cancelled order remains cancelled', () async {
      if (!isNetworkAvailable) return;

      final ordRes = await dio.get('/orders/$fullRefundOrderId');
      expect(ordRes.statusCode, equals(200));
      expect(ordRes.data['status'], equals('cancelled'));
      expect(ordRes.data['cancelled_at'], isNotNull);
    });

    // =========================================================================
    // 14. Retry with same operation_id is idempotent
    // =========================================================================
    test('14. Retry with same operation_id is idempotent', () async {
      if (!isNetworkAvailable) return;

      // Re-send the exact request from test 10 with op-ref-1001-$runId
      final retryRes = await postSafe('/refunds', {
        'id': fullRefundId,
        'order_id': fullRefundOrderId,
        'amount': 2500,
        'refund_method': 'cash',
      }, opId: 'op-ref-1001-$runId');

      expect(retryRes.statusCode, isIn([200, 201]));
      expect(retryRes.data['id'], equals(fullRefundId));
      expect(retryRes.data['amount'], equals(2500));
    });

    // =========================================================================
    // 15. Concurrent refunds cannot exceed total paid
    // =========================================================================
    test('15. Concurrent refunds cannot exceed total paid', () async {
      if (!isNetworkAvailable) return;

      final concurOrderId = await createCancelledOrder(
        orderSuffix: '1501',
        total: 1000,
        paymentAmount: 1000,
      );

      // Send two concurrent refunds of 800 each (sum 1600 > 1000)
      final fut1 = postSafe('/refunds', {
        'id': 'f6001501-0001-4001-8001-$runId',
        'order_id': concurOrderId,
        'amount': 800,
        'refund_method': 'cash',
      }, opId: 'op-concur1-$runId');

      final fut2 = postSafe('/refunds', {
        'id': 'f6001502-0001-4001-8001-$runId',
        'order_id': concurOrderId,
        'amount': 800,
        'refund_method': 'cash',
      }, opId: 'op-concur2-$runId');

      final results = await Future.wait([fut1, fut2]);
      final statusCodes = results.map((r) => r.statusCode).toList();

      // Exactly one succeeds (201) and one fails with 409
      expect(statusCodes, contains(201));
      expect(statusCodes, contains(409));
    });

    // =========================================================================
    // 16. Exactly one sync_changes row is created per successful refund
    // =========================================================================
    test('16. Exactly one sync_changes row is created per successful refund', () async {
      if (!isNetworkAvailable) return;

      final syncRes = await dio.get(
        '/sync/changes',
        queryParameters: {'after': baseSeq, 'limit': 500},
      );
      expect(syncRes.statusCode, equals(200));
      final List changes = syncRes.data['changes'] ?? [];

      // Find changes for fullRefundId
      final refundChanges = changes.where((c) =>
          c['entity_type'] == 'refund' &&
          c['entity_id'] == fullRefundId &&
          c['operation_type'] == 'create').toList();

      expect(refundChanges.length, equals(1));
      expect(refundChanges.first['server_version'], isNull); // Immutable append-only
    });

    // =========================================================================
    // 17. No sync_changes row is created for rejected refund
    // =========================================================================
    test('17. No sync_changes row is created for rejected refund', () async {
      if (!isNetworkAvailable) return;

      final failedRefundId = 'f6000601-0001-4001-8001-$runId'; // from test 6

      final syncRes = await dio.get(
        '/sync/changes',
        queryParameters: {'after': baseSeq, 'limit': 500},
      );
      expect(syncRes.statusCode, equals(200));
      final List changes = syncRes.data['changes'] ?? [];

      final failedChanges = changes.where((c) =>
          c['entity_type'] == 'refund' &&
          c['entity_id'] == failedRefundId).toList();

      expect(failedChanges, isEmpty);
    });

    // =========================================================================
    // 18. Refund method validation
    // =========================================================================
    test('18. Refund method validation', () async {
      if (!isNetworkAvailable) return;

      final orderId = await createCancelledOrder(
        orderSuffix: '1801',
        total: 3000,
        paymentAmount: 3000,
      );

      // Invalid method
      final invalidRes = await postSafe('/refunds', {
        'id': 'f6001801-0001-4001-8001-$runId',
        'order_id': orderId,
        'amount': 500,
        'refund_method': 'bitcoin',
      }, opId: 'op-ref-1801-bad-$runId');

      expect(invalidRes.statusCode, equals(422));
      final error = invalidRes.data['error'] ?? invalidRes.data['code'];
      expect(error, equals('BUSINESS_RULE_VIOLATION'));

      // Valid method e_wallet
      final validRes = await postSafe('/refunds', {
        'id': 'f6001802-0001-4001-8001-$runId',
        'order_id': orderId,
        'amount': 500,
        'refund_method': 'e_wallet',
      }, opId: 'op-ref-1801-ok-$runId');

      expect(validRes.statusCode, equals(201));
    });

    // =========================================================================
    // 19. Refund with no payment is rejected because refundable amount = 0
    // =========================================================================
    test('19. Refund with no payment is rejected because refundable amount = 0', () async {
      if (!isNetworkAvailable) return;

      // Seed order directly cancelled with 0 payments
      final orderId = await createCancelledOrder(
        orderSuffix: '1901',
        total: 1500,
      );

      final refundRes = await postSafe('/refunds', {
        'id': 'f6001901-0001-4001-8001-$runId',
        'order_id': orderId,
        'amount': 500,
        'refund_method': 'cash',
      }, opId: 'op-ref-1901-$runId');

      expect(refundRes.statusCode, equals(409));
      final error = refundRes.data['error'] ?? refundRes.data['code'];
      expect(error, equals('REFUND_BALANCE_EXCEEDED'));
    });

    // =========================================================================
    // 20. Refund history remains preserved
    // =========================================================================
    test('20. Refund history remains preserved', () async {
      if (!isNetworkAvailable) return;

      // Verify the refund records created in test 7 and 8 still exist in sync_changes
      final syncRes = await dio.get(
        '/sync/changes',
        queryParameters: {'after': baseSeq, 'limit': 500},
      );
      expect(syncRes.statusCode, equals(200));
      final List changes = syncRes.data['changes'] ?? [];

      final test7Change = changes.any((c) =>
          c['entity_type'] == 'refund' &&
          c['entity_id'] == 'f6000701-0001-4001-8001-$runId');
      final test8Change1 = changes.any((c) =>
          c['entity_type'] == 'refund' &&
          c['entity_id'] == 'f6000801-0001-4001-8001-$runId');
      final test8Change2 = changes.any((c) =>
          c['entity_type'] == 'refund' &&
          c['entity_id'] == 'f6000802-0001-4001-8001-$runId');

      expect(test7Change, isTrue);
      expect(test8Change1, isTrue);
      expect(test8Change2, isTrue);
    });
  });
}
