import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:laundry_management/core/di/injection.dart';
import 'package:laundry_management/core/network/dio_client.dart';
import 'package:laundry_management/core/network/interceptors/api_key_interceptor.dart';
import 'package:laundry_management/core/network/interceptors/logging_interceptor.dart';
import 'package:laundry_management/core/network/network_info.dart';

void main() {
  group('DioClient Tests', () {
    test('configures default 15-second timeouts', () {
      final client = DioClient();
      final options = client.dio.options;

      expect(options.connectTimeout, equals(const Duration(seconds: 15)));
      expect(options.receiveTimeout, equals(const Duration(seconds: 15)));
      expect(options.sendTimeout, equals(const Duration(seconds: 15)));
    });

    test('supports custom timeout overrides', () {
      final client = DioClient(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 25),
        sendTimeout: const Duration(seconds: 20),
      );
      final options = client.dio.options;

      expect(options.connectTimeout, equals(const Duration(seconds: 30)));
      expect(options.receiveTimeout, equals(const Duration(seconds: 25)));
      expect(options.sendTimeout, equals(const Duration(seconds: 20)));
    });

    test('configures JSON accept header and responseType', () {
      final client = DioClient();
      final options = client.dio.options;

      expect(options.headers['Accept'], equals('application/json'));
      expect(options.responseType, equals(ResponseType.json));
    });

    test('configures custom base URL when provided', () {
      const customBaseUrl = 'https://custom-project.supabase.co';
      final client = DioClient(baseUrl: customBaseUrl);

      expect(client.dio.options.baseUrl, equals(customBaseUrl));
    });

    test('registers ApiKeyInterceptor and LoggingInterceptor by default', () {
      final client = DioClient();
      final interceptors = client.dio.interceptors;

      expect(
        interceptors.any((i) => i is ApiKeyInterceptor),
        isTrue,
        reason: 'ApiKeyInterceptor must be registered',
      );
      expect(
        interceptors.any((i) => i is LoggingInterceptor),
        isTrue,
        reason: 'LoggingInterceptor must be registered',
      );
    });

    test('appends additionalInterceptors when supplied', () {
      final customInterceptor = QueuedInterceptor();
      final client = DioClient(additionalInterceptors: [customInterceptor]);

      expect(client.dio.interceptors.contains(customInterceptor), isTrue);
    });

    test(
      'attaches ApiKey and Content-Type headers through interceptors in fake request',
      () {
        const testKey = 'supabase_key_abc';
        final client = DioClient(
          apiKey: testKey,
          baseUrl: 'https://example.supabase.co',
        );

        final apiKeyInterceptor = client.dio.interceptors
            .whereType<ApiKeyInterceptor>()
            .first;
        expect(apiKeyInterceptor, isNotNull);

        final options = RequestOptions(path: '/rest/v1/customers');
        final handler = RequestInterceptorHandler();
        apiKeyInterceptor.onRequest(options, handler);

        expect(options.headers['apikey'], equals(testKey));
        expect(options.headers['Authorization'], equals('Bearer $testKey'));
        expect(options.headers['Content-Type'], equals('application/json'));
      },
    );
  });

  group('Networking DI Registration Tests', () {
    tearDown(() async {
      await GetIt.instance.reset();
    });

    test(
      'initDependencies registers NetworkInfo, DioClient, and Dio',
      () async {
        await initDependencies();

        expect(GetIt.instance.isRegistered<NetworkInfo>(), isTrue);
        expect(GetIt.instance.isRegistered<DioClient>(), isTrue);
        expect(GetIt.instance.isRegistered<Dio>(), isTrue);

        final networkInfo = GetIt.instance<NetworkInfo>();
        final dioClient = GetIt.instance<DioClient>();
        final dio = GetIt.instance<Dio>();

        expect(networkInfo, isA<NetworkInfo>());
        expect(dioClient, isA<DioClient>());
        expect(dio, isA<Dio>());
        expect(identical(dio, dioClient.dio), isTrue);
      },
    );
  });
}
