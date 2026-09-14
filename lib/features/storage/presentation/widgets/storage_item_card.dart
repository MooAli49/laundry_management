import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../domain/entities/storage_item.dart';

/// StorageItemCard visually matching the approved Figma design (`screens.tsx`).
///
/// Features a compact single-row horizontal layout:
/// - Selection checkbox (unstored items only)
/// - Leading package icon container (40x40, rounded 12px, secondary bg)
/// - Flexible info column:
///   - Row 1: Item type, definition pill (if present), service name, order number
///   - Row 2: Customer name, notes (if present)
/// - Trailing actions/status:
///   - Stored: Success location pill + Move button + Unstore menu
///   - Unstored: Warning "غير مخزنة" pill + Store button
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
    final isStored = item.isStored;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      borderRadius: AppSpacing.radiusXl,
      borderColor: isSelected ? AppColors.selectionBorder : AppColors.border,
      backgroundColor: isSelected ? AppColors.selectionBackground : AppColors.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Selection Checkbox (Unstored only)
          if (!isStored && onSelectionChanged != null) ...[
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: isSelected,
                onChanged: (val) => onSelectionChanged!(val == true),
                activeColor: AppColors.primary,
                checkColor: AppColors.onPrimary,
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.borderStrong,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            AppSpacing.gapHorizontalMd,
          ],

          // 2. Leading Package Icon Box (Figma: size-10 rounded-xl bg-secondary text-text-secondary)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
          AppSpacing.gapHorizontalMd,

          // 3. Middle Information Column (min-w-0 flex-1)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Line 1: Item Type + Definition Pill + Service + Order Number
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    Text(
                      orderItem.itemTypeNameSnapshot,
                      style: AppTextStyles.labelLarge.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (orderItem.itemDefinitionNameSnapshot != null &&
                        orderItem.itemDefinitionNameSnapshot!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          orderItem.itemDefinitionNameSnapshot!,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    Text(
                      '— ${orderItem.serviceNameSnapshot}',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '#${item.orderNumber}',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),

                // Line 2: Customer Name + Notes
                Text(
                  '${item.customerName}${orderItem.notes != null && orderItem.notes!.trim().isNotEmpty ? " • ${orderItem.notes!.trim()}" : ""}',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          AppSpacing.gapHorizontalMd,

          // 4. Trailing Actions / Status
          if (isStored) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Location Badge (Figma: rounded-full bg-success-light px-2.5 py-1 text-[12px] font-medium text-success)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.storageLocation?.name ?? '-',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
                AppSpacing.gapHorizontalSm,

                // Move Button (Figma: AppButton sm variant=secondary icon=swap)
                AppButton(
                  label: AppStrings.moveAction,
                  icon: Icons.swap_horiz,
                  variant: AppButtonVariant.secondary,
                  onPressed: onMove,
                ),
                AppSpacing.gapHorizontalXs,

                // Unstore More Options
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: 'خيارات إضافية',
                  onSelected: (val) {
                    if (val == 'unstore') onUnstore();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'unstore',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.remove_circle_outline,
                            color: AppColors.error,
                            size: 18,
                          ),
                          AppSpacing.gapHorizontalSm,
                          Text(
                            AppStrings.unstoreAction,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ] else ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status Badge (Figma: rounded-full bg-warning-light px-2.5 py-1 text-[12px] font-medium text-warning)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'غير مخزنة',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.warning,
                    ),
                  ),
                ),
                AppSpacing.gapHorizontalSm,

                // Single-item Store Button
                AppButton(
                  label: AppStrings.storeAction,
                  icon: Icons.add_box_outlined,
                  variant: AppButtonVariant.primary,
                  onPressed: onStore,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
