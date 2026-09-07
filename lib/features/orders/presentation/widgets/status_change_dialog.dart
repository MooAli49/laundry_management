import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../domain/enums/order_status.dart';

class StatusChangeDialog extends StatefulWidget {
  final OrderStatus targetStatus;
  final Future<void> Function(String reason) onConfirm;

  const StatusChangeDialog({
    super.key,
    required this.targetStatus,
    required this.onConfirm,
  });

  @override
  State<StatusChangeDialog> createState() => _StatusChangeDialogState();
}

class _StatusChangeDialogState extends State<StatusChangeDialog> {
  final TextEditingController _reasonController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  String get _statusLabel {
    switch (widget.targetStatus) {
      case OrderStatus.processing:
        return 'قيد التجهيز';
      case OrderStatus.ready:
        return 'جاهز';
      case OrderStatus.completed:
        return 'مكتمل';
      case OrderStatus.cancelled:
        return 'ملغي';
    }
  }

  Future<void> _handleConfirm() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _errorMessage = 'سبب التعديل اليدوي مطلوب');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onConfirm(reason);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('ValidationFailure: ', '');
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
                  Text('تغيير حالة الطلب يدويًا', style: AppTextStyles.titleLarge),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              AppSpacing.gapMd,

              Text(
                'سيتم تغيير حالة الطلب إلى "$_statusLabel". يتطلب هذا التغيير سبباً تشغيلياً واضحاً.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              AppSpacing.gapLg,

              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.error),
                ),
                AppSpacing.gapSm,
              ],

              AppTextField(
                controller: _reasonController,
                label: 'سبب التعديل *',
                hintText: 'اكتب سبب التعديل اليدوي للحالة...',
                maxLines: 3,
              ),
              AppSpacing.gapXl,

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
                    label: 'تأكيد التعديل',
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
}
