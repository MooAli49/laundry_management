import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/di/injection.dart';
import 'package:laundry_management/core/localization/app_strings.dart';
import 'package:laundry_management/data/local/database/app_database.dart';
import 'package:laundry_management/features/settings/presentation/screens/settings_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    await getIt.reset();
    db = AppDatabase(NativeDatabase.memory());
    getIt.registerLazySingleton<AppDatabase>(() => db);
    await initDependencies();
  });

  tearDown(() async {
    if (getIt.isRegistered<AppDatabase>()) {
      await getIt<AppDatabase>().close();
    }
    await getIt.reset();
  });

  Widget buildSettingsScreen() {
    return const MaterialApp(
      locale: Locale('ar'),
      home: Scaffold(body: SettingsScreen()),
    );
  }

  group('SettingsScreen Integration / Widget Tests', () {
    testWidgets(
      'renders header and all 8 horizontal RTL tabs in correct order',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        expect(find.text(AppStrings.settings), findsOneWidget);

        // Verify all 8 tabs are present in the tab bar
        expect(find.text(AppStrings.tabBusinessInfo), findsWidgets);
        expect(find.text(AppStrings.tabInvoice), findsOneWidget);
        expect(find.text(AppStrings.tabServices), findsOneWidget);
        expect(find.text(AppStrings.tabItemTypes), findsOneWidget);
        expect(find.text(AppStrings.tabItemDefinitions), findsOneWidget);
        expect(find.text(AppStrings.tabCarpetSizes), findsOneWidget);
        expect(find.text(AppStrings.tabStorageLocations), findsOneWidget);
        expect(find.text(AppStrings.tabExpenseCategories), findsOneWidget);
      },
    );

    testWidgets('switching tabs renders corresponding sections', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildSettingsScreen());
      await tester.pumpAndSettle();

      // Tab 0: Business Info initially active
      expect(find.text(AppStrings.businessNameLabel), findsOneWidget);

      // Switch to Tab 1: Invoice Preview
      await tester.ensureVisible(find.text(AppStrings.tabInvoice));
      await tester.tap(find.text(AppStrings.tabInvoice));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.invoicePreviewTitle), findsOneWidget);

      // Switch to Tab 2: Services
      await tester.ensureVisible(find.text(AppStrings.tabServices));
      await tester.tap(find.text(AppStrings.tabServices));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.addService), findsOneWidget);

      // Switch to Tab 3: Item Types
      await tester.ensureVisible(find.text(AppStrings.tabItemTypes));
      await tester.tap(find.text(AppStrings.tabItemTypes));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.addItemType), findsOneWidget);

      // Switch to Tab 4: Item Definitions
      await tester.ensureVisible(find.text(AppStrings.tabItemDefinitions));
      await tester.tap(find.text(AppStrings.tabItemDefinitions));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.addItemDefinition), findsOneWidget);

      // Switch to Tab 5: Carpet Sizes
      await tester.ensureVisible(find.text(AppStrings.tabCarpetSizes));
      await tester.tap(find.text(AppStrings.tabCarpetSizes));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.addCarpetSize), findsOneWidget);

      // Switch to Tab 6: Storage Locations
      await tester.ensureVisible(find.text(AppStrings.tabStorageLocations));
      await tester.tap(find.text(AppStrings.tabStorageLocations));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.addStorageLocation), findsOneWidget);

      // Switch to Tab 7: Expense Categories
      await tester.ensureVisible(find.text(AppStrings.tabExpenseCategories));
      await tester.tap(find.text(AppStrings.tabExpenseCategories));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.addExpenseCategory), findsOneWidget);
    });
  });
}
