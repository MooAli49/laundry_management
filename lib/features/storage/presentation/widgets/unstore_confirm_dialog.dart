import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../domain/entities/storage_item.dart';

/// UnstoreConfirmDialog matching the approved Figma modal design.
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
        _errorMessage = e
            .toString()
            .replaceFirst('BusinessRuleFailure: ', '')
            .replaceFirst('Failure: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      backgroundColor: AppColors.surfaceElevated,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.remove_circle_outline,
                      color: AppColors.error,
                      size: 20,
                    ),
                  ),
                  AppSpacing.gapHorizontalMd,
                  Expanded(
                    child: Text(
                      AppStrings.unstoreConfirmTitle,
                      style: AppTextStyles.headlineMedium.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              AppSpacing.gapLg,

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.error,
                      fontSize: 13,
                    ),
                  ),
                ),
                AppSpacing.gapMd,
              ],

              Text(
                AppStrings.unstoreConfirmMessage,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              AppSpacing.gapLg,

              // Item details banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${widget.item.orderNumber} — ${widget.item.customerName}',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.item.orderItem.itemTypeNameSnapshot} — ${widget.item.orderItem.serviceNameSnapshot}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.gapXxl,

              // Footer: Confirm + Cancel (in RTL, Confirm appears on right)
              Row(
                children: [
                  AppButton(
                    label: AppStrings.confirmUnstore,
                    variant: AppButtonVariant.destructive,
                    isLoading: _isLoading,
                    onPressed: _isLoading ? null : _handleConfirm,
                  ),
                  AppSpacing.gapHorizontalMd,
                  AppButton(
                    label: AppStrings.cancel,
                    variant: AppButtonVariant.secondary,
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
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
