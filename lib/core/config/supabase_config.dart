import 'package:flutter/foundation.dart';

/// Centralized configuration and environment resolution for Supabase infrastructure.
///
/// Encapsulates environment variable retrieval, development fallback defaults,
/// URI format validation, and Release-mode safety checks (RISK-002).
///
/// In Debug/Profile/Test environments, defaults to the development Supabase project
/// so that local development and automated integration tests run seamlessly.
///
/// In Release builds ([kReleaseMode] == true), silent fallback to development credentials
/// is strictly forbidden. Missing required environment variables fail fast with an actionable
/// [StateError].
class SupabaseConfig {
  /// The root URL of the Supabase project (e.g. `https://<ref>.supabase.co`).
  final String urlRoot;

  /// The base URL for Edge Function REST APIs (e.g. `https://<ref>.supabase.co/functions/v1/api`).
  final String apiUrl;

  /// The public anonymous client key.
  final String anonKey;

  const SupabaseConfig({
    required this.urlRoot,
    required this.apiUrl,
    required this.anonKey,
  });

  /// Production project reference.
  static const String prodProjectRef = 'rvrskluqfbrkvvlxtxfp';

  /// Expected production project root URL.
  static const String prodUrlRoot =
      'https://rvrskluqfbrkvvlxtxfp.supabase.co';

  /// Expected production Edge Function REST API endpoint.
  static const String prodApiUrl =
      'https://rvrskluqfbrkvvlxtxfp.supabase.co/functions/v1/api';

  /// Development project reference.
  static const String devProjectRef = 'dyhfgnbhijukbdptreto';

  /// Default development project root URL.
  static const String defaultDevUrlRoot =
      'https://dyhfgnbhijukbdptreto.supabase.co';

  /// Default development Edge Function REST API endpoint.
  static const String defaultDevApiUrl =
      'https://dyhfgnbhijukbdptreto.supabase.co/functions/v1/api';

  /// Default development public anonymous key.
  static const String defaultDevAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR5aGZnbmJoaWp1a2JkcHRyZXRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg0NjcxNDcsImV4cCI6MjEwNDA0MzE0N30.gInc0tuzZiWq8EeEqbNBYa_Ay4liCcB4iGGOjUMnOBw';

  /// Compile-time environment variables injected via `--dart-define`.
  static const String envUrlRoot = String.fromEnvironment('SUPABASE_URL_ROOT');
  static const String envUrl = String.fromEnvironment('SUPABASE_URL');
  static const String envAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Resolves the effective [SupabaseConfig] based on compilation mode and arguments.
  ///
  /// Priority order:
  /// 1. Explicit arguments ([customUrlRoot], [customApiUrl], [customAnonKey]).
  /// 2. Compile-time `--dart-define` variables ([envUrlRoot], [envUrl], [envAnonKey]).
  /// 3. In debug/test mode ([isRelease] == false), development defaults.
  ///
  /// Throws [StateError] in Release mode if required configuration is missing or if
  /// development credentials/URLs are accidentally provided.
  /// Throws [FormatException] if any configured URL is malformed.
  factory SupabaseConfig.resolve({
    String? customUrlRoot,
    String? customApiUrl,
    String? customAnonKey,
    bool isRelease = kReleaseMode,
  }) {
    final suppliedUrlRoot =
        (customUrlRoot != null && customUrlRoot.trim().isNotEmpty)
        ? customUrlRoot.trim()
        : (envUrlRoot.trim().isNotEmpty ? envUrlRoot.trim() : null);

    final suppliedApiUrl =
        (customApiUrl != null && customApiUrl.trim().isNotEmpty)
        ? customApiUrl.trim()
        : (envUrl.trim().isNotEmpty ? envUrl.trim() : null);

    final suppliedAnonKey =
        (customAnonKey != null && customAnonKey.trim().isNotEmpty)
        ? customAnonKey.trim()
        : (envAnonKey.trim().isNotEmpty ? envAnonKey.trim() : null);

    if (isRelease) {
      final missing = <String>[];
      if (suppliedUrlRoot == null && suppliedApiUrl == null) {
        missing.add('SUPABASE_URL_ROOT (or SUPABASE_URL)');
      }
      if (suppliedAnonKey == null) {
        missing.add('SUPABASE_ANON_KEY');
      }

      if (missing.isNotEmpty) {
        throw StateError(
          'Release build configuration error: missing required environment variables: ${missing.join(', ')}.\n'
          'Release builds must not silently fall back to development credentials.\n'
          'Provide them via --dart-define flags, for example:\n'
          '  --dart-define=SUPABASE_URL_ROOT=$prodUrlRoot\n'
          '  --dart-define=SUPABASE_ANON_KEY=<your-production-anon-key>',
        );
      }

      final targetUrl = suppliedUrlRoot ?? suppliedApiUrl ?? '';
      if (targetUrl.contains(devProjectRef)) {
        throw StateError(
          'Release build configuration error: Development Supabase project ($devProjectRef) cannot be targeted in release builds.\n'
          'Production release builds must target: $prodUrlRoot',
        );
      }

      if (suppliedAnonKey == defaultDevAnonKey) {
        throw StateError(
          'Release build configuration error: Development Supabase anon key cannot be used in release builds.\n'
          'Provide the Production anon key via --dart-define=SUPABASE_ANON_KEY=...',
        );
      }

      if (suppliedAnonKey != null &&
          (suppliedAnonKey.contains('<') ||
              suppliedAnonKey.contains('REPLACE_WITH_PRODUCTION_ANON_KEY') ||
              suppliedAnonKey.contains('your-production-anon-key'))) {
        throw StateError(
          'Release build configuration error: Placeholder anon key detected in release build.\n'
          'Replace the placeholder with your actual Production Supabase anon key.',
        );
      }
    }

    final effectiveUrlRoot =
        suppliedUrlRoot ??
        (suppliedApiUrl != null
            ? _extractRootFromApiUrl(suppliedApiUrl)
            : defaultDevUrlRoot);

    final effectiveApiUrl =
        suppliedApiUrl ??
        (suppliedUrlRoot != null
            ? '$suppliedUrlRoot/functions/v1/api'
            : defaultDevApiUrl);

    final effectiveAnonKey = suppliedAnonKey ?? defaultDevAnonKey;

    _validateUrl(effectiveUrlRoot, 'Supabase root URL');
    _validateUrl(effectiveApiUrl, 'Supabase API URL');

    return SupabaseConfig(
      urlRoot: effectiveUrlRoot,
      apiUrl: effectiveApiUrl,
      anonKey: effectiveAnonKey,
    );
  }

  static String _extractRootFromApiUrl(String apiUrl) {
    final uri = Uri.parse(apiUrl);
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }

  static void _validateUrl(String url, String label) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        !(uri.scheme == 'http' || uri.scheme == 'https')) {
      throw FormatException(
        'Invalid $label: "$url". Must be a valid HTTP or HTTPS URL.',
      );
    }
  }
}
