import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/order_status_badge.dart';
import '../../../../domain/entities/dashboard_order_item.dart';

class DashboardRecentOrdersSection extends StatelessWidget {
  final List<DashboardOrderItem> orders;

  const DashboardRecentOrdersSection({
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
                  Icons.receipt_long_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
                AppSpacing.gapHorizontalSm,
                Text(
                  'أحدث الطلبات',
                  style: AppTextStyles.titleLarge,
                ),
              ],
            ),
            if (orders.isNotEmpty)
              TextButton(
                onPressed: () => context.push(AppRoutes.orders),
                child: Text(
                  'عرض الكل',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        AppSpacing.gapMd,
        if (orders.isEmpty)
          AppCard(
            padding: AppSpacing.paddingXl,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 40,
                    color: AppColors.textTertiary,
                  ),
                  AppSpacing.gapSm,
                  Text(
                    'لا توجد طلبات حتى الآن',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  AppSpacing.gapMd,
                  AppButton(
                    label: 'إضافة طلب',
                    icon: Icons.add,
                    onPressed: () => context.push(AppRoutes.ordersNew),
                  ),
                ],
              ),
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
              final hasRemaining = item.remainingAmount.isPositive;

              return AppCard(
                key: ValueKey('recent_order_${item.order.id}'),
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
                            'الإجمالي: ${item.order.total.toEgp.toStringAsFixed(2)} ج.م'
                            '${hasRemaining ? ' • متبقي: ${item.remainingAmount.toEgp.toStringAsFixed(2)} ج.م' : ' • مدفوع بالكامل'}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: hasRemaining ? AppColors.warning : AppColors.textTertiary,
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
