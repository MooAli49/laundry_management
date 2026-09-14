import '../../../../domain/entities/carpet_size.dart';

class CarpetSizesManagementState {
  final List<CarpetSize> carpetSizes;
  final bool isLoading;
  final bool isActionInProgress;
  final String? errorMessage;
  final String? actionSuccessMessage;

  const CarpetSizesManagementState({
    this.carpetSizes = const [],
    this.isLoading = false,
    this.isActionInProgress = false,
    this.errorMessage,
    this.actionSuccessMessage,
  });

  CarpetSizesManagementState copyWith({
    List<CarpetSize>? carpetSizes,
    bool? isLoading,
    bool? isActionInProgress,
    String? errorMessage,
    String? actionSuccessMessage,
    bool clearErrorMessage = false,
    bool clearSuccessMessage = false,
  }) {
    return CarpetSizesManagementState(
      carpetSizes: carpetSizes ?? this.carpetSizes,
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
