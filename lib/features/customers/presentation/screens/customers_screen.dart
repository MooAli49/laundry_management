import 'package:flutter/material.dart';
import 'package:laundry_management/core/localization/app_strings.dart';
import 'package:laundry_management/core/theme/app_text_styles.dart';

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.customers)),
      body: const Center(
        child: Text(AppStrings.customers, style: AppTextStyles.headlineLarge),
      ),
    );
  }
}
