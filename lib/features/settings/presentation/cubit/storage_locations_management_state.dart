import '../../../../domain/entities/item_type.dart';
import '../../../../domain/entities/storage_location.dart';

class StorageLocationsManagementState {
  final List<StorageLocation> locations;
  final List<ItemType> itemTypes;
  final bool isLoading;
  final bool isActionInProgress;
  final String? errorMessage;
  final String? actionSuccessMessage;

  const StorageLocationsManagementState({
    this.locations = const [],
    this.itemTypes = const [],
    this.isLoading = false,
    this.isActionInProgress = false,
    this.errorMessage,
    this.actionSuccessMessage,
  });

  StorageLocationsManagementState copyWith({
    List<StorageLocation>? locations,
    List<ItemType>? itemTypes,
    bool? isLoading,
    bool? isActionInProgress,
    String? errorMessage,
    String? actionSuccessMessage,
    bool clearErrorMessage = false,
    bool clearSuccessMessage = false,
  }) {
    return StorageLocationsManagementState(
      locations: locations ?? this.locations,
      itemTypes: itemTypes ?? this.itemTypes,
      isLoading: isLoading ?? this.isLoading,
      isActionInProgress: isActionInProgress ?? this.isActionInProgress,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      actionSuccessMessage: clearSuccessMessage
          ? null
          : (actionSuccessMessage ?? this.actionSuccessMessage),
    );
  }
}
