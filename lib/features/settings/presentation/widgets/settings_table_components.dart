import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Standard Section Header for Settings Master Data cards.
class SettingsSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> actions;

  const SettingsSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              AppSpacing.gapXs,
              Text(
                subtitle,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (actions.isNotEmpty) ...[
          AppSpacing.gapHorizontalMd,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < actions.length; i++) ...[
                if (i > 0) AppSpacing.gapHorizontalMd,
                actions[i],
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// Standard Table Header Row decoration and cell builder for Settings.
class SettingsTableHelper {
  SettingsTableHelper._();

  static const EdgeInsets cellPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: AppSpacing.md,
  );

  static TableRow buildHeaderRow(List<String> titles) {
    return TableRow(
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      children: titles.map((title) {
        return Padding(
          padding: cellPadding,
          child: Text(
            title,
            style: AppTextStyles.labelLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        );
      }).toList(),
    );
  }

  static const BoxDecoration rowDecoration = BoxDecoration(
    border: Border(
      bottom: BorderSide(color: AppColors.divider, width: 1.0),
    ),
  );
}

/// Standardized action buttons for Settings table rows (Edit + Activate/Deactivate).
class SettingsRowActions extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final bool isActive;

  const SettingsRowActions({
    super.key,
    required this.onEdit,
    required this.onToggleStatus,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Edit Action
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            hoverColor: AppColors.primaryLighter,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm + 2,
                vertical: AppSpacing.xs + 2,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                color: AppColors.surface,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    AppStrings.edit,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AppSpacing.gapHorizontalSm,
        // Status Toggle Action (Deactivate / Activate)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onToggleStatus,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            hoverColor: isActive
                ? AppColors.errorLight
                : AppColors.successLight,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm + 2,
                vertical: AppSpacing.xs + 2,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.errorLight.withValues(alpha: 0.5)
                    : AppColors.successLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: isActive
                      ? AppColors.error.withValues(alpha: 0.2)
                      : AppColors.success.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isActive
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                    size: 16,
                    color: isActive ? AppColors.error : AppColors.success,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isActive
                        ? AppStrings.actionDeactivate
                        : AppStrings.actionActivate,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: isActive ? AppColors.error : AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
