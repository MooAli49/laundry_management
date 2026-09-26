import 'package:dio/dio.dart';

import '../config/supabase_config.dart';
import 'interceptors/api_key_interceptor.dart';
import 'interceptors/logging_interceptor.dart';

/// Centralized factory and configuration for the infrastructure [Dio] HTTP client.
///
/// Configures default base URL, sensible timeouts (15s), JSON content-type headers,
/// and registers infrastructure interceptors ([ApiKeyInterceptor], [LoggingInterceptor]).
class DioClient {
  /// Default connection timeout for all network requests.
  static const Duration defaultConnectTimeout = Duration(seconds: 15);

  /// Default receive timeout for all network requests.
  static const Duration defaultReceiveTimeout = Duration(seconds: 15);

  /// Default send timeout for all network requests.
  static const Duration defaultSendTimeout = Duration(seconds: 15);

  final Dio _dio;

  DioClient({
    String? baseUrl,
    String? apiKey,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
    List<Interceptor>? additionalInterceptors,
    Dio? dio,
    SupabaseConfig? config,
  }) : _dio = dio ?? Dio() {
    final effectiveConfig =
        config ??
        SupabaseConfig.resolve(
          customApiUrl: baseUrl,
          customAnonKey: apiKey,
        );

    final effectiveBaseUrl = baseUrl ?? effectiveConfig.apiUrl;
    final effectiveApiKey = apiKey ?? effectiveConfig.anonKey;

    _dio.options = BaseOptions(
      baseUrl: effectiveBaseUrl,
      connectTimeout: connectTimeout ?? defaultConnectTimeout,
      receiveTimeout: receiveTimeout ?? defaultReceiveTimeout,
      sendTimeout: sendTimeout ?? defaultSendTimeout,
      headers: {'Accept': 'application/json'},
      responseType: ResponseType.json,
    );

    _dio.interceptors.addAll([
      ApiKeyInterceptor(apiKey: effectiveApiKey),
      LoggingInterceptor(),
      if (additionalInterceptors != null) ...additionalInterceptors,
    ]);
  }

  /// The configured [Dio] instance for use by infrastructure data sources and Retrofit.
  Dio get dio => _dio;
}
