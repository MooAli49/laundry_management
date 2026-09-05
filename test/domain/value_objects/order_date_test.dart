import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';

void main() {
  group('OrderDate Value Object', () {
    test('constructs date and formats as YYYY-MM-DD', () {
      final date = OrderDate(2026, 9, 4);
      expect(date.year, 2026);
      expect(date.month, 9);
      expect(date.day, 4);
      expect(date.toString(), '2026-09-04');
    });

    test('constructs from DateTime and converts to DateTime UTC midnight', () {
      final dt = DateTime(2026, 5, 12, 18, 45, 30);
      final orderDate = OrderDate.fromDate(dt);

      expect(orderDate.year, 2026);
      expect(orderDate.month, 5);
      expect(orderDate.day, 12);

      final utcDt = orderDate.toDateTime();
      expect(utcDt, DateTime.utc(2026, 5, 12));
    });

    test('parses ISO date string correctly', () {
      final parsed = OrderDate.parse('2026-12-31');
      expect(parsed, OrderDate(2026, 12, 31));
    });

    test('validates month and day ranges', () {
      expect(() => OrderDate(2026, 0, 15), throwsArgumentError);
      expect(() => OrderDate(2026, 13, 15), throwsArgumentError);
      expect(() => OrderDate(2026, 6, 0), throwsArgumentError);
      expect(() => OrderDate(2026, 6, 32), throwsArgumentError);
    });

    test('supports chronological comparisons', () {
      final d1 = OrderDate(2026, 1, 10);
      final d2 = OrderDate(2026, 1, 20);
      final d3 = OrderDate(2026, 2, 1);

      expect(d1.isBefore(d2), isTrue);
      expect(d3.isAfter(d2), isTrue);
      expect(d1.isSameDay(OrderDate(2026, 1, 10)), isTrue);
      expect(d1 == OrderDate(2026, 1, 10), isTrue);
    });

    test('isBeforeToday correctly identifies past dates', () {
      final pastDate = OrderDate(2020, 1, 1);
      final futureDate = OrderDate(2099, 1, 1);

      expect(pastDate.isBeforeToday, isTrue);
      expect(futureDate.isBeforeToday, isFalse);
    });
  });
}
