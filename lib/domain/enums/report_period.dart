enum ReportPeriod {
  today,
  yesterday,
  last7Days,
  thisMonth,
  lastMonth,
  custom;

  String get label {
    switch (this) {
      case ReportPeriod.today:
        return 'اليوم';
      case ReportPeriod.yesterday:
        return 'أمس';
      case ReportPeriod.last7Days:
        return 'آخر 7 أيام';
      case ReportPeriod.thisMonth:
        return 'هذا الشهر';
      case ReportPeriod.lastMonth:
        return 'الشهر السابق';
      case ReportPeriod.custom:
        return 'مخصص';
    }
  }

  ({DateTime start, DateTime end}) resolveDateRange({
    DateTime? customStart,
    DateTime? customEnd,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final startOfToday = DateTime(current.year, current.month, current.day);
    final endOfToday = DateTime(current.year, current.month, current.day, 23, 59, 59, 999);

    switch (this) {
      case ReportPeriod.today:
        return (start: startOfToday, end: endOfToday);

      case ReportPeriod.yesterday:
        final yesterday = startOfToday.subtract(const Duration(days: 1));
        return (
          start: DateTime(yesterday.year, yesterday.month, yesterday.day),
          end: DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59, 999),
        );

      case ReportPeriod.last7Days:
        final start7DaysAgo = startOfToday.subtract(const Duration(days: 6));
        return (start: start7DaysAgo, end: endOfToday);

      case ReportPeriod.thisMonth:
        final startOfMonth = DateTime(current.year, current.month, 1);
        final endOfMonth = DateTime(current.year, current.month + 1, 0, 23, 59, 59, 999);
        return (start: startOfMonth, end: endOfMonth);

      case ReportPeriod.lastMonth:
        final startOfLastMonth = DateTime(current.year, current.month - 1, 1);
        final endOfLastMonth = DateTime(current.year, current.month, 0, 23, 59, 59, 999);
        return (start: startOfLastMonth, end: endOfLastMonth);

      case ReportPeriod.custom:
        final start = customStart != null
            ? DateTime(customStart.year, customStart.month, customStart.day)
            : startOfToday;
        final end = customEnd != null
            ? DateTime(customEnd.year, customEnd.month, customEnd.day, 23, 59, 59, 999)
            : endOfToday;
        return (start: start, end: end);
    }
  }
}
