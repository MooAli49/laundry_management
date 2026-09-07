import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../domain/entities/order_item.dart';
import '../../../../domain/entities/storage_location.dart';

class StoreItemsDialog extends StatefulWidget {
  final List<OrderItem> unstoredItems;
  final List<StorageLocation> availableLocations;
  final Future<void> Function({
    required List<String> orderItemIds,
    required String storageLocationId,
  }) onStore;

  const StoreItemsDialog({
    super.key,
    required this.unstoredItems,
    required this.availableLocations,
    required this.onStore,
  });

  @override
  State<StoreItemsDialog> createState() => _StoreItemsDialogState();
}

class _StoreItemsDialogState extends State<StoreItemsDialog> {
  late final Set<String> _selectedItemIds;
  StorageLocation? _selectedLocation;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedItemIds = widget.unstoredItems.map((i) => i.id).toSet();
    if (widget.availableLocations.isNotEmpty) {
      _selectedLocation = widget.availableLocations.first;
    }
  }

  Future<void> _handleStore() async {
    if (_selectedItemIds.isEmpty) {
      setState(() => _errorMessage = 'يرجى تحديد قطعة واحدة على الأقل');
      return;
    }
    if (_selectedLocation == null) {
      setState(() => _errorMessage = 'يرجى اختيار مكان التخزين');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onStore(
        orderItemIds: _selectedItemIds.toList(),
        storageLocationId: _selectedLocation!.id,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Failure: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('تخزين عناصر الطلب', style: AppTextStyles.titleLarge),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              AppSpacing.gapLg,

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

              Text('القطع غير المخزنة', style: AppTextStyles.labelLarge),
              AppSpacing.gapSm,
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.unstoredItems.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (context, index) {
                    final item = widget.unstoredItems[index];
                    final isChecked = _selectedItemIds.contains(item.id);
                    return CheckboxListTile(
                      value: isChecked,
                      title: Text(
                        '${item.itemTypeNameSnapshot} - ${item.serviceNameSnapshot}',
                        style: AppTextStyles.bodyMedium,
                      ),
                      subtitle: item.notes != null ? Text(item.notes!, style: AppTextStyles.labelSmall) : null,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedItemIds.add(item.id);
                          } else {
                            _selectedItemIds.remove(item.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              AppSpacing.gapLg,

              Text('مكان التخزين *', style: AppTextStyles.labelLarge),
              AppSpacing.gapXs,
              DropdownButtonFormField<StorageLocation>(
                initialValue: _selectedLocation,
                isExpanded: true,
                decoration: const InputDecoration(hintText: 'اختر موقع التخزين'),
                items: widget.availableLocations.map((loc) {
                  return DropdownMenuItem<StorageLocation>(
                    value: loc,
                    child: Text(loc.name, style: AppTextStyles.bodyMedium),
                  );
                }).toList(),
                onChanged: (loc) => setState(() => _selectedLocation = loc),
              ),
              AppSpacing.gapXl,

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'إلغاء',
                    variant: AppButtonVariant.secondary,
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  ),
                  AppSpacing.gapHorizontalMd,
                  AppButton(
                    label: 'تخزين',
                    isLoading: _isLoading,
                    onPressed: _handleStore,
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
