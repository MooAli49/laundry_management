import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../domain/entities/orders_report_data.dart';
import 'report_metric_card.dart';

class OrdersReportView extends StatelessWidget {
  final OrdersReportData data;

  const OrdersReportView({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    if (data.totalOrders == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
        child: EmptyState(
          title: 'لا توجد طلبات خلال هذه الفترة',
          message: 'لم يتم تسجيل أي طلبات في الفترة الزمنية المحددة. يمكنك تغيير الفترة من الأعلى.',
          icon: Icons.receipt_long_outlined,
        ),
      );
    }

    final total = data.totalOrders;
    final processingPercent = total > 0 ? (data.processingOrdersCount / total) : 0.0;
    final readyPercent = total > 0 ? (data.readyOrdersCount / total) : 0.0;
    final completedPercent = total > 0 ? (data.completedOrdersCount / total) : 0.0;
    final cancelledPercent = total > 0 ? (data.cancelledOrdersCount / total) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Metric Cards Row
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 650
                ? 1
                : (constraints.maxWidth < 950 ? 2 : 3);
            final cardWidth = (constraints.maxWidth - (AppSpacing.md * (columns - 1))) / columns;

            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: ReportMetricCard(
                    title: 'إجمالي الطلبات',
                    value: '${data.totalOrders}',
                    icon: Icons.receipt_long,
                    subtitle: 'جميع الطلبات المسجلة في الفترة',
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: ReportMetricCard(
                    title: 'إجمالي قيمة الطلبات',
                    value: '${data.totalOrderValue.toEgp.toStringAsFixed(2)} ج.م',
                    icon: Icons.monetization_on_outlined,
                    iconColor: AppColors.info,
                    iconBackground: AppColors.infoLight,
                    subtitle: 'القيمة المالية التاريخية للطلبات',
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: ReportMetricCard(
                    title: 'الطلبات المتأخرة',
                    value: '${data.overdueOrdersCount}',
                    icon: Icons.warning_amber_rounded,
                    iconColor: data.overdueOrdersCount > 0 ? AppColors.warning : AppColors.textSecondary,
                    iconBackground: data.overdueOrdersCount > 0 ? AppColors.warningLight : AppColors.backgroundSecondary,
                    valueColor: data.overdueOrdersCount > 0 ? AppColors.warning : null,
                    subtitle: 'تجاوزت تاريخ الاستلام المتوقع',
                  ),
                ),
              ],
            );
          },
        ),
        AppSpacing.gapXxl,

        // Status Breakdown Section
        Text('حالات الطلبات', style: AppTextStyles.titleLarge),
        AppSpacing.gapMd,

        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _buildStatusRow(
                label: 'قيد التنفيذ',
                count: data.processingOrdersCount,
                percent: processingPercent,
                color: AppColors.info,
                icon: Icons.sync,
              ),
              const Divider(height: AppSpacing.xxl),
              _buildStatusRow(
                label: 'جاهزة للتسليم',
                count: data.readyOrdersCount,
                percent: readyPercent,
                color: AppColors.warning,
                icon: Icons.inventory_2_outlined,
              ),
              const Divider(height: AppSpacing.xxl),
              _buildStatusRow(
                label: 'مكتملة',
                count: data.completedOrdersCount,
                percent: completedPercent,
                color: AppColors.success,
                icon: Icons.check_circle_outline,
              ),
              const Divider(height: AppSpacing.xxl),
              _buildStatusRow(
                label: 'ملغاة',
                count: data.cancelledOrdersCount,
                percent: cancelledPercent,
                color: AppColors.error,
                icon: Icons.cancel_outlined,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow({
    required String label,
    required int count,
    required double percent,
    required Color color,
    required IconData icon,
  }) {
    final percentText = '${(percent * 100).toStringAsFixed(1)}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            AppSpacing.gapHorizontalSm,
            Text(label, style: AppTextStyles.titleMedium),
            const Spacer(),
            Text(
              '$count طلب',
              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            AppSpacing.gapHorizontalMd,
            Text(
              percentText,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        AppSpacing.gapSm,
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 8,
            backgroundColor: AppColors.backgroundSecondary,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
