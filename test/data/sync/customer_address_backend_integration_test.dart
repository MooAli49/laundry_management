import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/network/dio_client.dart';

void main() {
  group('Customer Address Backend RPC Integration Tests', () {
    late DioClient client;
    late Dio dio;
    bool isNetworkAvailable = true;

    final runId = (DateTime.now().microsecondsSinceEpoch % 0xFFFFFFFFFFFF)
        .toRadixString(16)
        .padLeft(12, '0');

    late final String customer1Id;
    late final String customer1Phone;
    late final String customer2Id;
    late final String customer2Phone;
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

      customer1Id = 'c6000001-0001-4001-8001-$runId';
      customer1Phone =
          '012${(DateTime.now().microsecondsSinceEpoch % 100000000).toString().padLeft(8, '0')}';

      customer2Id = 'c6000002-0002-4002-8002-$runId';
      customer2Phone =
          '012${((DateTime.now().microsecondsSinceEpoch + 1) % 100000000).toString().padLeft(8, '0')}';
    });

    test('15. Create customer with address persists address and reflects in sync_changes', () async {
      if (!isNetworkAvailable) return;

      final opId = 'op-addr-create-$runId';
      final res = await dio.post(
        '/customers',
        options: Options(headers: {'X-Operation-ID': opId}),
        data: {
          'id': customer1Id,
          'name': 'عميل العنوان الحي',
          'phone': customer1Phone,
          'address': '10 شارع التحرير، الدقي',
          'notes': 'عميل تجريبي للعنوان',
        },
      );

      expect(res.statusCode, equals(201));
      final data = res.data as Map<String, dynamic>;
      expect(data['id'], equals(customer1Id));
      expect(data['address'], equals('10 شارع التحرير، الدقي'));

      // Verify GET returns address
      final getRes = await dio.get('/customers/$customer1Id');
      expect(getRes.statusCode, equals(200));
      expect(getRes.data['address'], equals('10 شارع التحرير، الدقي'));

      // Verify sync_changes payload contains address
      final syncRes = await dio.get('/sync/changes', queryParameters: {
        'after': baseSeq,
        'limit': 50,
      });
      expect(syncRes.statusCode, equals(200));
      final changes = (syncRes.data['changes'] as List).cast<Map<String, dynamic>>();
      final customerChange = changes.firstWhere(
        (c) => c['entity_id'] == customer1Id && c['operation_type'] == 'create',
      );
      expect(customerChange['payload']['address'], equals('10 شارع التحرير، الدقي'));
    });

    test('16. Update customer address replaces existing address and reflects in sync_changes', () async {
      if (!isNetworkAvailable) return;

      final opId = 'op-addr-update-$runId';
      final res = await dio.patch(
        '/customers/$customer1Id',
        options: Options(headers: {'X-Operation-ID': opId}),
        data: {
          'address': '50 شارع النيل، العجوزة',
        },
      );

      expect(res.statusCode, equals(200));
      final data = res.data as Map<String, dynamic>;
      expect(data['address'], equals('50 شارع النيل، العجوزة'));

      // Verify GET returns updated address
      final getRes = await dio.get('/customers/$customer1Id');
      expect(getRes.statusCode, equals(200));
      expect(getRes.data['address'], equals('50 شارع النيل، العجوزة'));

      // Verify sync_changes payload contains new address
      final syncRes = await dio.get('/sync/changes', queryParameters: {
        'after': baseSeq,
        'limit': 50,
      });
      final changes = (syncRes.data['changes'] as List).cast<Map<String, dynamic>>();
      final updateChange = changes.firstWhere(
        (c) => c['operation_id'] == opId,
      );
      expect(updateChange['payload']['address'], equals('50 شارع النيل، العجوزة'));
    });

    test('17. Clear address remotely by passing null sets address to NULL', () async {
      if (!isNetworkAvailable) return;

      final opId = 'op-addr-clear-$runId';
      final res = await dio.patch(
        '/customers/$customer1Id',
        options: Options(headers: {'X-Operation-ID': opId}),
        data: {
          'address': null,
        },
      );

      expect(res.statusCode, equals(200));
      final data = res.data as Map<String, dynamic>;
      expect(data['address'], isNull);

      // Verify GET returns null address
      final getRes = await dio.get('/customers/$customer1Id');
      expect(getRes.statusCode, equals(200));
      expect(getRes.data['address'], isNull);

      // Verify sync_changes payload contains null address
      final syncRes = await dio.get('/sync/changes', queryParameters: {
        'after': baseSeq,
        'limit': 50,
      });
      final changes = (syncRes.data['changes'] as List).cast<Map<String, dynamic>>();
      final clearChange = changes.firstWhere(
        (c) => c['operation_id'] == opId,
      );
      expect(clearChange['payload']['address'], isNull);
    });

    test('18. Existing customer behavior: absent address on create defaults to null; absent address on update preserves existing', () async {
      if (!isNetworkAvailable) return;

      // A. Create customer without address key
      final createOpId = 'op-addr-legacy-$runId';
      final createRes = await dio.post(
        '/customers',
        options: Options(headers: {'X-Operation-ID': createOpId}),
        data: {
          'id': customer2Id,
          'name': 'عميل بدون عنوان',
          'phone': customer2Phone,
        },
      );
      expect(createRes.statusCode, equals(201));
      expect(createRes.data['address'], isNull);

      // B. Set address on customer 2
      await dio.patch(
        '/customers/$customer2Id',
        data: {'address': 'ميدان لبنان، المهندسين'},
      );
      final check1 = await dio.get('/customers/$customer2Id');
      expect(check1.data['address'], equals('ميدان لبنان، المهندسين'));

      // C. Update only name on customer 2 (address key absent)
      final updateOpId = 'op-addr-preserve-$runId';
      final updateRes = await dio.patch(
        '/customers/$customer2Id',
        options: Options(headers: {'X-Operation-ID': updateOpId}),
        data: {
          'name': 'عميل بدون عنوان محدث الاسم',
        },
      );
      expect(updateRes.statusCode, equals(200));
      // Address must be preserved!
      expect(updateRes.data['address'], equals('ميدان لبنان، المهندسين'));

      final check2 = await dio.get('/customers/$customer2Id');
      expect(check2.data['name'], equals('عميل بدون عنوان محدث الاسم'));
      expect(check2.data['address'], equals('ميدان لبنان، المهندسين'));

      // D. Whitespace-only address is normalized to null
      final wsRes = await dio.patch(
        '/customers/$customer2Id',
        data: {'address': '   \t  '},
      );
      expect(wsRes.statusCode, equals(200));
      expect(wsRes.data['address'], isNull);

      final check3 = await dio.get('/customers/$customer2Id');
      expect(check3.data['address'], isNull);
    });
  });
}
