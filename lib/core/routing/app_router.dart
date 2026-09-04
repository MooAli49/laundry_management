import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:laundry_management/core/routing/app_routes.dart';
import 'package:laundry_management/core/widgets/app_shell.dart';
import 'package:laundry_management/features/customers/presentation/screens/customers_screen.dart';
import 'package:laundry_management/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:laundry_management/features/orders/presentation/screens/orders_screen.dart';
import 'package:laundry_management/features/reports/presentation/screens/reports_screen.dart';
import 'package:laundry_management/features/settings/presentation/screens/settings_screen.dart';
import 'package:laundry_management/features/storage/presentation/screens/storage_screen.dart';

class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> _shellNavigatorKey =
      GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.dashboard,
    routes: [
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return AppShell(mainContent: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.orders,
            builder: (context, state) => const OrdersScreen(),
          ),
          GoRoute(
            path: AppRoutes.customers,
            builder: (context, state) => const CustomersScreen(),
          ),
          GoRoute(
            path: AppRoutes.storage,
            builder: (context, state) => const StorageScreen(),
          ),
          GoRoute(
            path: AppRoutes.reports,
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
}
