import '../enums/pricing_type.dart';
import '../value_objects/money.dart';

class Service {
  final String id;
  final String name;
  final String? description;
  final PricingType pricingType;
  final Money price;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Service({
    required this.id,
    required this.name,
    this.description,
    required this.pricingType,
    required this.price,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('Service id cannot be empty');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('Service name cannot be empty');
    }
    if (price.isNegative) {
      throw ArgumentError.value(price, 'price', 'Service price cannot be negative');
    }
  }

  Service copyWith({
    String? id,
    String? name,
    String? description,
    PricingType? pricingType,
    Money? price,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Service(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      pricingType: pricingType ?? this.pricingType,
      price: price ?? this.price,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Service &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          pricingType == other.pricingType &&
          price == other.price &&
          isActive == other.isActive &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      Object.hash(id, name, description, pricingType, price, isActive, createdAt, updatedAt);

  @override
  String toString() => 'Service(id: $id, name: $name, price: $price, active: $isActive)';
}
