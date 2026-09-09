import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../domain/entities/storage_item.dart';
import '../../../../domain/entities/storage_location.dart';

/// StoreStorageDialog matching the approved Figma LocationDialog specification (`screens.tsx`).
///
/// Features:
/// - Max width: 480px, 16px radius, 24px padding
/// - Title: 18px font-semibold textPrimary
/// - Summary banner: rounded 12px, secondary bg, 14px textSecondary
/// - No locations warning: rounded 12px, warningLight bg, 14px warning text
/// - Location selector: "موقع التخزين *" label, 44px container, hint below
/// - Footer: Primary "تأكيد التخزين" with check icon, secondary "إلغاء"
class StoreStorageDialog extends StatefulWidget {
  final List<StorageItem> itemsToStore;
  final List<StorageLocation> availableLocations;
  final Future<void> Function(String storageLocationId) onConfirm;

  const StoreStorageDialog({
    super.key,
    required this.itemsToStore,
    required this.availableLocations,
    required this.onConfirm,
  });

  @override
  State<StoreStorageDialog> createState() => _StoreStorageDialogState();
}

class _StoreStorageDialogState extends State<StoreStorageDialog> {
  StorageLocation? _selectedLocation;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.availableLocations.isNotEmpty) {
      _selectedLocation = widget.availableLocations.first;
    }
  }

  Future<void> _handleSubmit() async {
    if (_selectedLocation == null) {
      setState(() => _errorMessage = AppStrings.selectLocation);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onConfirm(_selectedLocation!.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e
            .toString()
            .replaceFirst('BusinessRuleFailure: ', '')
            .replaceFirst('Failure: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBulk = widget.itemsToStore.length > 1;
    final single = widget.itemsToStore.isNotEmpty ? widget.itemsToStore.first : null;
    final hasLocations = widget.availableLocations.isNotEmpty;

    final summaryText = isBulk
        ? 'عدد العناصر: ${widget.itemsToStore.length}'
        : (single != null
            ? 'العنصر: ${single.orderItem.itemTypeNameSnapshot} — الطلب #${single.orderNumber}'
            : '');

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      backgroundColor: AppColors.surfaceElevated,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Title + Close Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isBulk ? 'تخزين العناصر' : AppStrings.storeAction,
                    style: AppTextStyles.headlineMedium.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20, color: AppColors.textTertiary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              AppSpacing.gapLg,

              // Error banner if any
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                      AppSpacing.gapHorizontalSm,
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AppSpacing.gapMd,
              ],

              // Summary Banner (Figma: rounded-xl bg-secondary px-4 py-3 text-[14px] text-text-secondary)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                ),
                child: Text(
                  summaryText,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              AppSpacing.gapLg,

              // Location Selector or No-Locations Warning
              if (!hasLocations) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                  child: Text(
                    'لا توجد أماكن تخزين مناسبة لهذه القطعة.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 14,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ] else ...[
                // Label with red asterisk
                Row(
                  children: [
                    Text(
                      AppStrings.storageLocationLabel,
                      style: AppTextStyles.labelLarge.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '*',
                      style: TextStyle(color: AppColors.error, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Dropdown selector
                DropdownButtonFormField<StorageLocation>(
                  initialValue: _selectedLocation,
                  isExpanded: true,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    hintText: AppStrings.chooseStorageLocation,
                  ),
                  items: widget.availableLocations.map((loc) {
                    return DropdownMenuItem<StorageLocation>(
                      value: loc,
                      child: Text(
                        loc.name,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (loc) => setState(() => _selectedLocation = loc),
                ),
                const SizedBox(height: 6),

                // Hint
                Text(
                  'تظهر المواقع المناسبة لنوع القطعة فقط',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              AppSpacing.gapXxl,

              // Footer: Confirm + Cancel (in RTL, Confirm appears first on the right)
              Row(
                children: [
                  if (hasLocations) ...[
                    AppButton(
                      label: AppStrings.confirmStore,
                      icon: Icons.check,
                      isLoading: _isLoading,
                      onPressed: (_isLoading || _selectedLocation == null)
                          ? null
                          : _handleSubmit,
                    ),
                    AppSpacing.gapHorizontalMd,
                  ],
                  AppButton(
                    label: AppStrings.cancel,
                    variant: AppButtonVariant.secondary,
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
