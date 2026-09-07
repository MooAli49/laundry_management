import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../domain/enums/payment_method.dart';
import '../../../../domain/value_objects/money.dart';

class AddPaymentDialog extends StatefulWidget {
  final Money remainingAmount;
  final Future<void> Function({
    required Money amount,
    required PaymentMethod method,
  }) onConfirm;

  const AddPaymentDialog({
    super.key,
    required this.remainingAmount,
    required this.onConfirm,
  });

  @override
  State<AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends State<AddPaymentDialog> {
  final TextEditingController _amountController = TextEditingController();
  PaymentMethod _selectedMethod = PaymentMethod.cash;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _fillFullAmount() {
    setState(() {
      _amountController.text = widget.remainingAmount.toEgp.toStringAsFixed(2);
      _errorMessage = null;
    });
  }

  Future<void> _handleConfirm() async {
    final text = _amountController.text.trim();
    final parsed = double.tryParse(text);

    if (parsed == null || parsed <= 0) {
      setState(() => _errorMessage = 'يرجى إدخال مبلغ أكبر من الصفر');
      return;
    }

    final enteredMoney = Money.fromEgp(parsed);
    if (enteredMoney > widget.remainingAmount) {
      setState(() => _errorMessage = 'المبلغ المدخل يتجاوز المبلغ المتبقي على الطلب');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onConfirm(
        amount: enteredMoney,
        method: _selectedMethod,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('BusinessRuleFailure: ', '');
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
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('إضافة دفعة', style: AppTextStyles.titleLarge),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              AppSpacing.gapLg,

              // Remaining Banner
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'المبلغ المتبقي',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryDark),
                    ),
                    Text(
                      '${widget.remainingAmount.toEgp.toStringAsFixed(2)} ج.م',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
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

              // Amount Field with "المبلغ كامل" Quick Action
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _amountController,
                      label: 'المبلغ (ج.م) *',
                      hintText: '0.00',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  AppSpacing.gapHorizontalSm,
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: AppButton(
                      label: 'المبلغ كامل',
                      variant: AppButtonVariant.outline,
                      onPressed: _fillFullAmount,
                    ),
                  ),
                ],
              ),
              AppSpacing.gapLg,

              // Payment Method Toggle
              Text('طريقة الدفع *', style: AppTextStyles.labelLarge),
              AppSpacing.gapSm,
              Row(
                children: [
                  Expanded(
                    child: _buildMethodButton(PaymentMethod.cash, 'كاش', Icons.money),
                  ),
                  AppSpacing.gapHorizontalSm,
                  Expanded(
                    child: _buildMethodButton(PaymentMethod.instapay, 'InstaPay', Icons.flash_on),
                  ),
                  AppSpacing.gapHorizontalSm,
                  Expanded(
                    child: _buildMethodButton(PaymentMethod.ewallet, 'محفظة إلكترونية', Icons.account_balance_wallet),
                  ),
                ],
              ),
              AppSpacing.gapXl,

              // Actions
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
                    label: 'تأكيد الدفع',
                    isLoading: _isLoading,
                    onPressed: _handleConfirm,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMethodButton(PaymentMethod method, String label, IconData icon) {
    final isSelected = _selectedMethod == method;
    return InkWell(
      onTap: () => setState(() => _selectedMethod = method),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.selectionBackground : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 20,
            ),
            AppSpacing.gapXs,
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
