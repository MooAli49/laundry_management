import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../domain/value_objects/money.dart';
import '../cubit/create_order_state.dart';

class OrderSummaryCard extends StatelessWidget {
  final CreateOrderState state;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  const OrderSummaryCard({
    super.key,
    required this.state,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    var totalPieces = 0;
    for (final item in state.items) {
      totalPieces += item.physicalQuantity;
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ملخص الطلب',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          AppSpacing.gapMd,

          _buildRow('عدد القطع', '$totalPieces قطعة'),
          AppSpacing.gapSm,
          _buildRow(
            'المجموع الفرعي',
            '${state.subtotal.toEgp.toStringAsFixed(2)} ج.م',
          ),

          if (state.discount.isPositive) ...[
            AppSpacing.gapSm,
            _buildRow(
              'الخصم',
              '- ${state.discount.toEgp.toStringAsFixed(2)} ج.م',
              valueColor: AppColors.error,
            ),
          ],

          if (state.customerPickupRequested) ...[
            AppSpacing.gapSm,
            _buildRow(
              'رسوم الاستلام',
              '+ ${state.customerPickupFee.toEgp.toStringAsFixed(2)} ج.م',
            ),
          ],

          if (state.customerDeliveryRequested) ...[
            AppSpacing.gapSm,
            _buildRow(
              'رسوم التوصيل',
              '+ ${state.customerDeliveryFee.toEgp.toStringAsFixed(2)} ج.م',
            ),
          ],

          if (state.tax.isPositive) ...[
            AppSpacing.gapSm,
            _buildRow(
              'الضريبة',
              '+ ${state.tax.toEgp.toStringAsFixed(2)} ج.م',
            ),
          ],

          if (state.isInitialPaymentEnabled &&
              state.initialPaymentAmount.isPositive) ...[
            AppSpacing.gapSm,
            _buildRow(
              'الدفعة المقدمة',
              '- ${state.initialPaymentAmount.toEgp.toStringAsFixed(2)} ج.م',
              valueColor: AppColors.success,
            ),
          ],

          if (state.isInitialPaymentEnabled) ...[
            AppSpacing.gapSm,
            _buildRow(
              'المتبقي',
              state.remainingAmount == Money.zero
                  ? '0.00 ج.م (مدفوع بالكامل)'
                  : '${state.remainingAmount.toEgp.toStringAsFixed(2)} ج.م',
              valueColor: state.remainingAmount == Money.zero
                  ? AppColors.success
                  : AppColors.warningDark,
            ),
          ],

          const Divider(height: AppSpacing.lg, color: AppColors.divider),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceSelected,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الإجمالي',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${state.total.toEgp.toStringAsFixed(2)} ج.م',
                  style: AppTextStyles.headlineSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),

          if (state.isInitialPaymentEnabled &&
              state.initialPaymentAmount.isPositive) ...[
            AppSpacing.gapXs,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'المتبقي للتحصيل عند التسليم:',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    state.remainingAmount == Money.zero
                        ? 'خالص بالكامل'
                        : '${state.remainingAmount.toEgp.toStringAsFixed(2)} ج.م',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: state.remainingAmount == Money.zero
                          ? AppColors.success
                          : AppColors.warningDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
          AppSpacing.gapLg,

          AppButton(
            label: 'حفظ الطلب',
            isFullWidth: true,
            isLoading: state.isSubmitting,
            onPressed: state.items.isEmpty || state.selectedCustomer == null
                ? null
                : onSubmit,
          ),
          AppSpacing.gapSm,
          AppButton(
            label: 'إلغاء',
            variant: AppButtonVariant.secondary,
            isFullWidth: true,
            onPressed: state.isSubmitting ? null : onCancel,
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
