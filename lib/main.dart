import 'package:flutter/material.dart';
import 'package:laundry_management/core/di/injection.dart';
import 'package:laundry_management/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();
  runApp(const LaundryManagementApp());
}
