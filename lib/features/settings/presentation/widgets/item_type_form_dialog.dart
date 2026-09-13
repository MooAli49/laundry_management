import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../domain/entities/item_type.dart';
import '../cubit/item_types_management_cubit.dart';

class ItemTypeFormDialog extends StatefulWidget {
  final ItemType? itemType;

  const ItemTypeFormDialog({super.key, this.itemType});

  static Future<bool?> show(BuildContext context, {ItemType? itemType}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: context.read<ItemTypesManagementCubit>(),
        child: ItemTypeFormDialog(itemType: itemType),
      ),
    );
  }

  @override
  State<ItemTypeFormDialog> createState() => _ItemTypeFormDialogState();
}

class _ItemTypeFormDialogState extends State<ItemTypeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.itemType?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() => _inlineError = null);
    if (!_formKey.currentState!.validate()) return;

    final cubit = context.read<ItemTypesManagementCubit>();
    bool success;

    if (widget.itemType == null) {
      success = await cubit.createItemType(_nameController.text.trim());
    } else {
      final updated = widget.itemType!.copyWith(name: _nameController.text.trim());
      success = await cubit.updateItemType(updated);
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
    final isEditing = widget.itemType != null;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? AppStrings.editItemType : AppStrings.addItemType,
                      style: AppTextStyles.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const Divider(color: AppColors.divider),
                AppSpacing.gapMd,
                if (_inlineError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                        AppSpacing.gapHorizontalSm,
                        Expanded(
                          child: Text(
                            _inlineError!,
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapMd,
                ],
                AppTextField(
                  controller: _nameController,
                  label: AppStrings.itemTypeNameLabel,
                  hintText: AppStrings.itemTypeNameHint,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return AppStrings.itemTypeNameRequired;
                    }
                    return null;
                  },
                ),
                AppSpacing.gapXxl,
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton(
                      label: AppStrings.cancel,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    AppSpacing.gapHorizontalMd,
                    AppButton(
                      label: AppStrings.save,
                      onPressed: _handleSubmit,
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
