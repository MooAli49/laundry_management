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
    if (location.startsWith(AppRoutes.storage)) return 2;
    if (location.startsWith(AppRoutes.customers)) return 3;
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
        context.go(AppRoutes.storage);
        break;
      case 3:
        context.go(AppRoutes.customers);
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
            AppSidebar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => _onItemTapped(index, context),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: mainContent),
          ],
        ),
      ),
    );
  }
}

class AppSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  static const List<_SidebarDestination> _destinations = [
    _SidebarDestination(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: AppStrings.dashboard,
    ),
    _SidebarDestination(
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      label: AppStrings.orders,
    ),
    _SidebarDestination(
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
      label: AppStrings.storage,
    ),
    _SidebarDestination(
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      label: AppStrings.customers,
    ),
    _SidebarDestination(
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      label: AppStrings.reports,
    ),
    _SidebarDestination(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: AppStrings.settings,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: AppColors.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
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
                          Expanded(
                            child: Text(
                              AppConstants.appName,
                              style: AppTextStyles.titleLarge,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.gapSm,
                    ...List.generate(_destinations.length, (index) {
                      final destination = _destinations[index];
                      final isSelected = index == selectedIndex;
                      return _buildSidebarItem(
                        context: context,
                        index: index,
                        destination: destination,
                        isSelected: isSelected,
                      );
                    }),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          AppSpacing.gapHorizontalSm,
                          Text(
                            'متصل',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSidebarItem({
    required BuildContext context,
    required int index,
    required _SidebarDestination destination,
    required bool isSelected,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 3.0,
      ),
      child: InkWell(
        onTap: () => onDestinationSelected(index),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        hoverColor: isSelected ? null : AppColors.secondary,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 10.0,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLighter : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? destination.selectedIcon : destination.icon,
                size: 22,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              AppSpacing.gapHorizontalMd,
              Expanded(
                child: Text(
                  destination.label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.primaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              if (isSelected)
                Container(
                  width: 3.5,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                )
              else
                const SizedBox(width: 3.5),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _SidebarDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
