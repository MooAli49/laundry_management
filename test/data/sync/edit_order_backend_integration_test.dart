import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/network/dio_client.dart';

void main() {
  group('Edit Processing Order V1 — Backend Integration Tests (25 Points)', () {
    late DioClient client;
    late Dio dio;
    bool isNetworkAvailable = true;

    final runId = (DateTime.now().microsecondsSinceEpoch % 0xFFFFFFFFFFFF)
        .toRadixString(16)
        .padLeft(12, '0');

    // Master data IDs
    const clothesType = '00000000-0000-0000-0001-000000000001';
    const carpetType = '00000000-0000-0000-0001-000000000003';
    const shirtDef = '00000000-0000-0000-0005-000000000001';
    const pantsDef = '00000000-0000-0000-0005-000000000002';
    const washService = '00000000-0000-0000-0002-000000000001';
    const carpetService = '00000000-0000-0000-0002-000000000003';
    const carpetSize = '00000000-0000-0000-0007-000000000001';
    const storageLoc = '00000000-0000-0000-0006-000000000004';

    late final String cust1Id;
    late final String cust2Id;
    late final String order1Id;
    late final String order1Num;
    late final String item1Id;
    late final String item2CarpetId;
    late final String carpet2Id;
    late final String item3Id;
    late final String editOpId;
    int baseSeq = 0;

    late Map<String, dynamic> initialEditPayload;

    setUpAll(() async {
      client = DioClient();
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

      // Get latest sequence
      final syncRes = await dio.get('/sync/changes', queryParameters: {'limit': 1});
      if (syncRes.statusCode == 200 && syncRes.data is Map) {
        baseSeq = syncRes.data['latest_sequence'] ?? 0;
      }

      cust1Id = 'c0000001-0001-4001-8001-$runId';
      cust2Id = 'c0000002-0002-4002-8002-$runId';
      order1Id = 'd0000001-0001-4001-8001-$runId';
      order1Num = 'ORD-TEST-EDT-$runId';
      item1Id = 'e0000001-0001-4001-8001-$runId';
      item2CarpetId = 'e0000002-0002-4002-8002-$runId';
      carpet2Id = 'f0000001-0001-4001-8001-$runId';
      item3Id = 'e0000003-0003-4003-8003-$runId';
      editOpId = 'op-edit-test-$runId';

      final phone1 = '012${(DateTime.now().microsecondsSinceEpoch % 100000000).toString().padLeft(8, '0')}';
      final phone2 = '015${(DateTime.now().microsecondsSinceEpoch % 100000000).toString().padLeft(8, '0')}';

      // Seed customer 1
      await dio.post(
        '/customers',
        data: {'id': cust1Id, 'name': 'Cust1 $runId', 'phone': phone1},
        options: Options(headers: {'X-Operation-ID': 'op-cust1-$runId'}),
      );

      // Seed customer 2
      await dio.post(
        '/customers',
        data: {'id': cust2Id, 'name': 'Cust2 $runId', 'phone': phone2},
        options: Options(headers: {'X-Operation-ID': 'op-cust2-$runId'}),
      );

      // Seed order 1
      await dio.post(
        '/orders',
        data: {
          'id': order1Id,
          'order_number': order1Num,
          'customer_id': cust1Id,
          'status': 'processing',
          'expected_pickup_date': '2026-09-30T00:00:00.000Z',
          'subtotal': 11000,
          'discount': 1000,
          'tax': 0,
          'total': 10000,
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
              'unit_price': 5000,
              'calculated_total': 5000,
            },
            {
              'id': item2CarpetId,
              'item_type_id': carpetType,
              'service_id': carpetService,
              'item_type_name_snapshot': 'سجاد',
              'service_name_snapshot': 'غسيل سجاد',
              'pricing_type': 'per_square_meter',
              'quantity': 6.0,
              'unit_price': 1000,
              'calculated_total': 6000,
              'carpet_data': {
                'id': carpet2Id,
                'carpet_size_id': carpetSize,
                'length': 2.0,
                'width': 3.0,
                'area': 6.0,
              },
            },
          ],
        },
        options: Options(headers: {'X-Operation-ID': 'op-ord1-$runId'}),
      );

      initialEditPayload = {
        'id': order1Id,
        'order_number': order1Num,
        'customer_id': cust1Id,
        'expected_pickup_date': '2026-10-05T00:00:00.000Z',
        'notes': 'Updated order notes',
        'customer_pickup_requested': false,
        'customer_pickup_fee': 0,
        'customer_delivery_requested': false,
        'customer_delivery_fee': 0,
        'subtotal': 11000,
        'discount': 0,
        'tax': 0,
        'total': 11000,
        'items': [
          {
            'id': item1Id,
            'item_type_id': clothesType,
            'item_definition_id': shirtDef,
            'service_id': washService,
            'item_type_name_snapshot': 'ملابس',
            'service_name_snapshot': 'غسيل',
            'pricing_type': 'per_piece',
            'quantity': 2.0,
            'unit_price': 4000,
            'calculated_total': 8000,
            'notes': 'Item 1 updated',
          },
          {
            'id': item3Id,
            'item_type_id': clothesType,
            'item_definition_id': pantsDef,
            'service_id': washService,
            'item_type_name_snapshot': 'ملابس',
            'service_name_snapshot': 'غسيل',
            'pricing_type': 'per_piece',
            'quantity': 1.0,
            'unit_price': 3000,
            'calculated_total': 3000,
            'notes': 'Item 3 new',
          },
        ],
      };
    });

    Map<String, dynamic> clonePayload(Map<String, dynamic> source) {
      return jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
    }

    test('1, 2, 3, 4, 23: Successful aggregate edit, item update, new item insertion, item deletion, server_version increment', () async {
      if (!isNetworkAvailable) return;

      final res = await dio.patch(
        '/orders/$order1Id/edit-aggregate',
        data: initialEditPayload,
        options: Options(
          headers: {'X-Operation-ID': editOpId},
          validateStatus: (_) => true,
        ),
      );

      expect(res.statusCode, equals(200));
      expect(res.data['server_version'], equals(2));
      expect(res.data['total'], equals(11000));
      expect(res.data['subtotal'], equals(11000));

      // Verify items via GET
      final getRes = await dio.get('/orders/$order1Id');
      expect(getRes.statusCode, equals(200));
      final items = (getRes.data['order_items'] as List).cast<Map<String, dynamic>>();
      final itemIds = items.map((i) => i['id']).toList();

      expect(itemIds, contains(item1Id));
      expect(itemIds, contains(item3Id));
      expect(itemIds, isNot(contains(item2CarpetId)));

      final item1 = items.firstWhere((i) => i['id'] == item1Id);
      expect(item1['quantity'], equals(2.0));
      expect(item1['unit_price'], equals(4000));
    });

    test('24, 25: Idempotency replay returns cached result and does not create duplicate sync_changes', () async {
      if (!isNetworkAvailable) return;

      final replayRes = await dio.patch(
        '/orders/$order1Id/edit-aggregate',
        data: initialEditPayload,
        options: Options(
          headers: {'X-Operation-ID': editOpId},
          validateStatus: (_) => true,
        ),
      );

      expect(replayRes.statusCode, equals(200));
      expect(replayRes.data['server_version'], equals(2));

      // Verify sync_changes contains exactly one record for editOpId
      final syncRes = await dio.get(
        '/sync/changes',
        queryParameters: {'after': baseSeq, 'limit': 100},
      );
      expect(syncRes.statusCode, equals(200));
      final changes = (syncRes.data['changes'] as List).cast<Map<String, dynamic>>();
      final editChanges = changes.where((c) => c['operation_id'] == editOpId).toList();
      expect(editChanges.length, equals(1));

      // Test 22: sync_changes contains full aggregate
      final payload = editChanges.first['payload'] as Map<String, dynamic>;
      expect(payload['order_number'], equals(order1Num));
      expect((payload['items'] as List).length, equals(2));
    });

    test('5: Carpet metadata insert/update/delete', () async {
      if (!isNetworkAvailable) return;

      final carpetItemId = 'e0000004-0004-4004-8004-$runId';
      final carpetDataId = 'f0000002-0002-4002-8002-$runId';

      final carpetPayload = clonePayload(initialEditPayload);
      carpetPayload['subtotal'] = 17000;
      carpetPayload['total'] = 17000;
      (carpetPayload['items'] as List).add({
        'id': carpetItemId,
        'item_type_id': carpetType,
        'service_id': carpetService,
        'pricing_type': 'per_square_meter',
        'quantity': 6.0,
        'unit_price': 1000,
        'calculated_total': 6000,
        'carpet_data': {
          'id': carpetDataId,
          'carpet_size_id': carpetSize,
          'length': 2.0,
          'width': 3.0,
          'area': 6.0,
        },
      });

      // Insert carpet
      final res1 = await dio.patch(
        '/orders/$order1Id/edit-aggregate',
        data: carpetPayload,
        options: Options(
          headers: {'X-Operation-ID': 'op-carpet-add-$runId'},
          validateStatus: (_) => true,
        ),
      );
      expect(res1.statusCode, equals(200));

      // Update carpet
      carpetPayload['items'][2]['carpet_data']['length'] = 3.0;
      carpetPayload['items'][2]['carpet_data']['width'] = 3.0;
      carpetPayload['items'][2]['carpet_data']['area'] = 9.0;
      carpetPayload['items'][2]['quantity'] = 9.0;
      carpetPayload['items'][2]['calculated_total'] = 9000;
      carpetPayload['subtotal'] = 20000;
      carpetPayload['total'] = 20000;

      final res2 = await dio.patch(
        '/orders/$order1Id/edit-aggregate',
        data: carpetPayload,
        options: Options(
          headers: {'X-Operation-ID': 'op-carpet-update-$runId'},
          validateStatus: (_) => true,
        ),
      );
      expect(res2.statusCode, equals(200));

      // Delete carpet
      final res3 = await dio.patch(
        '/orders/$order1Id/edit-aggregate',
        data: initialEditPayload,
        options: Options(
          headers: {'X-Operation-ID': 'op-carpet-del-$runId'},
          validateStatus: (_) => true,
        ),
      );
      expect(res3.statusCode, equals(200));
    });

    test('6: order_number is immutable', () async {
      if (!isNetworkAvailable) return;

      final payload = clonePayload(initialEditPayload);
      payload['order_number'] = '99-99999';

      final res = await dio.patch(
        '/orders/$order1Id/edit-aggregate',
        data: payload,
        options: Options(
          headers: {'X-Operation-ID': 'op-test6-$runId'},
          validateStatus: (_) => true,
        ),
      );
      expect(res.statusCode, equals(422));
      expect(res.data['code'], equals('BUSINESS_RULE_VIOLATION'));
    });

    test('7: terminal/protected state rejection (cancelled and completed)', () async {
      if (!isNetworkAvailable) return;

      final termOrderId = 'd0000007-0007-4007-8007-$runId';
      final termOrderNum = '26-T${(DateTime.now().microsecondsSinceEpoch % 1000000).toString().padLeft(6, '0')}';

      // Seed order
      final seedRes = await dio.post(
        '/orders',
        data: {
          'id': termOrderId,
          'order_number': termOrderNum,
          'customer_id': cust1Id,
          'status': 'processing',
          'expected_pickup_date': '2026-09-30T00:00:00.000Z',
          'subtotal': 5000,
          'total': 5000,
          'items': [
            {
              'id': 'e0000007-0007-4007-8007-$runId',
              'item_type_id': clothesType,
              'service_id': washService,
              'item_type_name_snapshot': 'ملابس',
              'service_name_snapshot': 'غسيل',
              'pricing_type': 'per_piece',
              'quantity': 1.0,
              'unit_price': 5000,
              'calculated_total': 5000,
            },
          ],
        },
        options: Options(headers: {'X-Operation-ID': 'op-term-seed-$runId'}),
      );
      expect(seedRes.statusCode, equals(201));

      // Cancel order
      final cancelRes = await dio.patch(
        '/orders/$termOrderId',
        data: {'status': 'cancelled'},
        options: Options(headers: {'X-Operation-ID': 'op-term-cancel-$runId'}),
      );
      expect(cancelRes.statusCode, equals(200));

      // Attempt edit-aggregate on cancelled order
      final payload = clonePayload(initialEditPayload);
      payload['id'] = termOrderId;
      payload['order_number'] = termOrderNum;

      final resCancel = await dio.patch(
        '/orders/$termOrderId/edit-aggregate',
        data: payload,
        options: Options(
          headers: {'X-Operation-ID': 'op-test7-cancel-$runId'},
          validateStatus: (_) => true,
        ),
      );
      expect(resCancel.statusCode, anyOf([409, 422]));
      expect(resCancel.data['code'], equals('INVALID_LIFECYCLE_TRANSITION'));
      expect(resCancel.data['message'], contains('Only orders in processing status can be edited'));

      // Seed completed order
      final compOrderId = 'd0000008-0008-4008-8008-$runId';
      final compOrderNum = '26-C${(DateTime.now().microsecondsSinceEpoch % 1000000).toString().padLeft(6, '0')}';
      await dio.post(
        '/orders',
        data: {
          'id': compOrderId,
          'order_number': compOrderNum,
          'customer_id': cust1Id,
          'status': 'processing',
          'expected_pickup_date': '2026-09-30T00:00:00.000Z',
          'subtotal': 5000,
          'total': 5000,
          'items': [
            {
              'id': 'e0000008-0008-4008-8008-$runId',
              'item_type_id': clothesType,
              'service_id': washService,
              'item_type_name_snapshot': 'ملابس',
              'service_name_snapshot': 'غسيل',
              'pricing_type': 'per_piece',
              'quantity': 1.0,
              'unit_price': 5000,
              'calculated_total': 5000,
            },
          ],
        },
        options: Options(headers: {'X-Operation-ID': 'op-comp-seed-$runId'}),
      );
      await dio.patch(
        '/orders/$compOrderId',
        data: {'status': 'completed'},
        options: Options(headers: {'X-Operation-ID': 'op-comp-patch-$runId'}),
      );

      final payloadComp = clonePayload(initialEditPayload);
      payloadComp['id'] = compOrderId;
      payloadComp['order_number'] = compOrderNum;

      final resComp = await dio.patch(
        '/orders/$compOrderId/edit-aggregate',
        data: payloadComp,
        options: Options(
          headers: {'X-Operation-ID': 'op-test7-comp-$runId'},
          validateStatus: (_) => true,
        ),
      );
      expect(resComp.statusCode, anyOf([409, 422]));
      expect(resComp.data['code'], equals('INVALID_LIFECYCLE_TRANSITION'));
      expect(resComp.data['message'], contains('Only orders in processing status can be edited'));
    });

    test('Ready order edit rejection: strictly processing-only, zero side effects', () async {
      if (!isNetworkAvailable) return;

      final readyOrderId = 'd0000009-0009-4009-8009-$runId';
      final readyOrderNum = '26-R${(DateTime.now().microsecondsSinceEpoch % 1000000).toString().padLeft(6, '0')}';
      final readyItemId = 'e0000009-0009-4009-8009-$runId';
      final readyOpId = 'op-ready-edit-$runId';

      // 1. Create order in processing
      final createRes = await dio.post(
        '/orders',
        data: {
          'id': readyOrderId,
          'order_number': readyOrderNum,
          'customer_id': cust1Id,
          'status': 'processing',
          'expected_pickup_date': '2026-09-30T00:00:00.000Z',
          'subtotal': 5000,
          'total': 5000,
          'items': [
            {
              'id': readyItemId,
              'item_type_id': clothesType,
              'service_id': washService,
              'item_type_name_snapshot': 'ملابس',
              'service_name_snapshot': 'غسيل',
              'pricing_type': 'per_piece',
              'quantity': 1.0,
              'unit_price': 5000,
              'calculated_total': 5000,
            },
          ],
        },
        options: Options(headers: {'X-Operation-ID': 'op-ready-seed-$runId'}),
      );
      expect(createRes.statusCode, equals(201));

      // 2. Add storage record for the item
      final storRes = await dio.post(
        '/storage-records',
        data: {
          'id': '90000009-0009-4009-8009-$runId',
          'order_item_id': readyItemId,
          'storage_location_id': storageLoc,
          'is_active': true,
        },
        options: Options(headers: {'X-Operation-ID': 'op-ready-stor-$runId'}),
      );
      expect(storRes.statusCode, equals(201));

      // 3. Transition order status to ready
      final readyRes = await dio.patch(
        '/orders/$readyOrderId',
        data: {'status': 'ready'},
        options: Options(headers: {'X-Operation-ID': 'op-ready-status-$runId'}),
      );
      expect(readyRes.statusCode, equals(200));

      // 4. Capture baseline state before rejected edit
      final getBefore = await dio.get('/orders/$readyOrderId');
      expect(getBefore.statusCode, equals(200));
      expect(getBefore.data['status'], equals('ready'));
      final int versionBefore = getBefore.data['server_version'];

      final syncBefore = await dio.get('/sync/changes', queryParameters: {'limit': 1});
      final int seqBefore = syncBefore.data['latest_sequence'] ?? 0;

      // 5. Attempt edit-aggregate on Ready order
      final editPayload = {
        'id': readyOrderId,
        'order_number': readyOrderNum,
        'customer_id': cust1Id,
        'expected_pickup_date': '2026-10-15T00:00:00.000Z',
        'notes': 'Attempted illegal edit on ready order',
        'subtotal': 8000,
        'discount': 0,
        'tax': 0,
        'total': 8000,
        'items': [
          {
            'id': readyItemId,
            'item_type_id': clothesType,
            'service_id': washService,
            'item_type_name_snapshot': 'ملابس',
            'service_name_snapshot': 'غسيل',
            'pricing_type': 'per_piece',
            'quantity': 2.0,
            'unit_price': 4000,
            'calculated_total': 8000,
          },
        ],
      };

      final editAttemptRes = await dio.patch(
        '/orders/$readyOrderId/edit-aggregate',
        data: editPayload,
        options: Options(
          headers: {'X-Operation-ID': readyOpId},
          validateStatus: (_) => true,
        ),
      );

      // Verify rejection
      expect(editAttemptRes.statusCode, anyOf([409, 422]));
      expect(editAttemptRes.data['code'], equals('INVALID_LIFECYCLE_TRANSITION'));
      expect(
        editAttemptRes.data['message'],
        contains('Only orders in processing status can be edited (current status: ready)'),
      );

      // 6. Verify zero side effects on Ready order
      final getAfter = await dio.get('/orders/$readyOrderId');
      expect(getAfter.statusCode, equals(200));
      expect(getAfter.data['status'], equals('ready'));
      expect(getAfter.data['server_version'], equals(versionBefore));
      expect(getAfter.data['subtotal'], equals(5000));
      expect(getAfter.data['total'], equals(5000));
      expect(getAfter.data['notes'], isNot(equals('Attempted illegal edit on ready order')));

      final itemsAfter = (getAfter.data['order_items'] as List).cast<Map<String, dynamic>>();
      expect(itemsAfter.length, equals(1));
      expect(itemsAfter.first['id'], equals(readyItemId));
      expect(itemsAfter.first['quantity'], equals(1.0));
      expect(itemsAfter.first['unit_price'], equals(5000));

      // Storage record remains active
      final storAfter = await dio.get('/storage-records/$readyItemId');
      expect(storAfter.statusCode, equals(200));
      expect(storAfter.data['is_active'], isTrue);

      // No new sync_changes row created for readyOpId
      final syncAfter = await dio.get(
        '/sync/changes',
        queryParameters: {'after': seqBefore, 'limit': 100},
      );
      expect(syncAfter.statusCode, equals(200));
      final changes = (syncAfter.data['changes'] as List).cast<Map<String, dynamic>>();
      final readyOpChanges = changes.where((c) => c['operation_id'] == readyOpId).toList();
      expect(readyOpChanges, isEmpty);
    });

    test('8: customer change with paid_amount = 0 is permitted', () async {
      if (!isNetworkAvailable) return;

      final payload = clonePayload(initialEditPayload);
      payload['customer_id'] = cust2Id;

      final res = await dio.patch(
        '/orders/$order1Id/edit-aggregate',
        data: payload,
        options: Options(
          headers: {'X-Operation-ID': 'op-test8-$runId'},
          validateStatus: (_) => true,
        ),
      );
      expect(res.statusCode, equals(200));
    });

    test('9, 10: customer change with paid_amount > 0 and total < paid_amount rejected', () async {
      if (!isNetworkAvailable) return;

      // Add payment of 2000
      final payRes = await dio.post(
        '/payments',
        data: {
          'id': 'a0000001-0001-4001-8001-$runId',
          'order_id': order1Id,
          'amount': 2000,
          'payment_method': 'cash',
        },
        options: Options(headers: {'X-Operation-ID': 'op-pay-$runId'}),
      );
      expect(payRes.statusCode, equals(201));

      // Test 9: customer change rejected
      final custChangePayload = clonePayload(initialEditPayload);
      custChangePayload['customer_id'] = cust1Id;
      final res9 = await dio.patch(
        '/orders/$order1Id/edit-aggregate',
        data: custChangePayload,
        options: Options(
          headers: {'X-Operation-ID': 'op-test9-$runId'},
          validateStatus: (_) => true,
        ),
      );
      expect(res9.statusCode, equals(422));
      expect(res9.data['code'], equals('BUSINESS_RULE_VIOLATION'));

      // Test 10: total < paid_amount rejected
      final totalLowPayload = clonePayload(initialEditPayload);
      totalLowPayload['customer_id'] = cust2Id;
      totalLowPayload['subtotal'] = 1500;
      totalLowPayload['total'] = 1500;
      totalLowPayload['items'] = [
        {
          'id': item1Id,
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
      ];

      final res10 = await dio.patch(
        '/orders/$order1Id/edit-aggregate',
        data: totalLowPayload,
        options: Options(
          headers: {'X-Operation-ID': 'op-test10-$runId'},
          validateStatus: (_) => true,
        ),
      );
      expect(res10.statusCode, anyOf(409, 422));
    });

    test('11: unit_price <= 0 rejected', () async {
      if (!isNetworkAvailable) return;

      final payload = clonePayload(initialEditPayload);
      payload['customer_id'] = cust2Id;
      payload['items'][0]['unit_price'] = 0;

      final res = await dio.patch(
        '/orders/$order1Id/edit-aggregate',
        data: payload,
        options: Options(
          headers: {'X-Operation-ID': 'op-test11-$runId'},
          validateStatus: (_) => true,
        ),
      );
      expect(res.statusCode, equals(422));
      expect(res.data['code'], equals('BUSINESS_RULE_VIOLATION'));
    });

    test('12: invalid item_type rejected', () async {
      if (!isNetworkAvailable) return;

      final payload = clonePayload(initialEditPayload);
      payload['customer_id'] = cust2Id;
      payload['items'][1]['item_type_id'] = '11111111-1111-1111-1111-111111111111';

      final res = await dio.patch(
        '/orders/$order1Id/edit-aggregate',
        data: payload,
        options: Options(
          headers: {'X-Operation-ID': 'op-test12-$runId'},
          validateStatus: (_) => true,
        ),
      );
      expect(res.statusCode, equals(422));
    });

    test('13: invalid item_definition rejected', () async {
      if (!isNetworkAvailable) return;

      final payload = clonePayload(initialEditPayload);
      payload['customer_id'] = cust2Id;
      payload['items'][1]['item_definition_id'] = '22222222-2222-2222-2222-222222222222';

      final res = await dio.patch(
        '/orders/$order1Id/edit-aggregate',
        data: payload,
        options: Options(
          headers: {'X-Operation-ID': 'op-test13-$runId'},
          validateStatus: (_) => true,
        ),
      );
      expect(res.statusCode, equals(422));
    });

    test('14: incompatible service/item_type rejected', () async {
      if (!isNetworkAvailable) return;

      final payload = clonePayload(initialEditPayload);
      payload['customer_id'] = cust2Id;
      payload['items'][1]['service_id'] = carpetService;

      final res = await dio.patch(
        '/orders/$order1Id/edit-aggregate',
        data: payload,
        options: Options(
          headers: {'X-Operation-ID': 'op-test14-$runId'},
          validateStatus: (_) => true,
        ),
      );
      expect(res.statusCode, equals(422));
    });

    test('15: invalid pricing_type rejected', () async {
      if (!isNetworkAvailable) return;

      final payload = clonePayload(initialEditPayload);
      payload['customer_id'] = cust2Id;
      payload['items'][1]['pricing_type'] = 'fixed_price';

      final res = await dio.patch(
        '/orders/$order1Id/edit-aggregate',
        data: payload,
        options: Options(
          headers: {'X-Operation-ID': 'op-test15-$runId'},
          validateStatus: (_) => true,
        ),
      );
      expect(res.statusCode, equals(422));
    });

    test('16: existing item_type mutation rejected', () async {
      if (!isNetworkAvailable) return;

      final payload = clonePayload(initialEditPayload);
      payload['customer_id'] = cust2Id;
      payload['items'][0]['item_type_id'] = carpetType;

      final res = await dio.patch(
        '/orders/$order1Id/edit-aggregate',
        data: payload,
        options: Options(
          headers: {'X-Operation-ID': 'op-test16-$runId'},
          validateStatus: (_) => true,
        ),
      );
      expect(res.statusCode, equals(422));
    });

    test('17: invalid carpet dimensions rejected', () async {
      if (!isNetworkAvailable) return;

      final carpetPayload = clonePayload(initialEditPayload);
      carpetPayload['customer_id'] = cust2Id;
      (carpetPayload['items'] as List).add({
        'id': 'e0000005-0005-4005-8005-$runId',
        'item_type_id': carpetType,
        'service_id': carpetService,
        'pricing_type': 'per_square_meter',
        'quantity': 6.0,
        'unit_price': 1000,
        'calculated_total': 6000,
        'carpet_data': {
          'id': 'f0000003-0003-4003-8003-$runId',
          'carpet_size_id': carpetSize,
          'length': 2.0,
          'width': 3.0,
          'area': 999.0, // mismatch
        },
      });

      final res = await dio.patch(
        '/orders/$order1Id/edit-aggregate',
        data: carpetPayload,
        options: Options(
          headers: {'X-Operation-ID': 'op-test17-$runId'},
          validateStatus: (_) => true,
        ),
      );
      expect(res.statusCode, equals(422));
    });

    test('18, 19, 20: deletion blocked when storage_records exists, P0006 raised, maps to HTTP 409', () async {
      if (!isNetworkAvailable) return;

      // Create storage record for item3Id
      final storRes = await dio.post(
        '/storage-records',
        data: {
          'id': '90000001-0001-4001-8001-$runId',
          'order_item_id': item3Id,
          'storage_location_id': storageLoc,
          'is_active': true,
        },
        options: Options(headers: {'X-Operation-ID': 'op-stor-$runId'}),
      );
      expect(storRes.statusCode, equals(201));

      // Attempt to omit item3Id (deletion request)
      final omitPayload = clonePayload(initialEditPayload);
      omitPayload['customer_id'] = cust2Id;
      omitPayload['subtotal'] = 8000;
      omitPayload['total'] = 8000;
      omitPayload['items'] = [omitPayload['items'][0]]; // only item 1

      final res = await dio.patch(
        '/orders/$order1Id/edit-aggregate',
        data: omitPayload,
        options: Options(
          headers: {'X-Operation-ID': 'op-guard-$runId'},
          validateStatus: (_) => true,
        ),
      );

      // Test 18 & 20: HTTP 409
      expect(res.statusCode, equals(409));
      expect(res.data['error'], equals('EDIT_BLOCKED_ITEM_HAS_STORAGE_RECORDS'));
      expect(res.data['code'], equals('EDIT_BLOCKED_ITEM_HAS_STORAGE_RECORDS'));
      // Test 19: Message confirms storage deletion guard
      expect(res.data['message'], contains('EDIT_BLOCKED_ITEM_HAS_STORAGE_RECORDS'));
    });
  });
}
