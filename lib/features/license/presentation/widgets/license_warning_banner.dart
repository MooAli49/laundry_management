import 'package:flutter/material.dart';

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
      color: const Color(0xFFFFF3CD), // amber-100
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFF856404),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              daysRemaining > 0
                  ? 'تنبيه: الترخيص معلق. متبقٍ $daysRemaining ${daysRemaining == 1 ? "يوم" : "أيام"} قبل إيقاف التطبيق. يرجى التواصل مع مزود النظام.'
                  : 'تنبيه: الترخيص معلق. يرجى التواصل مع مزود النظام فوراً.',
              style: AppTextStyles.bodySmall.copyWith(
                color: const Color(0xFF856404),
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
