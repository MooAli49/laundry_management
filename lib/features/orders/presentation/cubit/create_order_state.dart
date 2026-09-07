import '../../../../domain/entities/business_settings.dart';
import '../../../../domain/entities/carpet_size.dart';
import '../../../../domain/entities/customer.dart';
import '../../../../domain/entities/item_definition.dart';
import '../../../../domain/entities/item_type.dart';
import '../../../../domain/entities/order.dart';
import '../../../../domain/entities/service.dart';
import '../../../../domain/value_objects/money.dart';
import '../../../../domain/value_objects/order_date.dart';
import '../models/order_item_draft.dart';

class CreateOrderState {
  final bool isInitialLoading;
  final Customer? selectedCustomer;
  final List<Customer> customerSearchResults;
  final bool isSearchingCustomer;

  final List<ItemType> itemTypes;
  final List<Service> compatibleServices;
  final List<ItemDefinition> itemDefinitions;
  final List<CarpetSize> carpetSizes;
  final BusinessSettings? settings;

  // Item Draft Fields
  final ItemType? draftItemType;
  final ItemDefinition? draftItemDefinition;
  final Service? draftService;
  final Money? draftUnitPrice;
  final int draftQuantity;
  final CarpetSize? draftCarpetSize;
  final double draftCarpetLength;
  final double draftCarpetWidth;
  final String? draftNotes;

  // Order Items
  final List<OrderItemDraft> items;

  // Order Fields
  final OrderDate expectedPickupDate;
  final Money discount;
  final String? orderNotes;
  final bool customerPickupRequested;
  final Money customerPickupFee;
  final bool customerDeliveryRequested;
  final Money customerDeliveryFee;

  final bool isSubmitting;
  final String? errorMessage;
  final Order? createdOrder;

  const CreateOrderState({
    this.isInitialLoading = false,
    this.selectedCustomer,
    this.customerSearchResults = const [],
    this.isSearchingCustomer = false,
    this.itemTypes = const [],
    this.compatibleServices = const [],
    this.itemDefinitions = const [],
    this.carpetSizes = const [],
    this.settings,
    this.draftItemType,
    this.draftItemDefinition,
    this.draftService,
    this.draftUnitPrice,
    this.draftQuantity = 1,
    this.draftCarpetSize,
    this.draftCarpetLength = 0.0,
    this.draftCarpetWidth = 0.0,
    this.draftNotes,
    this.items = const [],
    required this.expectedPickupDate,
    this.discount = Money.zero,
    this.orderNotes,
    this.customerPickupRequested = false,
    this.customerPickupFee = Money.zero,
    this.customerDeliveryRequested = false,
    this.customerDeliveryFee = Money.zero,
    this.isSubmitting = false,
    this.errorMessage,
    this.createdOrder,
  });

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

  Money get totalDeliveryFees => effectivePickupFee + effectiveDeliveryFee;

  Money get tax {
    if (settings != null && settings!.taxEnabled && settings!.taxRate > 0) {
      final taxableBase = subtotal - discount;
      if (taxableBase.isPositive) {
        return Money.fromPiastres(
          (taxableBase.piastres * (settings!.taxRate / 100.0)).round(),
        );
      }
    }
    return Money.zero;
  }

  Money get total {
    final base = subtotal - discount;
    final nonNegativeBase = base.isNegative ? Money.zero : base;
    return nonNegativeBase + totalDeliveryFees + tax;
  }

  CreateOrderState copyWith({
    bool? isInitialLoading,
    Customer? selectedCustomer,
    bool clearSelectedCustomer = false,
    List<Customer>? customerSearchResults,
    bool? isSearchingCustomer,
    List<ItemType>? itemTypes,
    List<Service>? compatibleServices,
    List<ItemDefinition>? itemDefinitions,
    List<CarpetSize>? carpetSizes,
    BusinessSettings? settings,
    ItemType? draftItemType,
    bool clearDraftItemType = false,
    ItemDefinition? draftItemDefinition,
    bool clearDraftItemDefinition = false,
    Service? draftService,
    bool clearDraftService = false,
    Money? draftUnitPrice,
    int? draftQuantity,
    CarpetSize? draftCarpetSize,
    bool clearDraftCarpetSize = false,
    double? draftCarpetLength,
    double? draftCarpetWidth,
    String? draftNotes,
    List<OrderItemDraft>? items,
    OrderDate? expectedPickupDate,
    Money? discount,
    String? orderNotes,
    bool? customerPickupRequested,
    Money? customerPickupFee,
    bool? customerDeliveryRequested,
    Money? customerDeliveryFee,
    bool? isSubmitting,
    String? errorMessage,
    bool clearErrorMessage = false,
    Order? createdOrder,
  }) {
    return CreateOrderState(
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      selectedCustomer: clearSelectedCustomer
          ? null
          : (selectedCustomer ?? this.selectedCustomer),
      customerSearchResults:
          customerSearchResults ?? this.customerSearchResults,
      isSearchingCustomer: isSearchingCustomer ?? this.isSearchingCustomer,
      itemTypes: itemTypes ?? this.itemTypes,
      compatibleServices: compatibleServices ?? this.compatibleServices,
      itemDefinitions: itemDefinitions ?? this.itemDefinitions,
      carpetSizes: carpetSizes ?? this.carpetSizes,
      settings: settings ?? this.settings,
      draftItemType:
          clearDraftItemType ? null : (draftItemType ?? this.draftItemType),
      draftItemDefinition: clearDraftItemDefinition
          ? null
          : (draftItemDefinition ?? this.draftItemDefinition),
      draftService:
          clearDraftService ? null : (draftService ?? this.draftService),
      draftUnitPrice: draftUnitPrice ?? this.draftUnitPrice,
      draftQuantity: draftQuantity ?? this.draftQuantity,
      draftCarpetSize: clearDraftCarpetSize
          ? null
          : (draftCarpetSize ?? this.draftCarpetSize),
      draftCarpetLength: draftCarpetLength ?? this.draftCarpetLength,
      draftCarpetWidth: draftCarpetWidth ?? this.draftCarpetWidth,
      draftNotes: draftNotes ?? this.draftNotes,
      items: items ?? this.items,
      expectedPickupDate: expectedPickupDate ?? this.expectedPickupDate,
      discount: discount ?? this.discount,
      orderNotes: orderNotes ?? this.orderNotes,
      customerPickupRequested:
          customerPickupRequested ?? this.customerPickupRequested,
      customerPickupFee: customerPickupFee ?? this.customerPickupFee,
      customerDeliveryRequested:
          customerDeliveryRequested ?? this.customerDeliveryRequested,
      customerDeliveryFee: customerDeliveryFee ?? this.customerDeliveryFee,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      createdOrder: createdOrder ?? this.createdOrder,
    );
  }
}
