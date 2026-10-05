import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/core/localization/app_strings.dart';
import 'package:laundry_management/domain/entities/item_type.dart';
import 'package:laundry_management/domain/entities/storage_location.dart';
import 'package:laundry_management/domain/repositories/item_type_repository.dart';
import 'package:laundry_management/domain/repositories/storage_location_repository.dart';
import 'package:laundry_management/features/settings/presentation/cubit/storage_locations_management_cubit.dart';

class FakeStorageLocationRepository implements StorageLocationRepository {
  bool failDeactivationWithItems = false;
  final List<StorageLocation> locations = [];
  final Map<String, List<String>> supportedTypes = {};

  @override
  Future<StorageLocation> createStorageLocation(
    StorageLocation location, {
    required List<String> supportedItemTypeIds,
  }) async {
    locations.add(location);
    supportedTypes[location.id] = supportedItemTypeIds;
    return location;
  }

  @override
  Future<StorageLocation> updateStorageLocation(
    StorageLocation location, {
    List<String>? supportedItemTypeIds,
  }) async {
    final idx = locations.indexWhere((l) => l.id == location.id);
    if (idx != -1) locations[idx] = location;
    if (supportedItemTypeIds != null) {
      supportedTypes[location.id] = supportedItemTypeIds;
    }
    return location;
  }

  @override
  Future<List<StorageLocation>> getAllLocations() async {
    return List.from(locations);
  }

  @override
  Future<List<StorageLocation>> getActiveLocations() async {
    return locations.where((l) => l.isActive).toList();
  }

  @override
  Future<StorageLocation?> getStorageLocationById(String id) async {
    final matches = locations.where((l) => l.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<List<StorageLocation>> getCompatibleLocationsForItemType(
    String itemTypeId,
  ) async {
    return List.from(locations);
  }

  @override
  Future<void> activateStorageLocation(String id) async {
    final idx = locations.indexWhere((l) => l.id == id);
    if (idx != -1) locations[idx] = locations[idx].copyWith(isActive: true);
  }

  @override
  Future<void> deactivateStorageLocation(String id) async {
    if (failDeactivationWithItems) {
      throw const BusinessRuleFailure(
        'Cannot deactivate storage location while items are stored in it',
      );
    }
    final idx = locations.indexWhere((l) => l.id == id);
    if (idx != -1) locations[idx] = locations[idx].copyWith(isActive: false);
  }

  @override
  Future<List<String>> getSupportedItemTypeIds(String storageLocationId) async {
    return supportedTypes[storageLocationId] ?? [];
  }
}

class FakeItemTypeRepository implements ItemTypeRepository {
  final List<ItemType> itemTypes = [
    ItemType(
      id: 't-1',
      name: 'سجاد',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  @override
  Future<List<ItemType>> getActiveItemTypes() async => itemTypes;

  @override
  Future<List<ItemType>> getAllItemTypes() async => itemTypes;

  @override
  Future<ItemType> createItemType(ItemType itemType) async => itemType;

  @override
  Future<ItemType?> getItemTypeById(String id) async => null;

  @override
  Future<ItemType> updateItemType(ItemType itemType) async => itemType;

  @override
  Future<void> activateItemType(String id) async {}

  @override
  Future<void> deactivateItemType(String id) async {}
}

void main() {
  late FakeStorageLocationRepository storageRepo;
  late FakeItemTypeRepository itemTypeRepo;
  late StorageLocationsManagementCubit cubit;

  setUp(() {
    storageRepo = FakeStorageLocationRepository();
    itemTypeRepo = FakeItemTypeRepository();
    cubit = StorageLocationsManagementCubit(
      storageLocationRepository: storageRepo,
      itemTypeRepository: itemTypeRepo,
    );
  });

  tearDown(() {
    cubit.close();
  });

  group('StorageLocationsManagementCubit Tests', () {
    test('createStorageLocation with supported item types', () async {
      // Empty name fails
      var res = await cubit.createStorageLocation(
        name: '',
        supportedItemTypeIds: ['t-1'],
      );
      expect(res, isFalse);
      expect(cubit.state.errorMessage, AppStrings.storageLocationNameRequired);

      // Empty supported types fails
      res = await cubit.createStorageLocation(
        name: 'ستاند 1',
        supportedItemTypeIds: [],
      );
      expect(res, isFalse);
      expect(cubit.state.errorMessage, AppStrings.selectAtLeastOneItemType);

      // Successful create
      res = await cubit.createStorageLocation(
        name: 'ستاند سجاد A',
        supportedItemTypeIds: ['t-1'],
      );
      expect(res, isTrue);
      expect(cubit.state.locations.length, 1);
      expect(cubit.state.locations.first.name, 'ستاند سجاد A');
    });

    test(
      'updateStorageLocation updates name and supported item types',
      () async {
        await cubit.createStorageLocation(
          name: 'رف 1',
          supportedItemTypeIds: ['t-1'],
        );

        final loc = cubit.state.locations.first;
        final updateRes = await cubit.updateStorageLocation(
          location: loc.copyWith(name: 'رف A-1'),
          supportedItemTypeIds: ['t-1'],
        );
        expect(updateRes, isTrue);
        expect(cubit.state.locations.first.name, 'رف A-1');
      },
    );

    test(
      'deactivation failure when items are stored shows specific error',
      () async {
        await cubit.createStorageLocation(
          name: 'موقع به قطع',
          supportedItemTypeIds: ['t-1'],
        );
        final id = cubit.state.locations.first.id;

        storageRepo.failDeactivationWithItems = true;
        await cubit.deactivateStorageLocation(id);

        expect(
          cubit.state.errorMessage,
          AppStrings.storageLocationCannotDeactivateWithItems,
        );
        expect(cubit.state.locations.first.isActive, isTrue);
      },
    );
  });
}
