enum RefundMethod {
  cash('cash'),
  instaPay('insta_pay'),
  eWallet('e_wallet');

  final String value;

  const RefundMethod(this.value);

  static RefundMethod fromValue(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('_', '');
    for (final method in RefundMethod.values) {
      if (method.value == value ||
          method.name.toLowerCase() == normalized ||
          method.value.replaceAll('_', '') == normalized) {
        return method;
      }
    }
    throw ArgumentError.value(value, 'value', 'Unknown RefundMethod');
  }
}
