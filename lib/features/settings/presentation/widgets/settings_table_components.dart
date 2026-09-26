import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Standard Section Top Header for Settings Master Data (Figma layout).
class SettingsTopHeader extends StatelessWidget {
  final String? title;
  final int? count;
  final String? countLabel;
  final String actionLabel;
  final VoidCallback onAction;

  const SettingsTopHeader({
    super.key,
    this.title,
    this.count,
    this.countLabel,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Right side in RTL: Standard item count tag ("X عنصر")
          if (count != null)
            Text(
              '$count عنصر',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            )
          else if (title != null && title!.isNotEmpty)
            Text(
              title!,
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            )
          else
            const SizedBox.shrink(),
          // Left side in RTL: Primary "+ إضافة [الكيان]" action button
          ElevatedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add, size: 18, color: Colors.white),
            label: Text(
              actionLabel,
              style: AppTextStyles.labelLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft blue informational callout banner matching Figma.
class SettingsInfoBanner extends StatelessWidget {
  final String message;

  const SettingsInfoBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF), // Soft light sky blue
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyMedium.copyWith(
          color: const Color(0xFF1D4ED8), // Refined blue matching Figma
          fontWeight: FontWeight.w500,
          fontSize: 13.5,
          height: 1.4,
        ),
      ),
    );
  }
}

/// Reusable Master Data Card matching Figma.
class SettingsCard extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String subtitle;
  final String? secondarySubtitle;
  final bool isActive;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggleActive;
  final bool useOutlinedEditButton;

  const SettingsCard({
    super.key,
    this.icon,
    required this.title,
    required this.subtitle,
    this.secondarySubtitle,
    required this.isActive,
    required this.onEdit,
    required this.onToggleActive,
    this.useOutlinedEditButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon Container (44x44, rounded 10px, soft background)
          if (icon != null) ...[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(icon, size: 22, color: const Color(0xFF475569)),
            ),
            const SizedBox(width: 14),
          ],
          // Title + Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontSize: 15.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (secondarySubtitle != null &&
                    secondarySubtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    secondarySubtitle!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                      fontSize: 12.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Actions Area: Status badge + Edit pencil + Active Switch
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.successLight
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isActive
                        ? AppColors.success.withValues(alpha: 0.25)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6.0,
                      height: 6.0,
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.success
                            : const Color(0xFF94A3B8),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5.0),
                    Text(
                      isActive
                          ? AppStrings.statusActive
                          : AppStrings.statusInactive,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: isActive
                            ? AppColors.successDark
                            : const Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                        fontSize: 11.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Edit button: Outlined "[ ✏️ تعديل ]" button for services, or bare pencil icon
              if (useOutlinedEditButton)
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: Color(0xFF475569),
                  ),
                  label: Text(
                    'تعديل',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: const Color(0xFF475569),
                      fontWeight: FontWeight.w600,
                      fontSize: 12.0,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4.5,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
              else
                InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  child: const Padding(
                    padding: EdgeInsets.all(6.0),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              // Switch
              Transform.scale(
                scale: 0.82,
                child: Switch(
                  value: isActive,
                  onChanged: onToggleActive,
                  activeThumbColor: AppColors.primary,
                  activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
                  inactiveThumbColor: const Color(0xFF94A3B8),
                  inactiveTrackColor: const Color(0xFFE2E8F0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
    border: Border(bottom: BorderSide(color: AppColors.divider, width: 1.0)),
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

/// Responsive 2-column card grid helper for tablet layouts.
class SettingsCardGrid extends StatelessWidget {
  final List<Widget> children;

  const SettingsCardGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (int i = 0; i < children.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: children[i]),
              const SizedBox(width: 12),
              if (i + 1 < children.length)
                Expanded(child: children[i + 1])
              else
                const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ],
      ],
    );
  }
}
