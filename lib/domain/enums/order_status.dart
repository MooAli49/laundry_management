enum OrderStatus {
  processing('processing'),
  ready('ready'),
  completed('completed'),
  cancelled('cancelled');

  final String value;

  const OrderStatus(this.value);

  static OrderStatus fromValue(String value) {
    for (final status in OrderStatus.values) {
      if (status.value == value) {
        return status;
      }
    }
    throw ArgumentError.value(value, 'value', 'Unknown OrderStatus');
  }
}
