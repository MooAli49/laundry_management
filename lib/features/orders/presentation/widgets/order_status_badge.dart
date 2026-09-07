import 'package:flutter/material.dart';

import '../../../../domain/enums/order_status.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

class OrderStatusBadge extends StatelessWidget {
  final OrderStatus status;

  const OrderStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case OrderStatus.processing:
        bg = AppColors.infoLight;
        fg = AppColors.infoDark;
        label = 'قيد التجهيز';
        break;
      case OrderStatus.ready:
        bg = AppColors.successLight;
        fg = AppColors.successDark;
        label = 'جاهز';
        break;
      case OrderStatus.completed:
        bg = AppColors.backgroundSecondary;
        fg = AppColors.textSecondary;
        label = 'مكتمل';
        break;
      case OrderStatus.cancelled:
        bg = AppColors.errorLight;
        fg = AppColors.errorDark;
        label = 'ملغي';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
