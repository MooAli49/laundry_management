import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:laundry_management/core/constants/app_constants.dart';
import 'package:laundry_management/core/localization/app_strings.dart';
import 'package:laundry_management/core/routing/app_routes.dart';
import 'package:laundry_management/core/theme/app_colors.dart';
import 'package:laundry_management/core/theme/app_spacing.dart';
import 'package:laundry_management/core/theme/app_text_styles.dart';

class AppShell extends StatelessWidget {
  final Widget mainContent;

  const AppShell({super.key, required this.mainContent});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith(AppRoutes.orders)) return 1;
    if (location.startsWith(AppRoutes.customers)) return 2;
    if (location.startsWith(AppRoutes.storage)) return 3;
    if (location.startsWith(AppRoutes.reports)) return 4;
    if (location.startsWith(AppRoutes.settings)) return 5;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(AppRoutes.dashboard);
        break;
      case 1:
        context.go(AppRoutes.orders);
        break;
      case 2:
        context.go(AppRoutes.customers);
        break;
      case 3:
        context.go(AppRoutes.storage);
        break;
      case 4:
        context.go(AppRoutes.reports);
        break;
      case 5:
        context.go(AppRoutes.settings);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              extended: true,
              minExtendedWidth: 200,
              selectedIndex: selectedIndex,
              onDestinationSelected: (int index) =>
                  _onItemTapped(index, context),
              leading: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.lg,
                  horizontal: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_laundry_service,
                      color: AppColors.primary,
                      size: AppSpacing.xxxl,
                    ),
                    AppSpacing.gapHorizontalMd,
                    Text(AppConstants.appName, style: AppTextStyles.titleLarge),
                  ],
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text(AppStrings.dashboard),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: Text(AppStrings.orders),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: Text(AppStrings.customers),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: Text(AppStrings.storage),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: Text(AppStrings.reports),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text(AppStrings.settings),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: mainContent),
          ],
        ),
      ),
    );
  }
}
