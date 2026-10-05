import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'license_remote_api.g.dart';

/// Typed Retrofit contract for the license info endpoint.
///
/// Calls `GET /api/v1/license` on the Edge Function base URL.
/// The Edge Function translates this to a service-role SELECT on
/// `public.license_info` — no direct anon table access is used.
@RestApi()
abstract class LicenseRemoteApi {
  factory LicenseRemoteApi(Dio dio, {String? baseUrl}) = _LicenseRemoteApi;

  /// Fetches the singleton license record from the remote backend.
  ///
  /// Returns a raw JSON map with at minimum:
  ///   `status` (String), `suspended_at` (String? ISO-8601), `updated_at` (String)
  @GET('/api/v1/license')
  Future<dynamic> getLicenseInfo();
}
