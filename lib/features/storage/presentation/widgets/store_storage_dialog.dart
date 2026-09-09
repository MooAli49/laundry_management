import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../domain/entities/storage_item.dart';
import '../../../../domain/entities/storage_location.dart';

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
        _errorMessage = e.toString().replaceFirst('BusinessRuleFailure: ', '').replaceFirst('Failure: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBulk = widget.itemsToStore.length > 1;
    final single = widget.itemsToStore.isNotEmpty ? widget.itemsToStore.first : null;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isBulk ? AppStrings.storeItemsAction : AppStrings.storeAction,
                    style: AppTextStyles.titleLarge,
                  ),
                  IconButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              AppSpacing.gapMd,

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error),
                      AppSpacing.gapHorizontalSm,
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
                AppSpacing.gapMd,
              ],

              // Summary of items
              if (isBulk) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
                      AppSpacing.gapHorizontalSm,
                      Text(
                        'عدد العناصر المحددة: ${widget.itemsToStore.length}',
                        style: AppTextStyles.titleMedium,
                      ),
                    ],
                  ),
                ),
                AppSpacing.gapMd,
              ] else if (single != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${single.orderNumber} - ${single.customerName}',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      AppSpacing.gapXs,
                      Text(
                        '${single.orderItem.itemTypeNameSnapshot} - ${single.orderItem.serviceNameSnapshot}',
                        style: AppTextStyles.titleMedium,
                      ),
                    ],
                  ),
                ),
                AppSpacing.gapMd,
              ],

              // Storage Location Selector
              Text(AppStrings.storageLocationLabel, style: AppTextStyles.labelLarge),
              AppSpacing.gapXs,
              DropdownButtonFormField<StorageLocation>(
                initialValue: _selectedLocation,
                isExpanded: true,
                decoration: InputDecoration(
                  hintText: widget.availableLocations.isEmpty
                      ? 'لا توجد أماكن تخزين متوافقة متاحة'
                      : AppStrings.chooseStorageLocation,
                ),
                items: widget.availableLocations.map((loc) {
                  return DropdownMenuItem<StorageLocation>(
                    value: loc,
                    child: Text(loc.name, style: AppTextStyles.bodyMedium),
                  );
                }).toList(),
                onChanged: widget.availableLocations.isEmpty
                    ? null
                    : (loc) => setState(() => _selectedLocation = loc),
              ),
              AppSpacing.gapXl,

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: AppStrings.cancel,
                    variant: AppButtonVariant.secondary,
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  ),
                  AppSpacing.gapHorizontalMd,
                  AppButton(
                    label: AppStrings.confirmStore,
                    isLoading: _isLoading,
                    onPressed: (_isLoading || _selectedLocation == null || widget.availableLocations.isEmpty)
                        ? null
                        : _handleSubmit,
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
