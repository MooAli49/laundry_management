import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../services/bluetooth_printer/bluetooth_printer_service.dart';
import '../services/bluetooth_printer/printer_profile.dart';
import 'bluetooth_printer_state.dart';

/// Cubit managing the Bluetooth printer selection, discovery, connection,
/// and print operations.
///
/// This cubit is a singleton (registered in GetIt) so it persists across
/// navigation events and keeps the printer connection alive.
class BluetoothPrinterCubit extends Cubit<BluetoothPrinterState> {
  final BluetoothPrinterService _printerService;

  StreamSubscription<BluetoothPrinterConnectionState>? _connStateSub;
  StreamSubscription<List<DiscoveredPrinter>>? _scanSub;
  Future<void>? _initFuture;

  BluetoothPrinterCubit({required BluetoothPrinterService printerService})
    : _printerService = printerService,
      super(const BluetoothPrinterState()) {
    _subscribeToService();
  }

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  /// Load saved profile and attempt reconnect.  Call once after registration.
  Future<void> init() {
    return _initFuture ??= _loadSavedProfile();
  }

  Future<void> _loadSavedProfile() async {
    final saved = await _printerService.loadSavedProfile();
    dev.log(
      '[BluetoothPrinterCubit] savedProfile=$saved',
      name: 'BluetoothPrinterCubit',
    );
    emit(state.copyWith(savedProfile: saved, clearSavedProfile: saved == null));
  }

  /// Ensures the saved profile has been loaded and attempts reconnect before
  /// the invoice flow evaluates whether Bluetooth printing is available.
  Future<void> ensurePrinterReady() async {
    await init();
    final saved = state.savedProfile;
    dev.log(
      '[BluetoothPrinterCubit] isConfigured=${saved != null}, '
      'isConnected=${state.isConnected}, '
      'isReadyToPrint=${saved != null && state.isConnected}',
      name: 'BluetoothPrinterCubit',
    );
    if (saved == null || state.isConnected) return;

    await _printerService.reconnectIfNeeded();
    final connectedProfile = _printerService.connectedProfile;
    emit(
      state.copyWith(
        connectionState: _printerService.currentState,
        connectedProfile: connectedProfile,
        clearConnectedProfile: connectedProfile == null,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Service subscriptions
  // ---------------------------------------------------------------------------

  void _subscribeToService() {
    _connStateSub = _printerService.connectionState.listen((connState) {
      dev.log(
        '[BluetoothPrinterCubit] connectionState: $connState',
        name: 'BluetoothPrinterCubit',
      );
      emit(
        state.copyWith(
          connectionState: connState,
          connectedProfile: _printerService.connectedProfile,
          clearConnectedProfile:
              connState != BluetoothPrinterConnectionState.connected,
          clearPrintError:
              connState == BluetoothPrinterConnectionState.printing,
        ),
      );
    });

    _scanSub = _printerService.scanResults.listen((results) {
      emit(state.copyWith(discoveredPrinters: results));
    });
  }

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  Future<void> requestPermissions() async {
    final granted = await _printerService.requestPermissions();
    if (!granted) {
      emit(state.copyWith(connectionState: _printerService.currentState));
    }
  }

  // ---------------------------------------------------------------------------
  // Discovery
  // ---------------------------------------------------------------------------

  Future<void> startScan() async {
    emit(state.copyWith(clearDiscoveredPrinters: true, clearScanError: true));
    try {
      await _printerService.startScan();
    } on BluetoothPrinterException catch (e) {
      dev.log(
        '[BluetoothPrinterCubit] startScan failed: $e',
        name: 'BluetoothPrinterCubit',
      );
      emit(
        state.copyWith(
          connectionState: _printerService.currentState,
          scanError: _mapErrorCode(e.errorCode),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(scanError: 'حدث خطأ غير متوقع أثناء البحث عن الطابعات'),
      );
    }
  }

  Future<void> stopScan() async {
    await _printerService.stopScan();
  }

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  Future<void> connect(
    DiscoveredPrinter printer, {
    ThermalPaperWidth paperWidth = ThermalPaperWidth.w80,
    PrinterProtocol protocol = PrinterProtocol.auto,
  }) async {
    emit(
      state.copyWith(
        connectionState: BluetoothPrinterConnectionState.connecting,
        clearConnectionError: true,
      ),
    );
    try {
      final profile = PrinterProfile(
        name: printer.name,
        address: printer.address,
        paperWidth: paperWidth,
        protocol: protocol,
      );
      await _printerService.connect(printer, profile: profile);
      // Save profile on successful connection
      await _printerService.saveProfile(profile);
      emit(state.copyWith(savedProfile: profile));
    } on BluetoothPrinterException catch (e) {
      dev.log(
        '[BluetoothPrinterCubit] connect failed: $e',
        name: 'BluetoothPrinterCubit',
      );
      emit(
        state.copyWith(
          connectionState: BluetoothPrinterConnectionState.connectionFailed,
          connectionError: _mapErrorCode(e.errorCode),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          connectionState: BluetoothPrinterConnectionState.connectionFailed,
          connectionError: 'فشل الاتصال بالطابعة',
        ),
      );
    }
  }

  Future<void> disconnect() async {
    await _printerService.disconnect();
  }

  Future<void> forgetPrinter() async {
    await _printerService.disconnect();
    await _printerService.clearSavedProfile();
    emit(
      state.copyWith(
        clearSavedProfile: true,
        clearConnectedProfile: true,
        connectionState: BluetoothPrinterConnectionState.idle,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Printing
  // ---------------------------------------------------------------------------

  /// Alias for [writeBytes] to send a complete print payload.
  Future<void> write(List<int> bytes) => writeBytes(bytes);

  Future<void> writeBytes(List<int> bytes) async {
    emit(
      state.copyWith(
        connectionState: BluetoothPrinterConnectionState.printing,
        clearPrintError: true,
      ),
    );
    try {
      await _printerService.writeBytes(bytes);
      emit(
        state.copyWith(
          connectionState: BluetoothPrinterConnectionState.connected,
        ),
      );
      dev.log(
        '[BluetoothPrinterCubit] PRINT SUCCESS bytes=${bytes.length}',
        name: 'BluetoothPrinterCubit',
      );
    } on BluetoothPrinterException catch (e) {
      dev.log(
        '[BluetoothPrinterCubit] PRINT FAILED error=$e',
        name: 'BluetoothPrinterCubit',
      );
      emit(
        state.copyWith(
          connectionState: BluetoothPrinterConnectionState.printFailed,
          printError: _mapErrorCode(e.errorCode),
        ),
      );
      rethrow;
    } catch (e) {
      dev.log(
        '[BluetoothPrinterCubit] PRINT FAILED error=$e',
        name: 'BluetoothPrinterCubit',
      );
      emit(
        state.copyWith(
          connectionState: BluetoothPrinterConnectionState.printFailed,
          printError: 'فشلت عملية الطباعة',
        ),
      );
      rethrow;
    }
  }

  Future<void> writeBlockSequence(
    List<List<int>> blocks, {
    Duration delay = const Duration(milliseconds: 50),
  }) async {
    emit(
      state.copyWith(
        connectionState: BluetoothPrinterConnectionState.printing,
        clearPrintError: true,
      ),
    );
    try {
      await _printerService.writeBlockSequence(blocks, delay: delay);
      emit(
        state.copyWith(
          connectionState: BluetoothPrinterConnectionState.connected,
        ),
      );
    } on BluetoothPrinterException catch (e) {
      dev.log(
        '[BluetoothPrinterCubit] PRINT BLOCK SEQUENCE FAILED error=$e',
        name: 'BluetoothPrinterCubit',
      );
      emit(
        state.copyWith(
          connectionState: BluetoothPrinterConnectionState.printFailed,
          printError: _mapErrorCode(e.errorCode),
        ),
      );
      rethrow;
    } catch (e) {
      dev.log(
        '[BluetoothPrinterCubit] PRINT BLOCK SEQUENCE FAILED error=$e',
        name: 'BluetoothPrinterCubit',
      );
      emit(
        state.copyWith(
          connectionState: BluetoothPrinterConnectionState.printFailed,
          printError: 'فشلت عملية الطباعة',
        ),
      );
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Error mapping (error codes → Arabic user-facing messages)
  // ---------------------------------------------------------------------------

  String _mapErrorCode(BluetoothPrinterErrorCode code) {
    switch (code) {
      case BluetoothPrinterErrorCode.bluetoothOff:
        return 'البلوتوث مغلق. يرجى تشغيله والمحاولة مجدداً.';
      case BluetoothPrinterErrorCode.permissionDenied:
        return 'صلاحية البلوتوث مطلوبة. يرجى منح الصلاحيات من إعدادات الجهاز.';
      case BluetoothPrinterErrorCode.notConnected:
        return 'الطابعة غير متصلة. يرجى الاتصال بالطابعة أولاً.';
      case BluetoothPrinterErrorCode.connectionFailed:
        return 'فشل الاتصال بالطابعة. يرجى التأكد من تشغيل الطابعة والمحاولة مجدداً.';
      case BluetoothPrinterErrorCode.connectionTimeout:
        return 'انتهت مهلة الاتصال بالطابعة. يرجى المحاولة مجدداً.';
      case BluetoothPrinterErrorCode.printFailed:
        return 'فشلت عملية الطباعة. يرجى التحقق من اتصال الطابعة والمحاولة مجدداً.';
      case BluetoothPrinterErrorCode.scanFailed:
        return 'فشل البحث عن الطابعات. يرجى التحقق من صلاحيات البلوتوث.';
      case BluetoothPrinterErrorCode.unknown:
        return 'حدث خطأ غير متوقع.';
    }
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<void> close() async {
    await _connStateSub?.cancel();
    await _scanSub?.cancel();
    await super.close();
  }
}
