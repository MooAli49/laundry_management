import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'storage_remote_api.g.dart';

/// Typed Retrofit contract for Storage backend endpoints.
///
/// Follows `docs/05-api/backend-api-overview.md` §27.
@RestApi()
abstract class StorageRemoteApi {
  factory StorageRemoteApi(Dio dio, {String? baseUrl}) = _StorageRemoteApi;

  @GET('/api/v1/storage')
  Future<dynamic> getStorageRecords({
    @Query('page') int? page,
    @Query('limit') int? limit,
  });

  @GET('/api/v1/storage/{orderItemId}')
  Future<dynamic> getStorageRecordByOrderItemId(
    @Path('orderItemId') String orderItemId,
  );

  @POST('/api/v1/storage')
  Future<dynamic> createStorageRecord(
    @Header('X-Operation-ID') String operationId,
    @Body() Map<String, dynamic> body,
  );

  @PATCH('/api/v1/storage/{id}')
  Future<dynamic> updateStorageRecord(
    @Header('X-Operation-ID') String operationId,
    @Path('id') String id,
    @Body() Map<String, dynamic> body,
  );
}
