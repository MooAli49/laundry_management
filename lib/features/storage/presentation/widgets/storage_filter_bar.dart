import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';
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
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              border: Border.all(
                color: filter.itemTypeId != null ? AppColors.primary : AppColors.border,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              color: filter.itemTypeId != null ? AppColors.primaryLighter : AppColors.surface,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: filter.itemTypeId,
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: filter.itemTypeId != null ? AppColors.primary : AppColors.textSecondary,
                ),
                hint: Text(
                  AppStrings.filterByItemType,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      AppStrings.allItemTypes,
                      style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
                    ),
                  ),
                  ...itemTypes.map((t) => DropdownMenuItem<String?>(
                        value: t.id,
                        child: Text(
                          t.name,
                          style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
                        ),
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
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              border: Border.all(
                color: filter.serviceId != null ? AppColors.primary : AppColors.border,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              color: filter.serviceId != null ? AppColors.primaryLighter : AppColors.surface,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: filter.serviceId,
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: filter.serviceId != null ? AppColors.primary : AppColors.textSecondary,
                ),
                hint: Text(
                  AppStrings.filterByService,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      AppStrings.allServices,
                      style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
                    ),
                  ),
                  ...services.map((s) => DropdownMenuItem<String?>(
                        value: s.id,
                        child: Text(
                          s.name,
                          style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
                        ),
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
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                border: Border.all(
                  color: filter.storageLocationId != null ? AppColors.primary : AppColors.border,
                ),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                color: filter.storageLocationId != null ? AppColors.primaryLighter : AppColors.surface,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: filter.storageLocationId,
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: filter.storageLocationId != null ? AppColors.primary : AppColors.textSecondary,
                  ),
                  hint: Text(
                    AppStrings.filterByLocation,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        AppStrings.allLocations,
                        style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
                      ),
                    ),
                    ...locations.map((loc) => DropdownMenuItem<String?>(
                          value: loc.id,
                          child: Text(
                            loc.name,
                            style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
                          ),
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
          InkWell(
            onTap: () => _selectExpectedPickupDate(context),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: filter.expectedPickupDate != null ? AppColors.primaryLighter : AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: filter.expectedPickupDate != null ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 16,
                    color: filter.expectedPickupDate != null ? AppColors.primary : AppColors.textSecondary,
                  ),
                  AppSpacing.gapHorizontalXs,
                  Text(
                    filter.expectedPickupDate != null
                        ? '${AppStrings.filterByExpectedPickup}: ${DateFormatter.formatArabicDate(filter.expectedPickupDate!.toDateTime())}'
                        : AppStrings.filterByExpectedPickup,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: filter.expectedPickupDate != null ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: filter.expectedPickupDate != null ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                  if (filter.expectedPickupDate != null) ...[
                    AppSpacing.gapHorizontalXs,
                    GestureDetector(
                      onTap: () => onFilterChanged(filter.copyWith(clearExpectedPickupDate: true)),
                      child: const Icon(Icons.close, size: 14, color: AppColors.primary),
                    ),
                  ],
                ],
              ),
            ),
          ),
          AppSpacing.gapHorizontalSm,

          // Filter by Order Received Date Chip
          InkWell(
            onTap: () => _selectOrderReceivedDate(context),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: filter.orderReceivedDate != null ? AppColors.primaryLighter : AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: filter.orderReceivedDate != null ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history,
                    size: 16,
                    color: filter.orderReceivedDate != null ? AppColors.primary : AppColors.textSecondary,
                  ),
                  AppSpacing.gapHorizontalXs,
                  Text(
                    filter.orderReceivedDate != null
                        ? '${AppStrings.filterByOrderReceived}: ${DateFormatter.formatArabicDate(filter.orderReceivedDate!)}'
                        : AppStrings.filterByOrderReceived,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: filter.orderReceivedDate != null ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: filter.orderReceivedDate != null ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                  if (filter.orderReceivedDate != null) ...[
                    AppSpacing.gapHorizontalXs,
                    GestureDetector(
                      onTap: () => onFilterChanged(filter.copyWith(clearOrderReceivedDate: true)),
                      child: const Icon(Icons.close, size: 14, color: AppColors.primary),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Reset Filters Action Button
          if (filter.isActive) ...[
            AppSpacing.gapHorizontalSm,
            InkWell(
              onTap: onResetFilters,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.clear_all, size: 16, color: AppColors.error),
                    AppSpacing.gapHorizontalXs,
                    Text(
                      AppStrings.resetFilters,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
