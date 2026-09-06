import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/constants/app_constants.dart';
import 'package:laundry_management/core/theme/app_colors.dart';
import 'package:laundry_management/core/theme/app_colors_extension.dart';
import 'package:laundry_management/core/theme/app_spacing.dart';
import 'package:laundry_management/core/theme/app_text_styles.dart';
import 'package:laundry_management/core/theme/app_theme.dart';

void main() {
  group('AppTheme & Design System Tests', () {
    test('lightTheme is configured with Material 3 and custom font family', () {
      final theme = AppTheme.lightTheme;

      expect(theme.useMaterial3, isTrue);
      expect(theme.textTheme.bodyLarge?.fontFamily, equals(AppConstants.fontFamily));
      expect(theme.colorScheme.primary, equals(AppColors.primary));
      expect(theme.colorScheme.secondary, equals(AppColors.secondary));
      expect(theme.colorScheme.error, equals(AppColors.error));
      expect(theme.scaffoldBackgroundColor, equals(AppColors.background));
    });

    test('AppSpacing scale follows the 4px baseline', () {
      expect(AppSpacing.xs, equals(4.0));
      expect(AppSpacing.sm, equals(8.0));
      expect(AppSpacing.md, equals(12.0));
      expect(AppSpacing.lg, equals(16.0));
      expect(AppSpacing.xl, equals(20.0));
      expect(AppSpacing.xxl, equals(24.0));
      expect(AppSpacing.xxxl, equals(32.0));

      expect(AppSpacing.radiusSm, equals(4.0));
      expect(AppSpacing.radiusMd, equals(8.0));
      expect(AppSpacing.radiusLg, equals(12.0));
      expect(AppSpacing.radiusXl, equals(16.0));
    });

    test('AppColors defines required status and brand tokens', () {
      expect(AppColors.primary, equals(const Color(0xFF2563EB)));
      expect(AppColors.secondary, equals(const Color(0xFF0F172A)));
      expect(AppColors.success, equals(const Color(0xFF16A34A)));
      expect(AppColors.warning, equals(const Color(0xFFD97706)));
      expect(AppColors.error, equals(const Color(0xFFDC2626)));
      expect(AppColors.disabledBackground, equals(const Color(0xFFF1F5F9)));
      expect(AppColors.disabledBorder, equals(const Color(0xFFCBD5E1)));
    });

    test('AppSpacing includes extended section, page, and major tokens', () {
      expect(AppSpacing.section, equals(40.0));
      expect(AppSpacing.page, equals(48.0));
      expect(AppSpacing.major, equals(64.0));
      expect(AppSpacing.paddingPage, equals(const EdgeInsets.all(48.0)));
    });

    test('AppTextStyles bodySmall is 13px and caption is 12px per design system', () {
      expect(AppTextStyles.bodySmall.fontSize, equals(13.0));
      expect(AppTextStyles.caption.fontSize, equals(12.0));
    });

    test('AppColorsExtension is registered in ThemeData and implements copyWith & lerp', () {
      final theme = AppTheme.lightTheme;
      final ext = theme.extension<AppColorsExtension>();

      expect(ext, isNotNull);
      expect(ext!.success, equals(AppColors.success));
      expect(ext.warning, equals(AppColors.warning));
      expect(ext.error, equals(AppColors.error));
      expect(ext.info, equals(AppColors.info));
      expect(ext.disabledBackground, equals(AppColors.disabledBackground));

      // Test copyWith
      final customSuccess = const Color(0xFF00FF00);
      final copied = ext.copyWith(success: customSuccess);
      expect(copied.success, equals(customSuccess));
      expect(copied.warning, equals(ext.warning));

      // Test lerp
      final lerped = ext.lerp(copied, 0.5);
      expect(lerped.success, equals(Color.lerp(ext.success, customSuccess, 0.5)));
      expect(lerped.warning, equals(ext.warning));
    });

    test('InputDecorationTheme is centralized in ThemeData with all required borders', () {
      final theme = AppTheme.lightTheme;
      final inputTheme = theme.inputDecorationTheme;

      expect(inputTheme.filled, isTrue);
      expect(inputTheme.fillColor, equals(AppColors.surface));
      expect(inputTheme.border, isA<OutlineInputBorder>());
      expect(inputTheme.enabledBorder, isA<OutlineInputBorder>());
      expect(inputTheme.focusedBorder, isA<OutlineInputBorder>());
      expect(inputTheme.errorBorder, isA<OutlineInputBorder>());
      expect(inputTheme.focusedErrorBorder, isA<OutlineInputBorder>());
      expect(inputTheme.disabledBorder, isA<OutlineInputBorder>());
    });

    test('DialogThemeData and BottomSheetThemeData are minimally configured', () {
      final theme = AppTheme.lightTheme;
      expect(theme.dialogTheme.backgroundColor, equals(AppColors.surface));
      expect(theme.bottomSheetTheme.backgroundColor, equals(AppColors.surface));
    });
  });
}
