import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/app.dart';
import 'package:laundry_management/core/constants/app_constants.dart';
import 'package:laundry_management/core/localization/app_strings.dart';
import 'package:laundry_management/core/routing/app_router.dart';
import 'package:laundry_management/core/routing/app_routes.dart';
import 'package:laundry_management/core/widgets/app_shell.dart';
import 'package:laundry_management/features/customers/presentation/screens/customers_screen.dart';
import 'package:laundry_management/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:laundry_management/features/orders/presentation/screens/orders_screen.dart';
import 'package:laundry_management/features/reports/presentation/screens/reports_screen.dart';
import 'package:laundry_management/features/settings/presentation/screens/settings_screen.dart';
import 'package:laundry_management/features/storage/presentation/screens/storage_screen.dart';

void main() {
  group('Foundation App Bootstrap & Navigation Tests', () {
    testWidgets(
      'boots app, verifies RTL directionality, and renders dashboard',
      (WidgetTester tester) async {
        await tester.pumpWidget(const LaundryManagementApp());
        await tester.pumpAndSettle();

        // App Name should appear in the branding header
        expect(find.text(AppConstants.appName), findsOneWidget);

        // Verify RTL text directionality is enforced
        final BuildContext shellContext = tester.element(find.byType(AppShell));
        expect(Directionality.of(shellContext), equals(TextDirection.rtl));

        // Initial screen is Dashboard
        expect(find.byType(DashboardScreen), findsOneWidget);
      },
    );

    testWidgets(
      'renders all six primary navigation destinations in NavigationRail',
      (WidgetTester tester) async {
        await tester.pumpWidget(const LaundryManagementApp());
        await tester.pumpAndSettle();

        final railFinder = find.byType(NavigationRail);

        // Verify the 6 primary destinations in Arabic inside NavigationRail
        expect(
          find.descendant(of: railFinder, matching: find.text(AppStrings.dashboard)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: railFinder, matching: find.text(AppStrings.orders)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: railFinder, matching: find.text(AppStrings.customers)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: railFinder, matching: find.text(AppStrings.storage)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: railFinder, matching: find.text(AppStrings.reports)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: railFinder, matching: find.text(AppStrings.settings)),
          findsOneWidget,
        );
      },
    );

    testWidgets('switches routes when tapping navigation destinations', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const LaundryManagementApp());
      await tester.pumpAndSettle();

      final railFinder = find.byType(NavigationRail);

      // Helper to check GoRouter current path
      String currentPath() =>
          AppRouter.router.routerDelegate.currentConfiguration.uri.path;

      // Initial path is dashboard
      expect(currentPath(), equals(AppRoutes.dashboard));
      expect(find.byType(DashboardScreen), findsOneWidget);

      // 1. Navigate to Orders
      await tester.tap(
        find.descendant(of: railFinder, matching: find.text(AppStrings.orders)),
      );
      await tester.pumpAndSettle();
      expect(currentPath(), equals(AppRoutes.orders));
      expect(find.byType(OrdersScreen), findsOneWidget);

      // 2. Navigate to Customers
      await tester.tap(
        find.descendant(of: railFinder, matching: find.text(AppStrings.customers)),
      );
      await tester.pumpAndSettle();
      expect(currentPath(), equals(AppRoutes.customers));
      expect(find.byType(CustomersScreen), findsOneWidget);

      // 3. Navigate to Storage
      await tester.tap(
        find.descendant(of: railFinder, matching: find.text(AppStrings.storage)),
      );
      await tester.pumpAndSettle();
      expect(currentPath(), equals(AppRoutes.storage));
      expect(find.byType(StorageScreen), findsOneWidget);

      // 4. Navigate to Reports
      await tester.tap(
        find.descendant(of: railFinder, matching: find.text(AppStrings.reports)),
      );
      await tester.pumpAndSettle();
      expect(currentPath(), equals(AppRoutes.reports));
      expect(find.byType(ReportsScreen), findsOneWidget);

      // 5. Navigate to Settings
      await tester.tap(
        find.descendant(of: railFinder, matching: find.text(AppStrings.settings)),
      );
      await tester.pumpAndSettle();
      expect(currentPath(), equals(AppRoutes.settings));
      expect(find.byType(SettingsScreen), findsOneWidget);

      // 6. Navigate back to Dashboard
      await tester.tap(
        find.descendant(of: railFinder, matching: find.text(AppStrings.dashboard)),
      );
      await tester.pumpAndSettle();
      expect(currentPath(), equals(AppRoutes.dashboard));
      expect(find.byType(DashboardScreen), findsOneWidget);
    });
  });
}
