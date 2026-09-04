import 'package:flutter/material.dart';
import 'package:laundry_management/core/localization/app_strings.dart';
import 'package:laundry_management/core/theme/app_text_styles.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.orders)),
      body: const Center(
        child: Text(AppStrings.orders, style: AppTextStyles.headlineLarge),
      ),
    );
  }
}
