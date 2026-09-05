enum PricingType {
  perPiece('per_piece'),
  perKilogram('per_kilogram'),
  perSquareMeter('per_square_meter'),
  fixedPrice('fixed_price');

  final String value;

  const PricingType(this.value);

  static PricingType fromValue(String value) {
    for (final type in PricingType.values) {
      if (type.value == value) {
        return type;
      }
    }
    throw ArgumentError.value(value, 'value', 'Unknown PricingType');
  }
}
