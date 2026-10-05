import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/network/interceptors/logging_interceptor.dart';

void main() {
  group('LoggingInterceptor Tests', () {
    late List<String> printedLogs;
    late LoggingInterceptor interceptor;

    setUp(() {
      printedLogs = [];
      interceptor = LoggingInterceptor(
        isDebug: true,
        printer: (msg) => printedLogs.add(msg),
      );
    });

    test('logs request method and URI', () async {
      final options = RequestOptions(
        path: 'https://api.example.com/rest/v1/customers',
        method: 'GET',
      );
      final handler = RequestInterceptorHandler();

      interceptor.onRequest(options, handler);

      expect(
        printedLogs.any(
          (log) =>
              log.contains('--> GET https://api.example.com/rest/v1/customers'),
        ),
        isTrue,
      );
    });

    test(
      'redacts sensitive headers (apikey, Authorization, secret, token, password)',
      () async {
        final options = RequestOptions(
          path: 'https://api.example.com/rest/v1/customers',
          method: 'POST',
          headers: {
            'apikey': 'super_secret_anon_key_123',
            'Authorization': 'Bearer secret_jwt_token',
            'x-api-key': 'another_secret',
            'cookie': 'session=abc',
            'X-Custom-Token': 'custom_token_val',
            'user_password': 'plain_password',
            'X-Client-Version': '1.0.0',
          },
        );
        final handler = RequestInterceptorHandler();

        interceptor.onRequest(options, handler);

        // Verify that no secret value appears anywhere in logs
        final allLogs = printedLogs.join('\n');
        expect(allLogs.contains('super_secret_anon_key_123'), isFalse);
        expect(allLogs.contains('secret_jwt_token'), isFalse);
        expect(allLogs.contains('another_secret'), isFalse);
        expect(allLogs.contains('session=abc'), isFalse);
        expect(allLogs.contains('custom_token_val'), isFalse);
        expect(allLogs.contains('plain_password'), isFalse);

        // Sensitive headers should be marked as [REDACTED]
        expect(allLogs.contains('[REDACTED]'), isTrue);

        // Safe header value is preserved
        expect(allLogs.contains('1.0.0'), isTrue);
      },
    );

    test('logs response status code, method, and URI', () async {
      final options = RequestOptions(
        path: 'https://api.example.com/rest/v1/orders',
        method: 'GET',
      );
      final response = Response(requestOptions: options, statusCode: 200);
      final handler = ResponseInterceptorHandler();

      interceptor.onResponse(response, handler);

      expect(
        printedLogs.any(
          (log) => log.contains(
            '<-- 200 GET https://api.example.com/rest/v1/orders',
          ),
        ),
        isTrue,
      );
    });

    test('logs error status code, method, URI, and message', () async {
      final options = RequestOptions(
        path: 'https://api.example.com/rest/v1/orders',
        method: 'POST',
      );
      final dioException = DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 500),
        message: 'Internal server error occurred',
        type: DioExceptionType.badResponse,
      );
      final handler = TestErrorInterceptorHandler();

      interceptor.onError(dioException, handler);

      expect(handler.handledError, equals(dioException));
      final allLogs = printedLogs.join('\n');
      expect(
        allLogs.contains(
          '<-- ERROR 500 POST https://api.example.com/rest/v1/orders',
        ),
        isTrue,
      );
      expect(allLogs.contains('Internal server error occurred'), isTrue);
    });

    test(
      'does NOT emit any logs when isDebug is false (release mode simulation)',
      () async {
        final releaseInterceptor = LoggingInterceptor(
          isDebug: false,
          printer: (msg) => printedLogs.add(msg),
        );

        final options = RequestOptions(
          path: 'https://api.example.com/rest/v1/customers',
          method: 'GET',
          headers: {'apikey': 'secret'},
        );
        final requestHandler = RequestInterceptorHandler();
        releaseInterceptor.onRequest(options, requestHandler);

        final response = Response(requestOptions: options, statusCode: 200);
        final responseHandler = ResponseInterceptorHandler();
        releaseInterceptor.onResponse(response, responseHandler);

        final dioException = DioException(
          requestOptions: options,
          message: 'Failed',
        );
        final errorHandler = TestErrorInterceptorHandler();
        releaseInterceptor.onError(dioException, errorHandler);

        expect(errorHandler.handledError, equals(dioException));
        expect(printedLogs, isEmpty);
      },
    );
  });
}

class TestErrorInterceptorHandler extends ErrorInterceptorHandler {
  DioException? handledError;

  @override
  void next(DioException err) {
    handledError = err;
  }
}
