import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../domain/entities/storage_item.dart';
import '../../../orders/presentation/widgets/order_status_badge.dart';

class StorageItemCard extends StatelessWidget {
  final StorageItem item;
  final bool isSelected;
  final ValueChanged<bool>? onSelectionChanged;
  final VoidCallback onStore;
  final VoidCallback onMove;
  final VoidCallback onUnstore;

  const StorageItemCard({
    super.key,
    required this.item,
    this.isSelected = false,
    this.onSelectionChanged,
    required this.onStore,
    required this.onMove,
    required this.onUnstore,
  });

  @override
  Widget build(BuildContext context) {
    final orderItem = item.orderItem;
    final carpet = orderItem.carpetData;
    final isStored = item.isStored;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      borderColor: isSelected ? AppColors.primary : AppColors.border,
      backgroundColor: isSelected ? AppColors.primaryLight.withValues(alpha: 0.15) : AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Checkbox (if unstored), Order Number, Status, Pickup Date
          Row(
            children: [
              if (!isStored && onSelectionChanged != null) ...[
                Checkbox(
                  value: isSelected,
                  onChanged: (val) => onSelectionChanged!(val == true),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                ),
                AppSpacing.gapHorizontalXs,
              ],
              // Order Number Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  '${AppStrings.orderNumberPrefix}${item.orderNumber}',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              AppSpacing.gapHorizontalSm,
              OrderStatusBadge(status: item.orderStatus),
              const Spacer(),
              // Expected Pickup Date
              Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
              AppSpacing.gapHorizontalXs,
              Text(
                item.expectedPickupDate.toString(),
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          AppSpacing.gapSm,

          // Middle Row: Item Info & Customer Info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${orderItem.itemTypeNameSnapshot} - ${orderItem.serviceNameSnapshot}',
                      style: AppTextStyles.titleMedium,
                    ),
                    if (carpet != null) ...[
                      AppSpacing.gapXs,
                      Text(
                        'الأبعاد: ${carpet.length} × ${carpet.width} م (${carpet.area} م²)',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                    if (orderItem.notes != null && orderItem.notes!.trim().isNotEmpty) ...[
                      AppSpacing.gapXs,
                      Text(
                        'ملاحظة: ${orderItem.notes}',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
              // Customer Details
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.customerName,
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500),
                      ),
                      AppSpacing.gapHorizontalXs,
                      const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
                    ],
                  ),
                  AppSpacing.gapXs,
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.customerPhone,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                      AppSpacing.gapHorizontalXs,
                      const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary),
                    ],
                  ),
                ],
              ),
            ],
          ),
          AppSpacing.gapMd,

          // Bottom Row: Location Badge & Actions
          Row(
            children: [
              if (isStored) ...[
                // Current Location Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.successLight.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(color: AppColors.successLight),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.success),
                      AppSpacing.gapHorizontalXs,
                      Text(
                        '${AppStrings.currentLocationLabel}: ${item.storageLocation?.name ?? "-"}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Move Action
                AppButton(
                  label: AppStrings.moveAction,
                  icon: Icons.swap_horiz,
                  variant: AppButtonVariant.outline,
                  onPressed: onMove,
                ),
                AppSpacing.gapHorizontalSm,
                // More / Unstore Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'خيارات إضافية',
                  onSelected: (value) {
                    if (value == 'unstore') {
                      onUnstore();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'unstore',
                      child: Row(
                        children: [
                          const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 18),
                          AppSpacing.gapHorizontalSm,
                          Text(
                            AppStrings.unstoreAction,
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const Spacer(),
                // Store Action
                AppButton(
                  label: AppStrings.storeAction,
                  icon: Icons.add_box_outlined,
                  variant: AppButtonVariant.primary,
                  onPressed: onStore,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
