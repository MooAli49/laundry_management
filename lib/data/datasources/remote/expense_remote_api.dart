import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'expense_remote_api.g.dart';

/// Typed Retrofit contract for Expense backend endpoints.
///
/// Follows `docs/05-api/backend-api-overview.md` §45, §58.
@RestApi()
abstract class ExpenseRemoteApi {
  factory ExpenseRemoteApi(Dio dio, {String? baseUrl}) = _ExpenseRemoteApi;

  @GET('/api/v1/expenses')
  Future<dynamic> getExpenses({
    @Query('page') int? page,
    @Query('limit') int? limit,
    @Query('categoryId') String? categoryId,
    @Query('startDate') String? startDate,
    @Query('endDate') String? endDate,
  });

  @GET('/api/v1/expenses/{id}')
  Future<dynamic> getExpenseById(@Path('id') String id);

  @POST('/api/v1/expenses')
  Future<dynamic> createExpense(
    @Header('X-Operation-ID') String operationId,
    @Body() Map<String, dynamic> body,
  );

  @PATCH('/api/v1/expenses/{id}')
  Future<dynamic> updateExpense(
    @Header('X-Operation-ID') String operationId,
    @Path('id') String id,
    @Body() Map<String, dynamic> body,
  );
}
