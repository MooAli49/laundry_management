import 'package:flutter/material.dart';
import 'package:laundry_management/core/theme/app_colors.dart';
import 'package:laundry_management/core/theme/app_spacing.dart';
import 'package:laundry_management/core/theme/app_text_styles.dart';

class LoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;
  final Color? color;
  final EdgeInsetsGeometry? padding;

  const LoadingIndicator({
    super.key,
    this.message,
    this.size = 36.0,
    this.color,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final indicator = SizedBox(
      height: size,
      width: size,
      child: CircularProgressIndicator(
        strokeWidth: 3,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? AppColors.primary,
        ),
      ),
    );

    if (message == null) {
      return Center(
        child: padding != null
            ? Padding(padding: padding!, child: indicator)
            : indicator,
      );
    }

    return Center(
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: padding ?? AppSpacing.paddingMd,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            indicator,
            AppSpacing.gapMd,
            Text(
              message!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
