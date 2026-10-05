enum PaymentMethod {
  cash('cash'),
  instapay('instapay'),
  ewallet('ewallet');

  final String value;

  const PaymentMethod(this.value);

  static PaymentMethod fromValue(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('_', '');
    for (final method in PaymentMethod.values) {
      if (method.value == value ||
          method.name.toLowerCase() == normalized ||
          method.value.replaceAll('_', '') == normalized) {
        return method;
      }
    }
    throw ArgumentError.value(value, 'value', 'Unknown PaymentMethod');
  }
}
