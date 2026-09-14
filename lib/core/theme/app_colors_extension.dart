import 'package:flutter/material.dart';
import 'package:laundry_management/core/theme/app_colors.dart';

@immutable
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final Color success;
  final Color onSuccess;
  final Color successLight;
  final Color successDark;

  final Color warning;
  final Color onWarning;
  final Color warningLight;
  final Color warningDark;

  final Color error;
  final Color onError;
  final Color errorLight;
  final Color errorDark;

  final Color info;
  final Color onInfo;
  final Color infoLight;
  final Color infoDark;

  final Color disabledBackground;
  final Color disabledBorder;
  final Color disabledText;

  final Color selectionBackground;
  final Color selectionBorder;
  final Color selectionContent;

  final Color surfaceDisabled;
  final Color surfaceSelected;

  final Color borderStrong;
  final Color borderFocused;
  final Color borderDisabled;

  const AppColorsExtension({
    required this.success,
    required this.onSuccess,
    required this.successLight,
    required this.successDark,
    required this.warning,
    required this.onWarning,
    required this.warningLight,
    required this.warningDark,
    required this.error,
    required this.onError,
    required this.errorLight,
    required this.errorDark,
    required this.info,
    required this.onInfo,
    required this.infoLight,
    required this.infoDark,
    required this.disabledBackground,
    required this.disabledBorder,
    required this.disabledText,
    required this.selectionBackground,
    required this.selectionBorder,
    required this.selectionContent,
    required this.surfaceDisabled,
    required this.surfaceSelected,
    required this.borderStrong,
    required this.borderFocused,
    required this.borderDisabled,
  });

  static const AppColorsExtension light = AppColorsExtension(
    success: AppColors.success,
    onSuccess: AppColors.onSuccess,
    successLight: AppColors.successLight,
    successDark: AppColors.successDark,
    warning: AppColors.warning,
    onWarning: AppColors.onWarning,
    warningLight: AppColors.warningLight,
    warningDark: AppColors.warningDark,
    error: AppColors.error,
    onError: AppColors.onError,
    errorLight: AppColors.errorLight,
    errorDark: AppColors.errorDark,
    info: AppColors.info,
    onInfo: AppColors.onInfo,
    infoLight: AppColors.infoLight,
    infoDark: AppColors.infoDark,
    disabledBackground: AppColors.disabledBackground,
    disabledBorder: AppColors.disabledBorder,
    disabledText: AppColors.disabledText,
    selectionBackground: AppColors.selectionBackground,
    selectionBorder: AppColors.selectionBorder,
    selectionContent: AppColors.selectionContent,
    surfaceDisabled: AppColors.surfaceDisabled,
    surfaceSelected: AppColors.surfaceSelected,
    borderStrong: AppColors.borderStrong,
    borderFocused: AppColors.borderFocused,
    borderDisabled: AppColors.borderDisabled,
  );

  static AppColorsExtension of(BuildContext context) {
    return Theme.of(context).extension<AppColorsExtension>() ?? light;
  }

  @override
  AppColorsExtension copyWith({
    Color? success,
    Color? onSuccess,
    Color? successLight,
    Color? successDark,
    Color? warning,
    Color? onWarning,
    Color? warningLight,
    Color? warningDark,
    Color? error,
    Color? onError,
    Color? errorLight,
    Color? errorDark,
    Color? info,
    Color? onInfo,
    Color? infoLight,
    Color? infoDark,
    Color? disabledBackground,
    Color? disabledBorder,
    Color? disabledText,
    Color? selectionBackground,
    Color? selectionBorder,
    Color? selectionContent,
    Color? surfaceDisabled,
    Color? surfaceSelected,
    Color? borderStrong,
    Color? borderFocused,
    Color? borderDisabled,
  }) {
    return AppColorsExtension(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successLight: successLight ?? this.successLight,
      successDark: successDark ?? this.successDark,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningLight: warningLight ?? this.warningLight,
      warningDark: warningDark ?? this.warningDark,
      error: error ?? this.error,
      onError: onError ?? this.onError,
      errorLight: errorLight ?? this.errorLight,
      errorDark: errorDark ?? this.errorDark,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoLight: infoLight ?? this.infoLight,
      infoDark: infoDark ?? this.infoDark,
      disabledBackground: disabledBackground ?? this.disabledBackground,
      disabledBorder: disabledBorder ?? this.disabledBorder,
      disabledText: disabledText ?? this.disabledText,
      selectionBackground: selectionBackground ?? this.selectionBackground,
      selectionBorder: selectionBorder ?? this.selectionBorder,
      selectionContent: selectionContent ?? this.selectionContent,
      surfaceDisabled: surfaceDisabled ?? this.surfaceDisabled,
      surfaceSelected: surfaceSelected ?? this.surfaceSelected,
      borderStrong: borderStrong ?? this.borderStrong,
      borderFocused: borderFocused ?? this.borderFocused,
      borderDisabled: borderDisabled ?? this.borderDisabled,
    );
  }

  @override
  AppColorsExtension lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) {
      return this;
    }
    return AppColorsExtension(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successLight: Color.lerp(successLight, other.successLight, t)!,
      successDark: Color.lerp(successDark, other.successDark, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningLight: Color.lerp(warningLight, other.warningLight, t)!,
      warningDark: Color.lerp(warningDark, other.warningDark, t)!,
      error: Color.lerp(error, other.error, t)!,
      onError: Color.lerp(onError, other.onError, t)!,
      errorLight: Color.lerp(errorLight, other.errorLight, t)!,
      errorDark: Color.lerp(errorDark, other.errorDark, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoLight: Color.lerp(infoLight, other.infoLight, t)!,
      infoDark: Color.lerp(infoDark, other.infoDark, t)!,
      disabledBackground:
          Color.lerp(disabledBackground, other.disabledBackground, t)!,
      disabledBorder: Color.lerp(disabledBorder, other.disabledBorder, t)!,
      disabledText: Color.lerp(disabledText, other.disabledText, t)!,
      selectionBackground:
          Color.lerp(selectionBackground, other.selectionBackground, t)!,
      selectionBorder:
          Color.lerp(selectionBorder, other.selectionBorder, t)!,
      selectionContent:
          Color.lerp(selectionContent, other.selectionContent, t)!,
      surfaceDisabled:
          Color.lerp(surfaceDisabled, other.surfaceDisabled, t)!,
      surfaceSelected:
          Color.lerp(surfaceSelected, other.surfaceSelected, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      borderFocused: Color.lerp(borderFocused, other.borderFocused, t)!,
      borderDisabled: Color.lerp(borderDisabled, other.borderDisabled, t)!,
    );
  }
}
