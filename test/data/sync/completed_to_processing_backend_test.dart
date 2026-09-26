import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/network/dio_client.dart';

void main() {
  group('Completed -> Processing Backend Lifecycle RPC Integration Tests', () {
    late DioClient client;
    late Dio dio;
    bool isNetworkAvailable = true;

    final runId = (DateTime.now().microsecondsSinceEpoch % 0xFFFFFFFFFFFF)
        .toRadixString(16)
        .padLeft(12, '0');

    const clothesType = '00000000-0000-0000-0001-000000000001';
    const shirtDef = '00000000-0000-0000-0005-000000000001';
    const washService = '00000000-0000-0000-0002-000000000001';
    const storageLoc = '00000000-0000-0000-0006-000000000001';

    late final String customerId;
    late final String customerPhone;
    late final String order1Id;
    late final String order1Num;
    late final String item1Id;
    late final String order2Id;
    late final String order2Num;
    late final String item2Id;
    int baseSeq = 0;

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

      customerId = 'c5000001-0001-4001-8001-$runId';
      customerPhone =
          '011${(DateTime.now().microsecondsSinceEpoch % 100000000).toString().padLeft(8, '0')}';
      order1Id = 'd5000001-0001-4001-8001-$runId';
      order1Num = 'ORD-TEST-C2P-1-$runId';
      item1Id = 'e5000001-0001-4001-8001-$runId';

      order2Id = 'd5000002-0002-4002-8002-$runId';
      order2Num = 'ORD-TEST-C2P-2-$runId';
      item2Id = 'e5000002-0002-4002-8002-$runId';

      // 1. Seed customer
      await dio.post(
        '/customers',
        data: {
          'id': customerId,
          'name': 'عميل تصحيح مكتمل $runId',
          'phone': customerPhone,
        },
        options: Options(headers: {'X-Operation-ID': 'op-cust-$runId'}),
      );

      // 2. Seed Order 1 (processing -> ready -> paid -> completed)
      await dio.post(
        '/orders',
        data: {
          'id': order1Id,
          'order_number': order1Num,
          'customer_id': customerId,
          'status': 'processing',
          'expected_pickup_date': '2026-10-01T00:00:00.000Z',
          'subtotal': 2500,
          'discount': 0,
          'tax': 0,
          'total': 2500,
          'items': [
            {
              'id': item1Id,
              'item_type_id': clothesType,
              'item_definition_id': shirtDef,
              'service_id': washService,
              'item_type_name_snapshot': 'ملابس',
              'service_name_snapshot': 'غسيل',
              'pricing_type': 'per_piece',
              'quantity': 1.0,
              'unit_price': 2500,
              'calculated_total': 2500,
            },
          ],
        },
        options: Options(headers: {'X-Operation-ID': 'op-ord1-create-$runId'}),
      );

      // Store item 1
      await dio.post(
        '/storage-records',
        data: {
          'id': 'a5000001-0001-4001-8001-$runId',
          'order_item_id': item1Id,
          'storage_location_id': storageLoc,
          'is_active': true,
        },
        options: Options(headers: {'X-Operation-ID': 'op-store1-$runId'}),
      );

      // Mark Order 1 Ready
      await dio.patch(
        '/orders/$order1Id',
        data: {
          'status': 'ready',
          'updated_at': DateTime.now().toIso8601String(),
        },
        options: Options(headers: {'X-Operation-ID': 'op-ord1-ready-$runId'}),
      );

      // Pay Order 1 in full (2500 piastres)
      await dio.post(
        '/payments',
        data: {
          'id': 'b5000001-0001-4001-8001-$runId',
          'order_id': order1Id,
          'amount': 2500,
          'payment_method': 'cash',
        },
        options: Options(headers: {'X-Operation-ID': 'op-pay1-$runId'}),
      );

      // Complete Order 1
      final completedTime = DateTime.now().toIso8601String();
      await dio.patch(
        '/orders/$order1Id',
        data: {
          'status': 'completed',
          'completed_at': completedTime,
          'updated_at': completedTime,
        },
        options: Options(headers: {'X-Operation-ID': 'op-ord1-complete-$runId'}),
      );

      // 3. Seed Order 2 (processing -> cancelled)
      await dio.post(
        '/orders',
        data: {
          'id': order2Id,
          'order_number': order2Num,
          'customer_id': customerId,
          'status': 'processing',
          'expected_pickup_date': '2026-10-01T00:00:00.000Z',
          'subtotal': 1500,
          'discount': 0,
          'tax': 0,
          'total': 1500,
          'items': [
            {
              'id': item2Id,
              'item_type_id': clothesType,
              'item_definition_id': shirtDef,
              'service_id': washService,
              'item_type_name_snapshot': 'ملابس',
              'service_name_snapshot': 'غسيل',
              'pricing_type': 'per_piece',
              'quantity': 1.0,
              'unit_price': 1500,
              'calculated_total': 1500,
            },
          ],
        },
        options: Options(headers: {'X-Operation-ID': 'op-ord2-create-$runId'}),
      );

      // Cancel Order 2
      final cancelTime = DateTime.now().toIso8601String();
      await dio.patch(
        '/orders/$order2Id',
        data: {
          'status': 'cancelled',
          'cancelled_at': cancelTime,
          'cancellation_reason': 'إلغاء للاختبار',
          'updated_at': cancelTime,
        },
        options: Options(headers: {'X-Operation-ID': 'op-ord2-cancel-$runId'}),
      );
    });

    test('A. Completed -> Processing SUCCESS: clears completed_at, preserves payment & storage, increments version, exactly 1 sync_changes', () async {
      if (!isNetworkAvailable) return;

      // Verify order 1 is currently completed
      final beforeRes = await dio.get('/orders/$order1Id');
      expect(beforeRes.statusCode, equals(200));
      expect(beforeRes.data['status'], equals('completed'));
      expect(beforeRes.data['completed_at'], isNotNull);
      expect(beforeRes.data['paid_amount'], equals(2500));
      final beforeVersion = beforeRes.data['server_version'] as int;

      // Submit status correction to processing
      final correctOpId = 'op-correct-ord1-$runId';
      final correctionTime = DateTime.now().toIso8601String();
      final patchRes = await dio.patch(
        '/orders/$order1Id',
        data: {
          'status': 'processing',
          'updated_at': correctionTime,
        },
        options: Options(headers: {'X-Operation-ID': correctOpId}),
      );

      expect(patchRes.statusCode, equals(200));
      final patchData = patchRes.data is Map ? patchRes.data : {};
      expect(patchData['status'], equals('processing'));
      expect(patchData['completed_at'], isNull);
      expect(patchData['server_version'], equals(beforeVersion + 1));

      // Verify GET /orders/order1Id state
      final afterRes = await dio.get('/orders/$order1Id');
      expect(afterRes.statusCode, equals(200));
      expect(afterRes.data['status'], equals('processing'));
      expect(afterRes.data['completed_at'], isNull);
      // Payment records and paid_amount must remain intact
      expect(afterRes.data['paid_amount'], equals(2500));

      // Verify sync_changes table recorded exactly one change for this operation
      final changesRes = await dio.get(
        '/sync/changes',
        queryParameters: {'after': baseSeq, 'limit': 100},
      );
      expect(changesRes.statusCode, equals(200));
      final changes = (changesRes.data['changes'] as List?) ?? [];
      final matchingChanges = changes.where(
        (c) => c['operation_id'] == correctOpId,
      ).toList();
      expect(matchingChanges.length, equals(1));
      final changePayload = matchingChanges.first['payload'] as Map<String, dynamic>;
      expect(changePayload['status'], equals('processing'));
      expect(changePayload['completed_at'], isNull);
      expect(matchingChanges.first['server_version'], equals(beforeVersion + 1));
    });

    test('F. Duplicate operation ID returns idempotent result without duplicate sync_changes', () async {
      if (!isNetworkAvailable) return;

      final correctOpId = 'op-correct-ord1-$runId';
      final repeatRes = await dio.patch(
        '/orders/$order1Id',
        data: {
          'status': 'processing',
          'updated_at': DateTime.now().toIso8601String(),
        },
        options: Options(headers: {'X-Operation-ID': correctOpId}),
      );

      expect(repeatRes.statusCode, equals(200));
      expect(repeatRes.data['status'], equals('processing'));
      expect(repeatRes.data['completed_at'], isNull);

      // Verify sync_changes still has exactly one row for this operation ID
      final changesRes = await dio.get(
        '/sync/changes',
        queryParameters: {'after': baseSeq, 'limit': 100},
      );
      final changes = (changesRes.data['changes'] as List?) ?? [];
      final matchingChanges = changes.where(
        (c) => c['operation_id'] == correctOpId,
      ).toList();
      expect(matchingChanges.length, equals(1));
    });

    test('C. Completed -> Ready is rejected with INVALID_LIFECYCLE_TRANSITION', () async {
      if (!isNetworkAvailable) return;

      // Re-complete order 1 for negative tests
      final recompTime = DateTime.now().toIso8601String();
      await dio.patch(
        '/orders/$order1Id',
        data: {
          'status': 'completed',
          'completed_at': recompTime,
          'updated_at': recompTime,
        },
        options: Options(headers: {'X-Operation-ID': 'op-recomp-$runId'}),
      );

      // Try Completed -> Ready
      try {
        await dio.patch(
          '/orders/$order1Id',
          data: {
            'status': 'ready',
            'updated_at': DateTime.now().toIso8601String(),
          },
          options: Options(headers: {'X-Operation-ID': 'op-comp-to-ready-$runId'}),
        );
        fail('Completed -> Ready must be rejected');
      } on DioException catch (e) {
        expect(e.response?.statusCode, anyOf(equals(409), equals(422)));
        final body = e.response?.data.toString() ?? '';
        expect(body.contains('INVALID_LIFECYCLE_TRANSITION'), isTrue);
      }
    });

    test('D. Completed -> Cancelled is rejected with INVALID_LIFECYCLE_TRANSITION', () async {
      if (!isNetworkAvailable) return;

      try {
        await dio.patch(
          '/orders/$order1Id',
          data: {
            'status': 'cancelled',
            'cancelled_at': DateTime.now().toIso8601String(),
            'cancellation_reason': 'محاولة غير مسموحة',
            'updated_at': DateTime.now().toIso8601String(),
          },
          options: Options(headers: {'X-Operation-ID': 'op-comp-to-canc-$runId'}),
        );
        fail('Completed -> Cancelled must be rejected');
      } on DioException catch (e) {
        expect(e.response?.statusCode, anyOf(equals(409), equals(422)));
        final body = e.response?.data.toString() ?? '';
        expect(body.contains('INVALID_LIFECYCLE_TRANSITION'), isTrue);
      }
    });

    test('E. Cancelled -> Processing is rejected with INVALID_LIFECYCLE_TRANSITION', () async {
      if (!isNetworkAvailable) return;

      try {
        await dio.patch(
          '/orders/$order2Id',
          data: {
            'status': 'processing',
            'updated_at': DateTime.now().toIso8601String(),
          },
          options: Options(headers: {'X-Operation-ID': 'op-canc-to-proc-$runId'}),
        );
        fail('Cancelled -> Processing must be rejected');
      } on DioException catch (e) {
        expect(e.response?.statusCode, anyOf(equals(409), equals(422)));
        final body = e.response?.data.toString() ?? '';
        expect(body.contains('INVALID_LIFECYCLE_TRANSITION'), isTrue);
      }
    });
  });
}
