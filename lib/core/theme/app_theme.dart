import 'package:flutter/material.dart';
import 'package:laundry_management/core/styles/app_styles.dart';
import 'package:laundry_management/core/theme/color_manager.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: ColorManager.primary,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.grey[100],
      elevation: 0,
      centerTitle: true,
      titleTextStyle: AppStyles.headingMedium.copyWith(
        color: ColorManager.darkInputBackground,
      ),
    ),
    textTheme: TextTheme(
      headlineLarge: AppStyles.headingLarge,
      headlineMedium: AppStyles.headingMedium,
      headlineSmall: AppStyles.headingSmall,
      bodyLarge: AppStyles.bodyLarge,
      bodyMedium: AppStyles.bodyMedium,
      bodySmall: AppStyles.bodySmall,
      labelLarge: AppStyles.labelLarge,
      labelSmall: AppStyles.labelSmall,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ColorManager.primary,
        foregroundColor: ColorManager.textPrimary,
        textStyle: AppStyles.buttonText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ColorManager.lightGrey,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: ColorManager.primary,
      foregroundColor: ColorManager.textPrimary,
    ),
    cardColor: Colors.white,
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: ColorManager.primary,
    scaffoldBackgroundColor: ColorManager.darkBackground,
    appBarTheme: AppBarTheme(
      backgroundColor: ColorManager.darkSurfaceColor,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: AppStyles.headingMedium.copyWith(
        color: ColorManager.textPrimary,
      ),
    ),
    textTheme: TextTheme(
      headlineLarge: AppStyles.headingLarge.copyWith(color: Colors.white),
      headlineMedium: AppStyles.headingMedium.copyWith(color: Colors.white),
      headlineSmall: AppStyles.headingSmall.copyWith(color: Colors.white),
      bodyLarge: AppStyles.bodyLarge.copyWith(color: Colors.white70),
      bodyMedium: AppStyles.bodyMedium.copyWith(color: Colors.white60),
      bodySmall: AppStyles.bodySmall.copyWith(color: Colors.white54),
      labelLarge: AppStyles.labelLarge.copyWith(color: ColorManager.primary),
      labelSmall: AppStyles.labelSmall.copyWith(color: Colors.white60),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ColorManager.primary,
        foregroundColor: ColorManager.textPrimary,
        textStyle: AppStyles.buttonText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ColorManager.darkInputBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: ColorManager.primary,
      foregroundColor: ColorManager.textPrimary,
    ),
    cardColor: ColorManager.textSecondary.withOpacity(0.1),
  );
}
