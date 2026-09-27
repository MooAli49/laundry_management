import 'dart:async';
import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:bluetooth_print_plus/bluetooth_print_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bluetooth_printer_service.dart';
import 'printer_profile.dart';
import 'thermal_command_builder.dart';

/// SharedPreferences keys for printer persistence.
const _kPrinterName = 'bt_printer_name';
const _kPrinterAddress = 'bt_printer_address';
const _kPrinterPaperWidth = 'bt_printer_paper_width_mm';
const _kPrinterProtocol = 'bt_printer_protocol';

/// Concrete implementation of [BluetoothPrinterService] backed by the
/// [bluetooth_print_plus] package.
///
/// Responsibilities:
///   • Scanning for Bluetooth printers via BluetoothPrintPlus
///   • Managing the connection state stream
///   • Persisting the selected printer profile via SharedPreferences
///   • Writing raw print bytes to the connected device
///   • Translating SDK exceptions into [BluetoothPrinterException]
///
/// ⚠️  Android permissions must be requested before calling [startScan].
///     The [requestPermissions] method uses the platform-channel approach
///     provided by the package's own permission handling.  For Android 12+
///     BLUETOOTH_SCAN / BLUETOOTH_CONNECT are required; for 6–11
///     ACCESS_FINE_LOCATION is required.  All permissions are declared in
///     AndroidManifest.xml.
class BluetoothPrinterServiceImpl implements BluetoothPrinterService {
  // -------------------------------------------------------------------------
  // Internal state
  // -------------------------------------------------------------------------

  final _stateController =
      StreamController<BluetoothPrinterConnectionState>.broadcast();

  final _scanResultsController =
      StreamController<List<DiscoveredPrinter>>.broadcast();

  BluetoothPrinterConnectionState _currentState =
      BluetoothPrinterConnectionState.idle;

  PrinterProfile? _connectedProfile;
  Future<void>? _connectFuture;
  int _connectionGeneration = 0;
  int? _activeNativeGeneration;
  bool _isScanning = false;
  bool _disposed = false;

  // bluetooth_print_plus stream subscriptions
  StreamSubscription<List<BluetoothDevice>>? _scanSub;
  StreamSubscription<ConnectStateEvent>? _connectStateSub;
  StreamSubscription<bool>? _isScanSub;
  StreamSubscription<BlueState>? _blueStateSub;

  // -------------------------------------------------------------------------
  // BluetoothPrinterService interface — streams & accessors
  // -------------------------------------------------------------------------

  @override
  Stream<BluetoothPrinterConnectionState> get connectionState =>
      _stateController.stream;

  @override
  Stream<List<DiscoveredPrinter>> get scanResults =>
      _scanResultsController.stream;

  @override
  bool get isScanning => _isScanning;

  @override
  PrinterProfile? get connectedProfile => _connectedProfile;

  @override
  BluetoothPrinterConnectionState get currentState => _currentState;

  // -------------------------------------------------------------------------
  // Initialisation – call once after construction
  // -------------------------------------------------------------------------

  /// Must be called once after construction to set up internal subscriptions.
  void init() {
    _blueStateSub = BluetoothPrintPlus.blueState.listen((blueState) {
      dev.log(
        '[BluetoothPrinterService] blueState=$blueState',
        name: 'BluetoothPrinterService',
      );
      if (blueState == BlueState.blueOff) {
        _emitState(BluetoothPrinterConnectionState.bluetoothOff);
      } else if (_currentState ==
          BluetoothPrinterConnectionState.bluetoothOff) {
        _emitState(BluetoothPrinterConnectionState.idle);
      }
    });

    _isScanSub = BluetoothPrintPlus.isScanning.listen((scanning) {
      _isScanning = scanning;
      dev.log(
        '[BluetoothPrinterService] isScanning=$scanning',
        name: 'BluetoothPrinterService',
      );
    });

    _connectStateSub = BluetoothPrintPlus.connectStateEvents.listen((event) {
      final state = _mapConnectState(event.state);
      final attempt = _connectionGeneration;
      dev.log(
        '[DART SERVICE] event received attempt=${event.connectionAttempt} '
        'generation=${event.generation}',
        name: 'BluetoothPrinterService',
      );
      dev.log(
        '[DART SERVICE] expectedAttempt=$attempt '
        'expectedGeneration=$_activeNativeGeneration',
        name: 'BluetoothPrinterService',
      );
      final isCurrentAttempt =
          event.connectionAttempt == null || event.connectionAttempt == attempt;
      final isCurrentGeneration =
          event.generation == null ||
          event.generation == _activeNativeGeneration;
      if (!isCurrentAttempt || !isCurrentGeneration) {
        dev.log(
          '[BluetoothPrinterService] IGNORING STALE CALLBACK '
          'connectionAttempt=${event.connectionAttempt} '
          'currentAttempt=$attempt callbackNativeGeneration=${event.generation} '
          'currentNativeGeneration=$_activeNativeGeneration callback=$state',
          name: 'BluetoothPrinterService',
        );
        return;
      }
      dev.log(
        '[DART SERVICE] accepted=true attempt=$attempt generation=${event.generation}',
        name: 'BluetoothPrinterService',
      );
      if (event.generation != null && _activeNativeGeneration == null) {
        _activeNativeGeneration = event.generation;
      }
      dev.log(
        '[BluetoothPrinterService] connectionAttempt=$attempt '
        'callbackNativeGeneration=${event.generation} '
        'currentNativeGeneration=$_activeNativeGeneration accepted=true',
        name: 'BluetoothPrinterService',
      );
      dev.log(
        '[BluetoothPrinterService] connectionAttempt=$attempt state=$state',
        name: 'BluetoothPrinterService',
      );
      _emitState(state);
      if (state == BluetoothPrinterConnectionState.disconnected ||
          state == BluetoothPrinterConnectionState.connectionFailed) {
        // Keep profile so reconnect can be attempted, but clear connected ref.
        _connectedProfile = null;
      }
    });

    _scanSub = BluetoothPrintPlus.scanResults.listen((devices) {
      final discovered = devices
          .map(
            (d) => DiscoveredPrinter(
              name: d.name.isNotEmpty ? d.name : '(بدون اسم)',
              address: d.address,
            ),
          )
          .toList();
      _scanResultsController.add(discovered);
    });
  }

  // -------------------------------------------------------------------------
  // Permission handling
  // -------------------------------------------------------------------------

  @override
  Future<bool> requestPermissions() async {
    // bluetooth_print_plus handles Android runtime permissions internally
    // when startScan / connect are called.  We check the current Bluetooth
    // adapter state as a quick guard.
    try {
      final isOn = BluetoothPrintPlus.isBlueOn;
      if (!isOn) {
        _emitState(BluetoothPrinterConnectionState.bluetoothOff);
        return false;
      }
      return true;
    } catch (e) {
      dev.log(
        '[BluetoothPrinterService] requestPermissions error: $e',
        name: 'BluetoothPrinterService',
      );
      _emitState(BluetoothPrinterConnectionState.permissionDenied);
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Persistence
  // -------------------------------------------------------------------------

  @override
  Future<PrinterProfile?> loadSavedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final address = prefs.getString(_kPrinterAddress);
      final name = prefs.getString(_kPrinterName);
      if (address == null || address.isEmpty) {
        dev.log(
          '[BluetoothPrinterService] loadedProfile=null',
          name: 'BluetoothPrinterService',
        );
        return null;
      }

      final widthMm = prefs.getInt(_kPrinterPaperWidth) ?? 80;
      final protocolName =
          prefs.getString(_kPrinterProtocol) ?? PrinterProtocol.auto.name;

      final paperWidth = ThermalPaperWidth.values.firstWhere(
        (w) => w.mm == widthMm,
        orElse: () => ThermalPaperWidth.w80,
      );
      final protocol = PrinterProtocol.values.firstWhere(
        (p) => p.name == protocolName,
        orElse: () => PrinterProtocol.auto,
      );

      final profile = PrinterProfile(
        name: name ?? address,
        address: address,
        paperWidth: paperWidth,
        protocol: protocol,
      );
      dev.log(
        '[BluetoothPrinterService] loadedProfile=$profile',
        name: 'BluetoothPrinterService',
      );
      return profile;
    } catch (e) {
      dev.log(
        '[BluetoothPrinterService] loadSavedProfile error: $e',
        name: 'BluetoothPrinterService',
      );
      return null;
    }
  }

  @override
  Future<void> saveProfile(PrinterProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrinterName, profile.name);
      await prefs.setString(_kPrinterAddress, profile.address);
      await prefs.setInt(_kPrinterPaperWidth, profile.paperWidth.mm);
      await prefs.setString(_kPrinterProtocol, profile.protocol.name);
      dev.log(
        '[BluetoothPrinterService] profile saved: $profile',
        name: 'BluetoothPrinterService',
      );
    } catch (e) {
      dev.log(
        '[BluetoothPrinterService] saveProfile error: $e',
        name: 'BluetoothPrinterService',
      );
    }
  }

  @override
  Future<void> clearSavedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPrinterName);
      await prefs.remove(_kPrinterAddress);
      await prefs.remove(_kPrinterPaperWidth);
      await prefs.remove(_kPrinterProtocol);
    } catch (e) {
      dev.log(
        '[BluetoothPrinterService] clearSavedProfile error: $e',
        name: 'BluetoothPrinterService',
      );
    }
  }

  // -------------------------------------------------------------------------
  // Discovery
  // -------------------------------------------------------------------------

  @override
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    _guardDisposed();
    dev.log(
      '[BluetoothPrinterService] starting scan (timeout: $timeout)',
      name: 'BluetoothPrinterService',
    );

    try {
      final isOn = BluetoothPrintPlus.isBlueOn;
      if (!isOn) {
        _emitState(BluetoothPrinterConnectionState.bluetoothOff);
        throw const BluetoothPrinterException(
          errorCode: BluetoothPrinterErrorCode.bluetoothOff,
          diagnosticMessage: 'Bluetooth adapter is off',
        );
      }
      _emitState(BluetoothPrinterConnectionState.scanning);
      // Clear any previous scan results
      _scanResultsController.add([]);
      await BluetoothPrintPlus.startScan(timeout: timeout);
    } on BluetoothPrinterException {
      rethrow;
    } catch (e) {
      dev.log(
        '[BluetoothPrinterService] scan error: $e',
        name: 'BluetoothPrinterService',
      );
      _emitState(BluetoothPrinterConnectionState.idle);
      throw BluetoothPrinterException(
        errorCode: BluetoothPrinterErrorCode.scanFailed,
        diagnosticMessage: 'Scan failed: $e',
      );
    }
  }

  @override
  Future<void> stopScan() async {
    try {
      await BluetoothPrintPlus.stopScan();
    } catch (e) {
      dev.log(
        '[BluetoothPrinterService] stopScan error: $e',
        name: 'BluetoothPrinterService',
      );
    }
    if (_currentState == BluetoothPrinterConnectionState.scanning) {
      _emitState(BluetoothPrinterConnectionState.idle);
    }
  }

  // -------------------------------------------------------------------------
  // Connection
  // -------------------------------------------------------------------------

  @override
  Future<void> connect(DiscoveredPrinter printer, {PrinterProfile? profile}) {
    final activeConnect = _connectFuture;
    if (activeConnect != null) {
      dev.log(
        '[BluetoothPrinterService] connection attempt already running',
        name: 'BluetoothPrinterService',
      );
      return activeConnect;
    }

    final connectFuture = _connectInternal(printer, profile: profile);
    _connectFuture = connectFuture;
    return connectFuture.whenComplete(() {
      if (identical(_connectFuture, connectFuture)) {
        _connectFuture = null;
      }
    });
  }

  Future<void> _connectInternal(
    DiscoveredPrinter printer, {
    PrinterProfile? profile,
  }) async {
    _guardDisposed();
    final attempt = ++_connectionGeneration;
    _activeNativeGeneration = attempt;
    dev.log(
      '[BluetoothPrinterService] connectionAttempt=$attempt state=connecting '
      'printer=${printer.name} @ ${printer.address}',
      name: 'BluetoothPrinterService',
    );
    dev.log(
      '[BluetoothPrinterService] connectionAttempt=$attempt '
      'expectedNativeGeneration=$_activeNativeGeneration',
      name: 'BluetoothPrinterService',
    );

    _emitState(BluetoothPrinterConnectionState.connecting);

    try {
      final device = BluetoothDevice(printer.name, printer.address);
      final connectedProfile =
          profile ??
          PrinterProfile(name: printer.name, address: printer.address);
      _connectedProfile = connectedProfile;
      final callbackFuture = BluetoothPrintPlus.connectStateEvents
          .where(
            (event) =>
                event.connectionAttempt == attempt &&
                event.generation == _activeNativeGeneration,
          )
          .firstWhere(
            (event) =>
                event.state == ConnectState.connected ||
                event.state == ConnectState.disconnected,
          )
          .timeout(const Duration(seconds: 15));
      final nativeGeneration =
          await BluetoothPrintPlus.connect(device, connectionAttempt: attempt)
              as int?;
      if (nativeGeneration != _activeNativeGeneration) {
        throw const BluetoothPrinterException(
          errorCode: BluetoothPrinterErrorCode.connectionFailed,
          diagnosticMessage: 'Native connection generation mismatch',
        );
      }
      final connectState = (await callbackFuture).state;
      if (connectState != ConnectState.connected) {
        throw const BluetoothPrinterException(
          errorCode: BluetoothPrinterErrorCode.connectionFailed,
          diagnosticMessage: 'Printer disconnected during connection',
        );
      }
      dev.log(
        '[BluetoothPrinterService] connectionAttempt=$attempt '
        'result=connected isConnected=true isReadyToPrint=true',
        name: 'BluetoothPrinterService',
      );
    } catch (e) {
      _connectedProfile = null;
      _activeNativeGeneration = null;
      dev.log(
        '[BluetoothPrinterService] connectionAttempt=$attempt state=connectionFailed error=$e',
        name: 'BluetoothPrinterService',
      );
      dev.log(
        '[BluetoothPrinterService] connectionAttempt=$attempt result=failed/timeout',
        name: 'BluetoothPrinterService',
      );
      _emitState(BluetoothPrinterConnectionState.connectionFailed);
      throw BluetoothPrinterException(
        errorCode: BluetoothPrinterErrorCode.connectionFailed,
        diagnosticMessage: 'Connection failed: $e',
      );
    }
  }

  @override
  Future<void> disconnect() async {
    _connectionGeneration++;
    _activeNativeGeneration = null;
    try {
      await BluetoothPrintPlus.disconnect();
      _connectedProfile = null;
      _emitState(BluetoothPrinterConnectionState.disconnected);
    } catch (e) {
      dev.log(
        '[BluetoothPrinterService] disconnect error: $e',
        name: 'BluetoothPrinterService',
      );
    }
  }

  @override
  Future<void> reconnectIfNeeded() async {
    if (_currentState == BluetoothPrinterConnectionState.connected) return;
    final profile = await loadSavedProfile();
    dev.log(
      '[BluetoothPrinterService] isConfigured=${profile != null}, '
      'isConnected=${BluetoothPrintPlus.isConnected}',
      name: 'BluetoothPrinterService',
    );
    if (profile == null) return;

    try {
      final isOn = BluetoothPrintPlus.isBlueOn;
      if (!isOn) return;
      final printer = DiscoveredPrinter(
        name: profile.name,
        address: profile.address,
      );
      await connect(printer, profile: profile);
    } catch (e) {
      dev.log(
        '[BluetoothPrinterService] reconnect failed silently: $e',
        name: 'BluetoothPrinterService',
      );
    }
  }

  // -------------------------------------------------------------------------
  // Printing
  // -------------------------------------------------------------------------

  @override
  Future<void> writeBytes(List<int> bytes) async {
    _guardDisposed();
    final isConnected = BluetoothPrintPlus.isConnected;
    if (!isConnected) {
      throw const BluetoothPrinterException(
        errorCode: BluetoothPrinterErrorCode.notConnected,
        diagnosticMessage: 'Printer is not connected',
      );
    }

    dev.log(
      '[BluetoothPrinterService] PRINT WRITE START bytes=${bytes.length} '
      'chunkCount=1 chunkSizes=[${bytes.length}] method=BluetoothPrintPlus.write',
      name: 'BluetoothPrinterService',
    );

    try {
      _emitState(BluetoothPrinterConnectionState.printing);
      final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
      await BluetoothPrintPlus.write(data);
      dev.log(
        '[BluetoothPrinterService] PRINT WRITE SUCCESS bytes=${bytes.length}',
        name: 'BluetoothPrinterService',
      );
      // Return to connected state after write.
      _emitState(BluetoothPrinterConnectionState.connected);
    } catch (e, stackTrace) {
      dev.log(
        '[BluetoothPrinterService] PRINT WRITE FAILURE error=$e',
        name: 'BluetoothPrinterService',
        error: e,
        stackTrace: stackTrace,
      );
      _emitState(BluetoothPrinterConnectionState.printFailed);
      throw BluetoothPrinterException(
        errorCode: BluetoothPrinterErrorCode.printFailed,
        diagnosticMessage: 'Print write failed: $e',
      );
    }
  }

  @override
  Future<void> diagnosticPrint() async {
    dev.log('DIAGNOSTIC RASTER START', name: 'BluetoothPrinterService');
    final command = ThermalCommandBuilder.buildDiagnosticRasterCommand();
    const width = 128;
    const height = 64;
    const widthBytes = 16;
    const rasterPayloadLength = widthBytes * height;
    const rasterHeaderOffset = 8;
    final rasterHeader = command.sublist(
      rasterHeaderOffset,
      rasterHeaderOffset + 8,
    );
    final actualRasterLength = command.length - 16 - 3;
    if (rasterHeader.join(',') != '29,118,48,0,16,0,64,0' ||
        actualRasterLength != rasterPayloadLength) {
      throw StateError(
        'Invalid diagnostic raster command: header=$rasterHeader '
        'actualRasterLength=$actualRasterLength',
      );
    }
    dev.log(
      'DIAGNOSTIC RASTER COMMAND BUILT protocol=ESC/POS '
      'width=$width height=$height widthBytes=$widthBytes '
      'rasterPayloadLength=$rasterPayloadLength '
      'totalCommandLength=${command.length}',
      name: 'BluetoothPrinterService',
    );
    try {
      dev.log(
        'DIAGNOSTIC RASTER WRITE bytes=${command.length}',
        name: 'BluetoothPrinterService',
      );
      await writeBytes(command);
      dev.log('DIAGNOSTIC RASTER SUCCESS', name: 'BluetoothPrinterService');
    } catch (error, stackTrace) {
      dev.log(
        'DIAGNOSTIC RASTER FAILED error=$error',
        name: 'BluetoothPrinterService',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> diagnosticRasterPrint() async {
    await diagnosticRasterPrintVariant(DiagnosticRasterFormat.gsV0);
  }

  @override
  Future<void> diagnosticRasterPrintVariant(
    DiagnosticRasterFormat format,
  ) async {
    final command = switch (format) {
      DiagnosticRasterFormat.gsV0 =>
        ThermalCommandBuilder.buildDiagnosticRasterCommand(),
      DiagnosticRasterFormat.gsL =>
        ThermalCommandBuilder.buildDiagnosticGsLCommand(),
    };
    const payloadLength = 16 * 64;
    final headerLength = format == DiagnosticRasterFormat.gsV0 ? 16 : 13;
    dev.log(
      'DIAGNOSTIC FORMAT=${format.name.toUpperCase()} '
      'commandLength=${command.length} '
      'headerHex=${_hex(command.take(headerLength).toList())} '
      'payloadLength=$payloadLength',
      name: 'BluetoothPrinterService',
    );
    try {
      await writeBytes(command);
      dev.log(
        'DIAGNOSTIC FORMAT=${format.name.toUpperCase()} write result=SUCCESS',
        name: 'BluetoothPrinterService',
      );
    } catch (error, stackTrace) {
      dev.log(
        'DIAGNOSTIC FORMAT=${format.name.toUpperCase()} write result=FAILED error=$error',
        name: 'BluetoothPrinterService',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  String _hex(List<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ');

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _scanSub?.cancel();
    _connectStateSub?.cancel();
    _isScanSub?.cancel();
    _blueStateSub?.cancel();
    _stateController.close();
    _scanResultsController.close();
    dev.log(
      '[BluetoothPrinterService] disposed',
      name: 'BluetoothPrinterService',
    );
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  void _emitState(BluetoothPrinterConnectionState state) {
    _currentState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  void _guardDisposed() {
    if (_disposed) {
      throw const BluetoothPrinterException(
        errorCode: BluetoothPrinterErrorCode.unknown,
        diagnosticMessage: 'BluetoothPrinterService has been disposed',
      );
    }
  }

  /// Maps bluetooth_print_plus ConnectState to our domain enum.
  BluetoothPrinterConnectionState _mapConnectState(ConnectState state) {
    switch (state) {
      case ConnectState.connected:
        return BluetoothPrinterConnectionState.connected;
      case ConnectState.disconnected:
        return BluetoothPrinterConnectionState.disconnected;
    }
  }
}
