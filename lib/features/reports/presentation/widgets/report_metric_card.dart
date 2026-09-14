import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

class ReportMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final Color? valueColor;
  final String? subtitle;
  final bool isProminent;

  const ReportMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor = AppColors.primary,
    this.iconBackground = AppColors.primaryLighter,
    this.valueColor,
    this.subtitle,
    this.isProminent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isProminent ? AppColors.surfaceSelected : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: isProminent ? AppColors.selectionBorder : AppColors.border,
          width: isProminent ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isProminent ? AppColors.selectionContent : AppColors.textSecondary,
                    fontWeight: isProminent ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              AppSpacing.gapHorizontalXs,
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ],
          ),
          AppSpacing.gapMd,
          Text(
            value,
            style: isProminent
                ? AppTextStyles.headlineMedium.copyWith(
                    color: valueColor ?? AppColors.primaryDark,
                    fontWeight: FontWeight.bold,
                  )
                : AppTextStyles.headlineSmall.copyWith(
                    color: valueColor ?? AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
          ),
          if (subtitle != null) ...[
            AppSpacing.gapXs,
            Text(
              subtitle!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}
