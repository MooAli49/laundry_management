class BusinessSettings {
  final String id;
  final String businessName;
  final String? address;
  final String? phone;
  final String? logoReference;
  final String? invoiceFooterText;
  final bool taxEnabled;
  final double taxRate;
  final DateTime createdAt;
  final DateTime updatedAt;

  BusinessSettings({
    required this.id,
    required this.businessName,
    this.address,
    this.phone,
    this.logoReference,
    this.invoiceFooterText,
    this.taxEnabled = false,
    this.taxRate = 0.0,
    required this.createdAt,
    required this.updatedAt,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('BusinessSettings id cannot be empty');
    }
    if (taxRate < 0.0) {
      throw ArgumentError.value(taxRate, 'taxRate', 'taxRate cannot be negative');
    }
  }

  BusinessSettings copyWith({
    String? id,
    String? businessName,
    String? address,
    String? phone,
    String? logoReference,
    String? invoiceFooterText,
    bool? taxEnabled,
    double? taxRate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BusinessSettings(
      id: id ?? this.id,
      businessName: businessName ?? this.businessName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      logoReference: logoReference ?? this.logoReference,
      invoiceFooterText: invoiceFooterText ?? this.invoiceFooterText,
      taxEnabled: taxEnabled ?? this.taxEnabled,
      taxRate: taxRate ?? this.taxRate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BusinessSettings &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          businessName == other.businessName &&
          address == other.address &&
          phone == other.phone &&
          logoReference == other.logoReference &&
          invoiceFooterText == other.invoiceFooterText &&
          taxEnabled == other.taxEnabled &&
          taxRate == other.taxRate &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        businessName,
        address,
        phone,
        logoReference,
        invoiceFooterText,
        taxEnabled,
        taxRate,
        createdAt,
        updatedAt,
      );

  @override
  String toString() =>
      'BusinessSettings(name: $businessName, taxEnabled: $taxEnabled, taxRate: $taxRate)';
}
