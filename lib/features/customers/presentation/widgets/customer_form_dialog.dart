import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/phone_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../domain/entities/customer.dart';
import '../../../../domain/repositories/customer_repository.dart';

class CustomerFormDialog extends StatefulWidget {
  final Customer? customer;
  final Future<void> Function({
    required String name,
    required String phone,
    String? notes,
  }) onSave;
  final void Function(Customer existingCustomer)? onViewExisting;

  const CustomerFormDialog({
    super.key,
    this.customer,
    required this.onSave,
    this.onViewExisting,
  });

  @override
  State<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<CustomerFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _notesController;

  bool _isLoading = false;
  String? _errorMessage;
  Customer? _duplicateCustomer;

  bool get _isEditing => widget.customer != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer?.name ?? '');
    _phoneController = TextEditingController(text: widget.customer?.phone ?? '');
    _notesController = TextEditingController(text: widget.customer?.notes ?? '');
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
    final rawPhone = _phoneController.text.trim();
    final phone = PhoneUtils.normalizePhoneNumber(rawPhone);

    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'اسم العميل مطلوب';
        _duplicateCustomer = null;
      });
      return;
    }
    if (phone.isEmpty) {
      setState(() {
        _errorMessage = 'رقم الهاتف مطلوب';
        _duplicateCustomer = null;
      });
      return;
    }
    if (!PhoneUtils.isValidCustomerPhone(phone)) {
      setState(() {
        _errorMessage = 'رقم الهاتف غير صحيح';
        _duplicateCustomer = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _duplicateCustomer = null;
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
    } on DuplicateCustomerPhoneFailure catch (e) {
      Customer? existing;
      try {
        existing = await getIt<CustomerRepository>().getCustomerByPhone(phone);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.message;
          _duplicateCustomer = existing;
        });
      }
    } on Failure catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
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
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEditing ? 'تعديل بيانات العميل' : 'إضافة عميل جديد',
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error),
                          AppSpacing.gapHorizontalSm,
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_duplicateCustomer != null && widget.onViewExisting != null) ...[
                        AppSpacing.gapSm,
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton.icon(
                            onPressed: () {
                              final existing = _duplicateCustomer!;
                              Navigator.of(context).pop();
                              widget.onViewExisting!(existing);
                            },
                            icon: const Icon(Icons.visibility_outlined, size: 16),
                            label: const Text('عرض العميل'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
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
                    label: _isEditing ? 'حفظ التعديلات' : 'حفظ العميل',
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
