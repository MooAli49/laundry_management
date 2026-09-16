import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:laundry_management/app.dart';
import 'package:laundry_management/core/di/injection.dart';
import 'package:laundry_management/data/sync/sync_engine.dart';

AppLifecycleListener? _appLifecycleListener;

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Intercept known Flutter framework assertion mismatch on Android Emulator
  // when forwarding host physical keyboard shortcuts (e.g. Ctrl+V / modifier keys).
  PlatformDispatcher.instance.onError = (error, stack) {
    if (error is AssertionError &&
        error.message?.toString().contains('hardware_keyboard.dart') == true) {
      return true;
    }
    return false;
  };

  await initDependencies(enableDevTestData: true);

  // Initialize foreground synchronization infrastructure (non-blocking)
  final syncEngine = getIt<SyncEngine>();
  await syncEngine.initialize();
  setupAppLifecycleSync(syncEngine);

  runApp(const LaundryManagementApp());
}
