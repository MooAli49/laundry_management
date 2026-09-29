import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'application/license/license_service.dart';
import 'core/di/injection.dart';
import 'data/sync/sync_engine.dart';

AppLifecycleListener? _appLifecycleListener;
AppLifecycleListener? _licenseLifecycleListener;

/// Attaches an [AppLifecycleListener] to trigger [SyncEngine.sync] when the application resumes.
AppLifecycleListener setupAppLifecycleSync(SyncEngine syncEngine) {
  disposeAppLifecycleSync();
  final listener = AppLifecycleListener(
    onResume: () {
      unawaited(syncEngine.sync().catchError((_, __) => syncEngine.state));
    },
  );
  _appLifecycleListener = listener;
  return listener;
}

/// Disposes the active [AppLifecycleListener] if present.
void disposeAppLifecycleSync() {
  final listener = _appLifecycleListener;
  _appLifecycleListener = null;
  try {
    listener?.dispose();
  } catch (_) {}
}

/// Attaches an [AppLifecycleListener] to call [LicenseService.checkIfDue]
/// on application resume. The service internally enforces the 24-hour
/// throttle, so this is safe to call on every resume event.
AppLifecycleListener setupAppLifecycleLicenseCheck(
  LicenseService licenseService,
) {
  _licenseLifecycleListener?.dispose();
  final listener = AppLifecycleListener(
    onResume: () {
      unawaited(licenseService.checkIfDue().catchError((_) {}));
    },
  );
  _licenseLifecycleListener = listener;
  return listener;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Intercept known Flutter framework assertion mismatch on Android Emulator
  // when forwarding host physical keyboard shortcuts (e.g. Ctrl+V / modifier keys).
  // Confined to debug mode so release builds maintain standard error dispatching.
  if (kDebugMode) {
    PlatformDispatcher.instance.onError = (error, stack) {
      if (error is AssertionError &&
          error.message?.toString().contains('hardware_keyboard.dart') ==
              true) {
        return true;
      }
      return false;
    };
  }

  await initDependencies(enableDevTestData: kDebugMode);

  // Initialize license service BEFORE runApp so GoRouter's initial redirect
  // has the correct license status on the first frame.
  // Fails open (active) if there is no cache and no connectivity.
  final licenseService = getIt<LicenseService>();
  await licenseService.initialize();
  setupAppLifecycleLicenseCheck(licenseService);

  // Initialize foreground synchronization infrastructure (non-blocking)
  final syncEngine = getIt<SyncEngine>();
  await syncEngine.initialize();
  setupAppLifecycleSync(syncEngine);

  runApp(const LaundryManagementApp());
}
