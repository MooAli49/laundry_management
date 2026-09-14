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

  /// Formats DateTime as DD/MM/YYYY HH:mm
  static String formatDMYTime(DateTime date) {
    final dmy = formatDMY(date);
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$dmy $hour:$minute';
  }

  /// Arabic month names in chronological order (index 0 = January)
  static const List<String> arabicMonths = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  /// Formats DateTime as human-readable Arabic date (e.g. 26 أغسطس 2026)
  static String formatArabicDate(DateTime date) {
    final day = date.day;
    final monthName = arabicMonths[date.month - 1];
    final year = date.year;
    return '$day $monthName $year';
  }

  /// Formats DateTime as human-readable Arabic date with time (e.g. 26 أغسطس 2026 — 10:30 ص)
  static String formatArabicDateTime(DateTime date) {
    final datePart = formatArabicDate(date);
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour < 12 ? 'ص' : 'م';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$datePart — $hour12:$minute $period';
  }
}
