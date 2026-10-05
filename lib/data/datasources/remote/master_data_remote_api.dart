import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'master_data_remote_api.g.dart';

/// Typed Retrofit contract for Master Data backend endpoints.
///
/// Follows `docs/05-api/backend-api-overview.md` §30–37.
@RestApi()
abstract class MasterDataRemoteApi {
  factory MasterDataRemoteApi(Dio dio, {String? baseUrl}) =
      _MasterDataRemoteApi;

  // ==========================================
  // Business Settings (§36)
  // ==========================================

  @GET('/api/v1/business-settings')
  Future<dynamic> getBusinessSettings();

  @PATCH('/api/v1/business-settings')
  Future<dynamic> updateBusinessSettings(
    @Header('X-Operation-ID') String operationId,
    @Body() Map<String, dynamic> body,
  );

  // ==========================================
  // Expense Categories (§37)
  // ==========================================

  @GET('/api/v1/expense-categories')
  Future<dynamic> getExpenseCategories();

  @GET('/api/v1/expense-categories/{id}')
  Future<dynamic> getExpenseCategoryById(@Path('id') String id);

  @POST('/api/v1/expense-categories')
  Future<dynamic> createExpenseCategory(
    @Header('X-Operation-ID') String operationId,
    @Body() Map<String, dynamic> body,
  );

  @PATCH('/api/v1/expense-categories/{id}')
  Future<dynamic> updateExpenseCategory(
    @Header('X-Operation-ID') String operationId,
    @Path('id') String id,
    @Body() Map<String, dynamic> body,
  );

  // ==========================================
  // Item Types (§30)
  // ==========================================

  @GET('/api/v1/item-types')
  Future<dynamic> getItemTypes();

  @GET('/api/v1/item-types/{id}')
  Future<dynamic> getItemTypeById(@Path('id') String id);

  @POST('/api/v1/item-types')
  Future<dynamic> createItemType(
    @Header('X-Operation-ID') String operationId,
    @Body() Map<String, dynamic> body,
  );

  @PATCH('/api/v1/item-types/{id}')
  Future<dynamic> updateItemType(
    @Header('X-Operation-ID') String operationId,
    @Path('id') String id,
    @Body() Map<String, dynamic> body,
  );

  // ==========================================
  // Item Definitions (§31)
  // ==========================================

  @GET('/api/v1/item-definitions')
  Future<dynamic> getItemDefinitions();

  @GET('/api/v1/item-definitions/{id}')
  Future<dynamic> getItemDefinitionById(@Path('id') String id);

  @POST('/api/v1/item-definitions')
  Future<dynamic> createItemDefinition(
    @Header('X-Operation-ID') String operationId,
    @Body() Map<String, dynamic> body,
  );

  @PATCH('/api/v1/item-definitions/{id}')
  Future<dynamic> updateItemDefinition(
    @Header('X-Operation-ID') String operationId,
    @Path('id') String id,
    @Body() Map<String, dynamic> body,
  );

  // ==========================================
  // Services (§32)
  // ==========================================

  @GET('/api/v1/services')
  Future<dynamic> getServices();

  @GET('/api/v1/services/{id}')
  Future<dynamic> getServiceById(@Path('id') String id);

  @POST('/api/v1/services')
  Future<dynamic> createService(
    @Header('X-Operation-ID') String operationId,
    @Body() Map<String, dynamic> body,
  );

  @PATCH('/api/v1/services/{id}')
  Future<dynamic> updateService(
    @Header('X-Operation-ID') String operationId,
    @Path('id') String id,
    @Body() Map<String, dynamic> body,
  );

  // ==========================================
  // Service Item Types (§33)
  // ==========================================

  @GET('/api/v1/service-item-types')
  Future<dynamic> getServiceItemTypes();

  @POST('/api/v1/service-item-types')
  Future<dynamic> createServiceItemType(
    @Header('X-Operation-ID') String operationId,
    @Body() Map<String, dynamic> body,
  );

  @PATCH('/api/v1/service-item-types/{id}')
  Future<dynamic> updateServiceItemType(
    @Header('X-Operation-ID') String operationId,
    @Path('id') String id,
    @Body() Map<String, dynamic> body,
  );

  // ==========================================
  // Carpet Sizes (§34)
  // ==========================================

  @GET('/api/v1/carpet-sizes')
  Future<dynamic> getCarpetSizes();

  @GET('/api/v1/carpet-sizes/{id}')
  Future<dynamic> getCarpetSizeById(@Path('id') String id);

  @POST('/api/v1/carpet-sizes')
  Future<dynamic> createCarpetSize(
    @Header('X-Operation-ID') String operationId,
    @Body() Map<String, dynamic> body,
  );

  @PATCH('/api/v1/carpet-sizes/{id}')
  Future<dynamic> updateCarpetSize(
    @Header('X-Operation-ID') String operationId,
    @Path('id') String id,
    @Body() Map<String, dynamic> body,
  );

  // ==========================================
  // Storage Locations (§35)
  // ==========================================

  @GET('/api/v1/storage-locations')
  Future<dynamic> getStorageLocations();

  @GET('/api/v1/storage-locations/{id}')
  Future<dynamic> getStorageLocationById(@Path('id') String id);

  @POST('/api/v1/storage-locations')
  Future<dynamic> createStorageLocation(
    @Header('X-Operation-ID') String operationId,
    @Body() Map<String, dynamic> body,
  );

  @PATCH('/api/v1/storage-locations/{id}')
  Future<dynamic> updateStorageLocation(
    @Header('X-Operation-ID') String operationId,
    @Path('id') String id,
    @Body() Map<String, dynamic> body,
  );
}
