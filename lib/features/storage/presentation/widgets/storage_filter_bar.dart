import 'package:flutter/material.dart';

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

/// StorageFilterBar implemented as a structured form grid matching Figma (`screens.tsx`).
///
/// Layout:
/// - 4-column responsive grid on tablet (2-column on narrower viewports)
/// - Field labels (14px font-medium) above each control
/// - 44px height input/select containers with 12px radius, surface bg, border
/// - Item type dropdown, Service dropdown, Expected pickup date, Order received date,
///   plus Location dropdown when activeTab == currentStorage
/// - "مسح الفلاتر" text button below the grid when filters/search are active.
class StorageFilterBar extends StatelessWidget {
  final StorageTab activeTab;
  final StorageFilter filter;
  final List<ItemType> itemTypes;
  final List<Service> services;
  final List<StorageLocation> locations;
  final ValueChanged<StorageFilter> onFilterChanged;
  final VoidCallback onResetFilters;
  final bool isSearchActive;

  const StorageFilterBar({
    super.key,
    required this.activeTab,
    required this.filter,
    required this.itemTypes,
    required this.services,
    required this.locations,
    required this.onFilterChanged,
    required this.onResetFilters,
    this.isSearchActive = false,
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
    final hasActiveFilter = filter.isActive || isSearchActive;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final int columns = totalWidth >= 800 ? 4 : (totalWidth >= 500 ? 2 : 1);
        final itemWidth = (totalWidth - (columns - 1) * AppSpacing.md) / columns;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                // 1. Field: "نوع القطعة"
                SizedBox(
                  width: itemWidth,
                  child: _FilterField(
                    label: 'نوع القطعة',
                    child: _DropdownContainer(
                      isActive: filter.itemTypeId != null,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: filter.itemTypeId,
                          isExpanded: true,
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                'كل أنواع القطع',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            ...itemTypes.map((t) => DropdownMenuItem<String?>(
                                  value: t.id,
                                  child: Text(
                                    t.name,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontSize: 14,
                                      color: AppColors.textPrimary,
                                    ),
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
                  ),
                ),

                // 2. Field: "نوع الخدمة"
                SizedBox(
                  width: itemWidth,
                  child: _FilterField(
                    label: 'نوع الخدمة',
                    child: _DropdownContainer(
                      isActive: filter.serviceId != null,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: filter.serviceId,
                          isExpanded: true,
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                'كل الخدمات',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            ...services.map((s) => DropdownMenuItem<String?>(
                                  value: s.id,
                                  child: Text(
                                    s.name,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontSize: 14,
                                      color: AppColors.textPrimary,
                                    ),
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
                  ),
                ),

                // 3. Field: "موعد الاستلام المتوقع"
                SizedBox(
                  width: itemWidth,
                  child: _FilterField(
                    label: 'موعد الاستلام المتوقع',
                    child: _DateFilterContainer(
                      isActive: filter.expectedPickupDate != null,
                      onTap: () => _selectExpectedPickupDate(context),
                      onClear: filter.expectedPickupDate != null
                          ? () => onFilterChanged(
                              filter.copyWith(clearExpectedPickupDate: true))
                          : null,
                      displayText: filter.expectedPickupDate != null
                          ? DateFormatter.formatArabicDate(
                              filter.expectedPickupDate!.toDateTime())
                          : 'اختر التاريخ',
                    ),
                  ),
                ),

                // 4. Field: "تاريخ استلام الطلب"
                SizedBox(
                  width: itemWidth,
                  child: _FilterField(
                    label: 'تاريخ استلام الطلب',
                    child: _DateFilterContainer(
                      isActive: filter.orderReceivedDate != null,
                      onTap: () => _selectOrderReceivedDate(context),
                      onClear: filter.orderReceivedDate != null
                          ? () => onFilterChanged(
                              filter.copyWith(clearOrderReceivedDate: true))
                          : null,
                      displayText: filter.orderReceivedDate != null
                          ? DateFormatter.formatArabicDate(
                              filter.orderReceivedDate!)
                          : 'اختر التاريخ',
                    ),
                  ),
                ),

                // 5. Field: "الموقع" (Current Storage only)
                if (activeTab == StorageTab.currentStorage)
                  SizedBox(
                    width: itemWidth,
                    child: _FilterField(
                      label: 'الموقع',
                      child: _DropdownContainer(
                        isActive: filter.storageLocationId != null,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: filter.storageLocationId,
                            isExpanded: true,
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                  'كل المواقع',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              ...locations.map((loc) => DropdownMenuItem<String?>(
                                    value: loc.id,
                                    child: Text(
                                      loc.name,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontSize: 14,
                                        color: AppColors.textPrimary,
                                      ),
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
                    ),
                  ),
              ],
            ),

            // Clear Filters Button (shown when any filter or search is active)
            if (hasActiveFilter) ...[
              AppSpacing.gapSm,
              TextButton.icon(
                onPressed: onResetFilters,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.xs,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.close, size: 16),
                label: Text(
                  'مسح الفلاتر',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _FilterField extends StatelessWidget {
  final String label;
  final Widget child;

  const _FilterField({
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _DropdownContainer extends StatelessWidget {
  final Widget child;
  final bool isActive;

  const _DropdownContainer({
    required this.child,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primaryLighter.withValues(alpha: 0.3)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: isActive ? AppColors.primary : AppColors.border,
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _DateFilterContainer extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final String displayText;

  const _DateFilterContainer({
    required this.isActive,
    required this.onTap,
    this.onClear,
    required this.displayText,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primaryLighter.withValues(alpha: 0.3)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: isActive ? AppColors.primary : AppColors.textTertiary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                displayText,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 14,
                  color: isActive ? AppColors.textPrimary : AppColors.textTertiary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isActive && onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
