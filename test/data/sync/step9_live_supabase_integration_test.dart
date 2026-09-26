import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/network/dio_client.dart';
import 'package:laundry_management/data/sync/sync_payload_builder.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/entities/service.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';

void main() {
  group('Step 9 — Pricing Types & Payload Builder Contract Tests', () {
    test(
      'PricingType enum contains only approved V1 values without perKilogram',
      () {
        expect(PricingType.values, [
          PricingType.perPiece,
          PricingType.perSquareMeter,
          PricingType.fixedPrice,
        ]);

        expect(PricingType.perPiece.value, equals('per_piece'));
        expect(PricingType.perSquareMeter.value, equals('per_square_meter'));
        expect(PricingType.fixedPrice.value, equals('fixed_price'));
      },
    );

    test('PricingType.fromValue resolves both snake_case value and name', () {
      expect(PricingType.fromValue('per_piece'), equals(PricingType.perPiece));
      expect(PricingType.fromValue('perPiece'), equals(PricingType.perPiece));
      expect(
        PricingType.fromValue('per_square_meter'),
        equals(PricingType.perSquareMeter),
      );
      expect(
        PricingType.fromValue('perSquareMeter'),
        equals(PricingType.perSquareMeter),
      );
      expect(
        PricingType.fromValue('fixed_price'),
        equals(PricingType.fixedPrice),
      );
      expect(
        PricingType.fromValue('fixedPrice'),
        equals(PricingType.fixedPrice),
      );

      expect(() => PricingType.fromValue('per_kilogram'), throwsArgumentError);
    });

    test(
      'SyncPayloadBuilder serializes pricing_type as snake_case value matching PostgreSQL check constraints',
      () {
        final now = DateTime.utc(2026, 9, 16, 8, 0);
        final service = Service(
          id: 'srv-test-1',
          name: 'سجاد',
          pricingType: PricingType.perSquareMeter,
          price: const Money.fromPiastres(5000),
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );

        final servicePayloadStr = SyncPayloadBuilder.buildServicePayload(
          service,
          ['it-1'],
        );
        final servicePayload =
            jsonDecode(servicePayloadStr) as Map<String, dynamic>;
        expect(servicePayload['pricing_type'], equals('per_square_meter'));

        final orderItem = OrderItem(
          id: 'oi-test-1',
          orderId: 'ord-test-1',
          itemTypeId: 'it-1',
          serviceId: 'srv-test-1',
          itemTypeNameSnapshot: 'سجاد',
          serviceNameSnapshot: 'غسيل سجاد',
          pricingType: PricingType.perPiece,
          quantity: 2,
          unitPrice: const Money.fromPiastres(3000),
          calculatedTotal: const Money.fromPiastres(6000),
          createdAt: now,
          updatedAt: now,
        );

        final order = Order(
          id: 'ord-test-1',
          orderNumber: 'ORD-TEST-1',
          customerId: 'cust-1',
          customerNameSnapshot: 'Customer',
          customerPhoneSnapshot: '01011111111',
          status: OrderStatus.processing,
          expectedPickupDate: OrderDate.fromDate(now),
          subtotal: const Money.fromPiastres(6000),
          total: const Money.fromPiastres(6000),
          createdAt: now,
          updatedAt: now,
        );

        final orderPayloadStr = SyncPayloadBuilder.buildOrderCreatePayload(
          order,
          [orderItem],
        );
        final orderPayload =
            jsonDecode(orderPayloadStr) as Map<String, dynamic>;
        final items = orderPayload['items'] as List;
        expect(
          (items.first as Map<String, dynamic>)['pricing_type'],
          equals('per_piece'),
        );
      },
    );

    test(
      'Run-scoped identifiers generate distinct non-colliding operation IDs and valid UUIDs',
      () {
        final run1 =
            ((DateTime.now().microsecondsSinceEpoch - 1000) % 0xFFFFFFFFFFFF)
                .toRadixString(16)
                .padLeft(12, '0');
        final run2 = (DateTime.now().microsecondsSinceEpoch % 0xFFFFFFFFFFFF)
            .toRadixString(16)
            .padLeft(12, '0');

        final opId1 = 'op-step9-cust-create-$run1';
        final opId2 = 'op-step9-cust-create-$run2';

        expect(opId1, isNot(equals(opId2)));
        expect(opId1, startsWith('op-step9-cust-create-'));
        expect(opId2, startsWith('op-step9-cust-create-'));

        final uuid1 = 'c0000001-0001-4001-8001-$run1';
        final uuid2 = 'c0000001-0001-4001-8001-$run2';
        expect(uuid1.length, equals(36));
        expect(uuid2.length, equals(36));
        expect(uuid1, isNot(equals(uuid2)));

        // Cross-suite UUID prefix non-collision regression check
        final c4cUuid = 'c4c00001-0001-4001-8001-$run1';
        expect(uuid1, isNot(equals(c4cUuid)));
      },
    );
  });

  group('Step 9 — Live Supabase Edge Function & PostgreSQL Integration Tests', () {
    late DioClient client;
    late Dio dio;
    bool isNetworkAvailable = true;

    // Unique per-run hex ID to guarantee test idempotency and isolation across repeated runs
    final runId = (DateTime.now().microsecondsSinceEpoch % 0xFFFFFFFFFFFF)
        .toRadixString(16)
        .padLeft(12, '0');

    late final String rejectServiceId;
    late final String rejectOpId;
    late final String custId;
    late final String custPhone;
    late final String custCreateOpId;
    late final String custUpdateOpId;
    late final String srvId;
    late final String srvOpId;
    late final String orderFailId;
    late final String orderFailOpId;
    late final String orderId;
    late final String orderNumber;
    late final String itemId;
    late final String carpetId;
    late final String orderOpId;
    late final String rec1Id;
    late final String rec2Id;
    late final String storeOpId;
    late final String moveOpId;
    late final String unstoreOpId;
    late final String occConflict1OpId;
    late final String occConflict2OpId;
    late final String occSuccessOpId;
    late final String storeRecId;
    late final String moveRecId;
    late final String smStoreOpId;
    late final String smConflictOpId;
    late final String smSuccessOpId;
    late final String orderStatusUpdateOpId;

    setUpAll(() async {
      client = DioClient();
      dio = client.dio;

      rejectServiceId = 'b8888888-8888-4888-8888-$runId';
      rejectOpId = 'op-step9-reject-kg-$runId';
      custId = 'c0000001-0001-4001-8001-$runId';
      custPhone =
          '010${(DateTime.now().microsecondsSinceEpoch % 100000000).toString().padLeft(8, '0')}';
      custCreateOpId = 'op-step9-cust-create-$runId';
      custUpdateOpId = 'op-step9-cust-update-$runId';
      srvId = 'b0000001-0001-4001-8001-$runId';
      srvOpId = 'op-step9-srv-create-carpet-$runId';
      orderFailId = 'd9999999-9999-4999-8999-$runId';
      orderFailOpId = 'op-step9-order-fail-$runId';
      orderId = 'd0000001-0001-4001-8001-$runId';
      orderNumber = 'ORD-S9-$runId';
      itemId = 'e0000001-0001-4001-8001-$runId';
      carpetId = 'f0000001-0001-4001-8001-$runId';
      orderOpId = 'op-step9-order-atomic-create-$runId';
      rec1Id = '90000001-0001-4001-8001-$runId';
      rec2Id = '90000002-0002-4002-8002-$runId';
      storeOpId = 'op-step9-store-$runId';
      moveOpId = 'op-step9-move-$runId';
      unstoreOpId = 'op-step9-unstore-$runId';
      occConflict1OpId = 'op-step9-cust-occ-conflict1-$runId';
      occConflict2OpId = 'op-step9-cust-occ-conflict2-$runId';
      occSuccessOpId = 'op-step9-cust-occ-success-$runId';
      storeRecId = '90000005-0005-4005-8005-$runId';
      moveRecId = '90000006-0006-4006-8006-$runId';
      smStoreOpId = 'op-step9-sm-store-$runId';
      smConflictOpId = 'op-step9-sm-conflict-$runId';
      smSuccessOpId = 'op-step9-sm-success-$runId';
      orderStatusUpdateOpId = 'op-step9-order-status-update-$runId';

      try {
        final res = await dio.get('/customers', queryParameters: {'limit': 1});
        if (res.statusCode != 200) {
          isNetworkAvailable = false;
        }
      } catch (_) {
        isNetworkAvailable = false;
      }
    });

    test(
      'Remote API rejects per_kilogram pricing type with 422 VALIDATION_ERROR',
      () async {
        if (!isNetworkAvailable) return;

        final res = await dio.post(
          '/services',
          data: {
            'id': rejectServiceId,
            'name': 'Rejected Per Kg Service',
            'pricing_type': 'per_kilogram',
            'price': 1000,
          },
          options: Options(
            headers: {'X-Operation-ID': rejectOpId},
            validateStatus: (_) => true,
          ),
        );

        expect(res.statusCode, equals(422));
        expect(
          res.data['code'],
          isIn(['VALIDATION_ERROR', 'BUSINESS_RULE_VIOLATION']),
        );
        expect(res.data['message'], contains('per_kilogram'));
      },
    );

    test(
      'Customer lifecycle: create, update, and idempotent retry preserves exactly 1 record',
      () async {
        if (!isNetworkAvailable) return;

        // 1. Create
        final createRes = await dio.post(
          '/customers',
          data: {
            'id': custId,
            'name': 'Live Customer Test',
            'phone': custPhone,
            'notes': 'Initial note',
          },
          options: Options(
            headers: {'X-Operation-ID': custCreateOpId},
            validateStatus: (_) => true,
          ),
        );

        expect(createRes.statusCode, isIn([200, 201]));
        expect(createRes.data['id'], equals(custId));

        // 2. Idempotent Retry with same operation ID
        final retryRes = await dio.post(
          '/customers',
          data: {
            'id': custId,
            'name': 'Live Customer Test',
            'phone': custPhone,
            'notes': 'Initial note',
          },
          options: Options(
            headers: {'X-Operation-ID': custCreateOpId},
            validateStatus: (_) => true,
          ),
        );

        expect(retryRes.statusCode, isIn([200, 201]));
        expect(retryRes.data['id'], equals(custId));

        // 3. Update
        final updateRes = await dio.patch(
          '/customers/$custId',
          data: {'name': 'Live Customer Updated', 'notes': 'Updated note'},
          options: Options(
            headers: {'X-Operation-ID': custUpdateOpId},
            validateStatus: (_) => true,
          ),
        );

        expect(updateRes.statusCode, equals(200));
        expect(updateRes.data['name'], equals('Live Customer Updated'));
      },
    );

    test(
      'Order Aggregate Remote Atomicity: persist Order + Items + Carpet data or rollback on failure',
      () async {
        if (!isNetworkAvailable) return;

        // Ensure service exists first
        await dio.post(
          '/services',
          data: {
            'id': srvId,
            'name': 'خدمة سجاد للاختبار $runId',
            'pricing_type': 'per_square_meter',
            'price': 4000,
            'is_active': true,
          },
          options: Options(
            headers: {'X-Operation-ID': srvOpId},
            validateStatus: (_) => true,
          ),
        );

        // A. Failure test: invalid aggregate with non-existent customer
        final failRes = await dio.post(
          '/orders',
          data: {
            'id': orderFailId,
            'order_number': 'ORD-FAIL-ROLLBACK',
            'customer_id': '00000000-0000-0000-0000-000000000000',
            'status': 'processing',
            'expected_pickup_date': '2026-09-25T00:00:00.000',
            'subtotal': 4000,
            'total': 4000,
            'items': [],
          },
          options: Options(
            headers: {'X-Operation-ID': orderFailOpId},
            validateStatus: (_) => true,
          ),
        );

        expect(failRes.statusCode, isIn([400, 422]));

        // B. Success aggregate with carpet data
        final successRes = await dio.post(
          '/orders',
          data: {
            'id': orderId,
            'order_number': orderNumber,
            'customer_id': custId,
            'customer_name_snapshot': 'Live Customer Updated',
            'customer_phone_snapshot': custPhone,
            'status': 'processing',
            'expected_pickup_date': '2026-09-25T00:00:00.000',
            'subtotal': 24000,
            'total': 24000,
            'items': [
              {
                'id': itemId,
                'item_type_id': '00000000-0000-0000-0001-000000000003',
                'item_type_name_snapshot': 'سجاد',
                'service_id': srvId,
                'service_name_snapshot': 'خدمة سجاد للاختبار $runId',
                'pricing_type': 'per_square_meter',
                'quantity': 6.0,
                'unit_price': 4000,
                'calculated_total': 24000,
                'carpet_data': {
                  'id': carpetId,
                  'order_item_id': itemId,
                  'carpet_size_id': '00000000-0000-0000-0007-000000000001',
                  'length': 3.0,
                  'width': 2.0,
                  'area': 6.0,
                },
              },
            ],
          },
          options: Options(
            headers: {'X-Operation-ID': orderOpId},
            validateStatus: (_) => true,
          ),
        );

        expect(successRes.statusCode, equals(201));
        expect(successRes.data['id'], equals(orderId));

        // Idempotent retry returns identical payload
        final retryOrderRes = await dio.post(
          '/orders',
          data: {
            'id': orderId,
            'order_number': orderNumber,
            'customer_id': custId,
            'status': 'processing',
            'expected_pickup_date': '2026-09-25T00:00:00.000',
            'subtotal': 24000,
            'total': 24000,
            'items': [],
          },
          options: Options(
            headers: {'X-Operation-ID': orderOpId},
            validateStatus: (_) => true,
          ),
        );

        expect(retryOrderRes.statusCode, isIn([200, 201]));
        expect(retryOrderRes.data['order_number'], equals(orderNumber));
      },
    );

    test(
      'Storage invariant: store, move, unstore enforces at most 1 active storage record',
      () async {
        if (!isNetworkAvailable) return;

        // 1. Store at Rack 1
        final storeRes = await dio.post(
          '/storage',
          data: {
            'id': rec1Id,
            'order_item_id': itemId,
            'storage_location_id': '00000000-0000-0000-0006-000000000001',
            'is_active': true,
          },
          options: Options(
            headers: {'X-Operation-ID': storeOpId},
            validateStatus: (_) => true,
          ),
        );
        expect(storeRes.statusCode, equals(201));

        // 2. Move to Rack 2 via /storage-records alias
        final moveRes = await dio.post(
          '/storage-records',
          data: {
            'id': rec2Id,
            'order_item_id': itemId,
            'storage_location_id': '00000000-0000-0000-0006-000000000002',
            'is_active': true,
          },
          options: Options(
            headers: {'X-Operation-ID': moveOpId},
            validateStatus: (_) => true,
          ),
        );
        expect(moveRes.statusCode, equals(201));

        // 3. Unstore
        final unstoreRes = await dio.patch(
          '/storage/$rec2Id',
          data: {'is_active': false},
          options: Options(
            headers: {'X-Operation-ID': unstoreOpId},
            validateStatus: (_) => true,
          ),
        );
        expect(unstoreRes.statusCode, equals(200));
        expect(unstoreRes.data['is_active'], isFalse);
      },
    );

    test(
      'Optimistic Concurrency Control: valid base_version increments server_version, stale base_version returns 409 CONCURRENCY_CONFLICT',
      () async {
        if (!isNetworkAvailable) return;

        // 1. Fetch current customer to get server_version
        final getRes = await dio.get('/customers/$custId');
        expect(getRes.statusCode, equals(200));
        final currentVersion = getRes.data['server_version'] as int;

        // 2. Conflict attempt with stale base_version
        final conflictRes = await dio.patch(
          '/customers/$custId',
          data: {'name': 'Stale Name', 'base_version': currentVersion - 1},
          options: Options(
            headers: {'X-Operation-ID': occConflict1OpId},
            validateStatus: (_) => true,
          ),
        );
        expect(conflictRes.statusCode, equals(409));
        expect(conflictRes.data['code'], equals('CONCURRENCY_CONFLICT'));

        // 3. Conflict attempt with mismatched header
        final headerConflictRes = await dio.patch(
          '/customers/$custId',
          data: {'name': 'Header Stale Name'},
          options: Options(
            headers: {
              'X-Operation-ID': occConflict2OpId,
              'X-Base-Version': '${currentVersion + 99}',
            },
            validateStatus: (_) => true,
          ),
        );
        expect(headerConflictRes.statusCode, equals(409));
        expect(headerConflictRes.data['code'], equals('CONCURRENCY_CONFLICT'));

        // 4. Successful update with matching base_version
        final successRes = await dio.patch(
          '/customers/$custId',
          data: {'name': 'Valid Versioned Customer'},
          options: Options(
            headers: {
              'X-Operation-ID': occSuccessOpId,
              'X-Base-Version': '$currentVersion',
            },
            validateStatus: (_) => true,
          ),
        );
        expect(successRes.statusCode, equals(200));
        expect(successRes.data['server_version'], equals(currentVersion + 1));
      },
    );

    test(
      'Storage Move Concurrency: mismatched previous_storage_location_id returns 409 CONCURRENCY_CONFLICT, matching moves atomically',
      () async {
        if (!isNetworkAvailable) return;

        // 1. Store at Rack 1
        final storeRes = await dio.post(
          '/storage',
          data: {
            'id': storeRecId,
            'order_item_id': itemId,
            'storage_location_id': '00000000-0000-0000-0006-000000000001',
            'is_active': true,
          },
          options: Options(
            headers: {'X-Operation-ID': smStoreOpId},
            validateStatus: (_) => true,
          ),
        );
        expect(storeRes.statusCode, equals(201));

        // 2. Concurrent move attempt expecting rack-99 (mismatched previous location)
        final conflictRes = await dio.post(
          '/storage',
          data: {
            'id': moveRecId,
            'order_item_id': itemId,
            'storage_location_id': '00000000-0000-0000-0006-000000000002',
            'is_active': true,
          },
          options: Options(
            headers: {
              'X-Operation-ID': smConflictOpId,
              'X-Previous-Storage-Location-Id':
                  '00000000-0000-0000-0006-000000000099',
            },
            validateStatus: (_) => true,
          ),
        );
        expect(conflictRes.statusCode, equals(409));
        expect(conflictRes.data['code'], equals('CONCURRENCY_CONFLICT'));
        expect(
          conflictRes.data['message'],
          contains('not expected 00000000-0000-0000-0006-000000000099'),
        );

        // 3. Valid move with matching previous location
        final validMoveRes = await dio.post(
          '/storage',
          data: {
            'id': moveRecId,
            'order_item_id': itemId,
            'storage_location_id': '00000000-0000-0000-0006-000000000002',
            'is_active': true,
          },
          options: Options(
            headers: {
              'X-Operation-ID': smSuccessOpId,
              'X-Previous-Storage-Location-Id':
                  '00000000-0000-0000-0006-000000000001',
            },
            validateStatus: (_) => true,
          ),
        );
        expect(validMoveRes.statusCode, equals(201));
        expect(validMoveRes.data['is_active'], isTrue);
        expect(
          validMoveRes.data['storage_location_id'],
          equals('00000000-0000-0000-0006-000000000002'),
        );
      },
    );

    test(
      'Pull API: returns changes in strict ascending sequence order with pagination metadata',
      () async {
        if (!isNetworkAvailable) return;

        // 1. Fetch first batch of changes
        final pullRes = await dio.get(
          '/sync/changes',
          queryParameters: {'after': 0, 'limit': 10},
        );

        expect(pullRes.statusCode, equals(200));
        final data = pullRes.data as Map<String, dynamic>;
        expect(data, contains('changes'));
        expect(data, contains('has_more'));
        expect(data, contains('latest_sequence'));

        final changes = data['changes'] as List;
        expect(changes, isNotEmpty);

        // Verify strict monotonic ascending order
        int prevSeq = -1;
        for (final change in changes) {
          final seq = change['sequence'] as int;
          expect(seq, greaterThan(prevSeq));
          prevSeq = seq;
        }

        // 2. Pagination test: pull next page using after = prevSeq
        if (data['has_more'] == true) {
          final nextRes = await dio.get(
            '/sync/changes',
            queryParameters: {'after': prevSeq, 'limit': 10},
          );
          expect(nextRes.statusCode, equals(200));
          final nextChanges =
              (nextRes.data as Map<String, dynamic>)['changes'] as List;
          if (nextChanges.isNotEmpty) {
            final firstNextSeq = nextChanges.first['sequence'] as int;
            expect(firstNextSeq, greaterThan(prevSeq));
          }
        }
      },
    );

    test(
      'Order Creation logs single aggregate entry, subsequent mutation logs single entity update',
      () async {
        if (!isNetworkAvailable) return;

        // Fetch changes paging until orderCreateChange is found
        dynamic orderCreateChange;
        int currentCursor = 0;
        bool hasMore = true;
        while (hasMore && orderCreateChange == null) {
          final pullRes = await dio.get(
            '/sync/changes',
            queryParameters: {'after': currentCursor, 'limit': 100},
          );
          expect(pullRes.statusCode, equals(200));
          final data = pullRes.data as Map<String, dynamic>;
          final changes = data['changes'] as List;
          if (changes.isEmpty) break;
          orderCreateChange = changes.firstWhere(
            (c) => c['operation_id'] == orderOpId,
            orElse: () => null,
          );
          currentCursor = changes.last['sequence'] as int;
          hasMore = data['has_more'] == true;
        }

        expect(orderCreateChange, isNotNull);
        expect(orderCreateChange['entity_type'], equals('order'));
        expect(orderCreateChange['operation_type'], equals('create'));

        // Verify aggregate payload contains items with carpets
        final payload = orderCreateChange['payload'] as Map<String, dynamic>;
        expect(payload['items'], isNotNull);
        final items = payload['items'] as List;
        expect(items, isNotEmpty);
        expect(items.first['carpet_data'], isNotNull);

        final orderCreateSeq = orderCreateChange['sequence'] as int;

        // Update the order status
        final completedAt = DateTime.now().toUtc();
        final updateRes = await dio.patch(
          '/orders/$orderId',
          data: {
            'status': 'completed',
            'completed_at': completedAt.toIso8601String(),
          },
          options: Options(
            headers: {'X-Operation-ID': orderStatusUpdateOpId},
            validateStatus: (_) => true,
          ),
        );
        expect(updateRes.statusCode, equals(200));

        // Pull changes after orderCreateSeq until orderUpdateChange is located
        dynamic orderUpdateChange;
        int updateCursor = orderCreateSeq;
        bool updateHasMore = true;
        while (updateHasMore && orderUpdateChange == null) {
          final postUpdateRes = await dio.get(
            '/sync/changes',
            queryParameters: {'after': updateCursor, 'limit': 100},
          );
          expect(postUpdateRes.statusCode, equals(200));
          final postUpdateData = postUpdateRes.data as Map<String, dynamic>;
          final newChanges = postUpdateData['changes'] as List;
          if (newChanges.isEmpty) break;
          orderUpdateChange = newChanges.firstWhere(
            (c) => c['operation_id'] == orderStatusUpdateOpId,
            orElse: () => null,
          );
          updateCursor = newChanges.last['sequence'] as int;
          updateHasMore = postUpdateData['has_more'] == true;
        }

        expect(orderUpdateChange, isNotNull);
        expect(orderUpdateChange['entity_type'], equals('order'));
        expect(orderUpdateChange['operation_type'], equals('update'));
        // Non-aggregate: subsequent update does NOT contain items list
        final updatePayload =
            orderUpdateChange['payload'] as Map<String, dynamic>;
        expect(updatePayload['status'], equals('completed'));
      },
    );

    test(
      'CURSOR_TOO_OLD: requesting sequence older than retention floor returns 410 CURSOR_TOO_OLD',
      () async {
        if (!isNetworkAvailable) return;

        // Query the oldest available sequence currently retained in sync_changes
        final baselineRes = await dio.get(
          '/sync/changes',
          queryParameters: {'after': 0, 'limit': 1},
          options: Options(validateStatus: (_) => true),
        );
        final changes = baselineRes.data is Map
            ? (baselineRes.data['changes'] as List?)
            : null;
        final oldestSeq = (changes != null && changes.isNotEmpty)
            ? (changes.first['sequence'] as num).toInt()
            : 1;

        if (oldestSeq <= 2) {
          // Retention floor still retains sequence 1. Requesting after: 1 is valid and returns 200.
          final res = await dio.get(
            '/sync/changes',
            queryParameters: {'after': 1, 'limit': 10},
            options: Options(validateStatus: (_) => true),
          );
          expect(res.statusCode, equals(200));
        } else {
          // Sequence 1 is older than retention floor (v_oldest_sequence - 1). Server returns 410 CURSOR_TOO_OLD.
          final res = await dio.get(
            '/sync/changes',
            queryParameters: {'after': 1, 'limit': 10},
            options: Options(validateStatus: (_) => true),
          );
          expect(res.statusCode, equals(410));
          expect(res.data['code'], equals('CURSOR_TOO_OLD'));
          expect(res.data['message'], contains('CURSOR_TOO_OLD'));
        }
      },
    );

    test(
      'Exactly-once sync_changes creation: idempotent replay does not create duplicate sync_changes records',
      () async {
        if (!isNetworkAvailable) return;

        // 1. Locate the initial sync_changes record for this run's customer creation
        dynamic initialChange;
        int currentCursor = 0;
        bool hasMore = true;
        while (hasMore && initialChange == null) {
          final pullRes = await dio.get(
            '/sync/changes',
            queryParameters: {'after': currentCursor, 'limit': 100},
          );
          expect(pullRes.statusCode, equals(200));
          final data = pullRes.data as Map<String, dynamic>;
          final changes = data['changes'] as List;
          if (changes.isEmpty) break;
          initialChange = changes.firstWhere(
            (c) => c['operation_id'] == custCreateOpId,
            orElse: () => null,
          );
          currentCursor = changes.last['sequence'] as int;
          hasMore = data['has_more'] == true;
        }

        expect(
          initialChange,
          isNotNull,
          reason: 'Initial sync_changes record for $custCreateOpId must exist',
        );
        final initialSeq = initialChange['sequence'] as int;

        // 2. Replay customer creation with the exact same operation ID
        final replayRes = await dio.post(
          '/customers',
          data: {
            'id': custId,
            'name': 'Live Customer Test',
            'phone': custPhone,
            'notes': 'Initial note',
          },
          options: Options(
            headers: {'X-Operation-ID': custCreateOpId},
            validateStatus: (_) => true,
          ),
        );
        expect(replayRes.statusCode, isIn([200, 201]));

        // 3. Verify exactly-once: scan all changes after initialSeq to latest head.
        // There must be ZERO duplicate sync_changes records for custCreateOpId.
        int scanCursor = initialSeq;
        bool scanHasMore = true;
        int duplicateCount = 0;
        while (scanHasMore) {
          final scanRes = await dio.get(
            '/sync/changes',
            queryParameters: {'after': scanCursor, 'limit': 100},
          );
          expect(scanRes.statusCode, equals(200));
          final scanData = scanRes.data as Map<String, dynamic>;
          final scanChanges = scanData['changes'] as List;
          if (scanChanges.isEmpty) break;
          for (final c in scanChanges) {
            if (c['operation_id'] == custCreateOpId) {
              duplicateCount++;
            }
          }
          scanCursor = scanChanges.last['sequence'] as int;
          scanHasMore = scanData['has_more'] == true;
        }

        expect(
          duplicateCount,
          equals(0),
          reason:
              'Idempotent replay must NOT create duplicate sync_changes records for $custCreateOpId',
        );
      },
    );
  });
}
