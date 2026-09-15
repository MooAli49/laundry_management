import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/network/interceptors/api_key_interceptor.dart';

void main() {
  group('ApiKeyInterceptor Tests', () {
    const testApiKey = 'test_anon_key_12345';

    test('adds apikey and Authorization headers when apiKey is present', () {
      final interceptor = ApiKeyInterceptor(apiKey: testApiKey);
      final options = RequestOptions(path: '/rest/v1/customers');
      final handler = RequestInterceptorHandler();

      interceptor.onRequest(options, handler);

      expect(options.headers['apikey'], equals(testApiKey));
      expect(options.headers['Authorization'], equals('Bearer $testApiKey'));
    });

    test('sets Content-Type to application/json by default', () {
      final interceptor = ApiKeyInterceptor(apiKey: testApiKey);
      final options = RequestOptions(path: '/rest/v1/orders');
      final handler = RequestInterceptorHandler();

      interceptor.onRequest(options, handler);

      expect(options.headers['Content-Type'], equals('application/json'));
    });

    test('preserves existing Content-Type header if already set', () {
      final interceptor = ApiKeyInterceptor(apiKey: testApiKey);
      final options = RequestOptions(
        path: '/rest/v1/upload',
        headers: {'Content-Type': 'multipart/form-data'},
      );
      final handler = RequestInterceptorHandler();

      interceptor.onRequest(options, handler);

      expect(options.headers['Content-Type'], equals('multipart/form-data'));
    });

    test('omits apikey and Authorization headers when apiKey is empty', () {
      final interceptor = ApiKeyInterceptor(apiKey: '');
      final options = RequestOptions(path: '/rest/v1/health');
      final handler = RequestInterceptorHandler();

      interceptor.onRequest(options, handler);

      expect(options.headers.containsKey('apikey'), isFalse);
      expect(options.headers.containsKey('Authorization'), isFalse);
      expect(options.headers['Content-Type'], equals('application/json'));
    });
  });
}
