import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'payment_remote_api.g.dart';

/// Typed Retrofit contract for Payment backend endpoints.
///
/// Follows `docs/05-api/backend-api-overview.md` §21.
@RestApi()
abstract class PaymentRemoteApi {
  factory PaymentRemoteApi(Dio dio, {String? baseUrl}) = _PaymentRemoteApi;

  @GET('/api/v1/payments')
  Future<dynamic> getPayments({@Query('order_id') String? orderId});

  @GET('/api/v1/payments/{id}')
  Future<dynamic> getPaymentById(@Path('id') String id);

  @POST('/api/v1/payments')
  Future<dynamic> createPayment(
    @Header('X-Operation-ID') String operationId,
    @Body() Map<String, dynamic> body,
  );
}
