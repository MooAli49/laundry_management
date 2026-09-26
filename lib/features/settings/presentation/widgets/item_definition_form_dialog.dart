import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../domain/entities/item_definition.dart';
import '../../../../domain/entities/item_type.dart';
import '../cubit/item_types_management_cubit.dart';

class ItemDefinitionFormDialog extends StatefulWidget {
  final ItemDefinition? definition;
  final List<ItemType> availableItemTypes;
  final String? preselectedItemTypeId;

  const ItemDefinitionFormDialog({
    super.key,
    this.definition,
    required this.availableItemTypes,
    this.preselectedItemTypeId,
  });

  static Future<bool?> show(
    BuildContext context, {
    ItemDefinition? definition,
    required List<ItemType> availableItemTypes,
    String? preselectedItemTypeId,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: context.read<ItemTypesManagementCubit>(),
        child: ItemDefinitionFormDialog(
          definition: definition,
          availableItemTypes: availableItemTypes,
          preselectedItemTypeId: preselectedItemTypeId,
        ),
      ),
    );
  }

  @override
  State<ItemDefinitionFormDialog> createState() =>
      _ItemDefinitionFormDialogState();
}

class _ItemDefinitionFormDialogState extends State<ItemDefinitionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _selectedItemTypeId;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    final def = widget.definition;
    _nameController = TextEditingController(text: def?.name ?? '');

    if (def != null) {
      _selectedItemTypeId = def.itemTypeId;
    } else if (widget.preselectedItemTypeId != null &&
        widget.availableItemTypes.any(
          (t) => t.id == widget.preselectedItemTypeId,
        )) {
      _selectedItemTypeId = widget.preselectedItemTypeId!;
    } else if (widget.availableItemTypes.isNotEmpty) {
      _selectedItemTypeId = widget.availableItemTypes.first.id;
    } else {
      _selectedItemTypeId = '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() => _inlineError = null);
    if (!_formKey.currentState!.validate()) return;

    if (_selectedItemTypeId.isEmpty) {
      setState(() => _inlineError = 'يجب اختيار نوع القطعة');
      return;
    }

    final cubit = context.read<ItemTypesManagementCubit>();
    bool success;

    if (widget.definition == null) {
      success = await cubit.createItemDefinition(
        itemTypeId: _selectedItemTypeId,
        name: _nameController.text.trim(),
      );
    } else {
      final updated = widget.definition!.copyWith(
        itemTypeId: _selectedItemTypeId,
        name: _nameController.text.trim(),
      );
      success = await cubit.updateItemDefinition(updated);
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
    final isEditing = widget.definition != null;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
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
                      ? AppStrings.editItemDefinition
                      : AppStrings.addItemDefinition,
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                AppSpacing.gapLg,
                AppSpacing.gapMd,
                if (_inlineError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
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
                // Item Type Dropdown
                Text(
                  AppStrings.tableHeaderItemType,
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                AppSpacing.gapXs,
                DropdownButtonFormField<String>(
                  initialValue: _selectedItemTypeId.isNotEmpty
                      ? _selectedItemTypeId
                      : null,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  items: widget.availableItemTypes.map((type) {
                    return DropdownMenuItem<String>(
                      value: type.id,
                      child: Text(type.name, style: AppTextStyles.bodyMedium),
                    );
                  }).toList(),
                  onChanged: isEditing
                      ? null
                      : (val) {
                          if (val != null) {
                            setState(() => _selectedItemTypeId = val);
                          }
                        },
                  validator: (val) => val == null ? 'نوع القطعة مطلوب' : null,
                ),
                AppSpacing.gapLg,
                AppTextField(
                  controller: _nameController,
                  label: AppStrings.itemDefinitionNameLabel,
                  hintText: AppStrings.itemDefinitionNameHint,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return AppStrings.itemDefinitionNameRequired;
                    }
                    return null;
                  },
                ),
                AppSpacing.gapXxl,
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    AppButton(label: AppStrings.save, onPressed: _handleSubmit),
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
