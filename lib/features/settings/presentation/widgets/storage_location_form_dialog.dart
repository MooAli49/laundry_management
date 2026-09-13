import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../domain/entities/item_type.dart';
import '../../../../domain/entities/storage_location.dart';
import '../cubit/storage_locations_management_cubit.dart';

class StorageLocationFormDialog extends StatefulWidget {
  final StorageLocation? location;
  final List<ItemType> availableItemTypes;
  final List<String> initialSupportedTypeIds;

  const StorageLocationFormDialog({
    super.key,
    this.location,
    required this.availableItemTypes,
    this.initialSupportedTypeIds = const [],
  });

  static Future<bool?> show(
    BuildContext context, {
    StorageLocation? location,
    required List<ItemType> availableItemTypes,
    List<String> initialSupportedTypeIds = const [],
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: context.read<StorageLocationsManagementCubit>(),
        child: StorageLocationFormDialog(
          location: location,
          availableItemTypes: availableItemTypes,
          initialSupportedTypeIds: initialSupportedTypeIds,
        ),
      ),
    );
  }

  @override
  State<StorageLocationFormDialog> createState() =>
      _StorageLocationFormDialogState();
}

class _StorageLocationFormDialogState extends State<StorageLocationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late Set<String> _selectedTypeIds;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.location?.name ?? '');
    _selectedTypeIds = Set.from(widget.initialSupportedTypeIds);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() => _inlineError = null);
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTypeIds.isEmpty) {
      setState(() => _inlineError = AppStrings.selectAtLeastOneItemType);
      return;
    }

    final cubit = context.read<StorageLocationsManagementCubit>();
    bool success;

    if (widget.location == null) {
      success = await cubit.createStorageLocation(
        name: _nameController.text.trim(),
        supportedItemTypeIds: _selectedTypeIds.toList(),
      );
    } else {
      final updated =
          widget.location!.copyWith(name: _nameController.text.trim());
      success = await cubit.updateStorageLocation(
        location: updated,
        supportedItemTypeIds: _selectedTypeIds.toList(),
      );
    }

    if (success && mounted) {
      Navigator.of(context).pop(true);
    } else if (mounted) {
      setState(() {
        _inlineError = cubit.state.errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.location != null;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header matching Figma (no X button, no divider)
                Text(
                  isEditing
                      ? AppStrings.editStorageLocation
                      : AppStrings.addStorageLocation,
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                AppSpacing.gapLg,
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_inlineError != null) ...[
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.errorLight,
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusMd),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: AppColors.error,
                                  size: 20,
                                ),
                                AppSpacing.gapHorizontalSm,
                                Expanded(
                                  child: Text(
                                    _inlineError!,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AppSpacing.gapMd,
                        ],
                        AppTextField(
                          controller: _nameController,
                          label: AppStrings.storageLocationNameLabel,
                          hintText: AppStrings.storageLocationNameHint,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return AppStrings.storageLocationNameRequired;
                            }
                            return null;
                          },
                        ),
                        AppSpacing.gapLg,
                        Text(
                          AppStrings.supportedItemTypesLabel,
                          style: AppTextStyles.labelLarge.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        AppSpacing.gapSm,
                        if (widget.availableItemTypes.isEmpty)
                          Text(
                            AppStrings.noItemTypes,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          )
                        else
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: widget.availableItemTypes.map((type) {
                              final isSelected =
                                  _selectedTypeIds.contains(type.id);
                              return FilterChip(
                                label: Text(type.name),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedTypeIds.add(type.id);
                                    } else {
                                      _selectedTypeIds.remove(type.id);
                                    }
                                  });
                                },
                                selectedColor: AppColors.primaryLighter,
                                backgroundColor: AppColors.surface,
                                labelStyle: AppTextStyles.labelMedium.copyWith(
                                  color: isSelected
                                      ? AppColors.primaryDark
                                      : AppColors.textPrimary,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppSpacing.radiusMd),
                                  side: BorderSide(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.border,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        AppSpacing.gapMd,
                      ],
                    ),
                  ),
                ),
                AppSpacing.gapLg,
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    AppButton(
                      label: AppStrings.save,
                      onPressed: _handleSubmit,
                    ),
                    AppSpacing.gapHorizontalMd,
                    AppButton(
                      label: AppStrings.cancel,
                      variant: AppButtonVariant.text,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
