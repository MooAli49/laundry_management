import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../domain/entities/service.dart';
import '../../../../domain/enums/pricing_type.dart';
import '../../../../domain/repositories/item_type_repository.dart';
import '../../../../domain/repositories/service_repository.dart';
import '../../../../domain/value_objects/money.dart';
import 'services_management_state.dart';

import '../../../../domain/entities/service_item_type.dart';

class ServiceItemTypeConfig {
  final String itemTypeId;
  final PricingType pricingType;
  final Money price;

  const ServiceItemTypeConfig({
    required this.itemTypeId,
    required this.pricingType,
    required this.price,
  });
}

class ServicesManagementCubit extends Cubit<ServicesManagementState> {
  final ServiceRepository _serviceRepository;
  final ItemTypeRepository _itemTypeRepository;

  ServicesManagementCubit({
    required ServiceRepository serviceRepository,
    required ItemTypeRepository itemTypeRepository,
  }) : _serviceRepository = serviceRepository,
       _itemTypeRepository = itemTypeRepository,
       super(const ServicesManagementState());

  void clearMessages() {
    emit(state.copyWith(clearErrorMessage: true, clearSuccessMessage: true));
  }

  Future<void> loadServices() async {
    emit(
      state.copyWith(
        isLoading: true,
        clearErrorMessage: true,
        clearSuccessMessage: true,
      ),
    );

    try {
      final services = await _serviceRepository.getAllServices();
      final itemTypes = await _itemTypeRepository.getActiveItemTypes();
      emit(
        state.copyWith(
          isLoading: false,
          services: services,
          itemTypes: itemTypes,
        ),
      );
    } on Failure catch (f) {
      emit(state.copyWith(isLoading: false, errorMessage: f.message));
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: AppStrings.unexpectedError,
        ),
      );
    }
  }

  Future<List<ServiceItemType>> getServiceItemTypes(String serviceId) async {
    try {
      return await _serviceRepository.getServiceItemTypes(serviceId);
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> getSupportedItemTypeIds(String serviceId) async {
    try {
      return await _serviceRepository.getSupportedItemTypeIds(serviceId);
    } catch (_) {
      return [];
    }
  }

  Future<bool> createService({
    required String name,
    String? description,
    required List<ServiceItemTypeConfig> itemTypeConfigs,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      emit(state.copyWith(errorMessage: AppStrings.serviceNameRequired));
      return false;
    }
    if (itemTypeConfigs.isEmpty) {
      emit(state.copyWith(errorMessage: AppStrings.selectAtLeastOneItemType));
      return false;
    }
    for (final cfg in itemTypeConfigs) {
      if (cfg.price <= Money.zero) {
        emit(
          state.copyWith(errorMessage: AppStrings.servicePriceMustBePositive),
        );
        return false;
      }
    }

    emit(
      state.copyWith(
        isActionInProgress: true,
        clearErrorMessage: true,
        clearSuccessMessage: true,
      ),
    );

    try {
      final now = DateTime.now();
      final serviceId = const Uuid().v4();
      final service = Service(
        id: serviceId,
        name: trimmedName,
        description: description?.trim().isEmpty == true
            ? null
            : description?.trim(),
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final serviceItemTypes = itemTypeConfigs.map((cfg) {
        return ServiceItemType(
          id: const Uuid().v4(),
          serviceId: serviceId,
          itemTypeId: cfg.itemTypeId,
          pricingType: cfg.pricingType,
          price: cfg.price,
          createdAt: now,
          updatedAt: now,
        );
      }).toList();

      await _serviceRepository.createService(
        service,
        serviceItemTypes: serviceItemTypes,
      );

      final services = await _serviceRepository.getAllServices();
      emit(state.copyWith(isActionInProgress: false, services: services));
      return true;
    } on Failure catch (f) {
      final msg = _normalizeError(f.message);
      emit(state.copyWith(isActionInProgress: false, errorMessage: msg));
      return false;
    } catch (e) {
      emit(
        state.copyWith(
          isActionInProgress: false,
          errorMessage: AppStrings.unexpectedError,
        ),
      );
      return false;
    }
  }

  Future<bool> updateService({
    required Service service,
    required List<ServiceItemTypeConfig> itemTypeConfigs,
  }) async {
    final trimmedName = service.name.trim();
    if (trimmedName.isEmpty) {
      emit(state.copyWith(errorMessage: AppStrings.serviceNameRequired));
      return false;
    }
    if (itemTypeConfigs.isEmpty) {
      emit(state.copyWith(errorMessage: AppStrings.selectAtLeastOneItemType));
      return false;
    }
    for (final cfg in itemTypeConfigs) {
      if (cfg.price <= Money.zero) {
        emit(
          state.copyWith(errorMessage: AppStrings.servicePriceMustBePositive),
        );
        return false;
      }
    }

    emit(
      state.copyWith(
        isActionInProgress: true,
        clearErrorMessage: true,
        clearSuccessMessage: true,
      ),
    );

    try {
      final now = DateTime.now();
      final updated = service.copyWith(
        name: trimmedName,
        updatedAt: now,
      );

      final existingSits = await _serviceRepository.getServiceItemTypes(
        service.id,
      );
      final existingByItemTypeId = {
        for (final sit in existingSits) sit.itemTypeId: sit,
      };

      // Get active item types to distinguish between types the user explicitly
      // deselected in the UI vs types that were hidden because they are inactive.
      final activeItemTypes = await _itemTypeRepository.getActiveItemTypes();
      final activeItemTypeIds = activeItemTypes.map((t) => t.id).toSet();
      final submittedItemTypeIds = itemTypeConfigs
          .map((c) => c.itemTypeId)
          .toSet();

      final serviceItemTypes = itemTypeConfigs.map((cfg) {
        final existing = existingByItemTypeId[cfg.itemTypeId];
        return ServiceItemType(
          id: existing?.id ?? const Uuid().v4(),
          serviceId: service.id,
          itemTypeId: cfg.itemTypeId,
          pricingType: cfg.pricingType,
          price: cfg.price,
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        );
      }).toList();

      // MED-01: Preserve existing mappings for inactive item types that were hidden in UI
      for (final existing in existingSits) {
        if (!submittedItemTypeIds.contains(existing.itemTypeId) &&
            !activeItemTypeIds.contains(existing.itemTypeId)) {
          serviceItemTypes.add(existing);
        }
      }

      await _serviceRepository.updateService(
        updated,
        serviceItemTypes: serviceItemTypes,
      );

      final services = await _serviceRepository.getAllServices();
      emit(state.copyWith(isActionInProgress: false, services: services));
      return true;
    } on Failure catch (f) {
      final msg = _normalizeError(f.message);
      emit(state.copyWith(isActionInProgress: false, errorMessage: msg));
      return false;
    } catch (e) {
      emit(
        state.copyWith(
          isActionInProgress: false,
          errorMessage: AppStrings.unexpectedError,
        ),
      );
      return false;
    }
  }

  Future<void> activateService(String id) async {
    emit(state.copyWith(isActionInProgress: true));
    try {
      await _serviceRepository.activateService(id);
      final services = await _serviceRepository.getAllServices();
      emit(state.copyWith(isActionInProgress: false, services: services));
    } on Failure catch (f) {
      emit(state.copyWith(isActionInProgress: false, errorMessage: f.message));
    } catch (e) {
      emit(
        state.copyWith(
          isActionInProgress: false,
          errorMessage: AppStrings.unexpectedError,
        ),
      );
    }
  }

  Future<void> deactivateService(String id) async {
    emit(state.copyWith(isActionInProgress: true));
    try {
      await _serviceRepository.deactivateService(id);
      final services = await _serviceRepository.getAllServices();
      emit(state.copyWith(isActionInProgress: false, services: services));
    } on Failure catch (f) {
      emit(state.copyWith(isActionInProgress: false, errorMessage: f.message));
    } catch (e) {
      emit(
        state.copyWith(
          isActionInProgress: false,
          errorMessage: AppStrings.unexpectedError,
        ),
      );
    }
  }

  String _normalizeError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('unique') ||
        lower.contains('constraint') ||
        lower.contains('duplicate')) {
      return AppStrings.duplicateNameError;
    }
    return message;
  }
}
