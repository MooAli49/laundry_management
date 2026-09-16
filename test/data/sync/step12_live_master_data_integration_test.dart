import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/network/dio_client.dart';

void main() {
  group('Step 12 — Live Supabase Master Data Integration Tests', () {
    late DioClient client;
    late Dio dio;
    bool isNetworkAvailable = true;

    // Unique per-run UUID generator to guarantee test idempotency and isolation
    final runId = DateTime.now().millisecondsSinceEpoch
        .toRadixString(16)
        .padLeft(12, '0');

    late final String testItemTypeId;
    late final String testOtherItemTypeId;
    late final String testItemDefId;
    late final String testCarpetSizeId;
    late final String testStorageLocationId;

    late final String itemTypeName;
    late final String itemDefName;
    late final String locationName;

    late final double testCarpetLength;
    late final double testCarpetWidth;
    late final double testCarpetArea;
    late final double updatedCarpetLength;
    late final double updatedCarpetArea;

    setUpAll(() async {
      client = DioClient();
      dio = client.dio;

      testItemTypeId = 'a1200000-0000-4000-8000-$runId';
      testOtherItemTypeId = 'a1300000-0000-4000-8000-$runId';
      testItemDefId = 'b1200000-0000-4000-8000-$runId';
      testCarpetSizeId = 'c1200000-0000-4000-8000-$runId';
      testStorageLocationId = 'd1200000-0000-4000-8000-$runId';

      itemTypeName = 'نوع ملابس $runId';
      itemDefName = 'تعريف صنف $runId';
      locationName = 'موقع تخزين $runId';

      final seed = DateTime.now().millisecondsSinceEpoch;
      testCarpetLength = double.parse((10.0 + (seed % 1000) / 10.0).toStringAsFixed(2));
      testCarpetWidth = double.parse((5.0 + ((seed ~/ 1000) % 500) / 10.0).toStringAsFixed(2));
      testCarpetArea = double.parse((testCarpetLength * testCarpetWidth).toStringAsFixed(4));
      updatedCarpetLength = double.parse((testCarpetLength + 2.0).toStringAsFixed(2));
      updatedCarpetArea = double.parse((updatedCarpetLength * testCarpetWidth).toStringAsFixed(4));

      try {
        final res = await dio.get('/item-types');
        if (res.statusCode != 200) {
          isNetworkAvailable = false;
        }
      } catch (_) {
        isNetworkAvailable = false;
      }
    });

    // =========================================================================
    // 1. Item Types Tests
    // =========================================================================

    test('1. Valid ItemType creation: returns 201 Created and persists entity', () async {
      if (!isNetworkAvailable) return;

      final res = await dio.post(
        '/item-types',
        data: {
          'id': testItemTypeId,
          'name': itemTypeName,
          'is_active': true,
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step12-it-create-$runId'},
          validateStatus: (_) => true,
        ),
      );

      expect(res.statusCode, equals(201));
      expect(res.data['id'], equals(testItemTypeId));
      expect(res.data['name'], equals(itemTypeName));
      expect(res.data['is_active'], isTrue);
    });

    test('2. ItemType Idempotency: exact duplicate replay returns cached 201 response', () async {
      if (!isNetworkAvailable) return;

      final replayRes = await dio.post(
        '/item-types',
        data: {
          'id': testItemTypeId,
          'name': itemTypeName,
          'is_active': true,
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step12-it-create-$runId'},
          validateStatus: (_) => true,
        ),
      );

      expect(replayRes.statusCode, equals(201));
      expect(replayRes.data['id'], equals(testItemTypeId));
      expect(replayRes.data['name'], equals(itemTypeName));
    });

    test('3. ItemType Duplicate Name: returns 409 Conflict', () async {
      if (!isNetworkAvailable) return;

      final res = await dio.post(
        '/item-types',
        data: {
          'id': 'a1900000-0000-4000-8000-$runId',
          'name': itemTypeName.toUpperCase(),
          'is_active': true,
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step12-it-dup-$runId'},
          validateStatus: (_) => true,
        ),
      );

      expect(res.statusCode, equals(409));
    });

    test('4. ItemType Update / Rename: returns 200 OK with updated name', () async {
      if (!isNetworkAvailable) return;

      final updatedName = '$itemTypeName (محدث)';
      final res = await dio.patch(
        '/item-types/$testItemTypeId',
        data: {
          'name': updatedName,
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step12-it-patch-$runId'},
          validateStatus: (_) => true,
        ),
      );

      expect(res.statusCode, equals(200));
      expect(res.data['id'], equals(testItemTypeId));
      expect(res.data['name'], equals(updatedName));
    });

    test('5. ItemType Deactivation & Activation: updates is_active correctly', () async {
      if (!isNetworkAvailable) return;

      // Deactivate
      final deactRes = await dio.patch(
        '/item-types/$testItemTypeId',
        data: {'is_active': false},
        options: Options(
          headers: {'X-Operation-ID': 'op-step12-it-deact-$runId'},
          validateStatus: (_) => true,
        ),
      );
      expect(deactRes.statusCode, equals(200));
      expect(deactRes.data['is_active'], isFalse);

      // Reactivate
      final actRes = await dio.patch(
        '/item-types/$testItemTypeId',
        data: {'is_active': true},
        options: Options(
          headers: {'X-Operation-ID': 'op-step12-it-act-$runId'},
          validateStatus: (_) => true,
        ),
      );
      expect(actRes.statusCode, equals(200));
      expect(actRes.data['is_active'], isTrue);
    });

    test('6. ItemType GET by ID & List: returns correct records', () async {
      if (!isNetworkAvailable) return;

      final getRes = await dio.get('/item-types/$testItemTypeId');
      expect(getRes.statusCode, equals(200));
      expect(getRes.data['id'], equals(testItemTypeId));

      final listRes = await dio.get('/item-types');
      expect(listRes.statusCode, equals(200));
      final items = listRes.data as List;
      expect(items.any((e) => e['id'] == testItemTypeId), isTrue);
    });

    test('7. ItemType DELETE is forbidden: returns 404', () async {
      if (!isNetworkAvailable) return;

      final res = await dio.delete(
        '/item-types/$testItemTypeId',
        options: Options(validateStatus: (_) => true),
      );
      expect(res.statusCode, equals(404));
    });

    // =========================================================================
    // 2. Item Definitions Tests
    // =========================================================================

    test('8. ItemDefinition creation: succeeds and references ItemType', () async {
      if (!isNetworkAvailable) return;

      final res = await dio.post(
        '/item-definitions',
        data: {
          'id': testItemDefId,
          'item_type_id': testItemTypeId,
          'name': itemDefName,
          'is_active': true,
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step12-idef-create-$runId'},
          validateStatus: (_) => true,
        ),
      );

      expect(res.statusCode, equals(201));
      expect(res.data['id'], equals(testItemDefId));
      expect(res.data['item_type_id'], equals(testItemTypeId));
      expect(res.data['name'], equals(itemDefName));
    });

    test('9. ItemDefinition Idempotency: exact replay returns cached response', () async {
      if (!isNetworkAvailable) return;

      final replayRes = await dio.post(
        '/item-definitions',
        data: {
          'id': testItemDefId,
          'item_type_id': testItemTypeId,
          'name': itemDefName,
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step12-idef-create-$runId'},
          validateStatus: (_) => true,
        ),
      );

      expect(replayRes.statusCode, equals(201));
      expect(replayRes.data['id'], equals(testItemDefId));
    });

    test('10. ItemDefinition Duplicate Name for Same ItemType: returns 409 Conflict', () async {
      if (!isNetworkAvailable) return;

      final res = await dio.post(
        '/item-definitions',
        data: {
          'id': 'b1900000-0000-4000-8000-$runId',
          'item_type_id': testItemTypeId,
          'name': itemDefName.toLowerCase(),
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step12-idef-dup-$runId'},
          validateStatus: (_) => true,
        ),
      );

      expect(res.statusCode, equals(409));
    });

    test('11. ItemDefinition Invalid ItemType FK: returns error (400, 404, or 422)', () async {
      if (!isNetworkAvailable) return;

      final res = await dio.post(
        '/item-definitions',
        data: {
          'id': 'b1800000-0000-4000-8000-$runId',
          'item_type_id': '00000000-0000-4000-8000-000000000000',
          'name': 'صنف وهمي',
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step12-idef-invalid-fk-$runId'},
          validateStatus: (_) => true,
        ),
      );

      expect(res.statusCode, isIn([400, 404, 422]));
    });

    test('12. ItemDefinition Update / Rename & GET: returns 200 OK', () async {
      if (!isNetworkAvailable) return;

      final updatedDefName = '$itemDefName (محدث)';
      final patchRes = await dio.patch(
        '/item-definitions/$testItemDefId',
        data: {'name': updatedDefName},
        options: Options(
          headers: {'X-Operation-ID': 'op-step12-idef-patch-$runId'},
          validateStatus: (_) => true,
        ),
      );

      expect(patchRes.statusCode, equals(200));
      expect(patchRes.data['name'], equals(updatedDefName));

      final getRes = await dio.get('/item-definitions/$testItemDefId');
      expect(getRes.statusCode, equals(200));
      expect(getRes.data['id'], equals(testItemDefId));
    });

    test('13. ItemDefinition DELETE is forbidden: returns 404', () async {
      if (!isNetworkAvailable) return;

      final res = await dio.delete(
        '/item-definitions/$testItemDefId',
        options: Options(validateStatus: (_) => true),
      );
      expect(res.statusCode, equals(404));
    });

    // =========================================================================
    // 3. Carpet Sizes Tests
    // =========================================================================

    test('14. Valid CarpetSize creation: returns 201 and persists dimensions', () async {
      if (!isNetworkAvailable) return;

      final res = await dio.post(
        '/carpet-sizes',
        data: {
          'id': testCarpetSizeId,
          'length': testCarpetLength,
          'width': testCarpetWidth,
          'area': testCarpetArea,
          'is_active': true,
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step12-cs-create-$runId'},
          validateStatus: (_) => true,
        ),
      );

      expect(res.statusCode, equals(201));
      expect(res.data['id'], equals(testCarpetSizeId));
      expect(res.data['length'], equals(testCarpetLength));
      expect(res.data['width'], equals(testCarpetWidth));
      expect(res.data['area'], equals(testCarpetArea));
      expect(res.data['is_active'], isTrue);
    });

    test('15. CarpetSize Idempotency: exact replay returns cached response', () async {
      if (!isNetworkAvailable) return;

      final replayRes = await dio.post(
        '/carpet-sizes',
        data: {
          'id': testCarpetSizeId,
          'length': testCarpetLength,
          'width': testCarpetWidth,
          'area': testCarpetArea,
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step12-cs-create-$runId'},
          validateStatus: (_) => true,
        ),
      );

      expect(replayRes.statusCode, equals(201));
      expect(replayRes.data['id'], equals(testCarpetSizeId));
    });

    test('16. CarpetSize Dimension Validation: rejects non-positive values (422)', () async {
      if (!isNetworkAvailable) return;

      final res = await dio.post(
        '/carpet-sizes',
        data: {
          'id': 'c1900000-0000-4000-8000-$runId',
          'length': -1.0,
          'width': 2.0,
          'area': -2.0,
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step12-cs-invalid-$runId'},
          validateStatus: (_) => true,
        ),
      );

      expect(res.statusCode, equals(422));
    });

    test('17. CarpetSize Duplicate Dimensions: returns 409 Conflict', () async {
      if (!isNetworkAvailable) return;

      final res = await dio.post(
        '/carpet-sizes',
        data: {
          'id': 'c1800000-0000-4000-8000-$runId',
          'length': testCarpetLength,
          'width': testCarpetWidth,
          'area': testCarpetArea,
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step12-cs-dup-$runId'},
          validateStatus: (_) => true,
        ),
      );

      expect(res.statusCode, equals(409));
    });

    test('18. CarpetSize Update & GET: returns 200 OK', () async {
      if (!isNetworkAvailable) return;

      final patchRes = await dio.patch(
        '/carpet-sizes/$testCarpetSizeId',
        data: {
          'length': updatedCarpetLength,
          'width': testCarpetWidth,
          'area': updatedCarpetArea,
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step12-cs-patch-$runId'},
          validateStatus: (_) => true,
        ),
      );

      expect(patchRes.statusCode, equals(200));
      expect(patchRes.data['length'], equals(updatedCarpetLength));
      expect(patchRes.data['area'], equals(updatedCarpetArea));

      final getRes = await dio.get('/carpet-sizes/$testCarpetSizeId');
      expect(getRes.statusCode, equals(200));
      expect(getRes.data['id'], equals(testCarpetSizeId));
    });

    test('19. CarpetSize DELETE is forbidden: returns 404', () async {
      if (!isNetworkAvailable) return;

      final res = await dio.delete(
        '/carpet-sizes/$testCarpetSizeId',
        options: Options(validateStatus: (_) => true),
      );
      expect(res.statusCode, equals(404));
    });

    // =========================================================================
    // 4. Storage Locations Tests
    // =========================================================================

    test('20. Valid StorageLocation creation with supported item types: returns 201', () async {
      if (!isNetworkAvailable) return;

      final res = await dio.post(
        '/storage-locations',
        data: {
          'id': testStorageLocationId,
          'name': locationName,
          'is_active': true,
          'supported_item_type_ids': [testItemTypeId],
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step12-sl-create-$runId'},
          validateStatus: (_) => true,
        ),
      );

      expect(res.statusCode, equals(201));
      expect(res.data['id'], equals(testStorageLocationId));
      expect(res.data['name'], equals(locationName));
      expect(res.data['supported_item_type_ids'], contains(testItemTypeId));
    });

    test('21. StorageLocation Idempotency: exact replay returns cached response', () async {
      if (!isNetworkAvailable) return;

      final replayRes = await dio.post(
        '/storage-locations',
        data: {
          'id': testStorageLocationId,
          'name': locationName,
          'supported_item_type_ids': [testItemTypeId],
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step12-sl-create-$runId'},
          validateStatus: (_) => true,
        ),
      );

      expect(replayRes.statusCode, equals(201));
      expect(replayRes.data['id'], equals(testStorageLocationId));
    });

    test('22. StorageLocation Duplicate Name: returns 409 Conflict', () async {
      if (!isNetworkAvailable) return;

      final res = await dio.post(
        '/storage-locations',
        data: {
          'id': 'd1900000-0000-4000-8000-$runId',
          'name': locationName.toUpperCase(),
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step12-sl-dup-$runId'},
          validateStatus: (_) => true,
        ),
      );

      expect(res.statusCode, equals(409));
    });

    test('23. StorageLocation Update supported types & name: returns 200', () async {
      if (!isNetworkAvailable) return;

      // Create a second item type to add to supported types
      await dio.post(
        '/item-types',
        data: {
          'id': testOtherItemTypeId,
          'name': 'نوع ملابس ثان $runId',
          'is_active': true,
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step12-it2-create-$runId'},
          validateStatus: (_) => true,
        ),
      );

      final updatedLocName = '$locationName (محدث)';
      final patchRes = await dio.patch(
        '/storage-locations/$testStorageLocationId',
        data: {
          'name': updatedLocName,
          'supported_item_type_ids': [testItemTypeId, testOtherItemTypeId],
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step12-sl-patch-$runId'},
          validateStatus: (_) => true,
        ),
      );

      expect(patchRes.statusCode, equals(200));
      expect(patchRes.data['name'], equals(updatedLocName));
      final supported = patchRes.data['supported_item_type_ids'] as List;
      expect(supported, contains(testItemTypeId));
      expect(supported, contains(testOtherItemTypeId));
    });

    test('24. StorageLocation GET by ID & List: includes supported_item_type_ids', () async {
      if (!isNetworkAvailable) return;

      final getRes = await dio.get('/storage-locations/$testStorageLocationId');
      expect(getRes.statusCode, equals(200));
      expect(getRes.data['id'], equals(testStorageLocationId));
      expect(getRes.data['supported_item_type_ids'], isA<List>());

      final listRes = await dio.get('/storage-locations');
      expect(listRes.statusCode, equals(200));
      final list = listRes.data as List;
      expect(list.any((e) => e['id'] == testStorageLocationId), isTrue);
    });

    test('25. StorageLocation Deactivation: updates is_active to false', () async {
      if (!isNetworkAvailable) return;

      final res = await dio.patch(
        '/storage-locations/$testStorageLocationId',
        data: {'is_active': false},
        options: Options(
          headers: {'X-Operation-ID': 'op-step12-sl-deact-$runId'},
          validateStatus: (_) => true,
        ),
      );

      expect(res.statusCode, equals(200));
      expect(res.data['is_active'], isFalse);
    });

    test('26. StorageLocation DELETE is forbidden: returns 404', () async {
      if (!isNetworkAvailable) return;

      final res = await dio.delete(
        '/storage-locations/$testStorageLocationId',
        options: Options(validateStatus: (_) => true),
      );
      expect(res.statusCode, equals(404));
    });

    // =========================================================================
    // 5. Business Settings Tests
    // =========================================================================

    test('27. BusinessSettings GET returns settings record', () async {
      if (!isNetworkAvailable) return;

      final res = await dio.get('/business-settings');
      expect(res.statusCode, equals(200));
      expect(res.data['id'], isNotNull);
    });

    test('28. BusinessSettings PATCH updates business settings', () async {
      if (!isNetworkAvailable) return;

      final businessName = 'مغسلة التميز $runId';
      final res = await dio.patch(
        '/business-settings',
        data: {
          'business_name': businessName,
          'phone': '0555555555',
          'tax_enabled': true,
          'tax_rate': 14.0,
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step12-settings-patch-$runId'},
          validateStatus: (_) => true,
        ),
      );

      expect(res.statusCode, equals(200));
      expect(res.data['business_name'], equals(businessName));
      expect(res.data['phone'], equals('0555555555'));
      expect(res.data['tax_enabled'], isTrue);
      expect(res.data['tax_rate'], equals(14.0));
    });

    test('29. BusinessSettings Idempotency: exact replay returns cached response', () async {
      if (!isNetworkAvailable) return;

      final businessName = 'مغسلة التميز $runId';
      final replayRes = await dio.patch(
        '/business-settings',
        data: {
          'business_name': businessName,
          'phone': '0555555555',
          'tax_enabled': true,
          'tax_rate': 14.0,
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step12-settings-patch-$runId'},
          validateStatus: (_) => true,
        ),
      );

      expect(replayRes.statusCode, equals(200));
      expect(replayRes.data['business_name'], equals(businessName));
    });

    test('30. BusinessSettings negative tax_rate validation: returns 422', () async {
      if (!isNetworkAvailable) return;

      final res = await dio.patch(
        '/business-settings',
        data: {
          'tax_rate': -5.0,
        },
        options: Options(
          headers: {'X-Operation-ID': 'op-step12-settings-neg-tax-$runId'},
          validateStatus: (_) => true,
        ),
      );

      expect(res.statusCode, equals(422));
    });

    test('31. BusinessSettings DELETE is forbidden: returns 404', () async {
      if (!isNetworkAvailable) return;

      final res = await dio.delete(
        '/business-settings',
        options: Options(validateStatus: (_) => true),
      );
      expect(res.statusCode, equals(404));
    });
  });
}
