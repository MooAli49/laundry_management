import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../domain/entities/business_settings.dart';
import '../../../../domain/entities/customer.dart';
import '../../../../domain/entities/order.dart';
import '../../../../domain/entities/order_item.dart';
import '../../../../domain/value_objects/money.dart';
import 'order_status_badge.dart';

class InvoicePreviewDialog extends StatelessWidget {
  final Order order;
  final Customer? customer;
  final List<OrderItem> items;
  final Money totalPaid;
  final Money remainingAmount;
  final BusinessSettings? settings;

  const InvoicePreviewDialog({
    super.key,
    required this.order,
    this.customer,
    required this.items,
    required this.totalPaid,
    required this.remainingAmount,
    this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final businessName = (settings?.businessName != null && settings!.businessName.trim().isNotEmpty)
        ? settings!.businessName
        : AppStrings.defaultBusinessName;
    final address = settings?.address;
    final phone = settings?.phone;
    final footer = settings?.invoiceFooterText ?? 'شكراً لتعاملكم معنا!';

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 800),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              // Dialog Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('معاينة الفاتورة', style: AppTextStyles.titleLarge),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              AppSpacing.gapMd,

              // Printable Invoice Sheet
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Laundry Info Header
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLighter,
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                ),
                                child: const Icon(
                                  Icons.local_laundry_service_outlined,
                                  size: 28,
                                  color: AppColors.primary,
                                ),
                              ),
                              AppSpacing.gapSm,
                              Text(
                                businessName,
                                style: AppTextStyles.headlineSmall.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              if (address != null && address.trim().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  address,
                                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                              if (phone != null && phone.trim().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'هاتف: $phone',
                                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Divider(height: AppSpacing.xxl, color: AppColors.divider),

                        // Order & Customer Meta
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'فاتورة #${order.orderNumber}',
                                  style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold),
                                ),
                                AppSpacing.gapXs,
                                Text(
                                  'التاريخ: ${order.createdAt.year}-${order.createdAt.month.toString().padLeft(2, '0')}-${order.createdAt.day.toString().padLeft(2, '0')}',
                                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            OrderStatusBadge(status: order.status),
                          ],
                        ),
                        AppSpacing.gapMd,

                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'بيانات العميل',
                                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.textTertiary),
                                  ),
                                  Text(
                                    customer?.name ?? 'عميل غير مسجل',
                                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  if (customer?.phone != null)
                                    Text(
                                      customer!.phone,
                                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                                    ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'موعد الاستلام',
                                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.textTertiary),
                                  ),
                                  Text(
                                    order.expectedPickupDate.toString(),
                                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.gapLg,

                        // Itemized Table
                        Table(
                          columnWidths: const {
                            0: FlexColumnWidth(4),
                            1: FlexColumnWidth(1.5),
                            2: FlexColumnWidth(2),
                            3: FlexColumnWidth(2),
                          },
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(
                                color: AppColors.backgroundSecondary,
                              ),
                              children: [
                                _tableHeader('الصنف / الخدمة'),
                                _tableHeader('الكمية', align: TextAlign.center),
                                _tableHeader('سعر الوحدة', align: TextAlign.end),
                                _tableHeader('الإجمالي', align: TextAlign.end),
                              ],
                            ),
                            ...items.map((item) {
                              final itemTitle = item.itemDefinitionNameSnapshot != null
                                  ? '${item.itemTypeNameSnapshot} (${item.itemDefinitionNameSnapshot}) - ${item.serviceNameSnapshot}'
                                  : '${item.itemTypeNameSnapshot} - ${item.serviceNameSnapshot}';

                              return TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(itemTitle, style: AppTextStyles.bodyMedium),
                                        if (item.carpetData != null)
                                          Text(
                                            'سجاد (${item.carpetData!.length} × ${item.carpetData!.width} م)',
                                            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textTertiary),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                                    child: Text(
                                      '1',
                                      style: AppTextStyles.bodyMedium,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                                    child: Text(
                                      '${item.unitPrice.toEgp.toStringAsFixed(2)} ج.م',
                                      style: AppTextStyles.bodyMedium,
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                                    child: Text(
                                      '${item.calculatedTotal.toEgp.toStringAsFixed(2)} ج.م',
                                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                        const Divider(height: AppSpacing.xl, color: AppColors.divider),

                        // Financial Summary
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 280,
                            child: Column(
                              children: [
                                _summaryRow('المجموع الفرعي:', '${order.subtotal.toEgp.toStringAsFixed(2)} ج.م'),
                                if (order.discount.isPositive)
                                  _summaryRow('الخصم:', '- ${order.discount.toEgp.toStringAsFixed(2)} ج.م', isNegative: true),
                                if (order.customerPickupRequested)
                                  _summaryRow('استلام من العميل:', '+ ${order.customerPickupFee.toEgp.toStringAsFixed(2)} ج.م'),
                                if (order.customerDeliveryRequested)
                                  _summaryRow('توصيل للعميل:', '+ ${order.customerDeliveryFee.toEgp.toStringAsFixed(2)} ج.م'),
                                if (order.tax.isPositive)
                                  _summaryRow('الضريبة:', '+ ${order.tax.toEgp.toStringAsFixed(2)} ج.م'),
                                const Divider(height: AppSpacing.md),
                                _summaryRow('الإجمالي:', '${order.total.toEgp.toStringAsFixed(2)} ج.م', isBold: true),
                                _summaryRow('المدفوع:', '${totalPaid.toEgp.toStringAsFixed(2)} ج.م'),
                                _summaryRow(
                                  'المتبقي:',
                                  '${remainingAmount.toEgp.toStringAsFixed(2)} ج.م',
                                  isBold: true,
                                  color: remainingAmount.isZero ? AppColors.success : AppColors.warning,
                                ),
                              ],
                            ),
                          ),
                        ),
                        AppSpacing.gapXl,

                        // Footer Note
                        Center(
                          child: Text(
                            footer,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              AppSpacing.gapLg,

              // Dialog Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'إغلاق',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  AppSpacing.gapHorizontalMd,
                  AppButton(
                    label: 'طباعة الفاتورة',
                    icon: Icons.print,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('ميزة الطباعة غير مفعلة حالياً - جاري إعداد خدمة الطباعة'),
                          backgroundColor: AppColors.info,
                        ),
                      );
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tableHeader(String text, {TextAlign align = TextAlign.start}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
      child: Text(
        text,
        style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.bold),
        textAlign: align,
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, bool isNegative = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: isBold
                  ? AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)
                  : AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Text(
            value,
            style: isBold
                ? AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: color ?? AppColors.primary)
                : AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isNegative ? AppColors.error : color ?? AppColors.textPrimary,
                  ),
          ),
        ],
      ),
    );
  }
}
