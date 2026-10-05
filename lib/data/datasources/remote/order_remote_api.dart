import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'order_remote_api.g.dart';

/// Typed Retrofit contract for Order aggregate backend endpoints.
///
/// Follows `docs/05-api/backend-api-overview.md` §16.
@RestApi()
abstract class OrderRemoteApi {
  factory OrderRemoteApi(Dio dio, {String? baseUrl}) = _OrderRemoteApi;

  @GET('/api/v1/orders')
  Future<dynamic> getOrders({
    @Query('page') int? page,
    @Query('limit') int? limit,
  });

  @GET('/api/v1/orders/{id}')
  Future<dynamic> getOrderById(@Path('id') String id);

  @POST('/api/v1/orders')
  Future<dynamic> createOrder(
    @Header('X-Operation-ID') String operationId,
    @Body() Map<String, dynamic> body,
  );

  @PATCH('/api/v1/orders/{id}')
  Future<dynamic> updateOrder(
    @Header('X-Operation-ID') String operationId,
    @Path('id') String id,
    @Body() Map<String, dynamic> body,
  );

  @PATCH('/api/v1/orders/{id}/edit-aggregate')
  Future<dynamic> editOrderAggregate(
    @Header('X-Operation-ID') String operationId,
    @Path('id') String id,
    @Body() Map<String, dynamic> body,
  );
}
