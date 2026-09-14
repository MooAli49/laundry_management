import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/domain/enums/report_period.dart';

void main() {
  group('ReportPeriod Enum & Date Resolution Tests', () {
    final fixedNow = DateTime(2026, 8, 25, 14, 30, 0);

    test('verifies all approved Arabic labels', () {
      expect(ReportPeriod.today.label, 'اليوم');
      expect(ReportPeriod.yesterday.label, 'أمس');
      expect(ReportPeriod.last7Days.label, 'آخر 7 أيام');
      expect(ReportPeriod.thisMonth.label, 'هذا الشهر');
      expect(ReportPeriod.lastMonth.label, 'الشهر السابق');
      expect(ReportPeriod.custom.label, 'مخصص');
    });

    test('resolves today date range correctly', () {
      final range = ReportPeriod.today.resolveDateRange(now: fixedNow);
      expect(range.start, DateTime(2026, 8, 25, 0, 0, 0));
      expect(range.end, DateTime(2026, 8, 25, 23, 59, 59, 999));
    });

    test('resolves yesterday date range correctly', () {
      final range = ReportPeriod.yesterday.resolveDateRange(now: fixedNow);
      expect(range.start, DateTime(2026, 8, 24, 0, 0, 0));
      expect(range.end, DateTime(2026, 8, 24, 23, 59, 59, 999));
    });

    test('resolves last 7 days date range correctly', () {
      final range = ReportPeriod.last7Days.resolveDateRange(now: fixedNow);
      expect(range.start, DateTime(2026, 8, 19, 0, 0, 0));
      expect(range.end, DateTime(2026, 8, 25, 23, 59, 59, 999));
    });

    test('resolves this month date range correctly', () {
      final range = ReportPeriod.thisMonth.resolveDateRange(now: fixedNow);
      expect(range.start, DateTime(2026, 8, 1, 0, 0, 0));
      expect(range.end, DateTime(2026, 8, 31, 23, 59, 59, 999));
    });

    test('resolves last month date range correctly', () {
      final range = ReportPeriod.lastMonth.resolveDateRange(now: fixedNow);
      expect(range.start, DateTime(2026, 7, 1, 0, 0, 0));
      expect(range.end, DateTime(2026, 7, 31, 23, 59, 59, 999));
    });

    test('resolves custom date range correctly', () {
      final customStart = DateTime(2026, 8, 10);
      final customEnd = DateTime(2026, 8, 20);

      final range = ReportPeriod.custom.resolveDateRange(
        customStart: customStart,
        customEnd: customEnd,
        now: fixedNow,
      );

      expect(range.start, DateTime(2026, 8, 10, 0, 0, 0));
      expect(range.end, DateTime(2026, 8, 20, 23, 59, 59, 999));
    });
  });
}
