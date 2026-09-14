import '../../../../domain/entities/item_type.dart';
import '../../../../domain/entities/service.dart';

class ServicesManagementState {
  final List<Service> services;
  final List<ItemType> itemTypes;
  final bool isLoading;
  final bool isActionInProgress;
  final String? errorMessage;
  final String? actionSuccessMessage;

  const ServicesManagementState({
    this.services = const [],
    this.itemTypes = const [],
    this.isLoading = false,
    this.isActionInProgress = false,
    this.errorMessage,
    this.actionSuccessMessage,
  });

  ServicesManagementState copyWith({
    List<Service>? services,
    List<ItemType>? itemTypes,
    bool? isLoading,
    bool? isActionInProgress,
    String? errorMessage,
    String? actionSuccessMessage,
    bool clearErrorMessage = false,
    bool clearSuccessMessage = false,
  }) {
    return ServicesManagementState(
      services: services ?? this.services,
      itemTypes: itemTypes ?? this.itemTypes,
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
