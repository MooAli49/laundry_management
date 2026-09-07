import 'package:flutter/material.dart';
import 'package:laundry_management/app.dart';
import 'package:laundry_management/core/di/injection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies(enableDevTestData: true);
  runApp(const LaundryManagementApp());
}
