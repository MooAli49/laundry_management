import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../models/order_list_filter.dart';

class OrdersFilterBar extends StatelessWidget {
  final OrderListFilter selectedFilter;
  final ValueChanged<OrderListFilter> onFilterSelected;

  const OrdersFilterBar({
    super.key,
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    final statusFilters = [
      OrderListFilter.all,
      OrderListFilter.processing,
      OrderListFilter.ready,
      OrderListFilter.completed,
      OrderListFilter.cancelled,
    ];

    final isFiltered = selectedFilter != OrderListFilter.all;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Status Pills
          ...statusFilters.map((filter) {
            final isSelected = filter == selectedFilter;
            return Padding(
              padding: const EdgeInsets.only(left: 6.0),
              child: InkWell(
                onTap: () => onFilterSelected(filter),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 6.0,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    filter.label,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isSelected ? AppColors.textOnPrimary : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 13.0,
                    ),
                  ),
                ),
              ),
            );
          }),

          // Vertical Separator
          Container(
            width: 1.0,
            height: 20.0,
            color: AppColors.border,
            margin: const EdgeInsets.symmetric(horizontal: 8.0),
          ),

          // Remaining Balance Filter Toggle
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: InkWell(
              onTap: () {
                if (selectedFilter == OrderListFilter.hasRemaining) {
                  onFilterSelected(OrderListFilter.all);
                } else {
                  onFilterSelected(OrderListFilter.hasRemaining);
                }
              },
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 6.0,
                ),
                decoration: BoxDecoration(
                  color: selectedFilter == OrderListFilter.hasRemaining
                      ? AppColors.warningLight
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(
                    color: selectedFilter == OrderListFilter.hasRemaining
                        ? AppColors.warning
                        : AppColors.border,
                    width: 1,
                  ),
                ),
                child: Text(
                  OrderListFilter.hasRemaining.label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: selectedFilter == OrderListFilter.hasRemaining
                        ? AppColors.warning
                        : AppColors.textSecondary,
                    fontWeight: selectedFilter == OrderListFilter.hasRemaining
                        ? FontWeight.w600
                        : FontWeight.w500,
                    fontSize: 13.0,
                  ),
                ),
              ),
            ),
          ),

          // Clear Filters Action Button
          if (isFiltered)
            Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: InkWell(
                onTap: () => onFilterSelected(OrderListFilter.all),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                  child: Text(
                    'مسح الفلاتر',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 13.0,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
