import 'package:laundry_management/core/constants/app_constants.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  /// Formats integer minor units (e.g. 1500 piastres) to Egyptian Pounds ('15.00 ج.م').
  static String formatMinorUnits(int minorUnits, {bool includeSymbol = true}) {
    final double amount = minorUnits / 100.0;
    final String formatted = amount.toStringAsFixed(2);
    return includeSymbol ? '$formatted ${AppConstants.currency}' : formatted;
  }

  /// Formats a standard num amount (e.g. 15.5) to '15.50 ج.م'.
  static String format(num amount, {bool includeSymbol = true}) {
    final String formatted = amount.toStringAsFixed(2);
    return includeSymbol ? '$formatted ${AppConstants.currency}' : formatted;
  }
}
