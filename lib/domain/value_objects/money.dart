class Money implements Comparable<Money> {
  final int minorUnits;

  const Money.fromPiastres(this.minorUnits);

  factory Money.fromEgp(num egp) {
    return Money.fromPiastres((egp * 100).round());
  }

  static Money? tryParseEgp(String text) {
    var clean = text.trim();
    if (clean.isEmpty) return null;
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const westernDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    for (var i = 0; i < arabicDigits.length; i++) {
      clean = clean.replaceAll(arabicDigits[i], westernDigits[i]);
    }
    final parts = clean.split('.');
    if (parts.length > 2) return null;
    final pounds = int.tryParse(parts[0]);
    if (pounds == null || pounds < 0) return null;
    int piastres = pounds * 100;
    if (parts.length == 2) {
      final fraction = parts[1];
      if (fraction.length > 2) return null;
      if (fraction.length == 2) {
        final fractionVal = int.tryParse(fraction);
        if (fractionVal == null || fractionVal < 0) return null;
        piastres += fractionVal;
      } else if (fraction.length == 1) {
        final fractionVal = int.tryParse(fraction);
        if (fractionVal == null || fractionVal < 0) return null;
        piastres += fractionVal * 10;
      }
    }
    return Money.fromPiastres(piastres);
  }

  static const Money zero = Money.fromPiastres(0);

  int get piastres => minorUnits;

  double get toEgp => minorUnits / 100.0;

  bool get isZero => minorUnits == 0;

  bool get isPositive => minorUnits > 0;

  bool get isNegative => minorUnits < 0;

  Money operator +(Money other) {
    return Money.fromPiastres(minorUnits + other.minorUnits);
  }

  Money operator -(Money other) {
    return Money.fromPiastres(minorUnits - other.minorUnits);
  }

  Money operator *(num multiplier) {
    return Money.fromPiastres((minorUnits * multiplier).round());
  }

  bool operator <(Money other) => minorUnits < other.minorUnits;

  bool operator <=(Money other) => minorUnits <= other.minorUnits;

  bool operator >(Money other) => minorUnits > other.minorUnits;

  bool operator >=(Money other) => minorUnits >= other.minorUnits;

  @override
  int compareTo(Money other) => minorUnits.compareTo(other.minorUnits);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money &&
          runtimeType == other.runtimeType &&
          minorUnits == other.minorUnits;

  @override
  int get hashCode => minorUnits.hashCode;

  @override
  String toString() => 'Money(${toEgp.toStringAsFixed(2)} EGP)';
}
