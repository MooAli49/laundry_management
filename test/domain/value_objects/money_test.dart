import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/domain/value_objects/money.dart';

void main() {
  group('Money Value Object', () {
    test('constructs from piastres and converts to EGP', () {
      const money = Money.fromPiastres(1250);
      expect(money.piastres, 1250);
      expect(money.toEgp, 12.50);
      expect(money.toString(), 'Money(12.50 EGP)');
    });

    test('constructs from EGP accurately', () {
      final money = Money.fromEgp(15.75);
      expect(money.piastres, 1575);
      expect(money.toEgp, 15.75);
    });

    test('supports arithmetic operators (+, -, *)', () {
      const m1 = Money.fromPiastres(500);
      const m2 = Money.fromPiastres(300);

      expect(m1 + m2, const Money.fromPiastres(800));
      expect(m1 - m2, const Money.fromPiastres(200));
      expect(m1 * 2, const Money.fromPiastres(1000));
      expect(m2 * 1.5, const Money.fromPiastres(450));
    });

    test('supports comparisons (<, <=, >, >=, ==)', () {
      const m1 = Money.fromPiastres(100);
      const m2 = Money.fromPiastres(200);
      const m3 = Money.fromPiastres(100);

      expect(m1 < m2, isTrue);
      expect(m2 > m1, isTrue);
      expect(m1 <= m3, isTrue);
      expect(m1 >= m3, isTrue);
      expect(m1 == m3, isTrue);
      expect(m1.compareTo(m2), -1);
    });

    test('flags positive, negative, zero states', () {
      expect(Money.zero.isZero, isTrue);
      expect(Money.zero.isPositive, isFalse);
      expect(Money.zero.isNegative, isFalse);

      const pos = Money.fromPiastres(10);
      expect(pos.isPositive, isTrue);
      expect(pos.isNegative, isFalse);

      const neg = Money.fromPiastres(-10);
      expect(neg.isNegative, isTrue);
      expect(neg.isPositive, isFalse);
    });
  });
}
