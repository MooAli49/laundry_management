class DateFormatter {
  DateFormatter._();

  /// Formats DateTime as YYYY-MM-DD
  static String formatYMD(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Formats DateTime as DD/MM/YYYY
  static String formatDMY(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString().padLeft(4, '0');
    return '$day/$month/$year';
  }

  /// Formats DateTime with time (YYYY-MM-DD HH:mm)
  static String formatDateTime(DateTime date) {
    final ymd = formatYMD(date);
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$ymd $hour:$minute';
  }
}
