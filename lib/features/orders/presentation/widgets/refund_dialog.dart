import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../domain/entities/refund_balance_summary.dart';
import '../../../../domain/enums/refund_method.dart';
import '../../../../domain/value_objects/money.dart';
import '../cubit/refund_cubit.dart';
import '../cubit/refund_state.dart';

class RefundDialog extends StatefulWidget {
  final String orderId;
  final RefundBalanceSummary refundBalance;
  final VoidCallback? onRefundSuccess;
  final RefundCubit? cubit;

  const RefundDialog({
    super.key,
    required this.orderId,
    required this.refundBalance,
    this.onRefundSuccess,
    this.cubit,
  });

  @override
  State<RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<RefundDialog> {
  late final RefundCubit _cubit;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  RefundMethod _selectedMethod = RefundMethod.cash;
  String? _clientValidationError;

  @override
  void initState() {
    super.initState();
    _cubit = widget.cubit ?? getIt<RefundCubit>();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    if (widget.cubit == null) {
      _cubit.close();
    }
    super.dispose();
  }

  void _fillFullAmount() {
    setState(() {
      _amountController.text =
          widget.refundBalance.remainingRefundable.toEgp.toStringAsFixed(2);
      _clientValidationError = null;
    });
  }

  void _handleConfirm() {
    if (_cubit.state.isSubmitting) return;

    final text = _amountController.text.trim();
    if (text.isEmpty) {
      setState(() => _clientValidationError = 'يرجى إدخال مبلغ الاسترداد');
      return;
    }

    final parsedMoney = Money.tryParseEgp(text);
    if (parsedMoney == null || !parsedMoney.isPositive) {
      setState(
        () => _clientValidationError = 'مبلغ الاسترداد يجب أن يكون أكبر من الصفر',
      );
      return;
    }

    if (parsedMoney > widget.refundBalance.remainingRefundable) {
      setState(
        () =>
            _clientValidationError = 'مبلغ الاسترداد يتجاوز المبلغ القابل للاسترداد',
      );
      return;
    }

    setState(() => _clientValidationError = null);

    final rawReason = _reasonController.text.trim();
    final reason = rawReason.isEmpty ? null : rawReason;

    _cubit.submitRefund(
      orderId: widget.orderId,
      amount: parsedMoney,
      refundMethod: _selectedMethod,
      reason: reason,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<RefundCubit, RefundState>(
        listener: (context, state) {
          if (state.isSuccess) {
            Navigator.of(context).pop();
            widget.onRefundSuccess?.call();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم تسجيل الاسترداد بنجاح'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          final isSubmitting = state.isSubmitting;
          final activeError =
              _clientValidationError ?? state.errorMessage;

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            ),
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'استرداد المبلغ',
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    AppSpacing.gapLg,

                    // Financial Summary Banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusLg,
                        ),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          _buildSummaryRow(
                            'المبلغ المدفوع',
                            '${widget.refundBalance.totalPaid.toEgp.toStringAsFixed(2)} ج.م',
                            AppColors.textPrimary,
                          ),
                          const Divider(
                            height: AppSpacing.md,
                            color: AppColors.divider,
                          ),
                          _buildSummaryRow(
                            'المبلغ المسترد',
                            '${widget.refundBalance.totalRefunded.toEgp.toStringAsFixed(2)} ج.م',
                            AppColors.textSecondary,
                          ),
                          const Divider(
                            height: AppSpacing.md,
                            color: AppColors.divider,
                          ),
                          _buildSummaryRow(
                            'المبلغ القابل للاسترداد',
                            '${widget.refundBalance.remainingRefundable.toEgp.toStringAsFixed(2)} ج.م',
                            AppColors.warning,
                            isBold: true,
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.gapLg,

                    // Error Banner
                    if (activeError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.errorLight,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: AppColors.error,
                            ),
                            AppSpacing.gapHorizontalSm,
                            Expanded(
                              child: Text(
                                activeError,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppSpacing.gapMd,
                    ],

                    // Refund Amount Field with Full Refund Quick Action
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _amountController,
                            label: 'مبلغ الاسترداد (ج.م) *',
                            hintText: '0.00',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        AppSpacing.gapHorizontalSm,
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: AppButton(
                            label: 'استرداد كامل المبلغ',
                            variant: AppButtonVariant.secondary,
                            onPressed: isSubmitting ? null : _fillFullAmount,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapLg,

                    // Refund Method Selection
                    Text('طريقة الاسترداد *', style: AppTextStyles.labelLarge),
                    AppSpacing.gapSm,
                    Row(
                      children: [
                        Expanded(
                          child: _buildMethodButton(
                            RefundMethod.cash,
                            'نقدي',
                            Icons.payments_outlined,
                            isSubmitting,
                          ),
                        ),
                        AppSpacing.gapHorizontalSm,
                        Expanded(
                          child: _buildMethodButton(
                            RefundMethod.instaPay,
                            'InstaPay',
                            Icons.flash_on,
                            isSubmitting,
                          ),
                        ),
                        AppSpacing.gapHorizontalSm,
                        Expanded(
                          child: _buildMethodButton(
                            RefundMethod.eWallet,
                            'محفظة إلكترونية',
                            Icons.account_balance_wallet_outlined,
                            isSubmitting,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapLg,

                    // Optional Reason Field
                    AppTextField(
                      controller: _reasonController,
                      label: 'السبب (اختياري)',
                      hintText: 'سبب الاسترداد...',
                      maxLines: 2,
                    ),
                    AppSpacing.gapXl,

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        AppButton(
                          label: 'تأكيد الاسترداد',
                          isLoading: isSubmitting,
                          onPressed: isSubmitting ? null : _handleConfirm,
                        ),
                        AppSpacing.gapHorizontalMd,
                        AppButton(
                          label: 'إلغاء',
                          variant: AppButtonVariant.secondary,
                          onPressed: isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    Color color, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: isBold
                ? AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)
                : AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
          ),
        ),
        Text(
          value,
          style: isBold
              ? AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                )
              : AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
        ),
      ],
    );
  }

  Widget _buildMethodButton(
    RefundMethod method,
    String label,
    IconData icon,
    bool isSubmitting,
  ) {
    final isSelected = _selectedMethod == method;
    return InkWell(
      onTap: isSubmitting
          ? null
          : () => setState(() => _selectedMethod = method),
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
              color: isSelected
                  ? AppColors.primaryDark
                  : AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? AppColors.primaryDark
                    : AppColors.textSecondary,
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
