import '../entities/service.dart';
import '../entities/service_item_type.dart';
import '../enums/pricing_type.dart';
import '../value_objects/money.dart';

/// Bundles a [Service] with its configured pricing for a specific [ItemType].
class ServiceWithPricing {
  final Service service;
  final ServiceItemType serviceItemType;

  const ServiceWithPricing({
    required this.service,
    required this.serviceItemType,
  });

  String get id => service.id;
  String get name => service.name;
  String? get description => service.description;
  bool get isActive => service.isActive;
  PricingType get pricingType => serviceItemType.pricingType;
  Money get price => serviceItemType.price;
  String get itemTypeId => serviceItemType.itemTypeId;
  String get serviceItemTypeId => serviceItemType.id;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceWithPricing &&
          runtimeType == other.runtimeType &&
          service == other.service &&
          serviceItemType == other.serviceItemType;

  @override
  int get hashCode => Object.hash(service, serviceItemType);

  @override
  String toString() =>
      'ServiceWithPricing(service: ${service.name}, pricingType: ${pricingType.name}, price: $price)';
}
