import 'package:flutter/material.dart';

import '../../domain/enums/order_status.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

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
        fg = AppColors.info;
        label = 'قيد التجهيز';
        break;
      case OrderStatus.ready:
        bg = AppColors.primaryLighter;
        fg = AppColors.primaryDark;
        label = 'جاهز';
        break;
      case OrderStatus.completed:
        bg = AppColors.successLight;
        fg = AppColors.success;
        label = 'مكتمل';
        break;
      case OrderStatus.cancelled:
        bg = AppColors.errorLight;
        fg = AppColors.error;
        label = 'ملغي';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10.0,
        vertical: 3.0,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 6.0,
            height: 6.0,
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6.0),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: fg,
              fontWeight: FontWeight.w500,
              fontSize: 12.0,
            ),
          ),
        ],
      ),
    );
  }
}
