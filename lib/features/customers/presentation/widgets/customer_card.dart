import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../models/customer_list_item_view_model.dart';

class CustomerCard extends StatelessWidget {
  final CustomerListItemViewModel item;
  final VoidCallback? onTap;

  const CustomerCard({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final customer = item.customer;
    final orderCount = item.orderCount;

    return AppCard(
      onTap: onTap,
      padding: AppSpacing.paddingMd,
      child: Row(
        children: [
          // Avatar circle with initials or icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLighter,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              customer.name.trim().isNotEmpty
                  ? customer.name.trim().characters.first
                  : 'ع',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          AppSpacing.gapHorizontalMd,

          // Customer details: name and phone
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  customer.name,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                AppSpacing.gapXs,
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.phone_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      AppSpacing.gapHorizontalXs,
                      Text(
                        customer.phone,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textDirection: TextDirection.ltr,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Orders count badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: orderCount > 0
                  ? AppColors.primaryLighter
                  : AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                orderCount > 0 ? '$orderCount طلبات' : 'لا توجد طلبات',
                style: AppTextStyles.bodySmall.copyWith(
                  color: orderCount > 0 ? AppColors.primary : AppColors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          AppSpacing.gapHorizontalSm,

          // Forward chevron (in RTL layout, chevron_left points forward to the left)
          const Icon(
            Icons.chevron_left,
            color: AppColors.textTertiary,
            size: 20,
          ),
        ],
      ),
    );
  }
}
