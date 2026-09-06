import 'package:flutter/material.dart';
import 'package:laundry_management/core/theme/app_colors.dart';
import 'package:laundry_management/core/theme/app_spacing.dart';
import 'package:laundry_management/core/theme/app_text_styles.dart';

enum AppButtonVariant { primary, secondary, outline, destructive, text }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color foregroundColor;
    BorderSide? borderSide;

    switch (variant) {
      case AppButtonVariant.primary:
        backgroundColor = AppColors.primary;
        foregroundColor = AppColors.onPrimary;
        borderSide = null;
        break;
      case AppButtonVariant.secondary:
        backgroundColor = AppColors.secondary;
        foregroundColor = AppColors.onSecondary;
        borderSide = null;
        break;
      case AppButtonVariant.outline:
        backgroundColor = Colors.transparent;
        foregroundColor = AppColors.primary;
        borderSide = const BorderSide(color: AppColors.primary, width: 1.5);
        break;
      case AppButtonVariant.destructive:
        backgroundColor = AppColors.error;
        foregroundColor = AppColors.onError;
        borderSide = null;
        break;
      case AppButtonVariant.text:
        backgroundColor = Colors.transparent;
        foregroundColor = AppColors.primary;
        borderSide = null;
        break;
    }

    Widget content = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: foregroundColor),
                AppSpacing.gapHorizontalSm,
              ],
              Text(
                label,
                style: AppTextStyles.labelLarge.copyWith(
                  color: foregroundColor,
                ),
              ),
            ],
          );

    final button = ElevatedButton(
      onPressed: (isLoading || onPressed == null) ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        shadowColor: Colors.transparent,
        disabledBackgroundColor: isLoading ? backgroundColor : null,
        disabledForegroundColor: isLoading ? foregroundColor : null,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: borderSide ?? BorderSide.none,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
      child: content,
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }

    return button;
  }
}
