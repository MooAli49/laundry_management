import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
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
            style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold),
          ),
          AppSpacing.gapLg,

          _buildRow('عدد القطع', '$totalPieces قطعة'),
          AppSpacing.gapSm,
          _buildRow('المجموع الفرعي', '${state.subtotal.toEgp.toStringAsFixed(2)} ج.م'),

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

          const Divider(height: AppSpacing.xl, color: AppColors.divider),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الإجمالي',
                style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold),
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
          AppSpacing.gapXl,

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
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
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
