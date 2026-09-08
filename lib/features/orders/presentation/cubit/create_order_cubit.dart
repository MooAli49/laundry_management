import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../application/use_cases/create_order_use_case.dart';
import '../../../../core/errors/failures.dart';
import '../../../../domain/entities/carpet_size.dart';
import '../../../../domain/entities/customer.dart';
import '../../../../domain/entities/item_definition.dart';
import '../../../../domain/entities/item_type.dart';
import '../../../../domain/entities/service.dart';
import '../../../../domain/enums/pricing_type.dart';
import '../../../../domain/repositories/carpet_size_repository.dart';
import '../../../../domain/repositories/customer_repository.dart';
import '../../../../domain/repositories/item_definition_repository.dart';
import '../../../../domain/repositories/item_type_repository.dart';
import '../../../../domain/repositories/service_repository.dart';
import '../../../../domain/repositories/settings_repository.dart';
import '../../../../domain/value_objects/money.dart';
import '../../../../domain/value_objects/order_date.dart';
import '../models/order_item_draft.dart';
import 'create_order_state.dart';

class CreateOrderCubit extends Cubit<CreateOrderState> {
  final CustomerRepository _customerRepository;
  final ItemTypeRepository _itemTypeRepository;
  final ItemDefinitionRepository _itemDefinitionRepository;
  final ServiceRepository _serviceRepository;
  final CarpetSizeRepository _carpetSizeRepository;
  final SettingsRepository _settingsRepository;
  final CreateOrderUseCase _createOrderUseCase;
  final Uuid _uuid;

  CreateOrderCubit({
    required CustomerRepository customerRepository,
    required ItemTypeRepository itemTypeRepository,
    required ItemDefinitionRepository itemDefinitionRepository,
    required ServiceRepository serviceRepository,
    required CarpetSizeRepository carpetSizeRepository,
    required SettingsRepository settingsRepository,
    required CreateOrderUseCase createOrderUseCase,
    Uuid? uuid,
  })  : _customerRepository = customerRepository,
        _itemTypeRepository = itemTypeRepository,
        _itemDefinitionRepository = itemDefinitionRepository,
        _serviceRepository = serviceRepository,
        _carpetSizeRepository = carpetSizeRepository,
        _settingsRepository = settingsRepository,
        _createOrderUseCase = createOrderUseCase,
        _uuid = uuid ?? const Uuid(),
        super(CreateOrderState(
          expectedPickupDate: OrderDate.fromDate(
            DateTime.now().add(const Duration(days: 7)),
          ),
        ));

  Future<void> initialize() async {
    emit(state.copyWith(isInitialLoading: true, clearErrorMessage: true));
    try {
      final itemTypes = await _itemTypeRepository.getActiveItemTypes();
      final carpetSizes = await _carpetSizeRepository.getActiveCarpetSizes();
      final settings = await _settingsRepository.getSettings();

      if (isClosed) return;
      emit(state.copyWith(
        isInitialLoading: false,
        itemTypes: itemTypes,
        carpetSizes: carpetSizes,
        settings: settings,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        isInitialLoading: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> searchCustomers(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      emit(state.copyWith(customerSearchResults: []));
      return;
    }

    emit(state.copyWith(isSearchingCustomer: true));
    try {
      final results = await _customerRepository.searchCustomers(query: trimmed);
      if (isClosed) return;
      emit(state.copyWith(
        customerSearchResults: results,
        isSearchingCustomer: false,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(isSearchingCustomer: false));
    }
  }

  void selectCustomer(Customer? customer) {
    if (customer == null) {
      emit(state.copyWith(clearSelectedCustomer: true));
    } else {
      emit(state.copyWith(selectedCustomer: customer));
    }
  }

  Future<Customer> addNewCustomer({
    required String name,
    required String phone,
    String? notes,
  }) async {
    final trimmedName = name.trim();
    final trimmedPhone = phone.trim();

    if (trimmedName.isEmpty) {
      throw const ValidationFailure('اسم العميل مطلوب');
    }
    if (trimmedPhone.isEmpty) {
      throw const ValidationFailure('رقم الهاتف مطلوب');
    }

    final existing = await _customerRepository.getCustomerByPhone(trimmedPhone);
    if (existing != null) {
      throw const ValidationFailure('رقم الهاتف مسجل لعميل آخر بالفعل');
    }

    final now = DateTime.now();
    final newCustomer = Customer(
      id: _uuid.v4(),
      name: trimmedName,
      phone: trimmedPhone,
      notes: notes?.trim().isNotEmpty == true ? notes!.trim() : null,
      createdAt: now,
      updatedAt: now,
    );

    final saved = await _customerRepository.createCustomer(newCustomer);
    selectCustomer(saved);
    return saved;
  }

  Future<void> selectItemType(ItemType? itemType) async {
    if (itemType == null) {
      emit(state.copyWith(
        clearDraftItemType: true,
        clearDraftItemDefinition: true,
        clearDraftService: true,
        compatibleServices: [],
        itemDefinitions: [],
      ));
      return;
    }

    emit(state.copyWith(
      draftItemType: itemType,
      clearDraftItemDefinition: true,
      clearDraftService: true,
    ));

    try {
      final services = await _serviceRepository.getServicesForItemType(itemType.id);
      final definitions = await _itemDefinitionRepository.getDefinitionsForItemType(
        itemType.id,
        activeOnly: true,
      );

      if (isClosed) return;
      emit(state.copyWith(
        compatibleServices: services.where((s) => s.isActive).toList(),
        itemDefinitions: definitions,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  void selectItemDefinition(ItemDefinition? definition) {
    if (definition == null) {
      emit(state.copyWith(clearDraftItemDefinition: true));
    } else {
      emit(state.copyWith(draftItemDefinition: definition));
    }
  }

  void selectService(Service? service) {
    if (service == null) {
      emit(state.copyWith(clearDraftService: true));
    } else {
      emit(state.copyWith(
        draftService: service,
        draftUnitPrice: service.price,
      ));
    }
  }

  void updateUnitPrice(Money price) {
    emit(state.copyWith(draftUnitPrice: price));
  }

  void updateQuantity(int quantity) {
    final validQty = quantity < 1 ? 1 : quantity;
    emit(state.copyWith(draftQuantity: validQty));
  }

  void selectCarpetSize(CarpetSize? size) {
    if (size == null) {
      emit(state.copyWith(clearDraftCarpetSize: true));
    } else {
      emit(state.copyWith(
        draftCarpetSize: size,
        draftCarpetLength: size.length,
        draftCarpetWidth: size.width,
      ));
    }
  }

  void updateCarpetDimensions({double? length, double? width}) {
    emit(state.copyWith(
      draftCarpetLength: length ?? state.draftCarpetLength,
      draftCarpetWidth: width ?? state.draftCarpetWidth,
      clearDraftCarpetSize: true,
    ));
  }

  void updateDraftNotes(String? notes) {
    if (notes == null) {
      emit(state.copyWith(clearDraftNotes: true));
    } else {
      emit(state.copyWith(draftNotes: notes));
    }
  }

  void addItemDraftToOrder() {
    if (state.draftItemType == null) {
      emit(state.copyWith(errorMessage: 'يرجى اختيار نوع القطعة أولاً'));
      return;
    }
    if (state.draftService == null) {
      emit(state.copyWith(errorMessage: 'يرجى اختيار الخدمة أولاً'));
      return;
    }
    final price = state.draftUnitPrice ?? state.draftService!.price;
    if (price <= Money.zero) {
      emit(state.copyWith(errorMessage: 'سعر القطعة يجب أن يكون أكبر من الصفر'));
      return;
    }
    if (state.draftQuantity < 1) {
      emit(state.copyWith(errorMessage: 'الكمية يجب أن تكون 1 على الأقل'));
      return;
    }

    if (state.draftService!.pricingType == PricingType.perSquareMeter) {
      if (state.draftCarpetLength <= 0 || state.draftCarpetWidth <= 0) {
        emit(state.copyWith(errorMessage: 'أبعاد السجاد يجب أن تكون أكبر من الصفر'));
        return;
      }
    }

    final draftItem = OrderItemDraft(
      itemTypeId: state.draftItemType!.id,
      itemTypeName: state.draftItemType!.name,
      itemDefinitionId: state.draftItemDefinition?.id,
      itemDefinitionName: state.draftItemDefinition?.name,
      serviceId: state.draftService!.id,
      serviceName: state.draftService!.name,
      pricingType: state.draftService!.pricingType,
      unitPrice: price,
      physicalQuantity: state.draftQuantity,
      carpetSizeId: state.draftCarpetSize?.id,
      length: state.draftCarpetLength,
      width: state.draftCarpetWidth,
      notes: state.draftNotes?.trim().isNotEmpty == true ? state.draftNotes!.trim() : null,
    );

    final updatedItems = List<OrderItemDraft>.from(state.items)..add(draftItem);

    emit(state.copyWith(
      items: updatedItems,
      clearDraftItemType: true,
      clearDraftItemDefinition: true,
      clearDraftService: true,
      clearDraftCarpetSize: true,
      draftCarpetLength: 0.0,
      draftCarpetWidth: 0.0,
      clearDraftNotes: true,
      draftQuantity: 1,
      compatibleServices: [],
      itemDefinitions: [],
      clearErrorMessage: true,
    ));
  }

  void removeItem(int index) {
    if (index >= 0 && index < state.items.length) {
      final updatedItems = List<OrderItemDraft>.from(state.items)..removeAt(index);
      emit(state.copyWith(items: updatedItems));
    }
  }

  void updateExpectedPickupDate(OrderDate date) {
    if (date.isBeforeToday) {
      emit(state.copyWith(errorMessage: 'موعد الاستلام لا يمكن أن يكون في الماضي'));
      return;
    }
    emit(state.copyWith(expectedPickupDate: date, clearErrorMessage: true));
  }

  void updateDiscount(Money discount) {
    if (discount.isNegative) {
      emit(state.copyWith(errorMessage: 'الخصم لا يمكن أن يكون سالباً'));
      return;
    }
    emit(state.copyWith(discount: discount, clearErrorMessage: true));
  }

  void updateOrderNotes(String? notes) {
    emit(state.copyWith(orderNotes: notes));
  }

  void updateDelivery({
    bool? pickupRequested,
    Money? pickupFee,
    bool? deliveryRequested,
    Money? deliveryFee,
  }) {
    emit(state.copyWith(
      customerPickupRequested: pickupRequested ?? state.customerPickupRequested,
      customerPickupFee: pickupFee ?? state.customerPickupFee,
      customerDeliveryRequested: deliveryRequested ?? state.customerDeliveryRequested,
      customerDeliveryFee: deliveryFee ?? state.customerDeliveryFee,
    ));
  }

  Future<void> submitOrder() async {
    if (state.selectedCustomer == null) {
      emit(state.copyWith(errorMessage: 'يرجى اختيار عميل أولاً'));
      return;
    }
    if (state.items.isEmpty) {
      emit(state.copyWith(errorMessage: 'يجب إضافة قطعة واحدة على الأقل'));
      return;
    }
    if (state.expectedPickupDate.isBeforeToday) {
      emit(state.copyWith(errorMessage: 'موعد الاستلام المتوقع لا يمكن أن يكون في الماضي'));
      return;
    }
    if (state.discount > state.subtotal) {
      emit(state.copyWith(errorMessage: 'الخصم لا يمكن أن يتجاوز المجموع الفرعي'));
      return;
    }

    emit(state.copyWith(isSubmitting: true, clearErrorMessage: true));

    try {
      final createOrderItemsInput = state.items.map((draft) {
        CarpetItemInput? carpetData;
        if (draft.pricingType == PricingType.perSquareMeter) {
          carpetData = CarpetItemInput(
            carpetSizeId: draft.carpetSizeId,
            length: draft.length,
            width: draft.width,
          );
        }

        return CreateOrderItemInput(
          itemTypeId: draft.itemTypeId,
          itemDefinitionId: draft.itemDefinitionId,
          serviceId: draft.serviceId,
          customUnitPrice: draft.unitPrice,
          physicalQuantity: draft.physicalQuantity,
          notes: draft.notes,
          carpetData: carpetData,
        );
      }).toList();

      final input = CreateOrderInput(
        customerId: state.selectedCustomer!.id,
        expectedPickupDate: state.expectedPickupDate,
        notes: state.orderNotes?.trim().isNotEmpty == true ? state.orderNotes!.trim() : null,
        customerPickupRequested: state.customerPickupRequested,
        customerPickupFee: state.effectivePickupFee,
        customerDeliveryRequested: state.customerDeliveryRequested,
        customerDeliveryFee: state.effectiveDeliveryFee,
        discount: state.discount,
        items: createOrderItemsInput,
      );

      final order = await _createOrderUseCase.execute(input);

      if (isClosed) return;
      emit(state.copyWith(
        isSubmitting: false,
        createdOrder: order,
      ));
    } on Failure catch (f) {
      if (isClosed) return;
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: f.message,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
      ));
    }
  }
}
