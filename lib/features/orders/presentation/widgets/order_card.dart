import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../models/order_list_item_view_model.dart';
import 'order_status_badge.dart';

class OrderCard extends StatelessWidget {
  final OrderListItemViewModel item;
  final VoidCallback onTap;

  const OrderCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final order = item.order;
    final customer = item.customer;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          // Receipt Icon Box
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: const Icon(
              Icons.receipt_long,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          AppSpacing.gapHorizontalMd,

          // Order # & Customer
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '#${order.orderNumber}',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    AppSpacing.gapHorizontalSm,
                    OrderStatusBadge(status: order.status),
                  ],
                ),
                AppSpacing.gapXs,
                Text(
                  customer?.name ?? 'عميل غير مسجل',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Expected Pickup Date
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الاستلام',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                AppSpacing.gapXs,
                Text(
                  order.expectedPickupDate.toString(),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: item.isOverdue ? AppColors.error : AppColors.textPrimary,
                    fontWeight: item.isOverdue ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),

          // Financial Summary (Total & Remaining)
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'الإجمالي: ${order.total.toEgp.toStringAsFixed(2)} ج.م',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                AppSpacing.gapXs,
                if (item.isFullyPaid)
                  Text(
                    'مدفوع بالكامل',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  Text(
                    'المتبقي: ${item.remainingAmount.toEgp.toStringAsFixed(2)} ج.م',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),

          AppSpacing.gapHorizontalSm,
          // Chevron
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
