import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../domain/entities/storage_item.dart';

class UnstoreConfirmDialog extends StatefulWidget {
  final StorageItem item;
  final Future<void> Function() onConfirm;

  const UnstoreConfirmDialog({
    super.key,
    required this.item,
    required this.onConfirm,
  });

  @override
  State<UnstoreConfirmDialog> createState() => _UnstoreConfirmDialogState();
}

class _UnstoreConfirmDialogState extends State<UnstoreConfirmDialog> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleConfirm() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onConfirm();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('BusinessRuleFailure: ', '').replaceFirst('Failure: ', '');
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
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                  ),
                  AppSpacing.gapHorizontalMd,
                  Expanded(
                    child: Text(AppStrings.unstoreConfirmTitle, style: AppTextStyles.titleLarge),
                  ),
                ],
              ),
              AppSpacing.gapMd,

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
                  ),
                ),
                AppSpacing.gapMd,
              ],

              Text(
                AppStrings.unstoreConfirmMessage,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              AppSpacing.gapMd,

              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${AppStrings.orderNumberPrefix}${widget.item.orderNumber} - ${widget.item.customerName}',
                      style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
                    ),
                    AppSpacing.gapXs,
                    Text(
                      '${widget.item.orderItem.itemTypeNameSnapshot} - ${widget.item.orderItem.serviceNameSnapshot}',
                      style: AppTextStyles.titleMedium,
                    ),
                  ],
                ),
              ),
              AppSpacing.gapXl,

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: AppStrings.cancel,
                    variant: AppButtonVariant.secondary,
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  ),
                  AppSpacing.gapHorizontalMd,
                  AppButton(
                    label: AppStrings.confirmUnstore,
                    variant: AppButtonVariant.destructive,
                    isLoading: _isLoading,
                    onPressed: _isLoading ? null : _handleConfirm,
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
