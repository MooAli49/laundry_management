import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../domain/entities/dashboard_data.dart';

class DashboardAttentionSection extends StatelessWidget {
  final DashboardData data;

  const DashboardAttentionSection({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.warning,
              size: 22,
            ),
            AppSpacing.gapHorizontalSm,
            Text('يحتاج انتباه', style: AppTextStyles.titleLarge),
          ],
        ),
        AppSpacing.gapMd,
        _buildAttentionItem(
          context: context,
          key: const ValueKey('attention_storage_item'),
          title: 'عناصر تحتاج تخزين',
          subtitle: data.storageAttentionCount > 0
              ? '${data.storageAttentionCount} عنصر بانتظار التسكين في التخزين'
              : 'لا توجد عناصر تحتاج إلى تخزين',
          count: data.storageAttentionCount,
          icon: Icons.inventory_2_outlined,
          attentionColor: AppColors.warning,
          attentionBg: AppColors.warningLight,
          onTap: () => context.push(AppRoutes.storage),
        ),
        AppSpacing.gapSm,
        _buildAttentionItem(
          context: context,
          key: const ValueKey('attention_unpaid_item'),
          title: 'طلبات عليها مبالغ متبقية',
          subtitle: data.unpaidOrdersCount > 0
              ? '${data.unpaidOrdersCount} طلبات - المتبقي: ${data.totalRemainingAmount.toEgp.toStringAsFixed(2)} ج.م'
              : 'لا توجد مبالغ متبقية',
          count: data.unpaidOrdersCount,
          icon: Icons.payments_outlined,
          attentionColor: AppColors.warning,
          attentionBg: AppColors.warningLight,
          onTap: () => context.push('${AppRoutes.orders}?filter=hasRemaining'),
        ),
        AppSpacing.gapSm,
        _buildAttentionItem(
          context: context,
          key: const ValueKey('attention_overdue_item'),
          title: 'طلبات متأخرة',
          subtitle: data.overdueOrdersCount > 0
              ? '${data.overdueOrdersCount} طلبات تجاوزت موعد الاستلام المتوقع'
              : 'لا توجد طلبات متأخرة',
          count: data.overdueOrdersCount,
          icon: Icons.access_time_filled,
          attentionColor: AppColors.error,
          attentionBg: AppColors.errorLight,
          onTap: () => context.push('${AppRoutes.orders}?filter=overdue'),
        ),
      ],
    );
  }

  Widget _buildAttentionItem({
    required BuildContext context,
    required Key key,
    required String title,
    required String subtitle,
    required int count,
    required IconData icon,
    required Color attentionColor,
    required Color attentionBg,
    required VoidCallback onTap,
  }) {
    final hasAttention = count > 0;
    final iconColor = hasAttention ? attentionColor : AppColors.textSecondary;
    final iconBg = hasAttention ? attentionBg : AppColors.backgroundSecondary;

    return AppCard(
      key: key,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      borderColor: hasAttention
          ? attentionColor.withValues(alpha: 0.3)
          : AppColors.border,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          AppSpacing.gapHorizontalMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                AppSpacing.gapXs,
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: hasAttention
                        ? AppColors.textSecondary
                        : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapHorizontalSm,
          if (hasAttention)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: attentionBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: AppTextStyles.labelSmall.copyWith(
                  color: attentionColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            const Icon(
              Icons.check_circle_outline,
              color: AppColors.success,
              size: 20,
            ),
          AppSpacing.gapHorizontalXs,
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
