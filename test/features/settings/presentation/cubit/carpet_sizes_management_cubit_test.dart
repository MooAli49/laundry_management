import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/core/localization/app_strings.dart';
import 'package:laundry_management/domain/entities/carpet_size.dart';
import 'package:laundry_management/domain/repositories/carpet_size_repository.dart';
import 'package:laundry_management/features/settings/presentation/cubit/carpet_sizes_management_cubit.dart';

class FakeCarpetSizeRepository implements CarpetSizeRepository {
  bool shouldThrow = false;
  final List<CarpetSize> sizes = [];

  @override
  Future<CarpetSize> createCarpetSize(CarpetSize carpetSize) async {
    if (shouldThrow) throw const DatabaseFailure('DB error');
    sizes.add(carpetSize);
    return carpetSize;
  }

  @override
  Future<CarpetSize> updateCarpetSize(CarpetSize carpetSize) async {
    if (shouldThrow) throw const DatabaseFailure('DB error');
    final idx = sizes.indexWhere((s) => s.id == carpetSize.id);
    if (idx != -1) sizes[idx] = carpetSize;
    return carpetSize;
  }

  @override
  Future<List<CarpetSize>> getAllCarpetSizes() async {
    if (shouldThrow) throw const DatabaseFailure('DB error');
    return List.from(sizes);
  }

  @override
  Future<List<CarpetSize>> getActiveCarpetSizes() async {
    return sizes.where((s) => s.isActive).toList();
  }

  @override
  Future<CarpetSize?> getCarpetSizeById(String id) async {
    final matches = sizes.where((s) => s.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<void> activateCarpetSize(String id) async {
    final idx = sizes.indexWhere((s) => s.id == id);
    if (idx != -1) sizes[idx] = sizes[idx].copyWith(isActive: true);
  }

  @override
  Future<void> deactivateCarpetSize(String id) async {
    final idx = sizes.indexWhere((s) => s.id == id);
    if (idx != -1) sizes[idx] = sizes[idx].copyWith(isActive: false);
  }
}

void main() {
  late FakeCarpetSizeRepository repository;
  late CarpetSizesManagementCubit cubit;

  setUp(() {
    repository = FakeCarpetSizeRepository();
    cubit = CarpetSizesManagementCubit(carpetSizeRepository: repository);
  });

  tearDown(() {
    cubit.close();
  });

  group('CarpetSizesManagementCubit Tests', () {
    test('validates length and width > 0', () async {
      // Length <= 0
      var res = await cubit.createCarpetSize(length: 0, width: 2.0);
      expect(res, isFalse);
      expect(cubit.state.errorMessage, AppStrings.carpetLengthRequired);

      // Width <= 0
      res = await cubit.createCarpetSize(length: 3.0, width: -1.0);
      expect(res, isFalse);
      expect(cubit.state.errorMessage, AppStrings.carpetWidthRequired);
    });

    test('createCarpetSize calculates area = length * width', () async {
      final res = await cubit.createCarpetSize(length: 3.0, width: 2.0);
      expect(res, isTrue);
      expect(cubit.state.carpetSizes.length, 1);
      final size = cubit.state.carpetSizes.first;
      expect(size.length, 3.0);
      expect(size.width, 2.0);
      expect(size.area, 6.0);
    });

    test('updateCarpetSize recalculates area', () async {
      await cubit.createCarpetSize(length: 3.0, width: 2.0);
      final size = cubit.state.carpetSizes.first;

      final updateRes = await cubit.updateCarpetSize(
        carpetSize: size.copyWith(length: 4.0, width: 3.0),
      );
      expect(updateRes, isTrue);
      final updated = cubit.state.carpetSizes.first;
      expect(updated.length, 4.0);
      expect(updated.width, 3.0);
      expect(updated.area, 12.0);
    });

    test('activate and deactivate carpet size', () async {
      await cubit.createCarpetSize(length: 2.0, width: 2.0);
      final id = cubit.state.carpetSizes.first.id;

      await cubit.deactivateCarpetSize(id);
      expect(cubit.state.carpetSizes.first.isActive, isFalse);

      await cubit.activateCarpetSize(id);
      expect(cubit.state.carpetSizes.first.isActive, isTrue);
    });
  });
}
