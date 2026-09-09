import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';

class BulkStorageBottomBar extends StatelessWidget {
  final int selectedCount;
  final bool hasConflictingTypes;
  final VoidCallback onClearSelection;
  final VoidCallback onBulkStore;

  const BulkStorageBottomBar({
    super.key,
    required this.selectedCount,
    required this.hasConflictingTypes,
    required this.onClearSelection,
    required this.onBulkStore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.page,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, -2),
            blurRadius: 8,
          ),
        ],
        border: const Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasConflictingTypes) ...[
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                    AppSpacing.gapHorizontalSm,
                    Expanded(
                      child: Text(
                        AppStrings.conflictingTypesWarning,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Row(
              children: [
                Text(
                  AppStrings.selectedItemsCount(selectedCount),
                  style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary),
                ),
                AppSpacing.gapHorizontalMd,
                TextButton(
                  onPressed: onClearSelection,
                  child: Text(
                    'إلغاء التحديد',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                ),
                const Spacer(),
                AppButton(
                  label: AppStrings.storeItemsAction,
                  icon: Icons.inventory_2,
                  variant: AppButtonVariant.primary,
                  onPressed: hasConflictingTypes ? null : onBulkStore,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
