import '../services/bluetooth_printer/bluetooth_printer_service.dart';
import '../services/bluetooth_printer/printer_profile.dart';

/// Immutable state for [BluetoothPrinterCubit].
class BluetoothPrinterState {
  /// Current Bluetooth/connection state.
  final BluetoothPrinterConnectionState connectionState;

  /// Printers found during the last scan.
  final List<DiscoveredPrinter> discoveredPrinters;

  /// The currently connected printer profile (null if disconnected).
  final PrinterProfile? connectedProfile;

  /// The printer profile saved to local storage.
  final PrinterProfile? savedProfile;

  /// Non-null if the most recent scan attempt produced an error.
  final String? scanError;

  /// Non-null if the most recent connection attempt produced an error.
  final String? connectionError;

  /// Non-null if the most recent print job produced an error.
  final String? printError;

  const BluetoothPrinterState({
    this.connectionState = BluetoothPrinterConnectionState.idle,
    this.discoveredPrinters = const [],
    this.connectedProfile,
    this.savedProfile,
    this.scanError,
    this.connectionError,
    this.printError,
  });

  bool get isConnected =>
      connectionState == BluetoothPrinterConnectionState.connected;

  bool get isConfigured => savedProfile != null;

  bool get isReadyToPrint => isConfigured && isConnected;

  bool get isScanning =>
      connectionState == BluetoothPrinterConnectionState.scanning;

  bool get isConnecting =>
      connectionState == BluetoothPrinterConnectionState.connecting;

  bool get isPrinting =>
      connectionState == BluetoothPrinterConnectionState.printing;

  BluetoothPrinterState copyWith({
    BluetoothPrinterConnectionState? connectionState,
    List<DiscoveredPrinter>? discoveredPrinters,
    PrinterProfile? connectedProfile,
    PrinterProfile? savedProfile,
    String? scanError,
    String? connectionError,
    String? printError,
    bool clearDiscoveredPrinters = false,
    bool clearSavedProfile = false,
    bool clearConnectedProfile = false,
    bool clearScanError = false,
    bool clearConnectionError = false,
    bool clearPrintError = false,
  }) {
    return BluetoothPrinterState(
      connectionState: connectionState ?? this.connectionState,
      discoveredPrinters: clearDiscoveredPrinters
          ? []
          : (discoveredPrinters ?? this.discoveredPrinters),
      connectedProfile: clearConnectedProfile
          ? null
          : (connectedProfile ?? this.connectedProfile),
      savedProfile: clearSavedProfile
          ? null
          : (savedProfile ?? this.savedProfile),
      scanError: clearScanError ? null : (scanError ?? this.scanError),
      connectionError: clearConnectionError
          ? null
          : (connectionError ?? this.connectionError),
      printError: clearPrintError ? null : (printError ?? this.printError),
    );
  }
}
