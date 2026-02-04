import 'package:flutter/material.dart';
import 'package:laundry_management/core/routing/app_router.dart';
import 'package:laundry_management/core/theme/app_theme.dart';

class LaundryManagement extends StatelessWidget {
  const LaundryManagement({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: AppRouter.router,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
    );
  }
}
