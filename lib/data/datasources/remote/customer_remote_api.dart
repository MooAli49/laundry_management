import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'customer_remote_api.g.dart';

/// Typed Retrofit contract for Customer backend endpoints.
///
/// Follows `docs/05-api/backend-api-overview.md` §14.
@RestApi()
abstract class CustomerRemoteApi {
  factory CustomerRemoteApi(Dio dio, {String? baseUrl}) = _CustomerRemoteApi;

  @GET('/api/v1/customers')
  Future<dynamic> getCustomers({
    @Query('page') int? page,
    @Query('limit') int? limit,
  });

  @GET('/api/v1/customers/{id}')
  Future<dynamic> getCustomerById(@Path('id') String id);

  @POST('/api/v1/customers')
  Future<dynamic> createCustomer(
    @Header('X-Operation-ID') String operationId,
    @Body() Map<String, dynamic> body,
  );

  @PATCH('/api/v1/customers/{id}')
  Future<dynamic> updateCustomer(
    @Header('X-Operation-ID') String operationId,
    @Path('id') String id,
    @Body() Map<String, dynamic> body,
  );
}
