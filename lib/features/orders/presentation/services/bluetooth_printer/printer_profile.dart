/// Supported thermal-printer command protocols.
///
/// [escPos] – ESC/POS receipts (most common for receipt-style printers)
/// [tspl]   – TSPL/TSC label/receipt command language (used by TSC printers)
///
/// The [auto] variant lets the service choose the best default for the
/// discovered device; currently it maps to [escPos] via rasterized-image
/// printing which is universally compatible regardless of command set.
enum PrinterProtocol {
  /// ESC/POS: most common receipt printer protocol
  escPos,

  /// TSPL/TSC: label printer command language used by TSC printers
  tspl,

  /// Let the service decide based on available information.
  /// Currently resolves to image-based ESC/POS printing for maximum
  /// compatibility across unknown devices.
  auto,
}

/// Supported thermal paper widths in millimetres.
enum ThermalPaperWidth {
  w58(58),
  w76(76),
  w80(80),
  w104(104);

  const ThermalPaperWidth(this.mm);

  /// Paper width in millimetres.
  final int mm;

  /// Printable width pixels assuming 8 dots/mm (203 dpi).
  int get printablePixels => (mm - 6) * 8; // ~6 mm margin total

  String get label => '$mm مم';
}

/// Immutable value object representing a saved/selected thermal printer.
///
/// Persisted via [SharedPreferences] as individual keys; no JSON needed.
class PrinterProfile {
  /// Human-readable device name (as returned by Bluetooth scan).
  final String name;

  /// Bluetooth MAC address (Android) or UUID-based identifier (iOS).
  final String address;

  /// The paper width in use for this printer.
  final ThermalPaperWidth paperWidth;

  /// The command protocol to use when sending data.
  final PrinterProtocol protocol;

  const PrinterProfile({
    required this.name,
    required this.address,
    this.paperWidth = ThermalPaperWidth.w80,
    this.protocol = PrinterProtocol.auto,
  });

  PrinterProfile copyWith({
    String? name,
    String? address,
    ThermalPaperWidth? paperWidth,
    PrinterProtocol? protocol,
  }) {
    return PrinterProfile(
      name: name ?? this.name,
      address: address ?? this.address,
      paperWidth: paperWidth ?? this.paperWidth,
      protocol: protocol ?? this.protocol,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrinterProfile &&
          runtimeType == other.runtimeType &&
          address == other.address;

  @override
  int get hashCode => address.hashCode;

  @override
  String toString() => 'PrinterProfile(name: $name, address: $address, '
      'paper: ${paperWidth.mm}mm, protocol: $protocol)';
}
