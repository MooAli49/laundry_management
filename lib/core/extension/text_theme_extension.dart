import 'package:flutter/material.dart';

extension TextThemeExtension on BuildContext {
  TextStyle get titleMedium => Theme.of(this).textTheme.titleMedium!;

  TextStyle get bodyMedium => Theme.of(this).textTheme.bodyMedium!;

  TextStyle get bodyMediumRegular => Theme.of(
    this,
  ).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.normal);

  TextStyle get titleSmall => Theme.of(this).textTheme.titleSmall!;

  TextStyle get titleSmallRegular => Theme.of(
    this,
  ).textTheme.titleSmall!.copyWith(fontWeight: FontWeight.normal);

  TextStyle get bodySmall => Theme.of(this).textTheme.bodySmall!;

  TextStyle get bodySmallRegular => Theme.of(
    this,
  ).textTheme.bodySmall!.copyWith(fontWeight: FontWeight.normal);

  TextStyle get labelLarge => Theme.of(this).textTheme.labelLarge!;

  TextStyle get labelMedium => Theme.of(this).textTheme.labelMedium!;

  TextStyle get labelSmall => Theme.of(this).textTheme.labelSmall!;

  TextStyle get displayLarge => Theme.of(this).textTheme.displayLarge!;

  TextStyle get displayMedium => Theme.of(this).textTheme.displayMedium!;

  TextStyle get displaySmall => Theme.of(this).textTheme.displaySmall!;

  TextStyle get headlineLarge => Theme.of(this).textTheme.headlineLarge!;

  TextStyle get headlineMedium => Theme.of(this).textTheme.headlineMedium!;

  TextStyle get headlineSmall => Theme.of(this).textTheme.headlineSmall!;
}
