import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../domain/entities/expense_category.dart';
import '../cubit/expense_categories_management_cubit.dart';

class ExpenseCategoryFormDialog extends StatefulWidget {
  final ExpenseCategory? category;

  const ExpenseCategoryFormDialog({super.key, this.category});

  static Future<bool?> show(BuildContext context, {ExpenseCategory? category}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: context.read<ExpenseCategoriesManagementCubit>(),
        child: ExpenseCategoryFormDialog(category: category),
      ),
    );
  }

  @override
  State<ExpenseCategoryFormDialog> createState() =>
      _ExpenseCategoryFormDialogState();
}

class _ExpenseCategoryFormDialogState extends State<ExpenseCategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.category?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() => _inlineError = null);
    if (!_formKey.currentState!.validate()) return;

    final cubit = context.read<ExpenseCategoriesManagementCubit>();
    bool success;

    if (widget.category == null) {
      success = await cubit.createCategory(_nameController.text.trim());
    } else {
      final updated =
          widget.category!.copyWith(name: _nameController.text.trim());
      success = await cubit.updateCategory(updated);
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
    final isEditing = widget.category != null;

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing
                          ? AppStrings.editExpenseCategory
                          : AppStrings.addExpenseCategory,
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.lg, color: AppColors.divider),
                AppSpacing.gapMd,
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
                  label: AppStrings.expenseCategoryNameLabel,
                  hintText: AppStrings.expenseCategoryNameHint,
                  prefixIcon: const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return AppStrings.expenseCategoryNameRequired;
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
