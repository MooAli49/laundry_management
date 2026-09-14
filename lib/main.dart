import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:laundry_management/app.dart';
import 'package:laundry_management/core/di/injection.dart';

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
  runApp(const LaundryManagementApp());
}
