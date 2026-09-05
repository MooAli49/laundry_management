import '../entities/service.dart';

abstract class ServiceRepository {
  Future<Service> createService(
    Service service, {
    required List<String> supportedItemTypeIds,
  });

  Future<Service> updateService(
    Service service, {
    List<String>? supportedItemTypeIds,
  });

  Future<Service?> getServiceById(String id);
  Future<List<Service>> getActiveServices();
  Future<List<Service>> getAllServices();
  Future<List<Service>> getServicesForItemType(String itemTypeId);
  Future<void> activateService(String id);
  Future<void> deactivateService(String id);
}
