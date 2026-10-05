import 'dart:async';

import 'printer_profile.dart';

/// All states a thermal-printer connection can be in.
///
/// Callers should branch on this enum to show appropriate user-facing messages.
enum BluetoothPrinterConnectionState {
  /// Initial/idle state – nothing has been attempted yet.
  idle,

  /// Bluetooth adapter is off on the device.
  bluetoothOff,

  /// The necessary runtime permissions have been denied.
  permissionDenied,

  /// Actively scanning for nearby printers.
  scanning,

  /// Connecting to a specific printer.
  connecting,

  /// Successfully connected and ready to print.
  connected,

  /// The printer disconnected unexpectedly or was manually disconnected.
  disconnected,

  /// A connection attempt failed.
  connectionFailed,

  /// A print job is in progress.
  printing,

  /// The last print job failed.
  printFailed,
}

/// Discovered Bluetooth device representation returned by scan.
///
/// Intentionally thin so callers do not depend on bluetooth_print_plus types.
class DiscoveredPrinter {
  final String name;
  final String address;

  const DiscoveredPrinter({required this.name, required this.address});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredPrinter &&
          runtimeType == other.runtimeType &&
          address == other.address;

  @override
  int get hashCode => address.hashCode;

  @override
  String toString() => 'DiscoveredPrinter($name @ $address)';
}

/// Abstract interface for the Bluetooth thermal-printer service.
///
/// Consumers (Cubits, Widgets) depend only on this abstraction.
/// The concrete implementation lives in [BluetoothPrinterServiceImpl].
///
/// Arabic note:
///   All user-facing error messages are resolved by the Cubit layer from
///   [AppStrings], NOT from within this service.  This service throws
///   [BluetoothPrinterException] with an [errorCode] that the Cubit maps
///   to a localised string.
abstract class BluetoothPrinterService {
  /// Stream of connection-state changes.
  Stream<BluetoothPrinterConnectionState> get connectionState;

  /// Stream of available devices discovered during a scan.
  Stream<List<DiscoveredPrinter>> get scanResults;

  /// Whether the service is currently scanning.
  bool get isScanning;

  /// Currently connected printer profile, or null.
  PrinterProfile? get connectedProfile;

  /// Last known connection state (synchronous read).
  BluetoothPrinterConnectionState get currentState;

  // ---------------------------------------------------------------------------
  // Printer persistence
  // ---------------------------------------------------------------------------

  /// Load the previously saved printer profile from local storage.
  /// Returns null if no profile has been saved.
  Future<PrinterProfile?> loadSavedProfile();

  /// Persist the given profile to local storage.
  Future<void> saveProfile(PrinterProfile profile);

  /// Remove the saved profile from local storage.
  Future<void> clearSavedProfile();

  // ---------------------------------------------------------------------------
  // Discovery
  // ---------------------------------------------------------------------------

  /// Request Bluetooth permissions if not already granted.
  /// Returns true if permissions are sufficient to proceed.
  Future<bool> requestPermissions();

  /// Start a Bluetooth scan for nearby printers.
  ///
  /// The scan automatically stops after [timeout].
  /// Throws [BluetoothPrinterException] with [BluetoothPrinterErrorCode.bluetoothOff]
  /// if the adapter is disabled.
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)});

  /// Stop an ongoing scan.
  Future<void> stopScan();

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  /// Connect to the given [printer].
  ///
  /// Throws [BluetoothPrinterException] on failure.
  Future<void> connect(DiscoveredPrinter printer, {PrinterProfile? profile});

  /// Disconnect from the current printer.
  Future<void> disconnect();

  /// Attempt to reconnect to the [profile] that was previously saved.
  ///
  /// Silent no-op if no profile is saved or Bluetooth is off.
  Future<void> reconnectIfNeeded();

  // ---------------------------------------------------------------------------
  // Printing
  // ---------------------------------------------------------------------------

  /// Send raw bytes to the connected printer.
  /// Throws [BluetoothPrinterException] if not connected or on failure.
  Future<void> writeBytes(List<int> bytes);

  /// Send a sequence of complete command blocks to the connected printer with an optional delay between blocks.
  /// Each block must be an independent, complete valid printer command.
  Future<void> writeBlockSequence(
    List<List<int>> blocks, {
    Duration delay = const Duration(milliseconds: 50),
  });

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Release all resources (stream subscriptions, connections).
  void dispose();
}

/// Error codes returned by [BluetoothPrinterException].
enum BluetoothPrinterErrorCode {
  bluetoothOff,
  permissionDenied,
  notConnected,
  connectionFailed,
  connectionTimeout,
  printFailed,
  scanFailed,
  unknown,
}

/// Exception thrown by [BluetoothPrinterService] operations.
class BluetoothPrinterException implements Exception {
  final BluetoothPrinterErrorCode errorCode;
  final String diagnosticMessage;

  const BluetoothPrinterException({
    required this.errorCode,
    required this.diagnosticMessage,
  });

  @override
  String toString() =>
      'BluetoothPrinterException(${errorCode.name}): $diagnosticMessage';
}
