import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

class SettingsTabItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const SettingsTabItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

class SettingsTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const SettingsTabBar({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  static const List<SettingsTabItem> tabs = [
    SettingsTabItem(
      label: AppStrings.tabBusinessInfo,
      icon: Icons.store_outlined,
      selectedIcon: Icons.store,
    ),
    SettingsTabItem(
      label: AppStrings.tabInvoice,
      icon: Icons.receipt_outlined,
      selectedIcon: Icons.receipt,
    ),
    SettingsTabItem(
      label: AppStrings.tabServices,
      icon: Icons.local_laundry_service_outlined,
      selectedIcon: Icons.local_laundry_service,
    ),
    SettingsTabItem(
      label: AppStrings.tabItemTypes,
      icon: Icons.category_outlined,
      selectedIcon: Icons.category,
    ),
    SettingsTabItem(
      label: AppStrings.tabItemDefinitions,
      icon: Icons.list_alt_outlined,
      selectedIcon: Icons.list_alt,
    ),
    SettingsTabItem(
      label: AppStrings.tabCarpetSizes,
      icon: Icons.straighten_outlined,
      selectedIcon: Icons.straighten,
    ),
    SettingsTabItem(
      label: AppStrings.tabStorageLocations,
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
    ),
    SettingsTabItem(
      label: AppStrings.tabExpenseCategories,
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(tabs.length, (index) {
            final tab = tabs[index];
            final isSelected = index == selectedIndex;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Material(
                color: isSelected ? AppColors.primaryLighter : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: InkWell(
                  onTap: () => onTabSelected(index),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  hoverColor: isSelected ? null : AppColors.secondary,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? tab.selectedIcon : tab.icon,
                          size: 18,
                          color: isSelected
                              ? AppColors.primaryDark
                              : AppColors.textSecondary,
                        ),
                        AppSpacing.gapHorizontalSm,
                        Text(
                          tab.label,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: isSelected
                                ? AppColors.primaryDark
                                : AppColors.textSecondary,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
