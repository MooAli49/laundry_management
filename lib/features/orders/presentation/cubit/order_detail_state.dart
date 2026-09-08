import '../../../../domain/entities/business_settings.dart';
import '../../../../domain/entities/customer.dart';
import '../../../../domain/entities/order.dart';
import '../../../../domain/entities/order_item.dart';
import '../../../../domain/entities/payment.dart';
import '../../../../domain/entities/storage_location.dart';
import '../../../../domain/entities/storage_record.dart';
import '../../../../domain/value_objects/money.dart';

class OrderDetailState {
  final bool isLoading;
  final bool isActionLoading;
  final Order? order;
  final Customer? customer;
  final List<OrderItem> items;
  final Map<String, StorageRecord> activeStorageRecords; // orderItemId -> StorageRecord
  final Map<String, StorageLocation> storageLocations; // locationId -> StorageLocation
  final List<StorageLocation> allActiveLocations;
  final Map<String, List<StorageLocation>> compatibleLocationsByItemType; // itemTypeId -> compatible locations
  final List<Payment> payments;
  final Money totalPaid;
  final Money remainingAmount;
  final BusinessSettings? settings;
  final String? errorMessage;
  final String? actionSuccessMessage;

  const OrderDetailState({
    this.isLoading = false,
    this.isActionLoading = false,
    this.order,
    this.customer,
    this.items = const [],
    this.activeStorageRecords = const {},
    this.storageLocations = const {},
    this.allActiveLocations = const [],
    this.compatibleLocationsByItemType = const {},
    this.payments = const [],
    this.totalPaid = Money.zero,
    this.remainingAmount = Money.zero,
    this.settings,
    this.errorMessage,
    this.actionSuccessMessage,
  });

  bool get isFullyPaid => remainingAmount.isZero || remainingAmount.isNegative;
  bool get allItemsStored =>
      items.isNotEmpty && items.every((i) => activeStorageRecords.containsKey(i.id));
  bool get areAllItemsStored => allItemsStored;
  List<OrderItem> get unstoredItems =>
      items.where((i) => !activeStorageRecords.containsKey(i.id)).toList();

  /// Returns the intersection of compatible active locations for the given items.
  List<StorageLocation> compatibleLocationsForItems(List<OrderItem> targetItems) {
    if (targetItems.isEmpty || compatibleLocationsByItemType.isEmpty) {
      return allActiveLocations;
    }
    List<StorageLocation>? intersection;
    for (final item in targetItems) {
      final compatible = compatibleLocationsByItemType[item.itemTypeId] ?? [];
      if (intersection == null) {
        intersection = List.of(compatible);
      } else {
        intersection = intersection.where((loc) => compatible.any((c) => c.id == loc.id)).toList();
      }
    }
    return intersection ?? [];
  }

  OrderDetailState copyWith({
    bool? isLoading,
    bool? isActionLoading,
    Order? order,
    Customer? customer,
    List<OrderItem>? items,
    Map<String, StorageRecord>? activeStorageRecords,
    Map<String, StorageLocation>? storageLocations,
    List<StorageLocation>? allActiveLocations,
    Map<String, List<StorageLocation>>? compatibleLocationsByItemType,
    List<Payment>? payments,
    Money? totalPaid,
    Money? remainingAmount,
    BusinessSettings? settings,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? actionSuccessMessage,
    bool clearActionSuccessMessage = false,
  }) {
    return OrderDetailState(
      isLoading: isLoading ?? this.isLoading,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      order: order ?? this.order,
      customer: customer ?? this.customer,
      items: items ?? this.items,
      activeStorageRecords: activeStorageRecords ?? this.activeStorageRecords,
      storageLocations: storageLocations ?? this.storageLocations,
      allActiveLocations: allActiveLocations ?? this.allActiveLocations,
      compatibleLocationsByItemType:
          compatibleLocationsByItemType ?? this.compatibleLocationsByItemType,
      payments: payments ?? this.payments,
      totalPaid: totalPaid ?? this.totalPaid,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      settings: settings ?? this.settings,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      actionSuccessMessage: clearActionSuccessMessage
          ? null
          : (actionSuccessMessage ?? this.actionSuccessMessage),
    );
  }
}
