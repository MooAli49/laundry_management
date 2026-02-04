import 'package:flutter/material.dart';
import 'package:laundry_management/core/routing/app_router.dart';

class LaundryManagement extends StatelessWidget {
  const LaundryManagement({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: AppRouter.router,
    );
  }
}
