import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../application/use_cases/create_order_use_case.dart';
import '../../../../application/use_cases/edit_processing_order_use_case.dart';
import '../../../../core/errors/failures.dart';
import '../../../../data/local/daos/payments_dao.dart';
import '../../../../data/local/daos/storage_records_dao.dart';
import '../../../../domain/entities/carpet_size.dart';
import '../../../../domain/entities/customer.dart';
import '../../../../domain/entities/item_definition.dart';
import '../../../../domain/entities/item_type.dart';
import '../../../../domain/entities/service.dart';
import '../../../../domain/enums/order_status.dart';
import '../../../../domain/enums/pricing_type.dart';
import '../../../../domain/repositories/carpet_size_repository.dart';
import '../../../../domain/repositories/customer_repository.dart';
import '../../../../domain/repositories/item_definition_repository.dart';
import '../../../../domain/repositories/item_type_repository.dart';
import '../../../../domain/repositories/order_repository.dart';
import '../../../../domain/repositories/service_repository.dart';
import '../../../../domain/repositories/settings_repository.dart';
import '../../../../domain/repositories/storage_location_repository.dart';
import '../../../../domain/value_objects/money.dart';
import '../../../../domain/value_objects/order_date.dart';
import '../models/editable_order_item.dart';
import 'edit_processing_order_state.dart';

class EditProcessingOrderCubit extends Cubit<EditProcessingOrderState> {
  final OrderRepository _orderRepository;
  final CustomerRepository _customerRepository;
  final ItemTypeRepository _itemTypeRepository;
  final ItemDefinitionRepository _itemDefinitionRepository;
  final ServiceRepository _serviceRepository;
  final CarpetSizeRepository _carpetSizeRepository;
  final StorageLocationRepository _storageLocationRepository;
  final StorageRecordsDao _storageRecordsDao;
  final PaymentsDao _paymentsDao;
  final SettingsRepository _settingsRepository;
  final EditProcessingOrderUseCase _editProcessingOrderUseCase;

  EditProcessingOrderCubit({
    required OrderRepository orderRepository,
    required CustomerRepository customerRepository,
    required ItemTypeRepository itemTypeRepository,
    required ItemDefinitionRepository itemDefinitionRepository,
    required ServiceRepository serviceRepository,
    required CarpetSizeRepository carpetSizeRepository,
    required StorageLocationRepository storageLocationRepository,
    required StorageRecordsDao storageRecordsDao,
    required PaymentsDao paymentsDao,
    required SettingsRepository settingsRepository,
    required EditProcessingOrderUseCase editProcessingOrderUseCase,
  }) : _orderRepository = orderRepository,
       _customerRepository = customerRepository,
       _itemTypeRepository = itemTypeRepository,
       _itemDefinitionRepository = itemDefinitionRepository,
       _serviceRepository = serviceRepository,
       _carpetSizeRepository = carpetSizeRepository,
       _storageLocationRepository = storageLocationRepository,
       _storageRecordsDao = storageRecordsDao,
       _paymentsDao = paymentsDao,
       _settingsRepository = settingsRepository,
       _editProcessingOrderUseCase = editProcessingOrderUseCase,
       super(EditProcessingOrderState(expectedPickupDate: OrderDate.today()));

  Future<void> loadOrder(String orderId) async {
    emit(state.copyWith(isLoading: true, clearErrorMessage: true));
    try {
      final order = await _orderRepository.getOrderById(orderId);
      if (order == null) {
        emit(state.copyWith(isLoading: false, errorMessage: 'الطلب غير موجود'));
        return;
      }

      if (order.status != OrderStatus.processing) {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage:
                'لا يمكن تعديل هذا الطلب لأنه ليس في حالة قيد التجهيز',
          ),
        );
        return;
      }

      final totalPaidPiastres = await _paymentsDao.getTotalPaidForOrder(orderId);
      final totalPaid = Money.fromPiastres(totalPaidPiastres);

      final customer = await _customerRepository.getCustomerById(order.customerId);
      final rawItems = await _orderRepository.getOrderItems(orderId);

      // Fetch storage records for items
      final editableItems = <EditableOrderItem>[];
      for (final item in rawItems) {
        final count =
            await _storageRecordsDao.countAllRecordsForOrderItem(item.id);
        final activeRecord =
            await _storageRecordsDao.getActiveRecordForOrderItem(item.id);
        String? locName;
        if (activeRecord != null) {
          final loc = await _storageLocationRepository.getStorageLocationById(
            activeRecord.storageLocationId,
          );
          locName = loc?.name;
        }

        editableItems.add(
          EditableOrderItem(
            id: item.id,
            itemTypeId: item.itemTypeId,
            itemTypeName: item.itemTypeNameSnapshot,
            itemDefinitionId: item.itemDefinitionId,
            itemDefinitionName: item.itemDefinitionNameSnapshot,
            serviceId: item.serviceId,
            serviceName: item.serviceNameSnapshot,
            pricingType: item.pricingType,
            unitPrice: item.unitPrice,
            physicalQuantity: 1,
            carpetSizeId: item.carpetData?.carpetSizeId,
            length: item.carpetData?.length ?? 0.0,
            width: item.carpetData?.width ?? 0.0,
            notes: item.notes,
            hasStorageRecords: count > 0,
            storageLocationName: locName,
          ),
        );
      }

      // Master data
      final itemTypes = await _itemTypeRepository.getActiveItemTypes();
      final carpetSizes = await _carpetSizeRepository.getActiveCarpetSizes();
      final settings = await _settingsRepository.getSettings();

      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          initialOrder: order,
          totalPaid: totalPaid,
          selectedCustomer: customer,
          items: editableItems,
          deletedItemIds: const [],
          expectedPickupDate: order.expectedPickupDate,
          notes: order.notes,
          customerPickupRequested: order.customerPickupRequested,
          customerPickupFee: order.customerPickupFee,
          customerDeliveryRequested: order.customerDeliveryRequested,
          customerDeliveryFee: order.customerDeliveryFee,
          discount: order.discount,
          itemTypes: itemTypes,
          carpetSizes: carpetSizes,
          settings: settings,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> searchCustomers(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      emit(state.copyWith(customerSearchResults: const [], isSearchingCustomer: false));
      return;
    }

    emit(state.copyWith(isSearchingCustomer: true));
    try {
      final results = await _customerRepository.searchCustomers(query: trimmed);
      if (isClosed) return;
      emit(state.copyWith(customerSearchResults: results, isSearchingCustomer: false));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(isSearchingCustomer: false));
    }
  }

  void selectCustomer(Customer? customer) {
    if (!state.canChangeCustomer) {
      emit(
        state.copyWith(
          errorMessage: 'لا يمكن تغيير العميل لوجود مدفوعات مسجلة على الطلب',
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        selectedCustomer: customer,
        clearSelectedCustomer: customer == null,
        customerSearchResults: const [],
        isSearchingCustomer: false,
        clearErrorMessage: true,
      ),
    );
  }

  Future<void> addNewCustomer({
    required String name,
    required String phone,
    String? address,
    String? notes,
  }) async {
    if (!state.canChangeCustomer) {
      emit(
        state.copyWith(
          errorMessage: 'لا يمكن تغيير العميل لوجود مدفوعات مسجلة على الطلب',
        ),
      );
      return;
    }
    try {
      final customer = await _customerRepository.createCustomer(
        Customer(
          id: const Uuid().v4(),
          name: name,
          phone: phone,
          address: address,
          notes: notes,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      selectCustomer(customer);
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  void updateExpectedPickupDate(OrderDate date) {
    emit(state.copyWith(expectedPickupDate: date, clearErrorMessage: true));
  }

  void updateNotes(String? notes) {
    emit(state.copyWith(notes: notes));
  }

  void toggleCustomerPickup(bool requested) {
    emit(
      state.copyWith(
        customerPickupRequested: requested,
      ),
    );
  }

  void updateCustomerPickupFee(Money fee) {
    emit(state.copyWith(customerPickupFee: fee));
  }

  void toggleCustomerDelivery(bool requested) {
    emit(
      state.copyWith(
        customerDeliveryRequested: requested,
      ),
    );
  }

  void updateCustomerDeliveryFee(Money fee) {
    emit(state.copyWith(customerDeliveryFee: fee));
  }

  void updateDiscount(Money discount) {
    emit(state.copyWith(discount: discount));
  }

  // --- Draft Item Management ---

  Future<void> selectItemType(ItemType? itemType) async {
    if (state.editingItemIndex != null) {
      final existingItem = state.items[state.editingItemIndex!];
      if (existingItem.isExisting) {
        emit(
          state.copyWith(
            errorMessage: 'نوع العنصر غير قابل للتغيير للقطع الموجودة مسبقًا',
          ),
        );
        return;
      }
    }

    if (itemType == null) {
      emit(
        state.copyWith(
          clearDraftItemType: true,
          clearDraftItemDefinition: true,
          clearDraftService: true,
          clearDraftUnitPrice: true,
          compatibleServices: const [],
          itemDefinitions: const [],
        ),
      );
      return;
    }

    try {
      final services =
          await _serviceRepository.getServicesForItemType(itemType.id);
      final definitions = await _itemDefinitionRepository
          .getDefinitionsForItemType(itemType.id, activeOnly: true);

      // Deduplicate by ID
      final uniqueServices = {for (final s in services.where((s) => s.isActive)) s.id: s}.values.toList();
      final uniqueDefs = {for (final d in definitions.where((d) => d.isActive)) d.id: d}.values.toList();

      emit(
        state.copyWith(
          draftItemType: itemType,
          clearDraftItemDefinition: true,
          clearDraftService: true,
          clearDraftUnitPrice: true,
          compatibleServices: uniqueServices,
          itemDefinitions: uniqueDefs,
          clearErrorMessage: true,
        ),
      );
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  void selectItemDefinition(ItemDefinition? definition) {
    emit(
      state.copyWith(
        draftItemDefinition: definition,
        clearDraftItemDefinition: definition == null,
      ),
    );
  }

  void selectService(Service? service) {
    if (service == null) {
      emit(
        state.copyWith(
          clearDraftService: true,
          clearDraftUnitPrice: true,
          clearDraftCarpetSize: true,
          draftCarpetLength: 0.0,
          draftCarpetWidth: 0.0,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        draftService: service,
        draftUnitPrice: service.price,
        clearDraftCarpetSize: service.pricingType != PricingType.perSquareMeter,
        draftCarpetLength:
            service.pricingType != PricingType.perSquareMeter ? 0.0 : state.draftCarpetLength,
        draftCarpetWidth:
            service.pricingType != PricingType.perSquareMeter ? 0.0 : state.draftCarpetWidth,
      ),
    );
  }

  void updateDraftUnitPrice(Money price) {
    emit(state.copyWith(draftUnitPrice: price));
  }

  void updateDraftQuantity(int quantity) {
    emit(state.copyWith(draftQuantity: quantity > 0 ? quantity : 1));
  }

  void selectDraftCarpetSize(CarpetSize? size) {
    if (size == null) {
      emit(state.copyWith(clearDraftCarpetSize: true));
      return;
    }
    emit(
      state.copyWith(
        draftCarpetSize: size,
        draftCarpetLength: size.length,
        draftCarpetWidth: size.width,
      ),
    );
  }

  void updateDraftCarpetDimensions(double length, double width) {
    emit(
      state.copyWith(
        draftCarpetLength: length,
        draftCarpetWidth: width,
      ),
    );
  }

  void updateDraftNotes(String? notes) {
    emit(state.copyWith(draftNotes: notes, clearDraftNotes: notes == null));
  }

  Future<void> startEditItem(int index) async {
    if (index < 0 || index >= state.items.length) return;
    final item = state.items[index];

    // Find item type
    final matchingType = state.itemTypes.firstWhere(
      (t) => t.id == item.itemTypeId,
      orElse: () => ItemType(
        id: item.itemTypeId,
        name: item.itemTypeName,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    // Load compatible services and definitions
    final services =
        await _serviceRepository.getServicesForItemType(matchingType.id);
    final definitions = await _itemDefinitionRepository
        .getDefinitionsForItemType(matchingType.id, activeOnly: true);

    final matchingService = services.firstWhere(
      (s) => s.id == item.serviceId,
      orElse: () => Service(
        id: item.serviceId,
        name: item.serviceName,
        price: item.unitPrice,
        pricingType: item.pricingType,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    ItemDefinition? matchingDef;
    if (item.itemDefinitionId != null) {
      try {
        matchingDef = definitions.firstWhere(
          (d) => d.id == item.itemDefinitionId,
        );
      } catch (_) {}
    }

    CarpetSize? matchingSize;
    if (item.carpetSizeId != null) {
      try {
        matchingSize = state.carpetSizes.firstWhere(
          (c) => c.id == item.carpetSizeId,
        );
      } catch (_) {}
    }

    // Deduplicate and ensure matchingService and matchingDef are in lists
    final servicesList = {for (final s in services) s.id: s};
    servicesList[matchingService.id] = matchingService;

    final defsList = {for (final d in definitions) d.id: d};
    if (matchingDef != null) {
      defsList[matchingDef.id] = matchingDef;
    }

    emit(
      state.copyWith(
        editingItemIndex: index,
        draftItemType: matchingType,
        draftItemDefinition: matchingDef,
        clearDraftItemDefinition: matchingDef == null,
        draftService: matchingService,
        draftUnitPrice: item.unitPrice,
        draftQuantity: item.physicalQuantity,
        draftCarpetSize: matchingSize,
        clearDraftCarpetSize: matchingSize == null,
        draftCarpetLength: item.length,
        draftCarpetWidth: item.width,
        draftNotes: item.notes,
        clearDraftNotes: item.notes == null,
        compatibleServices: servicesList.values.toList(),
        itemDefinitions: defsList.values.toList(),
        clearErrorMessage: true,
      ),
    );
  }

  void cancelDraft() {
    emit(
      state.copyWith(
        clearEditingItemIndex: true,
        clearDraftItemType: true,
        clearDraftItemDefinition: true,
        clearDraftService: true,
        clearDraftUnitPrice: true,
        clearDraftCarpetSize: true,
        draftCarpetLength: 0.0,
        draftCarpetWidth: 0.0,
        clearDraftNotes: true,
        draftQuantity: 1,
        compatibleServices: const [],
        itemDefinitions: const [],
      ),
    );
  }

  void saveDraftItem() {
    if (state.draftItemType == null) {
      emit(state.copyWith(errorMessage: 'نوع العنصر مطلوب'));
      return;
    }
    if (state.draftService == null) {
      emit(state.copyWith(errorMessage: 'الخدمة مطلوبة'));
      return;
    }
    final unitPrice = state.draftUnitPrice ?? state.draftService!.price;
    if (unitPrice <= Money.zero) {
      emit(state.copyWith(errorMessage: 'يجب أن يكون السعر أكبر من الصفر'));
      return;
    }

    if (state.draftService!.pricingType == PricingType.perSquareMeter) {
      if (state.draftCarpetLength <= 0 || state.draftCarpetWidth <= 0) {
        emit(state.copyWith(errorMessage: 'أبعاد السجاد مطلوبة ويجب أن تكون أكبر من الصفر'));
        return;
      }
    }

    final currentItems = List<EditableOrderItem>.from(state.items);

    if (state.editingItemIndex != null) {
      // Updating existing item in list
      final old = currentItems[state.editingItemIndex!];
      final updated = old.copyWith(
        itemDefinitionId: state.draftItemDefinition?.id,
        itemDefinitionName: state.draftItemDefinition?.name,
        clearItemDefinition: state.draftItemDefinition == null,
        serviceId: state.draftService!.id,
        serviceName: state.draftService!.name,
        pricingType: state.draftService!.pricingType,
        unitPrice: unitPrice,
        carpetSizeId: state.draftCarpetSize?.id,
        length: state.draftCarpetLength,
        width: state.draftCarpetWidth,
        notes: state.draftNotes,
      );
      currentItems[state.editingItemIndex!] = updated;
    } else {
      // Adding new item(s) - expand physical quantity into individual physical piece entries
      final count = state.draftQuantity > 0 ? state.draftQuantity : 1;
      for (var i = 0; i < count; i++) {
        final newItem = EditableOrderItem(
          itemTypeId: state.draftItemType!.id,
          itemTypeName: state.draftItemType!.name,
          itemDefinitionId: state.draftItemDefinition?.id,
          itemDefinitionName: state.draftItemDefinition?.name,
          serviceId: state.draftService!.id,
          serviceName: state.draftService!.name,
          pricingType: state.draftService!.pricingType,
          unitPrice: unitPrice,
          physicalQuantity: 1,
          carpetSizeId: state.draftCarpetSize?.id,
          length: state.draftCarpetLength,
          width: state.draftCarpetWidth,
          notes: state.draftNotes,
          hasStorageRecords: false,
        );
        currentItems.add(newItem);
      }
    }

    emit(
      state.copyWith(
        items: currentItems,
        clearEditingItemIndex: true,
        clearDraftItemType: true,
        clearDraftItemDefinition: true,
        clearDraftService: true,
        clearDraftUnitPrice: true,
        clearDraftCarpetSize: true,
        draftCarpetLength: 0.0,
        draftCarpetWidth: 0.0,
        clearDraftNotes: true,
        draftQuantity: 1,
        compatibleServices: const [],
        itemDefinitions: const [],
        clearErrorMessage: true,
      ),
    );
  }

  void deleteItem(int index) {
    if (index < 0 || index >= state.items.length) return;
    final item = state.items[index];

    if (item.hasStorageRecords) {
      emit(
        state.copyWith(
          errorMessage:
              'لا يمكن حذف هذا العنصر لوجود سجلات تخزين مرتبطة به. لإلغاء العناصر المخزنة، يرجى إلغاء الطلب.',
        ),
      );
      return;
    }

    final currentItems = List<EditableOrderItem>.from(state.items);
    currentItems.removeAt(index);

    final deletedIds = List<String>.from(state.deletedItemIds);
    if (item.isExisting) {
      deletedIds.add(item.id!);
    }

    emit(
      state.copyWith(
        items: currentItems,
        deletedItemIds: deletedIds,
        clearErrorMessage: true,
      ),
    );
  }

  Future<void> submitEdit() async {
    if (state.isSubmitting) return;

    if (state.initialOrder == null) {
      emit(state.copyWith(errorMessage: 'بيانات الطلب غير مكتملة'));
      return;
    }
    if (state.selectedCustomer == null) {
      emit(state.copyWith(errorMessage: 'يرجى اختيار العميل'));
      return;
    }
    if (state.items.isEmpty) {
      emit(state.copyWith(errorMessage: 'يجب أن يحتوي الطلب على عنصر واحد على الأقل'));
      return;
    }
    if (!state.isTotalValid) {
      emit(
        state.copyWith(
          errorMessage:
              'إجمالي الطلب (${state.total.toEgp} ج.م) لا يمكن أن يكون أقل من المبلغ المدفوع (${state.totalPaid.toEgp} ج.م)',
        ),
      );
      return;
    }
    if (!state.isPickupDateValid) {
      emit(
        state.copyWith(
          errorMessage: 'تاريخ الاستلام المتوقع لا يمكن أن يكون في الماضي',
        ),
      );
      return;
    }

    emit(state.copyWith(isSubmitting: true, clearErrorMessage: true));

    try {
      final modifiedInputs = <OrderItemEditInput>[];
      final newInputs = <CreateOrderItemInput>[];

      for (final item in state.items) {
        CarpetItemInput? carpetInput;
        if (item.pricingType == PricingType.perSquareMeter) {
          carpetInput = CarpetItemInput(
            carpetSizeId: item.carpetSizeId,
            length: item.length,
            width: item.width,
          );
        }

        if (item.isExisting) {
          modifiedInputs.add(
            OrderItemEditInput(
              id: item.id!,
              itemDefinitionId: item.itemDefinitionId,
              serviceId: item.serviceId,
              customUnitPrice: item.unitPrice,
              notes: item.notes,
              carpetData: carpetInput,
            ),
          );
        } else {
          newInputs.add(
            CreateOrderItemInput(
              itemTypeId: item.itemTypeId,
              itemDefinitionId: item.itemDefinitionId,
              serviceId: item.serviceId,
              customUnitPrice: item.unitPrice,
              physicalQuantity: item.physicalQuantity,
              notes: item.notes,
              carpetData: carpetInput,
            ),
          );
        }
      }

      final input = EditProcessingOrderInput(
        orderId: state.initialOrder!.id,
        customerId: state.selectedCustomer!.id,
        expectedPickupDate: state.expectedPickupDate,
        notes: state.notes,
        customerPickupRequested: state.customerPickupRequested,
        customerPickupFee: state.effectivePickupFee,
        customerDeliveryRequested: state.customerDeliveryRequested,
        customerDeliveryFee: state.effectiveDeliveryFee,
        discount: state.discount,
        modifiedItems: modifiedInputs,
        deletedItemIds: state.deletedItemIds,
        newItems: newInputs,
      );

      final updated = await _editProcessingOrderUseCase.execute(input);

      if (isClosed) return;
      emit(state.copyWith(isSubmitting: false, savedOrder: updated));
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: e is Failure ? e.message : e.toString(),
        ),
      );
    }
  }
}
