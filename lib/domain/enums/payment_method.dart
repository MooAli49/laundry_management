enum PaymentMethod {
  cash('cash'),
  instapay('instapay'),
  ewallet('ewallet');

  final String value;

  const PaymentMethod(this.value);

  static PaymentMethod fromValue(String value) {
    for (final method in PaymentMethod.values) {
      if (method.value == value) {
        return method;
      }
    }
    throw ArgumentError.value(value, 'value', 'Unknown PaymentMethod');
  }
}
