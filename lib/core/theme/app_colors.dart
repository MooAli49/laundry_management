import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Color Scale (Figma Deep Teal)
  static const Color primary = Color(0xFF0F766E);
  static const Color primaryLight = Color(0xFF14A89C);
  static const Color primaryLighter = Color(0xFFE4F3F1);
  static const Color primaryDark = Color(0xFF0B5A54);
  static const Color onPrimary = Colors.white;

  // Secondary
  static const Color secondary = Color(0xFFEEF1F3);
  static const Color secondaryLight = Color(0xFFF5F7F8);
  static const Color secondaryDark = Color(0xFF17212E);
  static const Color onSecondary = Color(0xFF17212E);

  // Background
  static const Color background = Color(0xFFF5F7F8);
  static const Color backgroundSecondary = Color(0xFFEEF1F3);

  // Surface
  static const Color surface = Colors.white;
  static const Color surfaceElevated = Colors.white;
  static const Color surfaceSelected = Color(0xFFE4F3F1);
  static const Color surfaceDisabled = Color(0xFFEEF1F3);

  // Text
  static const Color textPrimary = Color(0xFF17212E);
  static const Color textSecondary = Color(0xFF5C6775);
  static const Color textTertiary = Color(0xFF8B95A1);
  static const Color textDisabled = Color(0xFF8B95A1);
  static const Color textOnPrimary = Colors.white;
  static const Color textOnSuccess = Colors.white;
  static const Color textOnWarning = Colors.white;
  static const Color textOnError = Colors.white;
  static const Color textOnInfo = Colors.white;

  // Border & Divider
  static const Color border = Color(0xFFE3E7EA);
  static const Color borderStrong = Color(0xFFCDD4DA);
  static const Color borderFocused = Color(0xFF0F766E);
  static const Color borderDisabled = Color(0xFFCDD4DA);
  static const Color divider = Color(0xFFEDF0F2);

  // States
  static const Color success = Color(0xFF1F8A4C);
  static const Color successLight = Color(0xFFE6F4EC);
  static const Color successDark = Color(0xFF15803D);
  static const Color onSuccess = Colors.white;

  static const Color warning = Color(0xFFB9770F);
  static const Color warningLight = Color(0xFFFBF1DF);
  static const Color warningDark = Color(0xFF92400E);
  static const Color onWarning = Colors.white;

  static const Color error = Color(0xFFC62828);
  static const Color errorLight = Color(0xFFFBEAEA);
  static const Color errorDark = Color(0xFF991B1B);
  static const Color onError = Colors.white;

  static const Color info = Color(0xFF2563A8);
  static const Color infoLight = Color(0xFFE8F0F9);
  static const Color infoDark = Color(0xFF1D4ED8);
  static const Color onInfo = Colors.white;

  // Interaction
  static const Color focus = Color(0xFF0F766E);
  static const Color selectionBackground = Color(0xFFE4F3F1);
  static const Color selectionBorder = Color(0xFF0F766E);
  static const Color selectionContent = Color(0xFF0B5A54);

  // Disabled
  static const Color disabledBackground = Color(0xFFEEF1F3);
  static const Color disabledBorder = Color(0xFFCDD4DA);
  static const Color disabledText = Color(0xFF8B95A1);

  // Overlay
  static const Color overlay = Color(0x66000000);
}
