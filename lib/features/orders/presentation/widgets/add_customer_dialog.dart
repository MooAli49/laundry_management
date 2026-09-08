import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';

class AddCustomerDialog extends StatefulWidget {
  final String? initialQuery;
  final Future<void> Function({
    required String name,
    required String phone,
    String? notes,
  }) onSave;

  const AddCustomerDialog({
    super.key,
    this.initialQuery,
    required this.onSave,
  });

  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  final TextEditingController _notesController = TextEditingController();

  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final query = widget.initialQuery?.trim() ?? '';
    final isDigitsOnly = RegExp(r'^[0-9]+$').hasMatch(query);

    _nameController = TextEditingController(text: isDigitsOnly ? '' : query);
    _phoneController = TextEditingController(text: isDigitsOnly ? query : '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      setState(() => _errorMessage = 'اسم العميل مطلوب');
      return;
    }
    if (phone.isEmpty) {
      setState(() => _errorMessage = 'رقم الهاتف مطلوب');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onSave(
        name: name,
        phone: phone,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );
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
                    'إضافة عميل جديد',
                    style: AppTextStyles.titleLarge,
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              AppSpacing.gapLg,

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error),
                      AppSpacing.gapHorizontalSm,
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
                AppSpacing.gapMd,
              ],

              AppTextField(
                controller: _nameController,
                label: 'اسم العميل *',
                hintText: 'مثال: محمد أحمد',
              ),
              AppSpacing.gapMd,

              AppTextField(
                controller: _phoneController,
                label: 'رقم الهاتف *',
                hintText: 'مثال: 01012345678',
                keyboardType: TextInputType.phone,
              ),
              AppSpacing.gapMd,

              AppTextField(
                controller: _notesController,
                label: 'ملاحظات',
                hintText: 'أي ملاحظات خاصة بالعميل',
                maxLines: 2,
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
                    label: 'حفظ العميل',
                    isLoading: _isLoading,
                    onPressed: _handleSave,
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
