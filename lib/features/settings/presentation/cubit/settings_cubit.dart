import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../domain/repositories/settings_repository.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final SettingsRepository _settingsRepository;

  SettingsCubit({
    required SettingsRepository settingsRepository,
  })  : _settingsRepository = settingsRepository,
        super(const SettingsState());

  void selectTab(int index) {
    if (state.selectedTabIndex == index) return;
    emit(state.copyWith(
      selectedTabIndex: index,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    ));
  }

  void clearMessages() {
    emit(state.copyWith(
      clearErrorMessage: true,
      clearSuccessMessage: true,
    ));
  }

  Future<void> loadSettings() async {
    emit(state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    ));

    try {
      final settings = await _settingsRepository.getSettings();
      emit(state.copyWith(
        isLoading: false,
        settings: settings,
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

  Future<bool> updateBusinessInfo({
    required String businessName,
    String? phone,
    String? address,
    String? invoiceFooterText,
  }) async {
    final trimmedName = businessName.trim();
    if (trimmedName.isEmpty) {
      emit(state.copyWith(
        errorMessage: AppStrings.businessNameRequired,
      ));
      return false;
    }

    emit(state.copyWith(
      isSaving: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    ));

    try {
      final current = state.settings ?? await _settingsRepository.getSettings();
      final updated = current.copyWith(
        businessName: trimmedName,
        phone: phone?.trim().isEmpty == true ? null : phone?.trim(),
        address: address?.trim().isEmpty == true ? null : address?.trim(),
        invoiceFooterText: invoiceFooterText?.trim().isEmpty == true
            ? null
            : invoiceFooterText?.trim(),
        updatedAt: DateTime.now(),
      );

      final result = await _settingsRepository.updateSettings(updated);
      emit(state.copyWith(
        isSaving: false,
        settings: result,
        saveSuccessMessage: AppStrings.saveBusinessSettingsSuccess,
      ));
      return true;
    } on Failure catch (f) {
      emit(state.copyWith(
        isSaving: false,
        errorMessage: f.message,
      ));
      return false;
    } catch (e) {
      emit(state.copyWith(
        isSaving: false,
        errorMessage: AppStrings.unexpectedError,
      ));
      return false;
    }
  }
}
