import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  // Spacing Scale (4px base)
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double section = 40.0;
  static const double page = 48.0;
  static const double major = 64.0;

  // Radius Scale
  static const double radiusSm = 4.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 12.0;
  static const double radiusXl = 16.0;

  // Uniform Padding
  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);
  static const EdgeInsets paddingXxl = EdgeInsets.all(xxl);
  static const EdgeInsets paddingSection = EdgeInsets.all(section);
  static const EdgeInsets paddingPage = EdgeInsets.all(page);
  static const EdgeInsets paddingMajor = EdgeInsets.all(major);

  // Horizontal Padding
  static const EdgeInsets horizontalXs = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);
  static const EdgeInsets horizontalSection = EdgeInsets.symmetric(horizontal: section);
  static const EdgeInsets horizontalPage = EdgeInsets.symmetric(horizontal: page);
  static const EdgeInsets horizontalMajor = EdgeInsets.symmetric(horizontal: major);

  // Vertical Padding
  static const EdgeInsets verticalXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);
  static const EdgeInsets verticalSection = EdgeInsets.symmetric(vertical: section);
  static const EdgeInsets verticalPage = EdgeInsets.symmetric(vertical: page);
  static const EdgeInsets verticalMajor = EdgeInsets.symmetric(vertical: major);

  // Vertical Gap (SizedBox)
  static const SizedBox gapXs = SizedBox(height: xs);
  static const SizedBox gapSm = SizedBox(height: sm);
  static const SizedBox gapMd = SizedBox(height: md);
  static const SizedBox gapLg = SizedBox(height: lg);
  static const SizedBox gapXl = SizedBox(height: xl);
  static const SizedBox gapXxl = SizedBox(height: xxl);
  static const SizedBox gapXxxl = SizedBox(height: xxxl);
  static const SizedBox gapSection = SizedBox(height: section);
  static const SizedBox gapPage = SizedBox(height: page);
  static const SizedBox gapMajor = SizedBox(height: major);

  // Horizontal Gap (SizedBox)
  static const SizedBox gapHorizontalXs = SizedBox(width: xs);
  static const SizedBox gapHorizontalSm = SizedBox(width: sm);
  static const SizedBox gapHorizontalMd = SizedBox(width: md);
  static const SizedBox gapHorizontalLg = SizedBox(width: lg);
  static const SizedBox gapHorizontalXl = SizedBox(width: xl);
  static const SizedBox gapHorizontalXxl = SizedBox(width: xxl);
  static const SizedBox gapHorizontalSection = SizedBox(width: section);
  static const SizedBox gapHorizontalPage = SizedBox(width: page);
  static const SizedBox gapHorizontalMajor = SizedBox(width: major);
}
