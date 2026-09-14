import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../domain/entities/item_definition.dart';
import '../../../../domain/entities/item_type.dart';
import '../../../../domain/repositories/item_definition_repository.dart';
import '../../../../domain/repositories/item_type_repository.dart';
import 'item_types_management_state.dart';

class ItemTypesManagementCubit extends Cubit<ItemTypesManagementState> {
  final ItemTypeRepository _itemTypeRepository;
  final ItemDefinitionRepository _itemDefinitionRepository;

  ItemTypesManagementCubit({
    required ItemTypeRepository itemTypeRepository,
    required ItemDefinitionRepository itemDefinitionRepository,
  })  : _itemTypeRepository = itemTypeRepository,
        _itemDefinitionRepository = itemDefinitionRepository,
        super(const ItemTypesManagementState());

  void clearMessages() {
    emit(state.copyWith(
      clearErrorMessage: true,
      clearSuccessMessage: true,
    ));
  }

  void selectFilterItemType(String? itemTypeId) {
    if (itemTypeId == null || itemTypeId.isEmpty) {
      emit(state.copyWith(clearFilterItemType: true));
    } else {
      emit(state.copyWith(selectedFilterItemTypeId: itemTypeId));
    }
  }

  Future<void> loadData() async {
    emit(state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    ));

    try {
      final types = await _itemTypeRepository.getAllItemTypes();
      final definitions = await _itemDefinitionRepository.getAllDefinitions();
      emit(state.copyWith(
        isLoading: false,
        itemTypes: types,
        definitions: definitions,
      ));
    } on Failure catch (f) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: f.message,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: AppStrings.unexpectedError,
      ));
    }
  }

  // --- Item Types CRUD ---

  Future<bool> createItemType(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      emit(state.copyWith(errorMessage: AppStrings.itemTypeNameRequired));
      return false;
    }

    emit(state.copyWith(
      isActionInProgress: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    ));

    try {
      final now = DateTime.now();
      final itemType = ItemType(
        id: const Uuid().v4(),
        name: trimmed,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      await _itemTypeRepository.createItemType(itemType);
      final types = await _itemTypeRepository.getAllItemTypes();
      emit(state.copyWith(
        isActionInProgress: false,
        itemTypes: types,
      ));
      return true;
    } on Failure catch (f) {
      emit(state.copyWith(
        isActionInProgress: false,
        errorMessage: _normalizeError(f.message),
      ));
      return false;
    } catch (e) {
      emit(state.copyWith(
        isActionInProgress: false,
        errorMessage: AppStrings.unexpectedError,
      ));
      return false;
    }
  }

  Future<bool> updateItemType(ItemType itemType) async {
    final trimmed = itemType.name.trim();
    if (trimmed.isEmpty) {
      emit(state.copyWith(errorMessage: AppStrings.itemTypeNameRequired));
      return false;
    }

    emit(state.copyWith(
      isActionInProgress: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    ));

    try {
      final updated = itemType.copyWith(
        name: trimmed,
        updatedAt: DateTime.now(),
      );

      await _itemTypeRepository.updateItemType(updated);
      final types = await _itemTypeRepository.getAllItemTypes();
      emit(state.copyWith(
        isActionInProgress: false,
        itemTypes: types,
      ));
      return true;
    } on Failure catch (f) {
      emit(state.copyWith(
        isActionInProgress: false,
        errorMessage: _normalizeError(f.message),
      ));
      return false;
    } catch (e) {
      emit(state.copyWith(
        isActionInProgress: false,
        errorMessage: AppStrings.unexpectedError,
      ));
      return false;
    }
  }

  Future<void> activateItemType(String id) async {
    emit(state.copyWith(isActionInProgress: true));
    try {
      await _itemTypeRepository.activateItemType(id);
      final types = await _itemTypeRepository.getAllItemTypes();
      emit(state.copyWith(
        isActionInProgress: false,
        itemTypes: types,
      ));
    } on Failure catch (f) {
      emit(state.copyWith(
        isActionInProgress: false,
        errorMessage: f.message,
      ));
    } catch (e) {
      emit(state.copyWith(
        isActionInProgress: false,
        errorMessage: AppStrings.unexpectedError,
      ));
    }
  }

  Future<void> deactivateItemType(String id) async {
    emit(state.copyWith(isActionInProgress: true));
    try {
      await _itemTypeRepository.deactivateItemType(id);
      final types = await _itemTypeRepository.getAllItemTypes();
      emit(state.copyWith(
        isActionInProgress: false,
        itemTypes: types,
      ));
    } on Failure catch (f) {
      emit(state.copyWith(
        isActionInProgress: false,
        errorMessage: f.message,
      ));
    } catch (e) {
      emit(state.copyWith(
        isActionInProgress: false,
        errorMessage: AppStrings.unexpectedError,
      ));
    }
  }

  // --- Item Definitions CRUD ---

  Future<bool> createItemDefinition({
    required String itemTypeId,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      emit(state.copyWith(errorMessage: AppStrings.itemDefinitionNameRequired));
      return false;
    }

    emit(state.copyWith(
      isActionInProgress: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    ));

    try {
      final now = DateTime.now();
      final def = ItemDefinition(
        id: const Uuid().v4(),
        itemTypeId: itemTypeId,
        name: trimmed,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      await _itemDefinitionRepository.createItemDefinition(def);
      final definitions = await _itemDefinitionRepository.getAllDefinitions();
      emit(state.copyWith(
        isActionInProgress: false,
        definitions: definitions,
      ));
      return true;
    } on Failure catch (f) {
      emit(state.copyWith(
        isActionInProgress: false,
        errorMessage: _normalizeError(f.message),
      ));
      return false;
    } catch (e) {
      emit(state.copyWith(
        isActionInProgress: false,
        errorMessage: AppStrings.unexpectedError,
      ));
      return false;
    }
  }

  Future<bool> updateItemDefinition(ItemDefinition def) async {
    final trimmed = def.name.trim();
    if (trimmed.isEmpty) {
      emit(state.copyWith(errorMessage: AppStrings.itemDefinitionNameRequired));
      return false;
    }

    emit(state.copyWith(
      isActionInProgress: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    ));

    try {
      final updated = def.copyWith(
        name: trimmed,
        updatedAt: DateTime.now(),
      );

      await _itemDefinitionRepository.updateItemDefinition(updated);
      final definitions = await _itemDefinitionRepository.getAllDefinitions();
      emit(state.copyWith(
        isActionInProgress: false,
        definitions: definitions,
      ));
      return true;
    } on Failure catch (f) {
      emit(state.copyWith(
        isActionInProgress: false,
        errorMessage: _normalizeError(f.message),
      ));
      return false;
    } catch (e) {
      emit(state.copyWith(
        isActionInProgress: false,
        errorMessage: AppStrings.unexpectedError,
      ));
      return false;
    }
  }

  Future<void> activateItemDefinition(String id) async {
    emit(state.copyWith(isActionInProgress: true));
    try {
      await _itemDefinitionRepository.activateItemDefinition(id);
      final definitions = await _itemDefinitionRepository.getAllDefinitions();
      emit(state.copyWith(
        isActionInProgress: false,
        definitions: definitions,
      ));
    } on Failure catch (f) {
      emit(state.copyWith(
        isActionInProgress: false,
        errorMessage: f.message,
      ));
    } catch (e) {
      emit(state.copyWith(
        isActionInProgress: false,
        errorMessage: AppStrings.unexpectedError,
      ));
    }
  }

  Future<void> deactivateItemDefinition(String id) async {
    emit(state.copyWith(isActionInProgress: true));
    try {
      await _itemDefinitionRepository.deactivateItemDefinition(id);
      final definitions = await _itemDefinitionRepository.getAllDefinitions();
      emit(state.copyWith(
        isActionInProgress: false,
        definitions: definitions,
      ));
    } on Failure catch (f) {
      emit(state.copyWith(
        isActionInProgress: false,
        errorMessage: f.message,
      ));
    } catch (e) {
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
