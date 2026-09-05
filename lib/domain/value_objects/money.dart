class Money implements Comparable<Money> {
  final int minorUnits;

  const Money.fromPiastres(this.minorUnits);

  factory Money.fromEgp(num egp) {
    return Money.fromPiastres((egp * 100).round());
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
