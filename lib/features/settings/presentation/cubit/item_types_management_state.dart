import '../../../../domain/entities/item_definition.dart';
import '../../../../domain/entities/item_type.dart';

class ItemTypesManagementState {
  final List<ItemType> itemTypes;
  final List<ItemDefinition> definitions;
  final String? selectedFilterItemTypeId;
  final bool isLoading;
  final bool isActionInProgress;
  final String? errorMessage;
  final String? actionSuccessMessage;

  const ItemTypesManagementState({
    this.itemTypes = const [],
    this.definitions = const [],
    this.selectedFilterItemTypeId,
    this.isLoading = false,
    this.isActionInProgress = false,
    this.errorMessage,
    this.actionSuccessMessage,
  });

  List<ItemDefinition> get filteredDefinitions {
    if (selectedFilterItemTypeId == null || selectedFilterItemTypeId!.isEmpty) {
      return definitions;
    }
    return definitions
        .where((d) => d.itemTypeId == selectedFilterItemTypeId)
        .toList();
  }

  int getDefinitionCountForType(String itemTypeId) {
    return definitions.where((d) => d.itemTypeId == itemTypeId).length;
  }

  ItemTypesManagementState copyWith({
    List<ItemType>? itemTypes,
    List<ItemDefinition>? definitions,
    String? selectedFilterItemTypeId,
    bool clearFilterItemType = false,
    bool? isLoading,
    bool? isActionInProgress,
    String? errorMessage,
    String? actionSuccessMessage,
    bool clearErrorMessage = false,
    bool clearSuccessMessage = false,
  }) {
    return ItemTypesManagementState(
      itemTypes: itemTypes ?? this.itemTypes,
      definitions: definitions ?? this.definitions,
      selectedFilterItemTypeId: clearFilterItemType
          ? null
          : (selectedFilterItemTypeId ?? this.selectedFilterItemTypeId),
      isLoading: isLoading ?? this.isLoading,
      isActionInProgress: isActionInProgress ?? this.isActionInProgress,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      actionSuccessMessage: clearSuccessMessage
          ? null
          : (actionSuccessMessage ?? this.actionSuccessMessage),
    );
  }
}
