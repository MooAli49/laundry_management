import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/di/injection.dart';
import 'package:laundry_management/core/localization/app_strings.dart';
import 'package:laundry_management/core/theme/app_theme.dart';
import 'package:laundry_management/data/local/database/app_database.dart' as db_pkg;
import 'package:laundry_management/data/local/database/dev_test_data.dart';
import 'package:laundry_management/domain/entities/storage_location.dart';
import 'package:laundry_management/domain/repositories/storage_location_repository.dart';
import 'package:laundry_management/domain/repositories/storage_repository.dart';
import 'package:laundry_management/features/storage/presentation/screens/storage_screen.dart';
import 'package:laundry_management/features/storage/presentation/widgets/bulk_storage_bottom_bar.dart';
import 'package:laundry_management/features/storage/presentation/widgets/move_storage_dialog.dart';
import 'package:laundry_management/features/storage/presentation/widgets/storage_filter_bar.dart';
import 'package:laundry_management/features/storage/presentation/widgets/storage_item_card.dart';
import 'package:laundry_management/features/storage/presentation/widgets/store_storage_dialog.dart';
import 'package:laundry_management/features/storage/presentation/widgets/unstore_confirm_dialog.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  late db_pkg.AppDatabase db;

  setUp(() async {
    await getIt.reset();
    db = db_pkg.AppDatabase(NativeDatabase.memory());
    await DevTestData.seedDevData(db);

    getIt.registerLazySingleton<db_pkg.AppDatabase>(() => db);
    await initDependencies();
  });

  tearDown(() async {
    if (getIt.isRegistered<db_pkg.AppDatabase>()) {
      await getIt<db_pkg.AppDatabase>().close();
    }
    await getIt.reset();
  });

  group('StorageScreen Widget Tests', () {
    testWidgets('44. Renders header, tab switcher, search field, and filter bar', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const StorageScreen()));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.storage), findsOneWidget);
      expect(find.text(AppStrings.itemsRequiringStorage), findsOneWidget);
      expect(find.text(AppStrings.currentStorage), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(StorageFilterBar), findsOneWidget);
      expect(find.byType(StorageItemCard), findsWidgets);
    });

    testWidgets('45. Items requiring storage tab lists unstored items with store action', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const StorageScreen()));
      await tester.pumpAndSettle();

      // Should show cards with store button
      final storeButtons = find.text(AppStrings.storeAction);
      expect(storeButtons, findsWidgets);

      // Checkboxes exist for bulk selection
      expect(find.byType(Checkbox), findsWidgets);
    });

    testWidgets('46. Selecting item checkbox displays BulkStorageBottomBar', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const StorageScreen()));
      await tester.pumpAndSettle();

      // Initially no bottom bar
      expect(find.byType(BulkStorageBottomBar), findsNothing);

      // Tap first checkbox
      final firstCheckbox = find.byType(Checkbox).first;
      await tester.tap(firstCheckbox);
      await tester.pumpAndSettle();

      // Bottom bar should now be visible
      expect(find.byType(BulkStorageBottomBar), findsOneWidget);
      expect(find.text(AppStrings.storeItemsAction), findsOneWidget);
    });

    testWidgets('47. Tapping store opens StoreStorageDialog and stores item', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const StorageScreen()));
      await tester.pumpAndSettle();

      // Tap store button on first item card
      final firstStoreButton = find.text(AppStrings.storeAction).first;
      await tester.tap(firstStoreButton);
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.byType(StoreStorageDialog), findsOneWidget);
      expect(find.text(AppStrings.confirmStore), findsOneWidget);

      // Choose a location from dropdown
      final locationRepo = getIt<StorageLocationRepository>();
      final allLocs = await locationRepo.getAllLocations();
      final targetLoc = allLocs.first;

      await tester.tap(find.byType(DropdownButtonFormField<StorageLocation>));
      await tester.pumpAndSettle();

      await tester.tap(find.text(targetLoc.name).last);
      await tester.pumpAndSettle();

      // Tap confirm button
      await tester.tap(find.text(AppStrings.confirmStore));
      await tester.pumpAndSettle();

      // Dialog should close
      expect(find.byType(StoreStorageDialog), findsNothing);
    });

    testWidgets('48. Switch to Current Storage tab displays stored items with move & unstore buttons', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Store an item first in the repository
      final storageRepo = getIt<StorageRepository>();
      final locationRepo = getIt<StorageLocationRepository>();
      final unstored = await storageRepo.getItemsRequiringStorageWithDetails(limit: 1, offset: 0);
      expect(unstored, isNotEmpty);

      final item = unstored.first;
      final locations = await locationRepo.getCompatibleLocationsForItemType(item.orderItem.itemTypeId);
      await storageRepo.storeItem(
        orderItemId: item.orderItem.id,
        storageLocationId: locations.first.id,
      );

      await tester.pumpWidget(createTestApp(const StorageScreen()));
      await tester.pumpAndSettle();

      // Switch tab to Current Storage
      await tester.tap(find.text(AppStrings.currentStorage));
      await tester.pumpAndSettle();

      // Should show the stored item with move and more options menu
      expect(find.text(AppStrings.moveAction), findsWidgets);
      expect(find.byIcon(Icons.more_vert), findsWidgets);
      expect(find.textContaining(locations.first.name), findsWidgets);
    });

    testWidgets('49. Current Storage tab: Move dialog opens and moves item', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Store an item in loc-1
      final storageRepo = getIt<StorageRepository>();
      final locationRepo = getIt<StorageLocationRepository>();
      final unstored = await storageRepo.getItemsRequiringStorageWithDetails(limit: 1, offset: 0);
      final item = unstored.first;
      final locations = await locationRepo.getCompatibleLocationsForItemType(item.orderItem.itemTypeId);
      expect(locations.length, greaterThanOrEqualTo(2));
      final sourceLoc = locations[0];
      final destLoc = locations[1];

      await storageRepo.storeItem(
        orderItemId: item.orderItem.id,
        storageLocationId: sourceLoc.id,
      );

      await tester.pumpWidget(createTestApp(const StorageScreen()));
      await tester.pumpAndSettle();

      // Switch to Current Storage
      await tester.tap(find.text(AppStrings.currentStorage));
      await tester.pumpAndSettle();

      // Tap Move button
      await tester.tap(find.text(AppStrings.moveAction).first);
      await tester.pumpAndSettle();

      // Move dialog opens
      expect(find.byType(MoveStorageDialog), findsOneWidget);
      expect(find.text(AppStrings.confirmMove), findsOneWidget);

      // Select destination location
      await tester.tap(find.byType(DropdownButtonFormField<StorageLocation>));
      await tester.pumpAndSettle();

      await tester.tap(find.text(destLoc.name).last);
      await tester.pumpAndSettle();

      // Confirm move
      await tester.tap(find.text(AppStrings.confirmMove));
      await tester.pumpAndSettle();

      expect(find.byType(MoveStorageDialog), findsNothing);
    });

    testWidgets('50. Current Storage tab: Unstore confirmation dialog unstores item', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final storageRepo = getIt<StorageRepository>();
      final locationRepo = getIt<StorageLocationRepository>();
      final unstored = await storageRepo.getItemsRequiringStorageWithDetails(limit: 1, offset: 0);
      final item = unstored.first;
      final locations = await locationRepo.getCompatibleLocationsForItemType(item.orderItem.itemTypeId);
      await storageRepo.storeItem(
        orderItemId: item.orderItem.id,
        storageLocationId: locations.first.id,
      );

      await tester.pumpWidget(createTestApp(const StorageScreen()));
      await tester.pumpAndSettle();

      // Switch to Current Storage
      await tester.tap(find.text(AppStrings.currentStorage));
      await tester.pumpAndSettle();

      // Tap more options menu
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      // Tap unstore option in popup menu
      await tester.tap(find.text(AppStrings.unstoreAction));
      await tester.pumpAndSettle();

      // Confirm unstore dialog opens
      expect(find.byType(UnstoreConfirmDialog), findsOneWidget);
      expect(find.text(AppStrings.confirmUnstore), findsOneWidget);

      // Confirm unstore
      await tester.tap(find.text(AppStrings.confirmUnstore));
      await tester.pumpAndSettle();

      expect(find.byType(UnstoreConfirmDialog), findsNothing);

      // Switch back to Requiring Storage: the item should be back!
      await tester.tap(find.text(AppStrings.itemsRequiringStorage));
      await tester.pumpAndSettle();

      expect(find.textContaining(item.orderItem.itemTypeNameSnapshot), findsWidgets);
    });

    testWidgets('51. Search query filters list and displays empty state when no matches', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const StorageScreen()));
      await tester.pumpAndSettle();

      // Enter search query that has no match
      await tester.enterText(find.byType(TextField), 'NON_EXISTENT_QUERY_99999');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.noStorageResults), findsOneWidget);
    });
  });
}
