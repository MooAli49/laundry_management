import '../../../../domain/entities/business_settings.dart';
import '../../../../domain/entities/carpet_size.dart';
import '../../../../domain/entities/customer.dart';
import '../../../../domain/entities/item_definition.dart';
import '../../../../domain/entities/item_type.dart';
import '../../../../domain/entities/order.dart';
import '../../../../domain/entities/service.dart';
import '../../../../domain/value_objects/money.dart';
import '../../../../domain/value_objects/order_date.dart';
import '../models/editable_order_item.dart';

class EditProcessingOrderState {
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final Order? initialOrder;
  final Money totalPaid;

  final Customer? selectedCustomer;
  final List<Customer> customerSearchResults;
  final bool isSearchingCustomer;

  final List<EditableOrderItem> items;
  final List<String> deletedItemIds;

  final OrderDate expectedPickupDate;
  final String? notes;
  final bool customerPickupRequested;
  final Money customerPickupFee;
  final bool customerDeliveryRequested;
  final Money customerDeliveryFee;
  final Money discount;
  final Order? savedOrder;

  // Master Data
  final List<ItemType> itemTypes;
  final List<Service> compatibleServices;
  final List<ItemDefinition> itemDefinitions;
  final List<CarpetSize> carpetSizes;
  final BusinessSettings? settings;

  // Draft for adding or editing an item
  final int? editingItemIndex; // null when adding new item; index when editing item
  final ItemType? draftItemType;
  final ItemDefinition? draftItemDefinition;
  final Service? draftService;
  final Money? draftUnitPrice;
  final int draftQuantity;
  final CarpetSize? draftCarpetSize;
  final double draftCarpetLength;
  final double draftCarpetWidth;
  final String? draftNotes;

  const EditProcessingOrderState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.initialOrder,
    this.totalPaid = Money.zero,
    this.selectedCustomer,
    this.customerSearchResults = const [],
    this.isSearchingCustomer = false,
    this.items = const [],
    this.deletedItemIds = const [],
    required this.expectedPickupDate,
    this.notes,
    this.customerPickupRequested = false,
    this.customerPickupFee = Money.zero,
    this.customerDeliveryRequested = false,
    this.customerDeliveryFee = Money.zero,
    this.discount = Money.zero,
    this.savedOrder,
    this.itemTypes = const [],
    this.compatibleServices = const [],
    this.itemDefinitions = const [],
    this.carpetSizes = const [],
    this.settings,
    this.editingItemIndex,
    this.draftItemType,
    this.draftItemDefinition,
    this.draftService,
    this.draftUnitPrice,
    this.draftQuantity = 1,
    this.draftCarpetSize,
    this.draftCarpetLength = 0.0,
    this.draftCarpetWidth = 0.0,
    this.draftNotes,
  });

  bool get canChangeCustomer => totalPaid == Money.zero;

  Money get subtotal {
    var sum = Money.zero;
    for (final item in items) {
      sum += item.calculatedTotal;
    }
    return sum;
  }

  Money get effectivePickupFee =>
      customerPickupRequested ? customerPickupFee : Money.zero;

  Money get effectiveDeliveryFee =>
      customerDeliveryRequested ? customerDeliveryFee : Money.zero;

  Money get total {
    final computed = subtotal - discount + effectivePickupFee + effectiveDeliveryFee;
    return computed.isNegative ? Money.zero : computed;
  }

  Money get remainingBalance {
    final diff = total - totalPaid;
    return diff.isNegative ? Money.zero : diff;
  }

  bool get isTotalValid => total >= totalPaid;

  bool get isPickupDateValid {
    if (initialOrder != null && expectedPickupDate == initialOrder!.expectedPickupDate) {
      return true;
    }
    return !expectedPickupDate.isBeforeToday;
  }

  bool get hasItems => items.isNotEmpty;

  bool get canSubmit =>
      !isSubmitting &&
      hasItems &&
      isTotalValid &&
      isPickupDateValid &&
      selectedCustomer != null;

  EditProcessingOrderState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    bool clearErrorMessage = false,
    Order? initialOrder,
    Money? totalPaid,
    Customer? selectedCustomer,
    bool clearSelectedCustomer = false,
    List<Customer>? customerSearchResults,
    bool? isSearchingCustomer,
    List<EditableOrderItem>? items,
    List<String>? deletedItemIds,
    OrderDate? expectedPickupDate,
    String? notes,
    bool? customerPickupRequested,
    Money? customerPickupFee,
    bool? customerDeliveryRequested,
    Money? customerDeliveryFee,
    Money? discount,
    Order? savedOrder,
    List<ItemType>? itemTypes,
    List<Service>? compatibleServices,
    List<ItemDefinition>? itemDefinitions,
    List<CarpetSize>? carpetSizes,
    BusinessSettings? settings,
    int? editingItemIndex,
    bool clearEditingItemIndex = false,
    ItemType? draftItemType,
    bool clearDraftItemType = false,
    ItemDefinition? draftItemDefinition,
    bool clearDraftItemDefinition = false,
    Service? draftService,
    bool clearDraftService = false,
    Money? draftUnitPrice,
    bool clearDraftUnitPrice = false,
    int? draftQuantity,
    CarpetSize? draftCarpetSize,
    bool clearDraftCarpetSize = false,
    double? draftCarpetLength,
    double? draftCarpetWidth,
    String? draftNotes,
    bool clearDraftNotes = false,
  }) {
    return EditProcessingOrderState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      initialOrder: initialOrder ?? this.initialOrder,
      totalPaid: totalPaid ?? this.totalPaid,
      selectedCustomer: clearSelectedCustomer
          ? null
          : (selectedCustomer ?? this.selectedCustomer),
      customerSearchResults: customerSearchResults ?? this.customerSearchResults,
      isSearchingCustomer: isSearchingCustomer ?? this.isSearchingCustomer,
      items: items ?? this.items,
      deletedItemIds: deletedItemIds ?? this.deletedItemIds,
      expectedPickupDate: expectedPickupDate ?? this.expectedPickupDate,
      notes: notes ?? this.notes,
      customerPickupRequested: customerPickupRequested ?? this.customerPickupRequested,
      customerPickupFee: customerPickupFee ?? this.customerPickupFee,
      customerDeliveryRequested: customerDeliveryRequested ?? this.customerDeliveryRequested,
      customerDeliveryFee: customerDeliveryFee ?? this.customerDeliveryFee,
      discount: discount ?? this.discount,
      savedOrder: savedOrder ?? this.savedOrder,
      itemTypes: itemTypes ?? this.itemTypes,
      compatibleServices: compatibleServices ?? this.compatibleServices,
      itemDefinitions: itemDefinitions ?? this.itemDefinitions,
      carpetSizes: carpetSizes ?? this.carpetSizes,
      settings: settings ?? this.settings,
      editingItemIndex: clearEditingItemIndex
          ? null
          : (editingItemIndex ?? this.editingItemIndex),
      draftItemType: clearDraftItemType ? null : (draftItemType ?? this.draftItemType),
      draftItemDefinition: clearDraftItemDefinition
          ? null
          : (draftItemDefinition ?? this.draftItemDefinition),
      draftService: clearDraftService ? null : (draftService ?? this.draftService),
      draftUnitPrice: clearDraftUnitPrice ? null : (draftUnitPrice ?? this.draftUnitPrice),
      draftQuantity: draftQuantity ?? this.draftQuantity,
      draftCarpetSize: clearDraftCarpetSize ? null : (draftCarpetSize ?? this.draftCarpetSize),
      draftCarpetLength: draftCarpetLength ?? this.draftCarpetLength,
      draftCarpetWidth: draftCarpetWidth ?? this.draftCarpetWidth,
      draftNotes: clearDraftNotes ? null : (draftNotes ?? this.draftNotes),
    );
  }
}
