import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../domain/entities/business_settings.dart';
import '../../../../domain/entities/customer.dart';
import '../../../../domain/entities/order.dart';
import '../../../../domain/entities/order_item.dart';
import '../../../../domain/value_objects/money.dart';
import '../services/invoice_printer.dart';
import 'order_status_badge.dart';

class InvoicePreviewDialog extends StatefulWidget {
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
  State<InvoicePreviewDialog> createState() => _InvoicePreviewDialogState();
}

class _InvoicePreviewDialogState extends State<InvoicePreviewDialog> {
  bool _isPrinting = false;

  Future<void> _handlePrint() async {
    if (_isPrinting) return;

    setState(() {
      _isPrinting = true;
    });

    try {
      await InvoicePrinter.printInvoice(
        order: widget.order,
        items: widget.items,
        totalPaid: widget.totalPaid,
        remainingAmount: widget.remainingAmount,
        customer: widget.customer,
        settings: widget.settings,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر بدء عملية الطباعة. حاول مرة أخرى.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessName = (widget.settings?.businessName != null && widget.settings!.businessName.trim().isNotEmpty)
        ? widget.settings!.businessName
        : AppStrings.defaultBusinessName;
    final address = widget.settings?.address;
    final phone = widget.settings?.phone;
    final footer = widget.settings?.invoiceFooterText?.trim().isNotEmpty == true
        ? widget.settings!.invoiceFooterText!
        : 'شكراً لتعاملكم معنا!';

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
                    onPressed: _isPrinting ? null : () => Navigator.of(context).pop(),
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
                                  'فاتورة #${widget.order.orderNumber}',
                                  style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold),
                                ),
                                AppSpacing.gapXs,
                                Text(
                                  'التاريخ: ${DateFormatter.formatArabicDate(widget.order.createdAt)}',
                                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            OrderStatusBadge(status: widget.order.status),
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
                                    widget.order.customerNameSnapshot.isNotEmpty
                                        ? widget.order.customerNameSnapshot
                                        : (widget.customer?.name ?? 'عميل غير مسجل'),
                                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  if (widget.order.customerPhoneSnapshot.isNotEmpty || widget.customer?.phone != null)
                                    Text(
                                      widget.order.customerPhoneSnapshot.isNotEmpty
                                          ? widget.order.customerPhoneSnapshot
                                          : widget.customer!.phone,
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
                                    DateFormatter.formatArabicDate(widget.order.expectedPickupDate.toDateTime()),
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
                                border: Border(bottom: BorderSide(color: AppColors.border, width: 1.5)),
                              ),
                              children: [
                                _tableHeader('البند والخدمة'),
                                _tableHeader('الكمية', align: TextAlign.center),
                                _tableHeader('سعر الوحدة', align: TextAlign.end),
                                _tableHeader('الإجمالي', align: TextAlign.end),
                              ],
                            ),
                            ...widget.items.map((item) {
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
                                            '(${InvoicePrinter.formatNumber(item.carpetData!.length)} × ${InvoicePrinter.formatNumber(item.carpetData!.width)} م)',
                                            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textTertiary),
                                          ),
                                        if (item.notes != null && item.notes!.trim().isNotEmpty)
                                          Text(
                                            'ملاحظة: ${item.notes!.trim()}',
                                            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textTertiary),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                                    child: Text(
                                      InvoicePrinter.formatQuantity(item),
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
                                _summaryRow('المجموع الفرعي:', '${widget.order.subtotal.toEgp.toStringAsFixed(2)} ج.م'),
                                if (widget.order.discount.isPositive)
                                  _summaryRow('الخصم:', '- ${widget.order.discount.toEgp.toStringAsFixed(2)} ج.م', isNegative: true),
                                if (widget.order.customerPickupRequested && widget.order.customerPickupFee.isPositive)
                                  _summaryRow('استلام من العميل:', '+ ${widget.order.customerPickupFee.toEgp.toStringAsFixed(2)} ج.م'),
                                if (widget.order.customerDeliveryRequested && widget.order.customerDeliveryFee.isPositive)
                                  _summaryRow('توصيل للعميل:', '+ ${widget.order.customerDeliveryFee.toEgp.toStringAsFixed(2)} ج.م'),
                                if (widget.order.tax.isPositive)
                                  _summaryRow('الضريبة:', '+ ${widget.order.tax.toEgp.toStringAsFixed(2)} ج.م'),
                                const Divider(height: AppSpacing.md),
                                _summaryRow('الإجمالي:', '${widget.order.total.toEgp.toStringAsFixed(2)} ج.م', isBold: true),
                                _summaryRow('المدفوع:', '${widget.totalPaid.toEgp.toStringAsFixed(2)} ج.م'),
                                _summaryRow(
                                  'المتبقي:',
                                  '${widget.remainingAmount.toEgp.toStringAsFixed(2)} ج.م',
                                  isBold: true,
                                  color: widget.remainingAmount.isZero ? AppColors.success : AppColors.warning,
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
                    onPressed: _isPrinting ? null : () => Navigator.of(context).pop(),
                  ),
                  AppSpacing.gapHorizontalMd,
                  AppButton(
                    label: 'طباعة الفاتورة',
                    icon: Icons.print,
                    isLoading: _isPrinting,
                    onPressed: _isPrinting ? null : _handlePrint,
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
