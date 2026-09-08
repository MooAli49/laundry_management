import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../domain/entities/customer.dart';
import 'add_customer_dialog.dart';

class CustomerSelector extends StatefulWidget {
  final Customer? selectedCustomer;
  final List<Customer> searchResults;
  final bool isSearching;
  final ValueChanged<String> onSearch;
  final ValueChanged<Customer?> onSelectCustomer;
  final Future<void> Function({
    required String name,
    required String phone,
    String? notes,
  }) onAddNewCustomer;

  const CustomerSelector({
    super.key,
    required this.selectedCustomer,
    required this.searchResults,
    required this.isSearching,
    required this.onSearch,
    required this.onSelectCustomer,
    required this.onAddNewCustomer,
  });

  @override
  State<CustomerSelector> createState() => _CustomerSelectorState();
}

class _CustomerSelectorState extends State<CustomerSelector> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddCustomerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AddCustomerDialog(
        initialQuery: _searchController.text,
        onSave: widget.onAddNewCustomer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedCustomer != null) {
      final customer = widget.selectedCustomer!;
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primaryLighter,
              child: Text(
                customer.name.isNotEmpty ? customer.name[0] : 'ع',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            AppSpacing.gapHorizontalMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.phone_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        customer.phone,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            AppButton(
              label: 'تغيير',
              variant: AppButtonVariant.secondary,
              onPressed: () => widget.onSelectCustomer(null),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _searchController,
                hintText: 'ابحث بالاسم أو رقم الهاتف...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary),
                onChanged: widget.onSearch,
              ),
            ),
            AppSpacing.gapHorizontalSm,
            AppButton(
              label: '+ عميل جديد',
              variant: AppButtonVariant.secondary,
              onPressed: _openAddCustomerDialog,
            ),
          ],
        ),
        if (widget.searchResults.isNotEmpty) ...[
          AppSpacing.gapSm,
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: widget.searchResults.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.divider),
              itemBuilder: (context, index) {
                final customer = widget.searchResults[index];
                return ListTile(
                  title: Text(customer.name, style: AppTextStyles.bodyMedium),
                  subtitle: Text(
                    customer.phone,
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                  ),
                  onTap: () {
                    _searchController.clear();
                    widget.onSelectCustomer(customer);
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
