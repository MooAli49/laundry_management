import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../domain/enums/order_status.dart';

class StatusChangeDialog extends StatefulWidget {
  final OrderStatus currentStatus;
  final OrderStatus targetStatus;
  final Future<void> Function(String reason) onConfirm;

  const StatusChangeDialog({
    super.key,
    this.currentStatus = OrderStatus.processing,
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

  String get _dialogTitle {
    if (widget.targetStatus == OrderStatus.processing) {
      return 'تصحيح تشغيلي — إعادة إلى قيد التجهيز';
    }
    return 'تعديل حالة الطلب يدويًا';
  }

  String get _consequenceExplanation {
    if (widget.currentStatus == OrderStatus.ready &&
        widget.targetStatus == OrderStatus.processing) {
      return 'تنبيه: هذا الإجراء تصحيح تشغيلي.\n'
          '• سيتم إلغاء تفعيل كافة سجلات التخزين الحالية لعناصر الطلب.\n'
          '• يتم الاحتفاظ بالسجلات التاريخية للتخزين دون حذف.\n'
          '• ستصبح كافة العناصر غير مخزنة ويجب تخزينها يدويًا مرة أخرى.\n'
          '• لن يتم إعادة تفعيل التخزين تلقائيًا.';
    }

    if (widget.currentStatus == OrderStatus.completed &&
        widget.targetStatus == OrderStatus.processing) {
      return 'تنبيه: هذا الإجراء تصحيح تشغيلي.\n'
          '• ستتم إعادة الطلب إلى حالة "قيد التجهيز".\n'
          '• لن يتم استرجاع التخزين تلقائيًا وتبقى العناصر غير مخزنة.\n'
          '• يجب تخزين العناصر يدويًا مرة أخرى إذا لزم الأمر.';
    }

    if (widget.currentStatus == OrderStatus.processing &&
        widget.targetStatus == OrderStatus.ready) {
      return 'تنبيه: هذا الإجراء تعديل يدوي للحالة فقط.\n'
          '• لن يتم تعديل، إنشاء، أو حذف أي سجلات تخزين حالية.\n'
          '• الحالة التشغيلية للتخزين تبقى كما هي بالضبط.';
    }

    return 'يتطلب هذا التعديل سببًا تشغيليًا إلزاميًا وواضحًا للمتابعة.';
  }

  Color get _bannerColor {
    if (widget.targetStatus == OrderStatus.processing) {
      return AppColors.warningLight;
    }
    return AppColors.infoLight;
  }

  Color get _bannerTextColor {
    if (widget.targetStatus == OrderStatus.processing) {
      return AppColors.warning;
    }
    return AppColors.info;
  }

  Future<void> _handleConfirm() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _errorMessage = 'سبب التعديل التشغيلي مطلوب');
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
        _errorMessage = e.toString().replaceFirst('ValidationFailure: ', '').replaceFirst('BusinessRuleFailure: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_dialogTitle, style: AppTextStyles.titleLarge),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              AppSpacing.gapMd,

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: _bannerColor,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(
                    color: _bannerTextColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _consequenceExplanation,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: _bannerTextColor,
                    height: 1.5,
                  ),
                ),
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
                label: 'سبب التعديل التشغيلي *',
                hintText: 'اكتب سبباً تشغيلياً دقيقاً لهذا التعديل...',
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
