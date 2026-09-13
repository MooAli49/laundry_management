import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../domain/entities/carpet_size.dart';
import '../cubit/carpet_sizes_management_cubit.dart';

class CarpetSizeFormDialog extends StatefulWidget {
  final CarpetSize? carpetSize;

  const CarpetSizeFormDialog({super.key, this.carpetSize});

  static Future<bool?> show(BuildContext context, {CarpetSize? carpetSize}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: context.read<CarpetSizesManagementCubit>(),
        child: CarpetSizeFormDialog(carpetSize: carpetSize),
      ),
    );
  }

  @override
  State<CarpetSizeFormDialog> createState() => _CarpetSizeFormDialogState();
}

class _CarpetSizeFormDialogState extends State<CarpetSizeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _lengthController;
  late final TextEditingController _widthController;
  late final TextEditingController _areaController;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    final cs = widget.carpetSize;
    _lengthController = TextEditingController(
      text: cs != null ? _formatNum(cs.length) : '',
    );
    _widthController = TextEditingController(
      text: cs != null ? _formatNum(cs.width) : '',
    );
    _areaController = TextEditingController(
      text: cs != null ? _formatNum(cs.area) : '',
    );

    _lengthController.addListener(_calculateArea);
    _widthController.addListener(_calculateArea);
  }

  @override
  void dispose() {
    _lengthController.removeListener(_calculateArea);
    _widthController.removeListener(_calculateArea);
    _lengthController.dispose();
    _widthController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  String _formatNum(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(2);
  }

  double? _parseLocalizedDouble(String text) {
    var clean = text.trim();
    if (clean.isEmpty) return null;
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const westernDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    for (var i = 0; i < arabicDigits.length; i++) {
      clean = clean.replaceAll(arabicDigits[i], westernDigits[i]);
    }
    return double.tryParse(clean);
  }

  void _calculateArea() {
    final len = _parseLocalizedDouble(_lengthController.text);
    final wid = _parseLocalizedDouble(_widthController.text);
    if (len != null && wid != null && len > 0 && wid > 0) {
      final area = len * wid;
      _areaController.text = _formatNum(area);
    } else {
      _areaController.text = '';
    }
  }

  Future<void> _handleSubmit() async {
    setState(() => _inlineError = null);
    if (!_formKey.currentState!.validate()) return;

    final length = _parseLocalizedDouble(_lengthController.text);
    final width = _parseLocalizedDouble(_widthController.text);

    if (length == null || length <= 0) {
      setState(() => _inlineError = AppStrings.carpetLengthRequired);
      return;
    }
    if (width == null || width <= 0) {
      setState(() => _inlineError = AppStrings.carpetWidthRequired);
      return;
    }

    final cubit = context.read<CarpetSizesManagementCubit>();
    bool success;

    if (widget.carpetSize == null) {
      success = await cubit.createCarpetSize(length: length, width: width);
    } else {
      final updated = widget.carpetSize!.copyWith(length: length, width: width);
      success = await cubit.updateCarpetSize(carpetSize: updated);
    }

    if (success && mounted) {
      Navigator.of(context).pop(true);
    } else if (mounted) {
      setState(() {
        _inlineError = cubit.state.errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.carpetSize != null;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? AppStrings.editCarpetSize : AppStrings.addCarpetSize,
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.lg, color: AppColors.divider),
                AppSpacing.gapMd,
                if (_inlineError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.error,
                          size: 20,
                        ),
                        AppSpacing.gapHorizontalSm,
                        Expanded(
                          child: Text(
                            _inlineError!,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapMd,
                ],
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _lengthController,
                        label: AppStrings.carpetLengthLabel,
                        hintText: 'مثال: 3.0',
                        prefixIcon: const Icon(
                          Icons.straighten_outlined,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return AppStrings.carpetLengthRequired;
                          }
                          final parsed = _parseLocalizedDouble(value);
                          if (parsed == null || parsed <= 0) {
                            return AppStrings.carpetLengthRequired;
                          }
                          return null;
                        },
                      ),
                    ),
                    AppSpacing.gapHorizontalMd,
                    Expanded(
                      child: AppTextField(
                        controller: _widthController,
                        label: AppStrings.carpetWidthLabel,
                        hintText: 'مثال: 2.0',
                        prefixIcon: const Icon(
                          Icons.straighten_outlined,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return AppStrings.carpetWidthRequired;
                          }
                          final parsed = _parseLocalizedDouble(value);
                          if (parsed == null || parsed <= 0) {
                            return AppStrings.carpetWidthRequired;
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapLg,
                // Read-only Area with auto calculation indicator
                AppTextField(
                  controller: _areaController,
                  label: '${AppStrings.carpetAreaLabel} (يُحسب تلقائياً)',
                  enabled: false,
                  prefixIcon: const Icon(
                    Icons.square_foot_outlined,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
                AppSpacing.gapXxl,
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton(
                      label: AppStrings.cancel,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    AppSpacing.gapHorizontalMd,
                    AppButton(
                      label: AppStrings.save,
                      onPressed: _handleSubmit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
