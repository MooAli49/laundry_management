import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/localization/app_strings.dart';
import 'package:laundry_management/domain/entities/item_type.dart';
import 'package:laundry_management/domain/entities/storage_location.dart';
import 'package:laundry_management/domain/repositories/item_type_repository.dart';
import 'package:laundry_management/domain/repositories/storage_location_repository.dart';
import 'package:laundry_management/features/settings/presentation/cubit/storage_locations_management_cubit.dart';
import 'package:laundry_management/features/settings/presentation/widgets/storage_location_form_dialog.dart';

class MockStorageLocationRepo implements StorageLocationRepository {
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
  }) async =>
      location;

  @override
  Future<List<StorageLocation>> getAllLocations() async => locations;

  @override
  Future<List<StorageLocation>> getActiveLocations() async => locations;

  @override
  Future<StorageLocation?> getStorageLocationById(String id) async => null;

  @override
  Future<List<StorageLocation>> getCompatibleLocationsForItemType(String itemTypeId) async =>
      locations;

  @override
  Future<List<String>> getSupportedItemTypeIds(String storageLocationId) async =>
      supportedTypes[storageLocationId] ?? [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockItemTypeRepo implements ItemTypeRepository {
  final List<ItemType> types = [
    ItemType(
      id: 't-1',
      name: 'ملابس',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    ItemType(
      id: 't-2',
      name: 'سجاد',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  @override
  Future<List<ItemType>> getActiveItemTypes() async => types;
  @override
  Future<List<ItemType>> getAllItemTypes({bool activeOnly = false}) async => types;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockStorageLocationRepo locationRepo;
  late MockItemTypeRepo itemTypeRepo;
  late StorageLocationsManagementCubit cubit;

  setUp(() {
    locationRepo = MockStorageLocationRepo();
    itemTypeRepo = MockItemTypeRepo();
    cubit = StorageLocationsManagementCubit(
      storageLocationRepository: locationRepo,
      itemTypeRepository: itemTypeRepo,
    );
  });

  tearDown(() {
    cubit.close();
  });

  Widget buildDialog({List<String> initialSupportedTypeIds = const []}) {
    return MaterialApp(
      locale: const Locale('ar'),
      home: Scaffold(
        body: Center(
          child: BlocProvider.value(
            value: cubit,
            child: StorageLocationFormDialog(
              availableItemTypes: itemTypeRepo.types,
              initialSupportedTypeIds: initialSupportedTypeIds,
            ),
          ),
        ),
      ),
    );
  }

  group('UAT-C — StorageLocationFormDialog Widget Tests', () {
    testWidgets('renders compactly and fits content without occupying 680px', (tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.pumpAndSettle();

      final contentFinder = find.byType(SingleChildScrollView);
      expect(contentFinder, findsOneWidget);

      final contentSize = tester.getSize(contentFinder);
      // Content wraps naturally, well under previous 680px constraint
      expect(contentSize.height, lessThan(550));
      expect(contentSize.width, lessThanOrEqualTo(480));
    });

    testWidgets('checkboxes/chips and fields remain fully accessible', (tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.addStorageLocation), findsOneWidget);
      expect(find.text(AppStrings.storageLocationNameLabel), findsOneWidget);
      expect(find.text('ملابس'), findsOneWidget);
      expect(find.text('سجاد'), findsOneWidget);
      expect(find.text(AppStrings.save), findsOneWidget);
      expect(find.text(AppStrings.cancel), findsOneWidget);
    });

    testWidgets('rejects empty name on submit', (tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.save));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.storageLocationNameRequired), findsOneWidget);
    });

    testWidgets('rejects when no supported item types selected', (tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.pumpAndSettle();

      final nameField = find.widgetWithText(TextFormField, '');
      await tester.enterText(nameField, 'موقع تجريبي');

      await tester.tap(find.text(AppStrings.save));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.selectAtLeastOneItemType), findsOneWidget);
    });

    testWidgets('submits successfully with valid data', (tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.pumpAndSettle();

      final nameField = find.widgetWithText(TextFormField, '');
      await tester.enterText(nameField, 'موقع تجريبي');

      // Select 'ملابس'
      await tester.tap(find.text('ملابس'));
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text(AppStrings.save));
      await tester.pumpAndSettle();

      expect(locationRepo.locations.length, 1);
      expect(locationRepo.locations.first.name, 'موقع تجريبي');
      expect(locationRepo.supportedTypes[locationRepo.locations.first.id], ['t-1']);
    });
  });
}
