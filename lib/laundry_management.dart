import 'package:flutter/material.dart';
import 'package:laundry_management/core/routing/app_router.dart';
import 'package:laundry_management/core/theme/app_theme.dart';
import 'package:laundry_management/core/theme/theme_manager.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class LaundryManagement extends StatelessWidget {
  const LaundryManagement({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812), // Standard design size, adjust if needed
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) {
        return ListenableBuilder(
          listenable: ThemeManager(),
          builder: (context, child) {
            return MaterialApp.router(
              debugShowCheckedModeBanner: false,
              routerConfig: AppRouter.router,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: ThemeManager().themeMode,
            );
          },
        );
      },
    );
  }
}
