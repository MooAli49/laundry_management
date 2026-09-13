import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_state.dart';
import 'settings_table_components.dart';

class InvoiceSettingsSection extends StatelessWidget {
  const InvoiceSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        if (state.isLoading && state.settings == null) {
          return const Center(child: LoadingIndicator());
        }

        final settings = state.settings;
        final businessName = (settings?.businessName.isNotEmpty == true)
            ? settings!.businessName
            : 'مغسلة الأمل الحديثة';
        final phone = settings?.phone ?? '01012345678';
        final address = settings?.address ?? 'القاهرة - مصر الجديدة';
        final liveFooter = (settings?.invoiceFooterText?.isNotEmpty == true)
            ? settings!.invoiceFooterText!
            : 'شكراً لتعاملكم معنا، نسعد بخدمتكم دائماً';

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.tabInvoice,
                            style: AppTextStyles.titleLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppStrings.invoicePreviewTitle,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _showReceiptPreviewDialog(
                          context,
                          businessName,
                          phone,
                          address,
                          liveFooter,
                        ),
                        icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.primary),
                        label: Text(
                          'معاينة الفاتورة',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapMd,
                  const SettingsInfoBanner(
                    message: 'تُبنى الفاتورة تلقائياً من «بيانات النشاط» (الاسم، الهاتف، العنوان، الشعار، نص التذييل) ومن بيانات الطلب. لتعديل هوية النشاط انتقل إلى قسم «بيانات النشاط».',
                  ),
                  AppSpacing.gapMd,
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryRow('اسم النشاط', businessName),
                        const Divider(height: 24, color: Color(0xFFE2E8F0)),
                        _buildSummaryRow('رقم الهاتف', phone),
                        const Divider(height: 24, color: Color(0xFFE2E8F0)),
                        _buildSummaryRow('العنوان', address),
                        const Divider(height: 24, color: Color(0xFFE2E8F0)),
                        _buildSummaryRow('نص التذييل', liveFooter),
                      ],
                    ),
                  ),
                  AppSpacing.gapXxl,
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: ElevatedButton.icon(
                      onPressed: () => _showReceiptPreviewDialog(
                        context,
                        businessName,
                        phone,
                        address,
                        liveFooter,
                      ),
                      icon: const Icon(Icons.receipt_long_outlined, size: 18, color: Colors.white),
                      label: Text(
                        'معاينة الفاتورة',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _showReceiptPreviewDialog(
    BuildContext context,
    String businessName,
    String phone,
    String address,
    String liveFooter,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Center(
            child: SingleChildScrollView(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildSampleReceiptCard(
                    businessName: businessName,
                    phone: phone,
                    address: address,
                    footerText: liveFooter,
                  ),
                  PositionedDirectional(
                    top: 8,
                    start: 8,
                    child: IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      tooltip: 'إغلاق',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSampleReceiptCard({
    required String businessName,
    required String phone,
    required String address,
    required String footerText,
  }) {
    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            businessName,
            textAlign: TextAlign.center,
            style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            phone,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          Text(
            address,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          _buildDashedLine(),
          const SizedBox(height: 10),
          Text(
            'فاتورة استلام طلب (نموذج 80 مم)',
            textAlign: TextAlign.center,
            style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _buildReceiptRow('رقم الطلب', 'ORD-2026-001'),
          _buildReceiptRow('العميل', 'محمد أحمد'),
          _buildReceiptRow('التاريخ', '2026/09/13'),
          const SizedBox(height: 8),
          _buildDashedLine(),
          const SizedBox(height: 8),
          _buildReceiptRow('غسيل وكي قميص × 3', '120.00 ج.م'),
          _buildReceiptRow('تنظيف جاف بدلة × 1', '80.00 ج.م'),
          _buildReceiptRow('سجادة مقاس 2×3 × 1', '240.00 ج.م'),
          const SizedBox(height: 8),
          _buildDashedLine(),
          const SizedBox(height: 8),
          _buildReceiptRow('الإجمالي', '440.00 ج.م', isBold: true),
          _buildReceiptRow('المدفوع', '200.00 ج.م'),
          _buildReceiptRow('المتبقي', '240.00 ج.م', isBold: true),
          const SizedBox(height: 12),
          _buildDashedLine(),
          const SizedBox(height: 12),
          Text(
            footerText,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isBold
                ? AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)
                : AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: isBold
                ? AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)
                : AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedLine() {
    return CustomPaint(
      size: const Size(double.infinity, 1.0),
      painter: _ReceiptDashedLinePainter(),
    );
  }
}

class _ReceiptDashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD1D5DB)
      ..strokeWidth = 1.0;
    const dashWidth = 4.0;
    const dashSpace = 3.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

