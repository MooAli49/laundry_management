import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'refund_remote_api.g.dart';

/// Typed Retrofit contract for Refund backend endpoints.
///
/// Phase 3 scope: POST /api/v1/refunds only.
/// Follows `docs/05-api/backend-api-overview.md`.
@RestApi()
abstract class RefundRemoteApi {
  factory RefundRemoteApi(Dio dio, {String? baseUrl}) = _RefundRemoteApi;

  @POST('/api/v1/refunds')
  Future<dynamic> createRefund(
    @Header('X-Operation-ID') String operationId,
    @Body() Map<String, dynamic> body,
  );
}
