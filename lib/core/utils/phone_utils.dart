/// Utility functions for customer phone normalization and basic validation.
class PhoneUtils {
  PhoneUtils._();

  static final RegExp _egyptianMobileRegex = RegExp(r'^01[0125][0-9]{8}$');

  /// Normalizes a phone number by:
  /// - Trimming whitespace.
  /// - Converting Eastern Arabic-Indic numerals (٠-٩) to standard ASCII digits (0-9).
  static String normalizePhoneNumber(String phone) {
    var result = phone.trim();
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const westernDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

    for (var i = 0; i < arabicDigits.length; i++) {
      result = result.replaceAll(arabicDigits[i], westernDigits[i]);
    }
    return result;
  }

  /// Validates that [phone] is a valid Egyptian mobile number after normalization.
  /// Canonical accepted format: 01[0125]XXXXXXXX (11 digits, prefixes: 010, 011, 012, 015).
  static bool isValidCustomerPhone(String phone) {
    final normalized = normalizePhoneNumber(phone);
    return _egyptianMobileRegex.hasMatch(normalized);
  }
}
