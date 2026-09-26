import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_constants.dart';
import '../localization/app_strings.dart';
import '../routing/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'sync_status_indicator.dart';

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
  final bool isCollapsed;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.isCollapsed = false,
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
    final showCompact = isCollapsed;
    return Container(
      width: showCompact ? 72 : 220,
      color: AppColors.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = showCompact || constraints.maxWidth < 140;
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : 0.0,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: AppSpacing.lg,
                        horizontal: isNarrow ? AppSpacing.sm : AppSpacing.md,
                      ),
                      child: isNarrow
                          ? Center(
                              child: SvgPicture.asset(
                                'assets/images/logo_primary_mark.svg',
                                height: 32,
                                width: 32,
                                fit: BoxFit.contain,
                                semanticsLabel: AppConstants.appName,
                              ),
                            )
                          : Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: SvgPicture.asset(
                                'assets/images/logo_primary_wordmark.svg',
                                height: 36,
                                fit: BoxFit.contain,
                                semanticsLabel: AppConstants.appName,
                              ),
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
                        isCollapsed: isNarrow,
                      );
                    }),
                    const Spacer(),
                    isNarrow
                        ? const Center(child: SyncStatusIndicator())
                        : const SyncStatusIndicator(),
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
    bool isCollapsed = false,
  }) {
    if (isCollapsed) {
      return Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 3.0,
        ),
        child: Tooltip(
          message: destination.label,
          child: InkWell(
            onTap: () => onDestinationSelected(index),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            hoverColor: isSelected ? null : AppColors.secondary,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryLighter
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
              child: Center(
                child: Icon(
                  isSelected ? destination.selectedIcon : destination.icon,
                  size: 22,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      );
    }
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
