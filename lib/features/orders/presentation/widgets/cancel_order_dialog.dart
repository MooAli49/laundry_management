import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';

class CancelOrderDialog extends StatefulWidget {
  final Future<void> Function(String reason) onConfirmCancel;

  const CancelOrderDialog({super.key, required this.onConfirmCancel});

  @override
  State<CancelOrderDialog> createState() => _CancelOrderDialogState();
}

class _CancelOrderDialogState extends State<CancelOrderDialog> {
  final TextEditingController _reasonController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _errorMessage = 'سبب الإلغاء مطلوب');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onConfirmCancel(reason);
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
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'إلغاء الطلب',
                    style: AppTextStyles.titleLarge.copyWith(color: AppColors.error),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              AppSpacing.gapMd,

              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Text(
                  'هل أنت متأكد من رغبتك في إلغاء هذا الطلب؟ سيتم تحويل حالة الطلب إلى ملغي وإلغاء حجز أماكن التخزين. الطلبات الملغاة تصبح للقراءة فقط ولا يمكن التراجع عنها.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.error, fontSize: 13),
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
                label: 'سبب الإلغاء *',
                hintText: 'اكتب سبب إلغاء الطلب بالتفصيل...',
                maxLines: 3,
              ),
              AppSpacing.gapXl,

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'تراجع',
                    variant: AppButtonVariant.secondary,
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  ),
                  AppSpacing.gapHorizontalMd,
                  AppButton(
                    label: 'تأكيد الإلغاء',
                    variant: AppButtonVariant.destructive,
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
