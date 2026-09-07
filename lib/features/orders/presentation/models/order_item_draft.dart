import '../../../../domain/enums/pricing_type.dart';
import '../../../../domain/value_objects/money.dart';

class OrderItemDraft {
  final String itemTypeId;
  final String itemTypeName;
  final String? itemDefinitionId;
  final String? itemDefinitionName;
  final String serviceId;
  final String serviceName;
  final PricingType pricingType;
  final Money unitPrice;
  final int physicalQuantity;
  final String? carpetSizeId;
  final double length;
  final double width;
  final String? notes;

  const OrderItemDraft({
    required this.itemTypeId,
    required this.itemTypeName,
    this.itemDefinitionId,
    this.itemDefinitionName,
    required this.serviceId,
    required this.serviceName,
    required this.pricingType,
    required this.unitPrice,
    this.physicalQuantity = 1,
    this.carpetSizeId,
    this.length = 0.0,
    this.width = 0.0,
    this.notes,
  });

  double get carpetArea => length * width;

  Money get calculatedTotal {
    if (pricingType == PricingType.perSquareMeter) {
      if (carpetArea <= 0) return Money.zero;
      final areaTotalPiastres = (unitPrice.piastres * carpetArea).round();
      return Money.fromPiastres(areaTotalPiastres * physicalQuantity);
    }
    // perPiece and fixedPrice (fixed price per physical piece)
    return unitPrice * physicalQuantity;
  }

  OrderItemDraft copyWith({
    String? itemTypeId,
    String? itemTypeName,
    String? itemDefinitionId,
    String? itemDefinitionName,
    String? serviceId,
    String? serviceName,
    PricingType? pricingType,
    Money? unitPrice,
    int? physicalQuantity,
    String? carpetSizeId,
    double? length,
    double? width,
    String? notes,
  }) {
    return OrderItemDraft(
      itemTypeId: itemTypeId ?? this.itemTypeId,
      itemTypeName: itemTypeName ?? this.itemTypeName,
      itemDefinitionId: itemDefinitionId ?? this.itemDefinitionId,
      itemDefinitionName: itemDefinitionName ?? this.itemDefinitionName,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      pricingType: pricingType ?? this.pricingType,
      unitPrice: unitPrice ?? this.unitPrice,
      physicalQuantity: physicalQuantity ?? this.physicalQuantity,
      carpetSizeId: carpetSizeId ?? this.carpetSizeId,
      length: length ?? this.length,
      width: width ?? this.width,
      notes: notes ?? this.notes,
    );
  }
}
