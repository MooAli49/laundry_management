import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';

class DeactivationConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;

  const DeactivationConfirmDialog({
    super.key,
    this.title = AppStrings.confirmDeactivationTitle,
    required this.message,
    this.confirmLabel = AppStrings.confirmDeactivationButton,
  });

  static Future<bool?> show(
    BuildContext context, {
    String title = AppStrings.confirmDeactivationTitle,
    required String message,
    String confirmLabel = AppStrings.confirmDeactivationButton,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => DeactivationConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.error,
                      size: 24,
                    ),
                  ),
                  AppSpacing.gapHorizontalMd,
                  Expanded(child: Text(title, style: AppTextStyles.titleLarge)),
                ],
              ),
              AppSpacing.gapLg,
              Text(
                message,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              AppSpacing.gapXxl,
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: AppStrings.cancel,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  AppSpacing.gapHorizontalMd,
                  AppButton(
                    label: confirmLabel,
                    variant: AppButtonVariant.destructive,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
