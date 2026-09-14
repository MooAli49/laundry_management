import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../domain/entities/storage_location.dart';
import '../../../../domain/repositories/item_type_repository.dart';
import '../../../../domain/repositories/storage_location_repository.dart';
import 'storage_locations_management_state.dart';

class StorageLocationsManagementCubit extends Cubit<StorageLocationsManagementState> {
  final StorageLocationRepository _storageLocationRepository;
  final ItemTypeRepository _itemTypeRepository;

  StorageLocationsManagementCubit({
    required StorageLocationRepository storageLocationRepository,
    required ItemTypeRepository itemTypeRepository,
  })  : _storageLocationRepository = storageLocationRepository,
        _itemTypeRepository = itemTypeRepository,
        super(const StorageLocationsManagementState());

  void clearMessages() {
    emit(state.copyWith(
      clearErrorMessage: true,
      clearSuccessMessage: true,
    ));
  }

  Future<void> loadLocations() async {
    emit(state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    ));

    try {
      final locations = await _storageLocationRepository.getAllLocations();
      final itemTypes = await _itemTypeRepository.getActiveItemTypes();
      emit(state.copyWith(
        isLoading: false,
        locations: locations,
        itemTypes: itemTypes,
      ));
    } on Failure catch (f) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: f.message,
      ));
    } catch (_) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: AppStrings.unexpectedError,
      ));
    }
  }

  Future<List<String>> getSupportedItemTypeIds(String storageLocationId) async {
    try {
      return await _storageLocationRepository.getSupportedItemTypeIds(storageLocationId);
    } catch (_) {
      return [];
    }
  }

  Future<bool> createStorageLocation({
    required String name,
    required List<String> supportedItemTypeIds,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      emit(state.copyWith(errorMessage: AppStrings.storageLocationNameRequired));
      return false;
    }
    if (supportedItemTypeIds.isEmpty) {
      emit(state.copyWith(errorMessage: AppStrings.selectAtLeastOneItemType));
      return false;
    }

    emit(state.copyWith(
      isActionInProgress: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    ));

    try {
      final now = DateTime.now();
      final location = StorageLocation(
        id: const Uuid().v4(),
        name: trimmedName,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      await _storageLocationRepository.createStorageLocation(
        location,
        supportedItemTypeIds: supportedItemTypeIds,
      );

      final locations = await _storageLocationRepository.getAllLocations();
      emit(state.copyWith(
        isActionInProgress: false,
        locations: locations,
      ));
      return true;
    } on Failure catch (f) {
      final msg = _normalizeError(f.message);
      emit(state.copyWith(
        isActionInProgress: false,
        errorMessage: msg,
      ));
      return false;
    } catch (_) {
      emit(state.copyWith(
        isActionInProgress: false,
        errorMessage: AppStrings.unexpectedError,
      ));
      return false;
    }
  }

  Future<bool> updateStorageLocation({
    required StorageLocation location,
    required List<String> supportedItemTypeIds,
  }) async {
    final trimmedName = location.name.trim();
    if (trimmedName.isEmpty) {
      emit(state.copyWith(errorMessage: AppStrings.storageLocationNameRequired));
      return false;
    }
    if (supportedItemTypeIds.isEmpty) {
      emit(state.copyWith(errorMessage: AppStrings.selectAtLeastOneItemType));
      return false;
    }

    emit(state.copyWith(
      isActionInProgress: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    ));

    try {
      final updated = location.copyWith(
        name: trimmedName,
        updatedAt: DateTime.now(),
      );

      await _storageLocationRepository.updateStorageLocation(
        updated,
        supportedItemTypeIds: supportedItemTypeIds,
      );

      final locations = await _storageLocationRepository.getAllLocations();
      emit(state.copyWith(
        isActionInProgress: false,
        locations: locations,
      ));
      return true;
    } on Failure catch (f) {
      final msg = _normalizeError(f.message);
      emit(state.copyWith(
        isActionInProgress: false,
        errorMessage: msg,
      ));
      return false;
    } catch (_) {
      emit(state.copyWith(
        isActionInProgress: false,
        errorMessage: AppStrings.unexpectedError,
      ));
      return false;
    }
  }

  Future<void> activateStorageLocation(String id) async {
    emit(state.copyWith(isActionInProgress: true));
    try {
      await _storageLocationRepository.activateStorageLocation(id);
      final locations = await _storageLocationRepository.getAllLocations();
      emit(state.copyWith(
        isActionInProgress: false,
        locations: locations,
      ));
    } on Failure catch (f) {
      emit(state.copyWith(
        isActionInProgress: false,
        errorMessage: f.message,
      ));
    } catch (_) {
      emit(state.copyWith(
        isActionInProgress: false,
        errorMessage: AppStrings.unexpectedError,
      ));
    }
  }

  Future<void> deactivateStorageLocation(String id) async {
    emit(state.copyWith(isActionInProgress: true));
    try {
      await _storageLocationRepository.deactivateStorageLocation(id);
      final locations = await _storageLocationRepository.getAllLocations();
      emit(state.copyWith(
        isActionInProgress: false,
        locations: locations,
      ));
    } on Failure catch (f) {
      String msg = f.message;
      if (f is BusinessRuleFailure ||
          msg.contains('Cannot deactivate storage location while items are stored in it') ||
          msg.contains('stored')) {
        msg = AppStrings.storageLocationCannotDeactivateWithItems;
      }
      emit(state.copyWith(
        isActionInProgress: false,
        errorMessage: msg,
      ));
    } catch (_) {
      emit(state.copyWith(
        isActionInProgress: false,
        errorMessage: AppStrings.unexpectedError,
      ));
    }
  }

  String _normalizeError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('unique') || lower.contains('constraint') || lower.contains('duplicate')) {
      return AppStrings.duplicateNameError;
    }
    return message;
  }
}
