import '../../../../domain/enums/pricing_type.dart';
import '../../../../domain/value_objects/money.dart';

class EditableOrderItem {
  final String? id; // null for newly added items, non-null for existing order items
  final String itemTypeId;
  final String itemTypeName;
  final String? itemDefinitionId;
  final String? itemDefinitionName;
  final String serviceId;
  final String serviceName;
  final PricingType pricingType;
  final Money unitPrice;
  final int physicalQuantity; // 1 for existing physical piece; for new can be >= 1
  final String? carpetSizeId;
  final double length;
  final double width;
  final String? notes;
  final bool hasStorageRecords; // true if COUNT(storage_records) > 0 (blocks deletion)
  final String? storageLocationName; // Displayed in badge if actively stored

  const EditableOrderItem({
    this.id,
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
    this.hasStorageRecords = false,
    this.storageLocationName,
  });

  bool get isExisting => id != null;
  bool get canDelete => !hasStorageRecords;
  double get carpetArea => length * width;

  Money get calculatedTotal {
    if (pricingType == PricingType.perSquareMeter) {
      if (carpetArea <= 0) return Money.zero;
      final areaTotalPiastres = (unitPrice.piastres * carpetArea).round();
      return Money.fromPiastres(areaTotalPiastres * physicalQuantity);
    }
    return unitPrice * physicalQuantity;
  }

  EditableOrderItem copyWith({
    String? id,
    String? itemTypeId,
    String? itemTypeName,
    String? itemDefinitionId,
    String? itemDefinitionName,
    bool clearItemDefinition = false,
    String? serviceId,
    String? serviceName,
    PricingType? pricingType,
    Money? unitPrice,
    int? physicalQuantity,
    String? carpetSizeId,
    double? length,
    double? width,
    String? notes,
    bool? hasStorageRecords,
    String? storageLocationName,
  }) {
    return EditableOrderItem(
      id: id ?? this.id,
      itemTypeId: itemTypeId ?? this.itemTypeId,
      itemTypeName: itemTypeName ?? this.itemTypeName,
      itemDefinitionId: clearItemDefinition
          ? null
          : (itemDefinitionId ?? this.itemDefinitionId),
      itemDefinitionName: clearItemDefinition
          ? null
          : (itemDefinitionName ?? this.itemDefinitionName),
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      pricingType: pricingType ?? this.pricingType,
      unitPrice: unitPrice ?? this.unitPrice,
      physicalQuantity: physicalQuantity ?? this.physicalQuantity,
      carpetSizeId: carpetSizeId ?? this.carpetSizeId,
      length: length ?? this.length,
      width: width ?? this.width,
      notes: notes ?? this.notes,
      hasStorageRecords: hasStorageRecords ?? this.hasStorageRecords,
      storageLocationName: storageLocationName ?? this.storageLocationName,
    );
  }
}
