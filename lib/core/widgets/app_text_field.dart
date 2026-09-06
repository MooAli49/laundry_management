import 'package:flutter/material.dart';
import 'package:laundry_management/core/theme/app_colors.dart';
import 'package:laundry_management/core/theme/app_spacing.dart';
import 'package:laundry_management/core/theme/app_text_styles.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hintText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final int maxLines;
  final bool enabled;

  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hintText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.validator,
    this.maxLines = 1,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveFillColor = enabled ? null : AppColors.disabledBackground;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: AppTextStyles.labelLarge),
          AppSpacing.gapXs,
        ],
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          validator: validator,
          maxLines: maxLines,
          enabled: enabled,
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(
            hintText: hintText,
            errorText: errorText,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            fillColor: effectiveFillColor,
          ),
        ),
      ],
    );
  }
}
