import '../enums/pricing_type.dart';
import '../value_objects/money.dart';

class ServiceItemType {
  final String id;
  final String serviceId;
  final String itemTypeId;
  final PricingType pricingType;
  final Money price;
  final DateTime createdAt;
  final DateTime updatedAt;

  ServiceItemType({
    required this.id,
    required this.serviceId,
    required this.itemTypeId,
    required this.pricingType,
    required this.price,
    required this.createdAt,
    required this.updatedAt,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('ServiceItemType id cannot be empty');
    }
    if (serviceId.trim().isEmpty) {
      throw ArgumentError('ServiceItemType serviceId cannot be empty');
    }
    if (itemTypeId.trim().isEmpty) {
      throw ArgumentError('ServiceItemType itemTypeId cannot be empty');
    }
    if (price <= Money.zero) {
      throw ArgumentError.value(
        price,
        'price',
        'ServiceItemType price must be strictly greater than zero',
      );
    }
  }

  ServiceItemType copyWith({
    String? id,
    String? serviceId,
    String? itemTypeId,
    PricingType? pricingType,
    Money? price,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ServiceItemType(
      id: id ?? this.id,
      serviceId: serviceId ?? this.serviceId,
      itemTypeId: itemTypeId ?? this.itemTypeId,
      pricingType: pricingType ?? this.pricingType,
      price: price ?? this.price,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceItemType &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          serviceId == other.serviceId &&
          itemTypeId == other.itemTypeId &&
          pricingType == other.pricingType &&
          price == other.price &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    serviceId,
    itemTypeId,
    pricingType,
    price,
    createdAt,
    updatedAt,
  );

  @override
  String toString() =>
      'ServiceItemType(id: $id, service: $serviceId, itemType: $itemTypeId, pricingType: ${pricingType.name}, price: $price)';
}
