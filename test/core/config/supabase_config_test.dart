import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/config/supabase_config.dart';
import 'package:laundry_management/core/network/dio_client.dart';
import 'package:laundry_management/core/network/interceptors/api_key_interceptor.dart';

void main() {
  group('SupabaseConfig Unit Tests (RISK-002)', () {
    group('Debug / Development Fallback Behavior', () {
      test(
        'resolve(isRelease: false) falls back to development credentials when unconfigured',
        () {
          final config = SupabaseConfig.resolve(isRelease: false);

          expect(config.urlRoot, equals(SupabaseConfig.defaultDevUrlRoot));
          expect(config.apiUrl, equals(SupabaseConfig.defaultDevApiUrl));
          expect(config.anonKey, equals(SupabaseConfig.defaultDevAnonKey));
        },
      );

      test(
        'resolve(isRelease: false) respects custom urlRoot and derives apiUrl',
        () {
          final config = SupabaseConfig.resolve(
            customUrlRoot: 'https://staging.supabase.co',
            isRelease: false,
          );

          expect(config.urlRoot, equals('https://staging.supabase.co'));
          expect(
            config.apiUrl,
            equals('https://staging.supabase.co/functions/v1/api'),
          );
          expect(config.anonKey, equals(SupabaseConfig.defaultDevAnonKey));
        },
      );

      test(
        'resolve(isRelease: false) respects custom apiUrl and derives urlRoot',
        () {
          final config = SupabaseConfig.resolve(
            customApiUrl: 'https://custom-api.supabase.co/functions/v1/api',
            isRelease: false,
          );

          expect(config.urlRoot, equals('https://custom-api.supabase.co'));
          expect(
            config.apiUrl,
            equals('https://custom-api.supabase.co/functions/v1/api'),
          );
          expect(config.anonKey, equals(SupabaseConfig.defaultDevAnonKey));
        },
      );

      test(
        'resolve(isRelease: false) respects custom anonKey with dev URLs',
        () {
          final config = SupabaseConfig.resolve(
            customAnonKey: 'dev-custom-key',
            isRelease: false,
          );

          expect(config.urlRoot, equals(SupabaseConfig.defaultDevUrlRoot));
          expect(config.apiUrl, equals(SupabaseConfig.defaultDevApiUrl));
          expect(config.anonKey, equals('dev-custom-key'));
        },
      );
    });

    group('Release Mode Fail-Fast & Validation Behavior', () {
      test(
        'resolve(isRelease: true) throws StateError when both URL and anonKey are missing',
        () {
          expect(
            () => SupabaseConfig.resolve(isRelease: true),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                allOf(
                  contains('Release build configuration error'),
                  contains('SUPABASE_URL_ROOT'),
                  contains('SUPABASE_ANON_KEY'),
                  contains('--dart-define'),
                ),
              ),
            ),
          );
        },
      );

      test(
        'resolve(isRelease: true) throws StateError when only anonKey is missing',
        () {
          expect(
            () => SupabaseConfig.resolve(
              customUrlRoot: 'https://prod.supabase.co',
              isRelease: true,
            ),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                allOf(
                  contains('missing required environment variables: SUPABASE_ANON_KEY.'),
                  contains('--dart-define=SUPABASE_ANON_KEY'),
                ),
              ),
            ),
          );
        },
      );

      test(
        'resolve(isRelease: true) throws StateError when only URL is missing',
        () {
          expect(
            () => SupabaseConfig.resolve(
              customAnonKey: 'prod-anon-key-xyz',
              isRelease: true,
            ),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                allOf(
                  contains('missing required environment variables: SUPABASE_URL_ROOT (or SUPABASE_URL).'),
                  contains('--dart-define=SUPABASE_URL_ROOT'),
                ),
              ),
            ),
          );
        },
      );

      test('resolve(isRelease: true) treats whitespace-only inputs as empty', () {
        expect(
          () => SupabaseConfig.resolve(
            customUrlRoot: '   ',
            customAnonKey: '   ',
            isRelease: true,
          ),
          throwsA(isA<StateError>()),
        );

        expect(
          () => SupabaseConfig.resolve(
            customUrlRoot: 'https://prod.supabase.co',
            customAnonKey: '   ',
            isRelease: true,
          ),
          throwsA(isA<StateError>()),
        );
      });

      test(
        'resolve(isRelease: true) succeeds when valid production URL and anonKey are supplied',
        () {
          final config = SupabaseConfig.resolve(
            customUrlRoot: 'https://prod-project.supabase.co',
            customAnonKey: 'prod-public-anon-key-12345',
            isRelease: true,
          );

          expect(config.urlRoot, equals('https://prod-project.supabase.co'));
          expect(
            config.apiUrl,
            equals('https://prod-project.supabase.co/functions/v1/api'),
          );
          expect(config.anonKey, equals('prod-public-anon-key-12345'));
        },
      );

      test(
        'resolve(isRelease: true) accepts customApiUrl and extracts urlRoot',
        () {
          final config = SupabaseConfig.resolve(
            customApiUrl: 'https://prod-api.supabase.co/functions/v1/api',
            customAnonKey: 'prod-public-anon-key-67890',
            isRelease: true,
          );

          expect(config.urlRoot, equals('https://prod-api.supabase.co'));
          expect(
            config.apiUrl,
            equals('https://prod-api.supabase.co/functions/v1/api'),
          );
          expect(config.anonKey, equals('prod-public-anon-key-67890'));
        },
      );

      test(
        'resolve(isRelease: true) isolates release configuration from development defaults',
        () {
          expect(SupabaseConfig.envUrlRoot, isA<String>());
          expect(SupabaseConfig.envUrl, isA<String>());
          expect(SupabaseConfig.envAnonKey, isA<String>());

          final config = SupabaseConfig.resolve(
            customUrlRoot: 'https://prod-project.supabase.co',
            customAnonKey: 'prod-public-anon-key-12345',
            isRelease: true,
          );

          expect(
            config.urlRoot,
            isNot(equals(SupabaseConfig.defaultDevUrlRoot)),
          );
          expect(
            config.apiUrl,
            isNot(equals(SupabaseConfig.defaultDevApiUrl)),
          );
          expect(
            config.anonKey,
            isNot(equals(SupabaseConfig.defaultDevAnonKey)),
          );
        },
      );

      test(
        'resolve(isRelease: true) throws StateError when Development Supabase URL is supplied',
        () {
          expect(
            () => SupabaseConfig.resolve(
              customUrlRoot: SupabaseConfig.defaultDevUrlRoot,
              customAnonKey: 'valid-prod-anon-key-12345',
              isRelease: true,
            ),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                allOf(
                  contains('Development Supabase project'),
                  contains('cannot be targeted in release builds'),
                ),
              ),
            ),
          );
        },
      );

      test(
        'resolve(isRelease: true) throws StateError when Development anon key is supplied',
        () {
          expect(
            () => SupabaseConfig.resolve(
              customUrlRoot: SupabaseConfig.prodUrlRoot,
              customAnonKey: SupabaseConfig.defaultDevAnonKey,
              isRelease: true,
            ),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                allOf(
                  contains('Development Supabase anon key cannot be used in release builds'),
                ),
              ),
            ),
          );
        },
      );

      test(
        'resolve(isRelease: true) throws StateError when placeholder anon key is supplied',
        () {
          expect(
            () => SupabaseConfig.resolve(
              customUrlRoot: SupabaseConfig.prodUrlRoot,
              customAnonKey: '<your-production-anon-key>',
              isRelease: true,
            ),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('Placeholder anon key detected in release build'),
              ),
            ),
          );
        },
      );

      test(
        'resolve(isRelease: true) succeeds with confirmed production URL and valid key',
        () {
          final config = SupabaseConfig.resolve(
            customUrlRoot: SupabaseConfig.prodUrlRoot,
            customAnonKey: 'valid-prod-anon-key-67890',
            isRelease: true,
          );

          expect(config.urlRoot, equals('https://rvrskluqfbrkvvlxtxfp.supabase.co'));
          expect(config.apiUrl, equals('https://rvrskluqfbrkvvlxtxfp.supabase.co/functions/v1/api'));
          expect(config.anonKey, equals('valid-prod-anon-key-67890'));
        },
      );
    });

    group('URL Format Validation', () {
      test('throws FormatException on malformed URL without scheme/host', () {
        expect(
          () => SupabaseConfig.resolve(
            customUrlRoot: 'not-a-valid-url',
            isRelease: false,
          ),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws FormatException on unsupported scheme (e.g. ftp)', () {
        expect(
          () => SupabaseConfig.resolve(
            customUrlRoot: 'ftp://files.supabase.co',
            isRelease: false,
          ),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws FormatException on invalid API URL', () {
        expect(
          () => SupabaseConfig.resolve(
            customApiUrl: '://invalid-api',
            isRelease: false,
          ),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('DioClient & ApiKeyInterceptor Integration', () {
      test('DioClient uses SupabaseConfig to configure baseUrl and headers', () {
        const customUrl = 'https://unit-test.supabase.co';
        const customKey = 'unit-test-anon-key';
        final config = SupabaseConfig.resolve(
          customUrlRoot: customUrl,
          customAnonKey: customKey,
          isRelease: false,
        );

        final client = DioClient(config: config);
        expect(
          client.dio.options.baseUrl,
          equals('$customUrl/functions/v1/api'),
        );

        final interceptor = client.dio.interceptors
            .whereType<ApiKeyInterceptor>()
            .first;
        final options = RequestOptions(path: '/orders');
        final handler = RequestInterceptorHandler();
        interceptor.onRequest(options, handler);

        expect(options.headers['apikey'], equals(customKey));
        expect(options.headers['Authorization'], equals('Bearer $customKey'));
      });

      test('DioClient direct parameter overrides take precedence over config', () {
        final config = SupabaseConfig.resolve(isRelease: false);
        final client = DioClient(
          config: config,
          baseUrl: 'https://direct-override.supabase.co',
          apiKey: 'direct-override-key',
        );

        expect(
          client.dio.options.baseUrl,
          equals('https://direct-override.supabase.co'),
        );

        final interceptor = client.dio.interceptors
            .whereType<ApiKeyInterceptor>()
            .first;
        final options = RequestOptions(path: '/orders');
        final handler = RequestInterceptorHandler();
        interceptor.onRequest(options, handler);

        expect(options.headers['apikey'], equals('direct-override-key'));
        expect(
          options.headers['Authorization'],
          equals('Bearer direct-override-key'),
        );
      });

      test(
        'ApiKeyInterceptor attaches apikey and Authorization Bearer headers',
        () {
          final interceptor = ApiKeyInterceptor(apiKey: 'standalone-key');
          final options = RequestOptions(path: '/test');
          final handler = RequestInterceptorHandler();
          interceptor.onRequest(options, handler);

          expect(options.headers['apikey'], equals('standalone-key'));
          expect(
            options.headers['Authorization'],
            equals('Bearer standalone-key'),
          );
          expect(options.headers['Content-Type'], equals('application/json'));
        },
      );
    });
  });
}
