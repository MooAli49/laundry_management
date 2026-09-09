import '../../../../domain/value_objects/order_date.dart';

class StorageFilter {
  final String? itemTypeId;
  final String? serviceId;
  final String? storageLocationId;
  final OrderDate? expectedPickupDate;
  final DateTime? orderReceivedDate;

  const StorageFilter({
    this.itemTypeId,
    this.serviceId,
    this.storageLocationId,
    this.expectedPickupDate,
    this.orderReceivedDate,
  });

  bool get isActive =>
      itemTypeId != null ||
      serviceId != null ||
      storageLocationId != null ||
      expectedPickupDate != null ||
      orderReceivedDate != null;

  StorageFilter copyWith({
    String? itemTypeId,
    bool clearItemTypeId = false,
    String? serviceId,
    bool clearServiceId = false,
    String? storageLocationId,
    bool clearStorageLocationId = false,
    OrderDate? expectedPickupDate,
    bool clearExpectedPickupDate = false,
    DateTime? orderReceivedDate,
    bool clearOrderReceivedDate = false,
  }) {
    return StorageFilter(
      itemTypeId: clearItemTypeId ? null : (itemTypeId ?? this.itemTypeId),
      serviceId: clearServiceId ? null : (serviceId ?? this.serviceId),
      storageLocationId:
          clearStorageLocationId ? null : (storageLocationId ?? this.storageLocationId),
      expectedPickupDate:
          clearExpectedPickupDate ? null : (expectedPickupDate ?? this.expectedPickupDate),
      orderReceivedDate:
          clearOrderReceivedDate ? null : (orderReceivedDate ?? this.orderReceivedDate),
    );
  }

  static const empty = StorageFilter();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StorageFilter &&
          runtimeType == other.runtimeType &&
          itemTypeId == other.itemTypeId &&
          serviceId == other.serviceId &&
          storageLocationId == other.storageLocationId &&
          expectedPickupDate == other.expectedPickupDate &&
          orderReceivedDate == other.orderReceivedDate;

  @override
  int get hashCode => Object.hash(
        itemTypeId,
        serviceId,
        storageLocationId,
        expectedPickupDate,
        orderReceivedDate,
      );
}
