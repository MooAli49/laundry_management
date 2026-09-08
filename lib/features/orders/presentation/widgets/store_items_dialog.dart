import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../domain/entities/order_item.dart';
import '../../../../domain/entities/storage_location.dart';

class StoreItemsDialog extends StatefulWidget {
  final List<OrderItem> unstoredItems;
  final List<StorageLocation>? availableLocations;
  final Map<String, List<StorageLocation>>? compatibleLocationsByItemType;
  final Future<void> Function({
    required List<String> orderItemIds,
    required String storageLocationId,
  }) onStore;

  const StoreItemsDialog({
    super.key,
    required this.unstoredItems,
    this.availableLocations,
    this.compatibleLocationsByItemType,
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

  List<StorageLocation> get _effectiveLocations {
    if (widget.compatibleLocationsByItemType == null ||
        widget.compatibleLocationsByItemType!.isEmpty) {
      return widget.availableLocations ?? [];
    }

    final selectedItems = widget.unstoredItems
        .where((i) => _selectedItemIds.contains(i.id))
        .toList();
    if (selectedItems.isEmpty) return [];

    List<StorageLocation>? intersection;
    for (final item in selectedItems) {
      final compatible =
          widget.compatibleLocationsByItemType![item.itemTypeId] ?? [];
      if (intersection == null) {
        intersection = List.of(compatible);
      } else {
        intersection = intersection
            .where((loc) => compatible.any((c) => c.id == loc.id))
            .toList();
      }
    }
    return intersection ?? [];
  }

  @override
  void initState() {
    super.initState();
    _selectedItemIds = widget.unstoredItems.map((i) => i.id).toSet();
    final effective = _effectiveLocations;
    if (effective.isNotEmpty) {
      _selectedLocation = effective.first;
    }
  }

  void _onItemToggled(String itemId, bool isChecked) {
    setState(() {
      if (isChecked) {
        _selectedItemIds.add(itemId);
      } else {
        _selectedItemIds.remove(itemId);
      }
      final effective = _effectiveLocations;
      if (_selectedLocation != null &&
          !effective.any((l) => l.id == _selectedLocation!.id)) {
        _selectedLocation = effective.isNotEmpty ? effective.first : null;
      } else if (_selectedLocation == null && effective.isNotEmpty) {
        _selectedLocation = effective.first;
      }
    });
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
        _errorMessage = e.toString().replaceFirst('BusinessRuleFailure: ', '').replaceFirst('Failure: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveLocations = _effectiveLocations;
    final hasConflictingTypes = _selectedItemIds.isNotEmpty && effectiveLocations.isEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
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
                      onChanged: (val) => _onItemToggled(item.id, val == true),
                    );
                  },
                ),
              ),
              AppSpacing.gapLg,

              if (hasConflictingTypes) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.warning),
                      AppSpacing.gapHorizontalSm,
                      Expanded(
                        child: Text(
                          'القطع المحددة تتطلب أماكن تخزين مختلفة (أنواع مختلفة). يرجى تخزين كل نوع على حدة.',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                ),
                AppSpacing.gapMd,
              ],

              Text('مكان التخزين *', style: AppTextStyles.labelLarge),
              AppSpacing.gapXs,
              DropdownButtonFormField<StorageLocation>(
                key: ValueKey('storage_loc_${_selectedLocation?.id}'),
                initialValue: _selectedLocation,
                isExpanded: true,
                decoration: InputDecoration(
                  hintText: effectiveLocations.isEmpty
                      ? 'لا توجد أماكن تخزين متوافقة متاحة'
                      : 'اختر موقع التخزين المتوافق',
                ),
                items: effectiveLocations.map((loc) {
                  return DropdownMenuItem<StorageLocation>(
                    value: loc,
                    child: Text(loc.name, style: AppTextStyles.bodyMedium),
                  );
                }).toList(),
                onChanged: effectiveLocations.isEmpty
                    ? null
                    : (loc) => setState(() => _selectedLocation = loc),
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
                    onPressed: (_isLoading || _selectedLocation == null || _selectedItemIds.isEmpty)
                        ? null
                        : _handleStore,
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
