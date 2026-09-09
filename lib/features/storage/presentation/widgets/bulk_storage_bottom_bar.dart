import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';

/// BulkStorageBottomBar matching the approved Figma floating/sticky selection bar.
///
/// Styling:
/// - Rounded-xl (12px radius)
/// - Border: 1px solid AppColors.primary
/// - Background: AppColors.surfaceSelected (teal tint #E4F3F1)
/// - Padding: horizontal 16px, vertical 12px
/// - Text: "تم تحديد $count عناصر" (14px font-medium AppColors.primaryDark)
/// - Actions: "إلغاء التحديد" (text variant) and "تخزين العناصر" (primary variant)
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
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSelected,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.primary, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.08),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasConflictingTypes) ...[
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: AppColors.warning,
                  ),
                  AppSpacing.gapHorizontalSm,
                  Expanded(
                    child: Text(
                      AppStrings.conflictingTypesWarning,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.warning,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            children: [
              Text(
                'تم تحديد $selectedCount عناصر',
                style: AppTextStyles.labelLarge.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryDark,
                ),
              ),
              const Spacer(),
              AppButton(
                label: 'إلغاء التحديد',
                variant: AppButtonVariant.text,
                onPressed: onClearSelection,
              ),
              AppSpacing.gapHorizontalSm,
              AppButton(
                label: AppStrings.storeItemsAction,
                icon: Icons.inventory_2_outlined,
                variant: AppButtonVariant.primary,
                onPressed: hasConflictingTypes ? null : onBulkStore,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
