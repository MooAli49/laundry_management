import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/customers/presentation/screens/customer_detail_screen.dart';
import '../../features/customers/presentation/screens/customers_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/orders/presentation/screens/create_order_screen.dart';
import '../../features/orders/presentation/screens/edit_order_screen.dart';
import '../../features/orders/presentation/screens/order_detail_screen.dart';
import '../../features/orders/presentation/screens/orders_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/storage/presentation/screens/storage_screen.dart';
import '../widgets/app_shell.dart';
import 'app_routes.dart';

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
            builder: (context, state) => OrdersScreen(
              initialFilter: state.uri.queryParameters['filter'],
            ),
          ),
          GoRoute(
            path: AppRoutes.ordersNew,
            builder: (context, state) => CreateOrderScreen(
              initialCustomerId: state.uri.queryParameters['customerId'],
            ),
          ),
          GoRoute(
            path: AppRoutes.ordersEdit,
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return EditOrderScreen(orderId: id);
            },
          ),
          GoRoute(
            path: AppRoutes.ordersDetail,
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return OrderDetailScreen(orderId: id);
            },
          ),
          GoRoute(
            path: AppRoutes.customers,
            builder: (context, state) => const CustomersScreen(),
          ),
          GoRoute(
            path: AppRoutes.customersDetail,
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return CustomerDetailScreen(customerId: id);
            },
          ),
          GoRoute(
            path: AppRoutes.storage,
            builder: (context, state) => StorageScreen(
              initialOrderId: state.uri.queryParameters['orderId'],
              initialOrderNumber: state.uri.queryParameters['orderNumber'],
            ),
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
