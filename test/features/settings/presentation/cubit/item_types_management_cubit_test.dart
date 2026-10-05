import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/core/localization/app_strings.dart';
import 'package:laundry_management/domain/entities/item_definition.dart';
import 'package:laundry_management/domain/entities/item_type.dart';
import 'package:laundry_management/domain/repositories/item_definition_repository.dart';
import 'package:laundry_management/domain/repositories/item_type_repository.dart';
import 'package:laundry_management/features/settings/presentation/cubit/item_types_management_cubit.dart';

class FakeItemTypeRepository implements ItemTypeRepository {
  bool shouldThrow = false;
  final List<ItemType> itemTypes = [];

  @override
  Future<ItemType> createItemType(ItemType itemType) async {
    if (shouldThrow) throw const DatabaseFailure('DB error');
    itemTypes.add(itemType);
    return itemType;
  }

  @override
  Future<ItemType> updateItemType(ItemType itemType) async {
    if (shouldThrow) throw const DatabaseFailure('DB error');
    final idx = itemTypes.indexWhere((t) => t.id == itemType.id);
    if (idx != -1) itemTypes[idx] = itemType;
    return itemType;
  }

  @override
  Future<List<ItemType>> getAllItemTypes() async {
    if (shouldThrow) throw const DatabaseFailure('DB error');
    return List.from(itemTypes);
  }

  @override
  Future<List<ItemType>> getActiveItemTypes() async {
    return itemTypes.where((t) => t.isActive).toList();
  }

  @override
  Future<ItemType?> getItemTypeById(String id) async {
    final matches = itemTypes.where((t) => t.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<void> activateItemType(String id) async {
    final idx = itemTypes.indexWhere((t) => t.id == id);
    if (idx != -1) itemTypes[idx] = itemTypes[idx].copyWith(isActive: true);
  }

  @override
  Future<void> deactivateItemType(String id) async {
    final idx = itemTypes.indexWhere((t) => t.id == id);
    if (idx != -1) itemTypes[idx] = itemTypes[idx].copyWith(isActive: false);
  }
}

class FakeItemDefinitionRepository implements ItemDefinitionRepository {
  bool shouldThrow = false;
  final List<ItemDefinition> definitions = [];

  @override
  Future<ItemDefinition> createItemDefinition(ItemDefinition def) async {
    if (shouldThrow) throw const DatabaseFailure('DB error');
    definitions.add(def);
    return def;
  }

  @override
  Future<ItemDefinition> updateItemDefinition(ItemDefinition def) async {
    if (shouldThrow) throw const DatabaseFailure('DB error');
    final idx = definitions.indexWhere((d) => d.id == def.id);
    if (idx != -1) definitions[idx] = def;
    return def;
  }

  @override
  Future<List<ItemDefinition>> getAllDefinitions() async {
    return List.from(definitions);
  }

  @override
  Future<List<ItemDefinition>> getDefinitionsForItemType(
    String itemTypeId, {
    bool activeOnly = true,
  }) async {
    return definitions
        .where((d) => d.itemTypeId == itemTypeId && (!activeOnly || d.isActive))
        .toList();
  }

  @override
  Future<ItemDefinition?> getItemDefinitionById(String id) async {
    final matches = definitions.where((d) => d.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<void> activateItemDefinition(String id) async {
    final idx = definitions.indexWhere((d) => d.id == id);
    if (idx != -1) definitions[idx] = definitions[idx].copyWith(isActive: true);
  }

  @override
  Future<void> deactivateItemDefinition(String id) async {
    final idx = definitions.indexWhere((d) => d.id == id);
    if (idx != -1) {
      definitions[idx] = definitions[idx].copyWith(isActive: false);
    }
  }
}

void main() {
  late FakeItemTypeRepository itemTypeRepo;
  late FakeItemDefinitionRepository defRepo;
  late ItemTypesManagementCubit cubit;

  setUp(() {
    itemTypeRepo = FakeItemTypeRepository();
    defRepo = FakeItemDefinitionRepository();
    cubit = ItemTypesManagementCubit(
      itemTypeRepository: itemTypeRepo,
      itemDefinitionRepository: defRepo,
    );
  });

  tearDown(() {
    cubit.close();
  });

  group('ItemTypesManagementCubit Tests', () {
    test('createItemType and updateItemType work correctly', () async {
      // Empty name fails
      final failRes = await cubit.createItemType('');
      expect(failRes, isFalse);
      expect(cubit.state.errorMessage, AppStrings.itemTypeNameRequired);

      // Successful create
      final createRes = await cubit.createItemType('ملابس');
      expect(createRes, isTrue);
      expect(cubit.state.itemTypes.length, 1);
      expect(cubit.state.itemTypes.first.name, 'ملابس');

      // Update
      final type = cubit.state.itemTypes.first;
      final updateRes = await cubit.updateItemType(
        type.copyWith(name: 'ملابس وأقمشة'),
      );
      expect(updateRes, isTrue);
      expect(cubit.state.itemTypes.first.name, 'ملابس وأقمشة');
    });

    test('activate and deactivate item type', () async {
      await cubit.createItemType('مفروشات');
      final id = cubit.state.itemTypes.first.id;

      await cubit.deactivateItemType(id);
      expect(cubit.state.itemTypes.first.isActive, isFalse);

      await cubit.activateItemType(id);
      expect(cubit.state.itemTypes.first.isActive, isTrue);
    });

    test(
      'definitions handling: create, update, filter, activate, deactivate',
      () async {
        await cubit.createItemType('ملابس');
        final typeId = cubit.state.itemTypes.first.id;

        // Create definition
        final defRes = await cubit.createItemDefinition(
          itemTypeId: typeId,
          name: 'قميص',
        );
        expect(defRes, isTrue);
        expect(cubit.state.definitions.length, 1);
        expect(cubit.state.definitions.first.name, 'قميص');

        // Filter
        cubit.selectFilterItemType(typeId);
        expect(cubit.state.filteredDefinitions.length, 1);

        cubit.selectFilterItemType('other-id');
        expect(cubit.state.filteredDefinitions.length, 0);

        cubit.selectFilterItemType(null);
        expect(cubit.state.filteredDefinitions.length, 1);

        // Update definition
        final def = cubit.state.definitions.first;
        await cubit.updateItemDefinition(def.copyWith(name: 'قميص رجالي'));
        expect(cubit.state.definitions.first.name, 'قميص رجالي');

        // Deactivate & activate definition
        final defId = cubit.state.definitions.first.id;
        await cubit.deactivateItemDefinition(defId);
        expect(cubit.state.definitions.first.isActive, isFalse);

        await cubit.activateItemDefinition(defId);
        expect(cubit.state.definitions.first.isActive, isTrue);
      },
    );
  });
}
