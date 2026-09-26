import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Pill badge representing Active (فعّال) or Inactive (معطّل) state.
///
/// Features a colored status indicator dot, smooth rounded pill shape,
/// and accessible contrasting colors adhering to the Figma design system.
class ActiveStatusBadge extends StatelessWidget {
  final bool isActive;

  const ActiveStatusBadge({super.key, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final bg = isActive ? AppColors.successLight : AppColors.secondary;
    final fg = isActive ? AppColors.successDark : AppColors.textSecondary;
    final dotColor = isActive ? AppColors.success : AppColors.textDisabled;
    final borderColor = isActive
        ? AppColors.success.withValues(alpha: 0.25)
        : AppColors.border;
    final label = isActive
        ? AppStrings.statusActive
        : AppStrings.statusInactive;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 6.0,
            height: 6.0,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6.0),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}
