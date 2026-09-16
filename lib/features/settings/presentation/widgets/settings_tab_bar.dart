import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

class SettingsTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const SettingsTabBar({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  static const List<String> tabs = [
    AppStrings.tabBusinessInfo,
    AppStrings.tabInvoice,
    AppStrings.tabServices,
    AppStrings.tabItemTypes,
    AppStrings.tabItemDefinitions,
    AppStrings.tabCarpetSizes,
    AppStrings.tabStorageLocations,
    AppStrings.tabExpenseCategories,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // Soft neutral pill container
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(4.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(tabs.length, (index) {
            final label = tabs[index];
            final isSelected = index == selectedIndex;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onTabSelected(index),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  hoverColor: isSelected
                      ? null
                      : Colors.white.withValues(alpha: 0.5),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: isSelected
                          ? Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 0.8,
                            )
                          : null,
                      boxShadow: isSelected
                          ? const [
                              BoxShadow(
                                color: Color(0x0F000000),
                                blurRadius: 4,
                                offset: Offset(0, 1.5),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      label,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
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
