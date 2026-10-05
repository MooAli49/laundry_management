import '../../../../domain/entities/business_settings.dart';

class SettingsState {
  final int selectedTabIndex;
  final BusinessSettings? settings;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final String? saveSuccessMessage;

  const SettingsState({
    this.selectedTabIndex = 0,
    this.settings,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.saveSuccessMessage,
  });

  SettingsState copyWith({
    int? selectedTabIndex,
    BusinessSettings? settings,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    String? saveSuccessMessage,
    bool clearErrorMessage = false,
    bool clearSuccessMessage = false,
  }) {
    return SettingsState(
      selectedTabIndex: selectedTabIndex ?? this.selectedTabIndex,
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      saveSuccessMessage: clearSuccessMessage
          ? null
          : (saveSuccessMessage ?? this.saveSuccessMessage),
    );
  }
}
