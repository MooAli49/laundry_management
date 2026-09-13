import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_state.dart';

class InvoiceSettingsSection extends StatefulWidget {
  const InvoiceSettingsSection({super.key});

  @override
  State<InvoiceSettingsSection> createState() => _InvoiceSettingsSectionState();
}

class _InvoiceSettingsSectionState extends State<InvoiceSettingsSection> {
  late final TextEditingController _footerController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _footerController = TextEditingController();
  }

  @override
  void dispose() {
    _footerController.dispose();
    super.dispose();
  }

  void _syncFooter(SettingsState state) {
    if (state.settings != null && !_initialized) {
      _footerController.text = state.settings!.invoiceFooterText ?? '';
      _initialized = true;
    }
  }

  Future<void> _handleSaveFooter() async {
    final cubit = context.read<SettingsCubit>();
    final current = cubit.state.settings;
    if (current == null) return;

    final success = await cubit.updateBusinessInfo(
      businessName: current.businessName,
      phone: current.phone,
      address: current.address,
      invoiceFooterText: _footerController.text.trim().isEmpty
          ? null
          : _footerController.text.trim(),
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
          _syncFooter(state);
        }
      },
      builder: (context, state) {
        if (state.isLoading && state.settings == null) {
          return const Center(child: LoadingIndicator());
        }

        if (!_initialized && state.settings != null) {
          _syncFooter(state);
        }

        final settings = state.settings;
        final businessName = (settings?.businessName.isNotEmpty == true)
            ? settings!.businessName
            : 'مغسلة الأمل الحديثة';
        final phone = settings?.phone ?? '01012345678';
        final address = settings?.address ?? 'القاهرة - مصر الجديدة';
        final liveFooter = _footerController.text.trim().isNotEmpty
            ? _footerController.text.trim()
            : (settings?.invoiceFooterText ?? 'شكراً لتعاملكم معنا، نسعد بخدمتكم دائماً');

        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.invoicePreviewTitle,
                style: AppTextStyles.titleLarge,
              ),
              AppSpacing.gapXs,
              Text(
                AppStrings.invoicePreviewDescription,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const Divider(height: AppSpacing.xxl, color: AppColors.divider),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left side (in RTL, Right side): Footer editing
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.invoiceFooterLabel,
                          style: AppTextStyles.titleMedium,
                        ),
                        AppSpacing.gapMd,
                        AppTextField(
                          controller: _footerController,
                          hintText: AppStrings.invoiceFooterHint,
                          maxLines: 4,
                          onChanged: (_) => setState(() {}),
                        ),
                        AppSpacing.gapLg,
                        AppButton(
                          label: AppStrings.save,
                          icon: Icons.save_outlined,
                          isLoading: state.isSaving,
                          onPressed: state.isSaving ? null : _handleSaveFooter,
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapHorizontalXxl,
                  // 80mm Live Thermal Receipt Preview Card
                  Expanded(
                    flex: 4,
                    child: Center(
                      child: Container(
                        width: 360,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          border: Border.all(color: AppColors.borderStrong),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              businessName,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.titleLarge.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (phone.isNotEmpty) ...[
                              AppSpacing.gapXs,
                              Text(
                                phone,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                            if (address.isNotEmpty) ...[
                              AppSpacing.gapXs,
                              Text(
                                address,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                            AppSpacing.gapMd,
                            _buildDashedDivider(),
                            AppSpacing.gapSm,
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('رقم الطلب: #1024', style: AppTextStyles.labelMedium),
                                Text('13/09/2026', style: AppTextStyles.bodySmall),
                              ],
                            ),
                            AppSpacing.gapSm,
                            _buildDashedDivider(),
                            AppSpacing.gapMd,
                            // Sample Items
                            _buildReceiptLine(AppStrings.sampleInvoiceItem1, '120.00 ج.م'),
                            AppSpacing.gapSm,
                            _buildReceiptLine(AppStrings.sampleInvoiceItem2, '180.00 ج.م'),
                            AppSpacing.gapMd,
                            _buildDashedDivider(),
                            AppSpacing.gapSm,
                            _buildReceiptLine(AppStrings.sampleInvoiceSubtotal, '300.00 ج.م'),
                            AppSpacing.gapSm,
                            _buildReceiptLine(
                              AppStrings.sampleInvoiceTotal,
                              '300.00 ج.م',
                              isBold: true,
                            ),
                            AppSpacing.gapSm,
                            _buildReceiptLine(AppStrings.sampleInvoicePaid, '300.00 ج.م'),
                            AppSpacing.gapSm,
                            _buildReceiptLine(AppStrings.sampleInvoiceRemaining, '0.00 ج.م'),
                            AppSpacing.gapLg,
                            _buildDashedDivider(),
                            AppSpacing.gapMd,
                            // Footer text
                            Text(
                              liveFooter,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDashedDivider() {
    return Row(
      children: List.generate(
        24,
        (index) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Container(
              height: 1,
              color: AppColors.borderStrong,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptLine(String title, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: (isBold ? AppTextStyles.titleSmall : AppTextStyles.bodySmall).copyWith(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: (isBold ? AppTextStyles.titleSmall : AppTextStyles.bodySmall).copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
