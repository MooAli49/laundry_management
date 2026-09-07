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
      padding: const EdgeInsets.all(AppSpacing.lg),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          // Receipt Icon Box (Figma: size-10 rounded-lg bg-secondary text-text-secondary)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),
          AppSpacing.gapHorizontalMd,

          // Order # & Customer
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '#${order.orderNumber}',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    OrderStatusBadge(status: order.status),
                  ],
                ),
                AppSpacing.gapXs,
                Text(
                  customer?.name ?? 'عميل غير مسجل',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Expected Pickup Date
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الاستلام',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  order.expectedPickupDate.toString(),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: item.isOverdue ? AppColors.error : AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
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
                  '${order.total.toEgp.toStringAsFixed(2)} ج.م',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                if (item.isFullyPaid)
                  Text(
                    'مدفوع بالكامل',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  )
                else
                  Text(
                    'المتبقي: ${item.remainingAmount.toEgp.toStringAsFixed(2)} ج.م',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
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
