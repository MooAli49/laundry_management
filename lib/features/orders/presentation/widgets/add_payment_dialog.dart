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

              // Remaining Banner (Figma: warning-light background with warning text)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'المبلغ المتبقي',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${widget.remainingAmount.toEgp.toStringAsFixed(2)} ج.م',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.warning,
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
                      variant: AppButtonVariant.secondary,
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
                    child: _buildMethodButton(PaymentMethod.cash, 'كاش', Icons.payments_outlined),
                  ),
                  AppSpacing.gapHorizontalSm,
                  Expanded(
                    child: _buildMethodButton(PaymentMethod.instapay, 'إنستاباي', Icons.flash_on),
                  ),
                  AppSpacing.gapHorizontalSm,
                  Expanded(
                    child: _buildMethodButton(PaymentMethod.ewallet, 'محفظة إلكترونية', Icons.account_balance_wallet_outlined),
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
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceSelected : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
                fontSize: 13.0,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
