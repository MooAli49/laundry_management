import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_state.dart';
import 'settings_table_components.dart';

class BusinessInfoSection extends StatefulWidget {
  const BusinessInfoSection({super.key});

  @override
  State<BusinessInfoSection> createState() => _BusinessInfoSectionState();
}

class _BusinessInfoSectionState extends State<BusinessInfoSection> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _invoiceFooterController;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _invoiceFooterController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _invoiceFooterController.dispose();
    super.dispose();
  }

  void _populateFields(SettingsState state) {
    if (state.settings != null && !_initialized) {
      _nameController.text = state.settings!.businessName;
      _phoneController.text = state.settings!.phone ?? '';
      _addressController.text = state.settings!.address ?? '';
      _invoiceFooterController.text = state.settings!.invoiceFooterText ?? '';
      _initialized = true;
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final cubit = context.read<SettingsCubit>();
    final success = await cubit.updateBusinessInfo(
      businessName: _nameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      invoiceFooterText: _invoiceFooterController.text.trim().isEmpty
          ? null
          : _invoiceFooterController.text.trim(),
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.saveBusinessSettingsSuccess),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettingsCubit, SettingsState>(
      listener: (context, state) {
        if (state.settings != null && !_initialized) {
          _populateFields(state);
        }
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state.isLoading && state.settings == null) {
          return const Center(child: LoadingIndicator());
        }

        if (!_initialized && state.settings != null) {
          _populateFields(state);
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.tabBusinessInfo,
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontSize: 20,
                      ),
                    ),
                    AppSpacing.gapMd,
                    const SettingsInfoBanner(
                      message:
                          'هذه البيانات هي المصدر الوحيد لهوية النشاط، وتُستخدم تلقائياً في الفاتورة عند الطباعة.',
                    ),
                    AppSpacing.gapMd,
                    AppTextField(
                      controller: _nameController,
                      label: AppStrings.businessNameLabel,
                      hintText: 'مثال: مغسلةالحديثة',
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return AppStrings.businessNameRequired;
                        }
                        return null;
                      },
                    ),
                    AppSpacing.gapLg,
                    AppTextField(
                      controller: _phoneController,
                      label: AppStrings.businessPhoneLabel,
                      hintText: 'مثال: 01012345678',
                      keyboardType: TextInputType.phone,
                    ),
                    AppSpacing.gapLg,
                    AppTextField(
                      controller: _addressController,
                      label: AppStrings.businessAddressLabel,
                      hintText: 'مثال: شارع الجمهورية، المعادي، القاهرة',
                    ),
                    AppSpacing.gapLg,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          controller: TextEditingController(),
                          enabled: false,
                          label: 'الشعار (رابط صورة)',
                          hintText: '...//:https',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'اختياري — يظهر بجانب اسم النشاط في الفاتورة',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapLg,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          controller: _invoiceFooterController,
                          label: AppStrings.invoiceFooterLabel,
                          hintText:
                              'مثال: شكراً لتعاملكم معنا، نسعد بخدمتكم دائماً',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'اختياري — يظهر أسفل الفاتورة',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapXxl,
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ElevatedButton(
                        onPressed: state.isSaving ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd,
                            ),
                          ),
                        ),
                        child: Text(
                          state.isSaving ? 'جاري الحفظ...' : 'حفظ التغييرات',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
