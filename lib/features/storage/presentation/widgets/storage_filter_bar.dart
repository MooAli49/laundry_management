import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../domain/entities/item_type.dart';
import '../../../../domain/entities/service.dart';
import '../../../../domain/entities/storage_location.dart';
import '../../../../domain/value_objects/order_date.dart';
import '../models/storage_filter.dart';
import '../models/storage_tab.dart';

class StorageFilterBar extends StatelessWidget {
  final StorageTab activeTab;
  final StorageFilter filter;
  final List<ItemType> itemTypes;
  final List<Service> services;
  final List<StorageLocation> locations;
  final ValueChanged<StorageFilter> onFilterChanged;
  final VoidCallback onResetFilters;

  const StorageFilterBar({
    super.key,
    required this.activeTab,
    required this.filter,
    required this.itemTypes,
    required this.services,
    required this.locations,
    required this.onFilterChanged,
    required this.onResetFilters,
  });

  Future<void> _selectExpectedPickupDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: filter.expectedPickupDate?.toDateTime() ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      onFilterChanged(filter.copyWith(
        expectedPickupDate: OrderDate.fromDate(picked),
      ));
    }
  }

  Future<void> _selectOrderReceivedDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: filter.orderReceivedDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      onFilterChanged(filter.copyWith(
        orderReceivedDate: picked,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Filter by Item Type
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              color: AppColors.surface,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: filter.itemTypeId,
                hint: Text(AppStrings.filterByItemType, style: AppTextStyles.bodySmall),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text(AppStrings.allItemTypes),
                  ),
                  ...itemTypes.map((t) => DropdownMenuItem<String?>(
                        value: t.id,
                        child: Text(t.name),
                      )),
                ],
                onChanged: (val) {
                  onFilterChanged(filter.copyWith(
                    itemTypeId: val,
                    clearItemTypeId: val == null,
                  ));
                },
              ),
            ),
          ),
          AppSpacing.gapHorizontalSm,

          // Filter by Service
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              color: AppColors.surface,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: filter.serviceId,
                hint: Text(AppStrings.filterByService, style: AppTextStyles.bodySmall),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text(AppStrings.allServices),
                  ),
                  ...services.map((s) => DropdownMenuItem<String?>(
                        value: s.id,
                        child: Text(s.name),
                      )),
                ],
                onChanged: (val) {
                  onFilterChanged(filter.copyWith(
                    serviceId: val,
                    clearServiceId: val == null,
                  ));
                },
              ),
            ),
          ),
          AppSpacing.gapHorizontalSm,

          // Filter by Location (Current Storage view only)
          if (activeTab == StorageTab.currentStorage) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                color: AppColors.surface,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: filter.storageLocationId,
                  hint: Text(AppStrings.filterByLocation, style: AppTextStyles.bodySmall),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text(AppStrings.allLocations),
                    ),
                    ...locations.map((loc) => DropdownMenuItem<String?>(
                          value: loc.id,
                          child: Text(loc.name),
                        )),
                  ],
                  onChanged: (val) {
                    onFilterChanged(filter.copyWith(
                      storageLocationId: val,
                      clearStorageLocationId: val == null,
                    ));
                  },
                ),
              ),
            ),
            AppSpacing.gapHorizontalSm,
          ],

          // Filter by Expected Pickup Date Chip
          FilterChip(
            label: Text(
              filter.expectedPickupDate != null
                  ? '${AppStrings.filterByExpectedPickup}: ${filter.expectedPickupDate}'
                  : AppStrings.filterByExpectedPickup,
              style: AppTextStyles.bodySmall.copyWith(
                color: filter.expectedPickupDate != null ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            selected: filter.expectedPickupDate != null,
            onSelected: (_) => _selectExpectedPickupDate(context),
            avatar: const Icon(Icons.event, size: 16),
            onDeleted: filter.expectedPickupDate != null
                ? () => onFilterChanged(filter.copyWith(clearExpectedPickupDate: true))
                : null,
          ),
          AppSpacing.gapHorizontalSm,

          // Filter by Order Received Date Chip
          FilterChip(
            label: Text(
              filter.orderReceivedDate != null
                  ? '${AppStrings.filterByOrderReceived}: ${filter.orderReceivedDate!.year}-${filter.orderReceivedDate!.month.toString().padLeft(2, '0')}-${filter.orderReceivedDate!.day.toString().padLeft(2, '0')}'
                  : AppStrings.filterByOrderReceived,
              style: AppTextStyles.bodySmall.copyWith(
                color: filter.orderReceivedDate != null ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            selected: filter.orderReceivedDate != null,
            onSelected: (_) => _selectOrderReceivedDate(context),
            avatar: const Icon(Icons.history, size: 16),
            onDeleted: filter.orderReceivedDate != null
                ? () => onFilterChanged(filter.copyWith(clearOrderReceivedDate: true))
                : null,
          ),

          // Reset Filters Button
          if (filter.isActive) ...[
            AppSpacing.gapHorizontalSm,
            TextButton.icon(
              onPressed: onResetFilters,
              icon: const Icon(Icons.clear_all, size: 16, color: AppColors.error),
              label: Text(
                AppStrings.resetFilters,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
