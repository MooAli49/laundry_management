import 'package:flutter/material.dart';
import 'package:laundry_management/core/localization/app_strings.dart';
import 'package:laundry_management/core/theme/app_text_styles.dart';

class StorageScreen extends StatelessWidget {
  const StorageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.storage)),
      body: const Center(
        child: Text(AppStrings.storage, style: AppTextStyles.headlineLarge),
      ),
    );
  }
}
