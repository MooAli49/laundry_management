import '../enums/pricing_type.dart';
import '../value_objects/money.dart';
import 'carpet_item_data.dart';

class OrderItem {
  final String id;
  final String orderId;
  final String itemTypeId;
  final String? itemDefinitionId;
  final String serviceId;
  final String itemTypeNameSnapshot;
  final String? itemDefinitionNameSnapshot;
  final String serviceNameSnapshot;
  final PricingType pricingType;
  final double quantity;
  final Money unitPrice;
  final Money calculatedTotal;
  final String? notes;
  final CarpetItemData? carpetData;
  final DateTime createdAt;
  final DateTime updatedAt;

  OrderItem({
    required this.id,
    required this.orderId,
    required this.itemTypeId,
    this.itemDefinitionId,
    required this.serviceId,
    required this.itemTypeNameSnapshot,
    this.itemDefinitionNameSnapshot,
    required this.serviceNameSnapshot,
    required this.pricingType,
    required this.quantity,
    required this.unitPrice,
    required this.calculatedTotal,
    this.notes,
    this.carpetData,
    required this.createdAt,
    required this.updatedAt,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('OrderItem id cannot be empty');
    }
    if (orderId.trim().isEmpty) {
      throw ArgumentError('OrderItem orderId cannot be empty');
    }
    if (itemTypeId.trim().isEmpty) {
      throw ArgumentError('OrderItem itemTypeId cannot be empty');
    }
    if (serviceId.trim().isEmpty) {
      throw ArgumentError('OrderItem serviceId cannot be empty');
    }
    if (itemTypeNameSnapshot.trim().isEmpty) {
      throw ArgumentError('OrderItem itemTypeNameSnapshot cannot be empty');
    }
    if (serviceNameSnapshot.trim().isEmpty) {
      throw ArgumentError('OrderItem serviceNameSnapshot cannot be empty');
    }
    if (quantity <= 0) {
      throw ArgumentError.value(quantity, 'quantity', 'Quantity must be greater than 0');
    }
    if (unitPrice.isNegative) {
      throw ArgumentError.value(unitPrice, 'unitPrice', 'UnitPrice cannot be negative');
    }
    if (calculatedTotal.isNegative) {
      throw ArgumentError.value(calculatedTotal, 'calculatedTotal', 'CalculatedTotal cannot be negative');
    }
  }

  OrderItem copyWith({
    String? id,
    String? orderId,
    String? itemTypeId,
    String? itemDefinitionId,
    String? serviceId,
    String? itemTypeNameSnapshot,
    String? itemDefinitionNameSnapshot,
    String? serviceNameSnapshot,
    PricingType? pricingType,
    double? quantity,
    Money? unitPrice,
    Money? calculatedTotal,
    String? notes,
    CarpetItemData? carpetData,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      itemTypeId: itemTypeId ?? this.itemTypeId,
      itemDefinitionId: itemDefinitionId ?? this.itemDefinitionId,
      serviceId: serviceId ?? this.serviceId,
      itemTypeNameSnapshot: itemTypeNameSnapshot ?? this.itemTypeNameSnapshot,
      itemDefinitionNameSnapshot:
          itemDefinitionNameSnapshot ?? this.itemDefinitionNameSnapshot,
      serviceNameSnapshot: serviceNameSnapshot ?? this.serviceNameSnapshot,
      pricingType: pricingType ?? this.pricingType,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      calculatedTotal: calculatedTotal ?? this.calculatedTotal,
      notes: notes ?? this.notes,
      carpetData: carpetData ?? this.carpetData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          orderId == other.orderId &&
          itemTypeId == other.itemTypeId &&
          itemDefinitionId == other.itemDefinitionId &&
          serviceId == other.serviceId &&
          itemTypeNameSnapshot == other.itemTypeNameSnapshot &&
          itemDefinitionNameSnapshot == other.itemDefinitionNameSnapshot &&
          serviceNameSnapshot == other.serviceNameSnapshot &&
          pricingType == other.pricingType &&
          quantity == other.quantity &&
          unitPrice == other.unitPrice &&
          calculatedTotal == other.calculatedTotal &&
          notes == other.notes &&
          carpetData == other.carpetData &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        orderId,
        itemTypeId,
        itemDefinitionId,
        serviceId,
        itemTypeNameSnapshot,
        itemDefinitionNameSnapshot,
        serviceNameSnapshot,
        pricingType,
        quantity,
        unitPrice,
        calculatedTotal,
        notes,
        carpetData,
        createdAt,
        updatedAt,
      );

  @override
  String toString() =>
      'OrderItem(id: $id, type: $itemTypeNameSnapshot, service: $serviceNameSnapshot, total: $calculatedTotal)';
}
