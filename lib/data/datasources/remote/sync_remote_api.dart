import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'sync_remote_api.g.dart';

/// Typed Retrofit contract for Pull synchronization endpoint.
///
/// Follows `docs/08-implementation/synchronization-implementation.md` §68.3.
@RestApi()
abstract class SyncRemoteApi {
  factory SyncRemoteApi(Dio dio, {String? baseUrl}) = _SyncRemoteApi;

  @GET('/api/v1/sync/changes')
  Future<dynamic> getChanges({
    @Query('after') required int after,
    @Query('limit') int? limit,
  });
}
