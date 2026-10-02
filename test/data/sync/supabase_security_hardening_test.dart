import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/config/supabase_config.dart';
import 'package:laundry_management/core/network/dio_client.dart';

void main() {
  group('Supabase Security Hardening Integration Tests', () {
    late final SupabaseConfig config;
    late final Dio directPostgrestDio;
    late final Dio edgeFunctionDio;

    setUpAll(() async {
      config = SupabaseConfig.resolve();
      edgeFunctionDio = DioClient(
        baseUrl: '${config.apiUrl}/api/v1',
        receiveTimeout: const Duration(seconds: 30),
        connectTimeout: const Duration(seconds: 30),
      ).dio;

      // Direct client simulating an untrusted external client targeting PostgREST endpoints directly
      directPostgrestDio = Dio(
        BaseOptions(
          baseUrl: config.urlRoot,
          headers: {
            'apikey': config.anonKey,
            'Authorization': 'Bearer ${config.anonKey}',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          validateStatus: (_) => true,
        ),
      );

      try {
        final res = await edgeFunctionDio.get(
          '/customers',
          queryParameters: {'limit': 1},
        );
        if (res.statusCode != 200) {
          fail('Backend /customers probe returned ${res.statusCode}');
        }
      } catch (e) {
        fail('Backend probe failed: $e. Configure live Supabase before running integration tests.');
      }
    });

    test(
      'Direct PostgREST RPC get_sync_changes is forbidden for anon role (HTTP 401/403)',
      () async {

        final res = await directPostgrestDio.post(
          '/rest/v1/rpc/get_sync_changes',
          data: {'p_after': 0, 'p_limit': 10},
        );

        // Expect permission denied
        expect(res.statusCode, isIn([401, 403, 404]));
      },
    );

    test(
      'Direct PostgREST RPC sync_create_customer is forbidden for anon role (HTTP 401/403)',
      () async {

        final res = await directPostgrestDio.post(
          '/rest/v1/rpc/sync_create_customer',
          data: {
            'p_op_id': 'op-unauthorized-test',
            'p_customer': {'name': 'Hacker', 'phone': '0500000000'},
          },
        );

        // Expect permission denied
        expect(res.statusCode, isIn([401, 403, 404]));
      },
    );

    test(
      'Direct PostgREST table SELECT on customers returns empty set under RLS default-deny',
      () async {

        final res = await directPostgrestDio.get('/rest/v1/customers');

        // PostgREST with RLS enabled and no policies returns empty array [] with 200
        expect(res.statusCode, equals(200));
        expect(res.data, equals([]));
      },
    );

    test(
      'Edge Function /sync/changes remains authorized and functional via service-role bridge',
      () async {

        final res = await edgeFunctionDio.get(
          '/sync/changes',
          queryParameters: {'after': 0, 'limit': 1},
        );

        expect(res.statusCode, equals(200));
        expect(res.data, isA<Map<String, dynamic>>());
        expect((res.data as Map)['changes'], isNotNull);
      },
    );

    test(
      'Edge Function /customers remains authorized and functional via service-role bridge',
      () async {

        final res = await edgeFunctionDio.get(
          '/customers',
          queryParameters: {'limit': 5},
        );

        expect(res.statusCode, equals(200));
        expect(res.data, isA<List>());
      },
    );
  });
}
