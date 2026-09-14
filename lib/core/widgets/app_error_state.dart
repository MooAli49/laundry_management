import 'package:flutter/material.dart';
import 'package:laundry_management/core/localization/app_strings.dart';
import 'package:laundry_management/core/theme/app_colors.dart';
import 'package:laundry_management/core/theme/app_colors_extension.dart';
import 'package:laundry_management/core/theme/app_spacing.dart';
import 'package:laundry_management/core/theme/app_text_styles.dart';
import 'package:laundry_management/core/widgets/app_button.dart';

/// Reusable error presentation widget adhering to the Laundry Design System.
///
/// Displays an error icon, title, descriptive message, and an optional retry action.
class AppErrorState extends StatelessWidget {
  final String title;
  final String? message;
  final IconData icon;
  final VoidCallback? onRetry;
  final String retryLabel;

  const AppErrorState({
    super.key,
    this.title = AppStrings.errorTitle,
    this.message,
    this.icon = Icons.error_outline,
    this.onRetry,
    this.retryLabel = AppStrings.retry,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = AppColorsExtension.of(context);

    return Center(
      child: Padding(
        padding: AppSpacing.paddingXl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: appColors.error),
            AppSpacing.gapMd,
            Text(
              title,
              style: AppTextStyles.titleLarge.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              AppSpacing.gapSm,
              Text(
                message!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              AppSpacing.gapLg,
              AppButton(
                label: retryLabel,
                icon: Icons.refresh,
                onPressed: onRetry,
                variant: AppButtonVariant.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
