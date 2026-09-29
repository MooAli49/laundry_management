import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Full-screen lock screen displayed when [LicenseStatus.lockedOut].
///
/// Rendered outside the [ShellRoute] — no sidebar or navigation bar is visible.
/// The screen has no back button and no swipe-to-dismiss affordance.
///
/// The user is automatically unblocked when the owner reinstates the license:
/// [LicenseService] will detect the change on the next check and broadcast a
/// status update, causing GoRouter to redirect away from this screen.
///
/// Contact information: this screen deliberately avoids hard-coding a phone
/// number or email. A future enhancement can read contact info from
/// [BusinessSettings] once the license is reinstated.
class LicenseLockScreen extends StatelessWidget {
  const LicenseLockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Prevent Android back-button from navigating away
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 44,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'تم تعليق ترخيص النظام',
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'يرجى التواصل مع مزود النظام لإعادة تفعيل التطبيق.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
