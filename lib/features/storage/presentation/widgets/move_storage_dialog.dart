import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../domain/entities/storage_item.dart';
import '../../../../domain/entities/storage_location.dart';

class MoveStorageDialog extends StatefulWidget {
  final StorageItem item;
  final List<StorageLocation> destinationLocations;
  final Future<void> Function(String newStorageLocationId) onConfirm;

  const MoveStorageDialog({
    super.key,
    required this.item,
    required this.destinationLocations,
    required this.onConfirm,
  });

  @override
  State<MoveStorageDialog> createState() => _MoveStorageDialogState();
}

class _MoveStorageDialogState extends State<MoveStorageDialog> {
  StorageLocation? _selectedLocation;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.destinationLocations.isNotEmpty) {
      _selectedLocation = widget.destinationLocations.first;
    }
  }

  Future<void> _handleSubmit() async {
    if (_selectedLocation == null) {
      setState(() => _errorMessage = AppStrings.selectLocation);
      return;
    }

    if (_selectedLocation!.id == widget.item.activeRecord?.storageLocationId) {
      setState(() => _errorMessage = AppStrings.cannotMoveToSameLocation);
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
                  Text(AppStrings.moveAction, style: AppTextStyles.titleLarge),
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

              // Item details
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
                      '#${widget.item.orderNumber} - ${widget.item.customerName}',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    AppSpacing.gapXs,
                    Text(
                      '${widget.item.orderItem.itemTypeNameSnapshot} - ${widget.item.orderItem.serviceNameSnapshot}',
                      style: AppTextStyles.titleMedium,
                    ),
                    AppSpacing.gapSm,
                    Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.textSecondary),
                        AppSpacing.gapHorizontalXs,
                        Text(
                          '${AppStrings.currentLocationLabel}: ${widget.item.storageLocation?.name ?? "-"}',
                          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              AppSpacing.gapLg,

              // Destination Location Selector (Excludes current location)
              Text(AppStrings.newLocationLabel, style: AppTextStyles.labelLarge),
              AppSpacing.gapXs,
              DropdownButtonFormField<StorageLocation>(
                initialValue: _selectedLocation,
                isExpanded: true,
                decoration: InputDecoration(
                  hintText: widget.destinationLocations.isEmpty
                      ? 'لا توجد مواقع بديلة متوافقة'
                      : AppStrings.chooseStorageLocation,
                ),
                items: widget.destinationLocations.map((loc) {
                  return DropdownMenuItem<StorageLocation>(
                    value: loc,
                    child: Text(loc.name, style: AppTextStyles.bodyMedium),
                  );
                }).toList(),
                onChanged: widget.destinationLocations.isEmpty
                    ? null
                    : (loc) => setState(() => _selectedLocation = loc),
              ),
              AppSpacing.gapXl,

              // Actions
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
                    label: AppStrings.confirmMove,
                    isLoading: _isLoading,
                    onPressed: (_isLoading || _selectedLocation == null || widget.destinationLocations.isEmpty)
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
