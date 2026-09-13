import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class ActiveStatusBadge extends StatelessWidget {
  final bool isActive;

  const ActiveStatusBadge({super.key, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final bg = isActive ? AppColors.successLight : AppColors.secondary;
    final fg = isActive ? AppColors.success : AppColors.textSecondary;
    final label = isActive ? AppStrings.statusActive : AppStrings.statusInactive;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10.0,
        vertical: 3.0,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 6.0,
            height: 6.0,
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6.0),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
