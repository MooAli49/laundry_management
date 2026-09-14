class OrderDate implements Comparable<OrderDate> {
  final int year;
  final int month;
  final int day;

  OrderDate(this.year, this.month, this.day) {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'Month must be between 1 and 12');
    }
    if (day < 1 || day > 31) {
      throw ArgumentError.value(day, 'day', 'Day must be between 1 and 31');
    }
  }

  factory OrderDate.fromDate(DateTime dt) {
    return OrderDate(dt.year, dt.month, dt.day);
  }

  factory OrderDate.today() {
    final now = DateTime.now();
    return OrderDate(now.year, now.month, now.day);
  }

  factory OrderDate.parse(String isoDateString) {
    final parts = isoDateString.split('-');
    if (parts.length != 3) {
      throw FormatException('Invalid date format, expected YYYY-MM-DD', isoDateString);
    }
    return OrderDate(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  DateTime toDateTime() => DateTime.utc(year, month, day);

  bool isBefore(OrderDate other) => compareTo(other) < 0;

  bool isAfter(OrderDate other) => compareTo(other) > 0;

  bool isSameDay(OrderDate other) => compareTo(other) == 0;

  bool get isBeforeToday => isBefore(OrderDate.today());

  @override
  int compareTo(OrderDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderDate &&
          runtimeType == other.runtimeType &&
          year == other.year &&
          month == other.month &&
          day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}
