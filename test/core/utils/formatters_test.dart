import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/utils/currency_formatter.dart';
import 'package:laundry_management/core/utils/date_formatter.dart';

void main() {
  group('Currency & Date Formatter Tests', () {
    test('CurrencyFormatter formats minor units correctly', () {
      expect(CurrencyFormatter.formatMinorUnits(1500), equals('15.00 ج.م'));
      expect(
        CurrencyFormatter.formatMinorUnits(1500, includeSymbol: false),
        equals('15.00'),
      );
      expect(CurrencyFormatter.formatMinorUnits(0), equals('0.00 ج.م'));
      expect(CurrencyFormatter.formatMinorUnits(50), equals('0.50 ج.م'));
      expect(CurrencyFormatter.formatMinorUnits(125050), equals('1250.50 ج.م'));
    });

    test('CurrencyFormatter formats numeric amounts correctly', () {
      expect(CurrencyFormatter.format(15), equals('15.00 ج.م'));
      expect(CurrencyFormatter.format(15.75), equals('15.75 ج.م'));
      expect(
        CurrencyFormatter.format(15.75, includeSymbol: false),
        equals('15.75'),
      );
    });

    test('DateFormatter formats dates and times correctly', () {
      final testDate = DateTime(2026, 9, 4, 14, 30);

      expect(DateFormatter.formatYMD(testDate), equals('2026-09-04'));
      expect(DateFormatter.formatDMY(testDate), equals('04/09/2026'));
      expect(
        DateFormatter.formatDateTime(testDate),
        equals('2026-09-04 14:30'),
      );
      expect(
        DateFormatter.formatDMYTime(testDate),
        equals('04/09/2026 14:30'),
      );
    });
  });
}
