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
    required PricingType pricingType,
    required Money price,
    required List<String> supportedItemTypeIds,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      emit(state.copyWith(errorMessage: AppStrings.serviceNameRequired));
      return false;
    }
    if (price <= Money.zero) {
      emit(state.copyWith(errorMessage: AppStrings.servicePriceMustBePositive));
      return false;
    }
    if (supportedItemTypeIds.isEmpty) {
      emit(state.copyWith(errorMessage: AppStrings.selectAtLeastOneItemType));
      return false;
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
      final service = Service(
        id: const Uuid().v4(),
        name: trimmedName,
        description: description?.trim().isEmpty == true
            ? null
            : description?.trim(),
        pricingType: pricingType,
        price: price,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      await _serviceRepository.createService(
        service,
        supportedItemTypeIds: supportedItemTypeIds,
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
    required List<String> supportedItemTypeIds,
  }) async {
    final trimmedName = service.name.trim();
    if (trimmedName.isEmpty) {
      emit(state.copyWith(errorMessage: AppStrings.serviceNameRequired));
      return false;
    }
    if (service.price <= Money.zero) {
      emit(state.copyWith(errorMessage: AppStrings.servicePriceMustBePositive));
      return false;
    }
    if (supportedItemTypeIds.isEmpty) {
      emit(state.copyWith(errorMessage: AppStrings.selectAtLeastOneItemType));
      return false;
    }

    emit(
      state.copyWith(
        isActionInProgress: true,
        clearErrorMessage: true,
        clearSuccessMessage: true,
      ),
    );

    try {
      final updated = service.copyWith(
        name: trimmedName,
        updatedAt: DateTime.now(),
      );

      await _serviceRepository.updateService(
        updated,
        supportedItemTypeIds: supportedItemTypeIds,
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
