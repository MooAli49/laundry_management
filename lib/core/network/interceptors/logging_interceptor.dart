import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// A safe, debug-only logging interceptor for Dio HTTP requests and responses.
///
/// Ensures sensitive headers (API keys, authorization tokens, secrets) are never
/// printed to logs. In release mode, logging is completely disabled.
class LoggingInterceptor extends Interceptor {
  final bool _isEnabled;
  final void Function(String message) _printer;

  static const String _startTimeKey = '_request_start_time';

  static const Set<String> _explicitSensitiveHeaders = {
    'authorization',
    'apikey',
    'x-api-key',
    'cookie',
    'set-cookie',
    'token',
    'x-supabase-auth',
  };

  LoggingInterceptor({bool? isDebug, void Function(String message)? printer})
    : _isEnabled = isDebug ?? kDebugMode,
      _printer = printer ?? debugPrint;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!_isEnabled) {
      return handler.next(options);
    }

    options.extra[_startTimeKey] = DateTime.now().millisecondsSinceEpoch;

    _printer('--> ${options.method} ${options.uri}');

    final safeHeaders = _sanitizeHeaders(options.headers);
    if (safeHeaders.isNotEmpty) {
      _printer('Headers: $safeHeaders');
    }

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!_isEnabled) {
      return handler.next(response);
    }

    final duration = _calculateDuration(response.requestOptions);
    final durationStr = duration != null ? ' (${duration}ms)' : '';
    _printer(
      '<-- ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.uri}$durationStr',
    );

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!_isEnabled) {
      return handler.next(err);
    }

    final duration = _calculateDuration(err.requestOptions);
    final durationStr = duration != null ? ' (${duration}ms)' : '';
    final statusCode = err.response?.statusCode != null
        ? '${err.response!.statusCode}'
        : 'NO_STATUS';

    _printer(
      '<-- ERROR $statusCode ${err.requestOptions.method} ${err.requestOptions.uri}$durationStr',
    );
    if (err.message != null && err.message!.isNotEmpty) {
      _printer('Error Message: ${err.message}');
    }

    handler.next(err);
  }

  int? _calculateDuration(RequestOptions options) {
    final startTime = options.extra[_startTimeKey] as int?;
    if (startTime == null) return null;
    return DateTime.now().millisecondsSinceEpoch - startTime;
  }

  Map<String, dynamic> _sanitizeHeaders(Map<String, dynamic> headers) {
    final sanitized = <String, dynamic>{};
    headers.forEach((key, value) {
      if (_isSensitiveHeader(key)) {
        sanitized[key] = '[REDACTED]';
      } else {
        sanitized[key] = value;
      }
    });
    return sanitized;
  }

  static bool _isSensitiveHeader(String name) {
    final lower = name.toLowerCase();
    if (_explicitSensitiveHeaders.contains(lower)) return true;
    return lower.contains('secret') ||
        lower.contains('token') ||
        lower.contains('key') ||
        lower.contains('auth') ||
        lower.contains('password') ||
        lower.contains('credential');
  }
}
