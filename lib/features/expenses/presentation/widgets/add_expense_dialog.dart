import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../domain/entities/expense.dart';
import '../../../../domain/entities/expense_category.dart';
import '../../../../domain/repositories/expense_category_repository.dart';
import '../../../../domain/repositories/expense_repository.dart';
import '../../../../domain/value_objects/money.dart';
import '../../../../domain/value_objects/order_date.dart';

class AddExpenseDialog extends StatefulWidget {
  final Future<void> Function(Expense expense)? onExpenseCreated;

  const AddExpenseDialog({
    super.key,
    this.onExpenseCreated,
  });

  @override
  State<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<AddExpenseDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<ExpenseCategory> _categories = [];
  ExpenseCategory? _selectedCategory;
  DateTime _selectedDate = DateTime.now();

  bool _isLoadingCategories = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final repo = getIt<ExpenseCategoryRepository>();
      final cats = await repo.getActiveCategories();
      if (mounted) {
        setState(() {
          _categories = cats;
          _isLoadingCategories = false;
          if (cats.isNotEmpty) {
            _selectedCategory = cats.firstWhere(
              (c) => c.name != 'أخرى' && !c.name.contains('أخرى'),
              orElse: () => cats.first,
            );
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
          _errorMessage = 'تعذر تحميل تصنيفات المصروفات';
        });
      }
    }
  }

  bool get _isOtherCategory =>
      _selectedCategory != null &&
      (_selectedCategory!.name == 'أخرى' || _selectedCategory!.name.contains('أخرى'));

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

  Future<void> _handleSave() async {
    final amountText = _amountController.text.trim();
    final amountVal = double.tryParse(amountText);

    if (amountVal == null || amountVal <= 0) {
      setState(() => _errorMessage = 'يرجى إدخال مبلغ صحيح أكبر من الصفر');
      return;
    }

    if (_selectedCategory == null) {
      setState(() => _errorMessage = 'يرجى اختيار تصنيف المصروف');
      return;
    }

    final nameText = _nameController.text.trim();
    if (_isOtherCategory && nameText.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال اسم المصروف عند اختيار تصنيف أخرى');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now();
      final expense = Expense(
        id: const Uuid().v4(),
        expenseCategoryId: _selectedCategory!.id,
        amount: Money.fromEgp(amountVal),
        expenseName: nameText.isNotEmpty ? nameText : null,
        expenseDate: OrderDate.fromDate(_selectedDate),
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        categoryNameSnapshot: _selectedCategory!.name,
        createdAt: now,
        updatedAt: now,
      );

      final repo = getIt<ExpenseRepository>();
      await repo.createExpense(expense);

      if (widget.onExpenseCreated != null) {
        await widget.onExpenseCreated!(expense);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Failure catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'حدث خطأ أثناء حفظ المصروف';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'إضافة مصروف',
                    style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              AppSpacing.gapLg,

              // Error notification
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

              // Amount Field
              AppTextField(
                controller: _amountController,
                label: 'المبلغ (ج.م) *',
                hintText: '0.00',
                keyboardType: TextInputType.number,
              ),
              AppSpacing.gapMd,

              // Category Dropdown
              Text('التصنيف *', style: AppTextStyles.labelLarge),
              AppSpacing.gapXs,
              if (_isLoadingCategories)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: LinearProgressIndicator(),
                )
              else
                DropdownButtonFormField<ExpenseCategory>(
                  key: const ValueKey('expense_category_dropdown'),
                  initialValue: _selectedCategory,
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
                      borderSide: const BorderSide(color: AppColors.borderFocused, width: 1.5),
                    ),
                  ),
                  items: _categories.map((cat) {
                    return DropdownMenuItem<ExpenseCategory>(
                      value: cat,
                      child: Text(cat.name, style: AppTextStyles.bodyMedium),
                    );
                  }).toList(),
                  onChanged: (cat) {
                    if (cat != null) {
                      setState(() {
                        _selectedCategory = cat;
                        _errorMessage = null;
                      });
                    }
                  },
                ),
              AppSpacing.gapMd,

              // Expense Name (Conditional when category is "أخرى")
              if (_isOtherCategory) ...[
                AppTextField(
                  key: const ValueKey('expense_name_field'),
                  controller: _nameController,
                  label: 'اسم المصروف *',
                  hintText: 'مثال: قهوة للعاملين، صيانة كهربائية',
                ),
                AppSpacing.gapMd,
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
                      const Icon(Icons.calendar_today_outlined,
                          size: 20, color: AppColors.textSecondary),
                      AppSpacing.gapHorizontalSm,
                      Expanded(
                        child: Text(
                          DateFormatter.formatArabicDate(_selectedDate),
                          style: AppTextStyles.bodyMedium,
                        ),
                      ),
                      Text(
                        'تغيير',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
              AppSpacing.gapMd,

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
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  AppSpacing.gapHorizontalSm,
                  AppButton(
                    key: const ValueKey('save_expense_button'),
                    label: 'حفظ المصروف',
                    isLoading: _isLoading,
                    onPressed: _handleSave,
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
