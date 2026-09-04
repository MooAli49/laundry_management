import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/constants/app_constants.dart';
import 'package:laundry_management/core/theme/app_colors.dart';
import 'package:laundry_management/core/theme/app_spacing.dart';
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
    });
  });
}
