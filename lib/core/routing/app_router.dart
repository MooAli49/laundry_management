import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:laundry_management/core/routing/app_routes.dart';
import 'package:laundry_management/core/widgets/app_shell.dart';

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
          return AppShell(child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) =>
                const _FoundationPlaceholderScreen(title: 'الرئيسية'),
          ),
          GoRoute(
            path: AppRoutes.orders,
            builder: (context, state) =>
                const _FoundationPlaceholderScreen(title: 'الطلبات'),
          ),
          GoRoute(
            path: AppRoutes.customers,
            builder: (context, state) =>
                const _FoundationPlaceholderScreen(title: 'العملاء'),
          ),
          GoRoute(
            path: AppRoutes.storage,
            builder: (context, state) =>
                const _FoundationPlaceholderScreen(title: 'التخزين'),
          ),
          GoRoute(
            path: AppRoutes.reports,
            builder: (context, state) =>
                const _FoundationPlaceholderScreen(title: 'التقارير'),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) =>
                const _FoundationPlaceholderScreen(title: 'الإعدادات'),
          ),
        ],
      ),
    ],
  );
}

class _FoundationPlaceholderScreen extends StatelessWidget {
  final String title;

  const _FoundationPlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(title, style: Theme.of(context).textTheme.headlineLarge),
      ),
    );
  }
}
