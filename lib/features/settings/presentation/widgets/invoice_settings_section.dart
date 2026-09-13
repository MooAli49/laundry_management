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
import 'settings_table_components.dart';

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
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SettingsSectionHeader(
                title: AppStrings.invoicePreviewTitle,
                subtitle: AppStrings.invoicePreviewDescription,
                actions: [
                  AppButton(
                    label: AppStrings.save,
                    icon: Icons.save_outlined,
                    isLoading: state.isSaving,
                    onPressed: state.isSaving ? null : _handleSaveFooter,
                  ),
                ],
              ),
              const Divider(height: AppSpacing.xxl, color: AppColors.divider),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Editor Column
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.invoiceFooterLabel,
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        AppSpacing.gapXs,
                        Text(
                          'اكتب نص التذييل المطبوع أسفل كل فاتورة حرارية (مثل سياسة الاستلام أو رسالة شكر للعميل).',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        AppSpacing.gapMd,
                        AppTextField(
                          controller: _footerController,
                          hintText: AppStrings.invoiceFooterHint,
                          maxLines: 4,
                          onChanged: (_) => setState(() {}),
                        ),
                        AppSpacing.gapLg,
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.infoLight,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            border: Border.all(
                              color: AppColors.info.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.print_outlined,
                                color: AppColors.info,
                                size: 20,
                              ),
                              AppSpacing.gapHorizontalSm,
                              Expanded(
                                child: Text(
                                  'المعاينة المجاورة تمثل الطباعة الحية على بكرة ورق طابعة الكاشير الحرارية مقاس 80 مم بدقة 203 DPI.',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.infoDark,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.gapXxl,
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
                  // 80mm Live Thermal Receipt Preview Tray
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryLight,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Center(
                        child: Container(
                          width: 350,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.xl,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            border: Border.all(color: AppColors.borderStrong),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Thermal paper cut indicator header
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.receipt_long_outlined,
                                    size: 16,
                                    color: AppColors.textTertiary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'فاتورة استلام (80 مم)',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textTertiary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              AppSpacing.gapSm,
                              _buildDashedDivider(),
                              AppSpacing.gapMd,
                              Text(
                                businessName,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.titleLarge.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
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
                                children: [
                                  Expanded(
                                    child: Text(
                                      'رقم الطلب: #1024',
                                      style: AppTextStyles.labelMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
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
                              // Live Footer text
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                ),
                                child: Text(
                                  liveFooter,
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
    return const SizedBox(
      height: 1,
      width: double.infinity,
      child: CustomPaint(painter: _ReceiptDashedLinePainter()),
    );
  }

  Widget _buildReceiptLine(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: isBold
                ? AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold)
                : AppTextStyles.bodySmall,
          ),
        ),
        AppSpacing.gapHorizontalSm,
        Text(
          value,
          style: isBold
              ? AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold)
              : AppTextStyles.bodySmall,
        ),
      ],
    );
  }
}

class _ReceiptDashedLinePainter extends CustomPainter {
  const _ReceiptDashedLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 4.0;
    const dashSpace = 3.0;
    final paint = Paint()
      ..color = AppColors.borderStrong
      ..strokeWidth = 1.0;

    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

