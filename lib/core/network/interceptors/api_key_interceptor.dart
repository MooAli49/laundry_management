import 'package:dio/dio.dart';

import '../../config/supabase_config.dart';

/// Interceptor that attaches the static infrastructure API key headers
/// required by the remote Supabase REST API / Edge Functions.
///
/// This is NOT an authentication or session-management mechanism.
/// It operates purely at the infrastructure layer.
class ApiKeyInterceptor extends Interceptor {
  final String _apiKey;

  ApiKeyInterceptor({String? apiKey, SupabaseConfig? config})
      : _apiKey = apiKey ??
            (config?.anonKey ??
                SupabaseConfig.resolve(customAnonKey: apiKey).anonKey);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_apiKey.isNotEmpty) {
      options.headers['apikey'] = _apiKey;
      options.headers['Authorization'] = 'Bearer $_apiKey';
    }
    options.headers['Content-Type'] ??= 'application/json';
    handler.next(options);
  }
}
