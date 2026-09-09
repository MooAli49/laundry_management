import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      borderColor: isSelected ? AppColors.selectionBorder : AppColors.border,
      backgroundColor: isSelected ? AppColors.selectionBackground : AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Selection Checkbox (if unstored), Order Number, Status, Expected Pickup Date
          Row(
            children: [
              if (!isStored && onSelectionChanged != null) ...[
                Checkbox(
                  value: isSelected,
                  activeColor: AppColors.primary,
                  onChanged: (val) => onSelectionChanged!(val == true),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                ),
                AppSpacing.gapHorizontalXs,
              ],
              // Order Number
              Text(
                '#${item.orderNumber}',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontSize: 15,
                ),
              ),
              AppSpacing.gapHorizontalSm,
              OrderStatusBadge(status: item.orderStatus),
              const Spacer(),
              // Expected Pickup Date
              const Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
              AppSpacing.gapHorizontalXs,
              Text(
                'الاستلام: ${DateFormatter.formatArabicDate(item.expectedPickupDate.toDateTime())}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          AppSpacing.gapMd,

          // Middle Row: Physical Item Details & Customer Details
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
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (carpet != null) ...[
                      AppSpacing.gapXs,
                      Text(
                        'الأبعاد: ${carpet.length} × ${carpet.width} م (${carpet.area} م²)',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (orderItem.notes != null && orderItem.notes!.trim().isNotEmpty) ...[
                      AppSpacing.gapXs,
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.sticky_note_2_outlined,
                            size: 14,
                            color: AppColors.textTertiary,
                          ),
                          AppSpacing.gapHorizontalXs,
                          Expanded(
                            child: Text(
                              orderItem.notes!,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              AppSpacing.gapHorizontalMd,
              // Customer Details
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.customerName,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
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
                        textDirection: TextDirection.ltr,
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

          // Bottom Row: Current Location Badge & Action Buttons
          Row(
            children: [
              if (isStored) ...[
                // Current Location Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3),
                    ),
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
                  icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
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
