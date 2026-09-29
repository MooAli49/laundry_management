import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Non-dismissible warning banner shown during the license grace period.
///
/// Displayed at the top of [AppShell] when [LicenseStatus.gracePeriod] is active.
/// Informs the user that the license is suspended and shows days remaining.
class LicenseWarningBanner extends StatelessWidget {
  /// Number of days remaining in the grace period (0–7).
  final int daysRemaining;

  const LicenseWarningBanner({super.key, required this.daysRemaining});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      color: AppColors.warningLight,
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warningDark,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              daysRemaining > 0
                  ? AppStrings.licenseWarningGrace(daysRemaining)
                  : AppStrings.licenseWarningImmediate,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.warningDark,
                fontWeight: FontWeight.w500,
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }
}
