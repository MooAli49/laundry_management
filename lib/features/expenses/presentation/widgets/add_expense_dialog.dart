import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../domain/entities/expense.dart';
import '../../../../domain/entities/expense_category.dart';
import '../../../../domain/value_objects/money.dart';
import '../../../../domain/value_objects/order_date.dart';
import '../cubit/add_expense_cubit.dart';
import '../cubit/add_expense_state.dart';

class AddExpenseDialog extends StatelessWidget {
  final Future<void> Function(Expense expense)? onExpenseCreated;
  final AddExpenseCubit? cubit;

  const AddExpenseDialog({
    super.key,
    this.onExpenseCreated,
    this.cubit,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => (cubit ?? getIt<AddExpenseCubit>())..loadCategories(),
      child: _AddExpenseDialogView(onExpenseCreated: onExpenseCreated),
    );
  }
}

class _AddExpenseDialogView extends StatefulWidget {
  final Future<void> Function(Expense expense)? onExpenseCreated;

  const _AddExpenseDialogView({this.onExpenseCreated});

  @override
  State<_AddExpenseDialogView> createState() => _AddExpenseDialogViewState();
}

class _AddExpenseDialogViewState extends State<_AddExpenseDialogView> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String? _validationError;

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool _isOtherCategory(ExpenseCategory? category) =>
      category != null && (category.name == 'أخرى' || category.name.contains('أخرى'));

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('ar'),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _handleSave(AddExpenseState state) async {
    final amountText = _amountController.text.trim();
    final amountVal = double.tryParse(amountText);

    if (amountVal == null || amountVal <= 0) {
      setState(() => _validationError = 'يرجى إدخال مبلغ صحيح أكبر من الصفر');
      return;
    }

    if (state.selectedCategory == null) {
      setState(() => _validationError = 'يرجى اختيار تصنيف المصروف');
      return;
    }

    final nameText = _nameController.text.trim();
    if (_isOtherCategory(state.selectedCategory) && nameText.isEmpty) {
      setState(() => _validationError = 'يرجى إدخال اسم المصروف عند اختيار تصنيف أخرى');
      return;
    }

    setState(() => _validationError = null);

    final cubit = context.read<AddExpenseCubit>();
    final expense = await cubit.createExpense(
      amount: Money.fromEgp(amountVal),
      category: state.selectedCategory!,
      expenseName: nameText.isNotEmpty ? nameText : null,
      expenseDate: OrderDate.fromDate(_selectedDate),
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
    );

    if (expense != null) {
      if (widget.onExpenseCreated != null) {
        await widget.onExpenseCreated!(expense);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AddExpenseCubit, AddExpenseState>(
      builder: (context, state) {
        final errorMessage = _validationError ?? state.errorMessage;
        final isOther = _isOtherCategory(state.selectedCategory);

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
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
                      Text('إضافة مصروف', style: AppTextStyles.titleLarge),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  AppSpacing.gapLg,

                  // Error notification
                  if (errorMessage != null) ...[
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
                              errorMessage,
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.gapMd,
                  ],

                  // Amount Field
                  AppTextField(
                    controller: _amountController,
                    label: 'المبلغ (ج.م) *',
                    hintText: '0.00',
                    keyboardType: TextInputType.number,
                  ),
                  AppSpacing.gapLg,

                  // Category Dropdown
                  Text('فئة المصروف *', style: AppTextStyles.labelLarge),
                  AppSpacing.gapXs,
                  if (state.isLoadingCategories)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: LinearProgressIndicator(),
                    )
                  else
                    DropdownButtonFormField<ExpenseCategory>(
                      key: const ValueKey('expense_category_dropdown'),
                      initialValue: state.selectedCategory,
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          borderSide: const BorderSide(
                            color: AppColors.borderFocused,
                            width: 1.5,
                          ),
                        ),
                      ),
                      items: state.categories.map((cat) {
                        return DropdownMenuItem<ExpenseCategory>(
                          value: cat,
                          child: Text(cat.name, style: AppTextStyles.bodyMedium),
                        );
                      }).toList(),
                      onChanged: (cat) {
                        if (cat != null) {
                          setState(() => _validationError = null);
                          context.read<AddExpenseCubit>().selectCategory(cat);
                        }
                      },
                    ),
                  AppSpacing.gapLg,

                  // Expense Name (Conditional when category is "أخرى")
                  if (isOther) ...[
                    AppTextField(
                      key: const ValueKey('expense_name_field'),
                      controller: _nameController,
                      label: 'اسم المصروف *',
                      hintText: 'مثال: قهوة للعاملين، صيانة كهربائية',
                    ),
                    AppSpacing.gapLg,
                  ],

                  // Date Picker Field
                  Text('التاريخ *', style: AppTextStyles.labelLarge),
                  AppSpacing.gapXs,
                  InkWell(
                    key: const ValueKey('expense_date_picker_button'),
                    onTap: _selectDate,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          AppSpacing.gapHorizontalSm,
                          Expanded(
                            child: Text(
                              DateFormatter.formatArabicDate(_selectedDate),
                              style: AppTextStyles.bodyMedium,
                            ),
                          ),
                          Text(
                            'تغيير',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AppSpacing.gapLg,

                  // Notes Field
                  AppTextField(
                    controller: _notesController,
                    label: 'ملاحظات',
                    hintText: 'أي ملاحظات إضافية حول المصروف',
                    maxLines: 2,
                  ),
                  AppSpacing.gapXl,

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AppButton(
                        label: 'إلغاء',
                        variant: AppButtonVariant.secondary,
                        onPressed: state.isSaving ? null : () => Navigator.of(context).pop(),
                      ),
                      AppSpacing.gapHorizontalMd,
                      AppButton(
                        key: const ValueKey('save_expense_button'),
                        label: 'حفظ',
                        isLoading: state.isSaving,
                        onPressed: () => _handleSave(state),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
