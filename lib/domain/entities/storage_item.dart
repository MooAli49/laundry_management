import '../enums/order_status.dart';
import '../value_objects/order_date.dart';
import 'order_item.dart';
import 'storage_location.dart';
import 'storage_record.dart';

class StorageItem {
  final OrderItem orderItem;
  final String orderId;
  final String orderNumber;
  final String customerName;
  final String customerPhone;
  final OrderStatus orderStatus;
  final OrderDate expectedPickupDate;
  final DateTime orderCreatedAt;
  final StorageRecord? activeRecord;
  final StorageLocation? storageLocation;

  const StorageItem({
    required this.orderItem,
    required this.orderId,
    required this.orderNumber,
    required this.customerName,
    required this.customerPhone,
    required this.orderStatus,
    required this.expectedPickupDate,
    required this.orderCreatedAt,
    this.activeRecord,
    this.storageLocation,
  });

  bool get isStored => activeRecord != null && activeRecord!.isActive;

  StorageItem copyWith({
    OrderItem? orderItem,
    String? orderId,
    String? orderNumber,
    String? customerName,
    String? customerPhone,
    OrderStatus? orderStatus,
    OrderDate? expectedPickupDate,
    DateTime? orderCreatedAt,
    StorageRecord? activeRecord,
    StorageLocation? storageLocation,
  }) {
    return StorageItem(
      orderItem: orderItem ?? this.orderItem,
      orderId: orderId ?? this.orderId,
      orderNumber: orderNumber ?? this.orderNumber,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      orderStatus: orderStatus ?? this.orderStatus,
      expectedPickupDate: expectedPickupDate ?? this.expectedPickupDate,
      orderCreatedAt: orderCreatedAt ?? this.orderCreatedAt,
      activeRecord: activeRecord ?? this.activeRecord,
      storageLocation: storageLocation ?? this.storageLocation,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StorageItem &&
          runtimeType == other.runtimeType &&
          orderItem == other.orderItem &&
          orderId == other.orderId &&
          orderNumber == other.orderNumber &&
          customerName == other.customerName &&
          customerPhone == other.customerPhone &&
          orderStatus == other.orderStatus &&
          expectedPickupDate == other.expectedPickupDate &&
          orderCreatedAt == other.orderCreatedAt &&
          activeRecord == other.activeRecord &&
          storageLocation == other.storageLocation;

  @override
  int get hashCode => Object.hash(
        orderItem,
        orderId,
        orderNumber,
        customerName,
        customerPhone,
        orderStatus,
        expectedPickupDate,
        orderCreatedAt,
        activeRecord,
        storageLocation,
      );

  @override
  String toString() =>
      'StorageItem(item: ${orderItem.id}, order: $orderNumber, stored: $isStored, location: ${storageLocation?.name})';
}
