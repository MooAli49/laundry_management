import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/order_status_badge.dart';
import '../../../../domain/entities/dashboard_order_item.dart';

class DashboardTodayPickupsSection extends StatelessWidget {
  final List<DashboardOrderItem> orders;

  const DashboardTodayPickupsSection({
    super.key,
    required this.orders,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.event_available_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
                AppSpacing.gapHorizontalSm,
                Text(
                  'استلام اليوم',
                  style: AppTextStyles.titleLarge,
                ),
              ],
            ),
            if (orders.isNotEmpty)
              Text(
                '${orders.length} طلبات',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        AppSpacing.gapMd,
        if (orders.isEmpty)
          AppCard(
            padding: AppSpacing.paddingLg,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.textTertiary,
                  size: 20,
                ),
                AppSpacing.gapHorizontalSm,
                Text(
                  'لا توجد طلبات للاستلام اليوم',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: orders.length,
            separatorBuilder: (_, __) => AppSpacing.gapSm,
            itemBuilder: (context, index) {
              final item = orders[index];
              return AppCard(
                key: ValueKey('today_pickup_order_${item.order.id}'),
                onTap: () => context.push(AppRoutes.orderDetailPath(item.order.id)),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: Text(
                        item.order.orderNumber,
                        style: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    AppSpacing.gapHorizontalMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.order.customerNameSnapshot,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          AppSpacing.gapXs,
                          Text(
                            'موعد الاستلام: ${DateFormatter.formatArabicDate(item.order.expectedPickupDate.toDateTime())}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.gapHorizontalSm,
                    OrderStatusBadge(status: item.order.status),
                    AppSpacing.gapHorizontalXs,
                    const Icon(
                      Icons.chevron_left,
                      color: AppColors.textTertiary,
                      size: 20,
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
