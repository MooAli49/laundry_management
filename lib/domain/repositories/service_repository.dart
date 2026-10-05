import '../entities/service.dart';
import '../entities/service_item_type.dart';
import '../models/service_with_pricing.dart';

abstract class ServiceRepository {
  Future<Service> createService(
    Service service, {
    required List<ServiceItemType> serviceItemTypes,
  });

  Future<Service> updateService(
    Service service, {
    List<ServiceItemType>? serviceItemTypes,
  });

  Future<Service?> getServiceById(String id);
  Future<List<Service>> getActiveServices();
  Future<List<Service>> getAllServices();
  Future<List<ServiceWithPricing>> getServicesForItemType(String itemTypeId);
  Future<ServiceItemType?> getServiceItemType(String serviceId, String itemTypeId);
  Future<List<ServiceItemType>> getServiceItemTypes(String serviceId);
  Future<void> activateService(String id);
  Future<void> deactivateService(String id);
  Future<List<String>> getSupportedItemTypeIds(String serviceId);
}
