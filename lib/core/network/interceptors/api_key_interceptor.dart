import 'package:dio/dio.dart';

/// Interceptor that attaches the static infrastructure API key headers
/// required by the remote Supabase REST API / Edge Functions.
///
/// This is NOT an authentication or session-management mechanism.
/// It operates purely at the infrastructure layer.
class ApiKeyInterceptor extends Interceptor {
  final String _apiKey;

  ApiKeyInterceptor({String? apiKey})
    : _apiKey =
          apiKey ??
          const String.fromEnvironment(
            'SUPABASE_ANON_KEY',
            defaultValue:
                'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR5aGZnbmJoaWp1a2JkcHRyZXRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg0NjcxNDcsImV4cCI6MjEwNDA0MzE0N30.gInc0tuzZiWq8EeEqbNBYa_Ay4liCcB4iGGOjUMnOBw',
          );

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
