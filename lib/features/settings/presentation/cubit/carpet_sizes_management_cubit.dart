import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../domain/entities/carpet_size.dart';
import '../../../../domain/repositories/carpet_size_repository.dart';
import 'carpet_sizes_management_state.dart';

class CarpetSizesManagementCubit extends Cubit<CarpetSizesManagementState> {
  final CarpetSizeRepository _carpetSizeRepository;

  CarpetSizesManagementCubit({
    required CarpetSizeRepository carpetSizeRepository,
  }) : _carpetSizeRepository = carpetSizeRepository,
       super(const CarpetSizesManagementState());

  void clearMessages() {
    emit(state.copyWith(clearErrorMessage: true, clearSuccessMessage: true));
  }

  Future<void> loadCarpetSizes() async {
    emit(
      state.copyWith(
        isLoading: true,
        clearErrorMessage: true,
        clearSuccessMessage: true,
      ),
    );

    try {
      final carpetSizes = await _carpetSizeRepository.getAllCarpetSizes();
      emit(state.copyWith(isLoading: false, carpetSizes: carpetSizes));
    } on Failure catch (f) {
      emit(state.copyWith(isLoading: false, errorMessage: f.message));
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: AppStrings.unexpectedError,
        ),
      );
    }
  }

  Future<bool> createCarpetSize({
    required double length,
    required double width,
  }) async {
    if (length <= 0) {
      emit(state.copyWith(errorMessage: AppStrings.carpetLengthRequired));
      return false;
    }
    if (width <= 0) {
      emit(state.copyWith(errorMessage: AppStrings.carpetWidthRequired));
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
      final area = length * width;
      final carpetSize = CarpetSize(
        id: const Uuid().v4(),
        length: length,
        width: width,
        area: area,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      await _carpetSizeRepository.createCarpetSize(carpetSize);
      final carpetSizes = await _carpetSizeRepository.getAllCarpetSizes();
      emit(state.copyWith(isActionInProgress: false, carpetSizes: carpetSizes));
      return true;
    } on Failure catch (f) {
      emit(state.copyWith(isActionInProgress: false, errorMessage: f.message));
      return false;
    } catch (_) {
      emit(
        state.copyWith(
          isActionInProgress: false,
          errorMessage: AppStrings.unexpectedError,
        ),
      );
      return false;
    }
  }

  Future<bool> updateCarpetSize({required CarpetSize carpetSize}) async {
    if (carpetSize.length <= 0) {
      emit(state.copyWith(errorMessage: AppStrings.carpetLengthRequired));
      return false;
    }
    if (carpetSize.width <= 0) {
      emit(state.copyWith(errorMessage: AppStrings.carpetWidthRequired));
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
      final area = carpetSize.length * carpetSize.width;
      final updated = carpetSize.copyWith(
        area: area,
        updatedAt: DateTime.now(),
      );

      await _carpetSizeRepository.updateCarpetSize(updated);
      final carpetSizes = await _carpetSizeRepository.getAllCarpetSizes();
      emit(state.copyWith(isActionInProgress: false, carpetSizes: carpetSizes));
      return true;
    } on Failure catch (f) {
      emit(state.copyWith(isActionInProgress: false, errorMessage: f.message));
      return false;
    } catch (_) {
      emit(
        state.copyWith(
          isActionInProgress: false,
          errorMessage: AppStrings.unexpectedError,
        ),
      );
      return false;
    }
  }

  Future<void> activateCarpetSize(String id) async {
    emit(state.copyWith(isActionInProgress: true));
    try {
      await _carpetSizeRepository.activateCarpetSize(id);
      final carpetSizes = await _carpetSizeRepository.getAllCarpetSizes();
      emit(state.copyWith(isActionInProgress: false, carpetSizes: carpetSizes));
    } on Failure catch (f) {
      emit(state.copyWith(isActionInProgress: false, errorMessage: f.message));
    } catch (_) {
      emit(
        state.copyWith(
          isActionInProgress: false,
          errorMessage: AppStrings.unexpectedError,
        ),
      );
    }
  }

  Future<void> deactivateCarpetSize(String id) async {
    emit(state.copyWith(isActionInProgress: true));
    try {
      await _carpetSizeRepository.deactivateCarpetSize(id);
      final carpetSizes = await _carpetSizeRepository.getAllCarpetSizes();
      emit(state.copyWith(isActionInProgress: false, carpetSizes: carpetSizes));
    } on Failure catch (f) {
      emit(state.copyWith(isActionInProgress: false, errorMessage: f.message));
    } catch (_) {
      emit(
        state.copyWith(
          isActionInProgress: false,
          errorMessage: AppStrings.unexpectedError,
        ),
      );
    }
  }
}
