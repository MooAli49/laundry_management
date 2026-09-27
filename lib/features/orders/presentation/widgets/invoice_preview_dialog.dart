import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/di/injection.dart';
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
import '../cubit/bluetooth_printer_cubit.dart';
import '../cubit/bluetooth_printer_state.dart';
import '../services/bluetooth_printer/thermal_command_builder.dart';
import '../services/bluetooth_printer/thermal_invoice_renderer.dart';
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

  // ---------------------------------------------------------------------------
  // PDF / System printing (existing path – unchanged)
  // ---------------------------------------------------------------------------

  Future<void> _handlePdfPrint() async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
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
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Bluetooth thermal printing (new path)
  // ---------------------------------------------------------------------------

  Future<void> _handleBluetoothPrint(BuildContext context) async {
    if (_isPrinting) return;

    dev.log(
      'PRINT START order=${widget.order.orderNumber} selectedMethod=bluetooth',
      name: 'BluetoothPrinterService',
    );
    final cubit = getIt<BluetoothPrinterCubit>();
    await cubit.ensurePrinterReady();
    if (!mounted) return;
    final printerState = cubit.state;
    dev.log(
      'PRINT READINESS isConfigured=${printerState.isConfigured} '
      'isConnected=${printerState.isConnected} '
      'isReadyToPrint=${printerState.isReadyToPrint}',
      name: 'BluetoothPrinterService',
    );

    if (!printerState.isConfigured) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.btPrinterNotConfigured),
            backgroundColor: AppColors.warning,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    if (!printerState.isConnected || printerState.connectedProfile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.btPrinterDisconnected),
            backgroundColor: AppColors.warning,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    setState(() => _isPrinting = true);

    try {
      final profile = printerState.connectedProfile!;
      dev.log(
        'PRINT RENDER START order=${widget.order.orderNumber} '
        'paper=${profile.paperWidth.mm}mm protocol=${profile.protocol.name}',
        name: 'BluetoothPrinterService',
      );

      // 1. Render invoice to PNG raster (Arabic-safe via Flutter text engine)
      final imageBytes = await ThermalInvoiceRenderer.renderToImage(
        context: context,
        order: widget.order,
        items: widget.items,
        totalPaid: widget.totalPaid,
        remainingAmount: widget.remainingAmount,
        profile: profile,
        customer: widget.customer,
        settings: widget.settings,
        pixelRatio: 1.0,
      );
      dev.log(
        'PRINT RENDER SUCCESS bytes=${imageBytes.length} format=PNG',
        name: 'BluetoothPrinterService',
      );

      // 2. Build printer command bytes
      final printBytes = await ThermalCommandBuilder.buildPrintCommand(
        imageBytes: imageBytes,
        profile: profile,
      );
      dev.log(
        'PRINT COMMAND BUILD SUCCESS bytes=${printBytes.length} '
        'protocol=${profile.protocol.name}',
        name: 'BluetoothPrinterService',
      );

      // 3. Send to printer
      await cubit.writeBytes(printBytes);
      dev.log('PRINT SUCCESS', name: 'BluetoothPrinterService');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال الفاتورة إلى الطابعة بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e, stackTrace) {
      dev.log(
        'PRINT FAILED error=$e',
        name: 'BluetoothPrinterService',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشلت عملية الطباعة: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Print method selection bottom-sheet
  // ---------------------------------------------------------------------------

  void _showPrintMethodSheet(BuildContext context) {
    if (!getIt.isRegistered<BluetoothPrinterCubit>()) {
      _handlePdfPrint();
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return BlocProvider<BluetoothPrinterCubit>.value(
          value: getIt<BluetoothPrinterCubit>(),
          child: BlocBuilder<BluetoothPrinterCubit, BluetoothPrinterState>(
            builder: (_, printerState) {
              final connectedProfile = printerState.connectedProfile;
              final hasConnectedPrinter =
                  printerState.isConnected && connectedProfile != null;
              final bluetoothSubtitle = hasConnectedPrinter
                  ? connectedProfile.name
                  : printerState.isConfigured
                  ? AppStrings.btPrinterDisconnected
                  : AppStrings.btPrinterNotConfigured;

              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.printMethodTitle,
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    AppSpacing.gapLg,
                    // Bluetooth option
                    _PrintOptionTile(
                      icon: Icons.print,
                      label: AppStrings.printViaBluetooth,
                      subtitle: bluetoothSubtitle,
                      subtitleColor: hasConnectedPrinter
                          ? AppColors.success
                          : AppColors.textTertiary,
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        _handleBluetoothPrint(context);
                      },
                    ),
                    const Divider(height: AppSpacing.xxl),
                    // PDF option
                    _PrintOptionTile(
                      icon: Icons.picture_as_pdf_outlined,
                      label: AppStrings.printViaPdf,
                      subtitle: 'طباعة عبر النظام أو حفظ PDF',
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        _handlePdfPrint();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final businessName =
        (widget.settings?.businessName != null &&
            widget.settings!.businessName.trim().isNotEmpty)
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
                    onPressed: _isPrinting
                        ? null
                        : () => Navigator.of(context).pop(),
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
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLighter,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusMd,
                                  ),
                                ),
                                child: SvgPicture.asset(
                                  'assets/images/logo_primary_mark.svg',
                                  fit: BoxFit.contain,
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
                              if (address != null &&
                                  address.trim().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  address,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                              if (phone != null && phone.trim().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'هاتف: $phone',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Divider(
                          height: AppSpacing.xxl,
                          color: AppColors.divider,
                        ),

                        // Order & Customer Meta
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'فاتورة ',
                                      style: AppTextStyles.titleLarge.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '#${widget.order.orderNumber}',
                                      textDirection: TextDirection.ltr,
                                      style: AppTextStyles.titleLarge.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                AppSpacing.gapXs,
                                Text(
                                  'التاريخ: ${DateFormatter.formatArabicDate(widget.order.createdAt)}',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
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
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'بيانات العميل',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                  Text(
                                    widget.order.customerNameSnapshot.isNotEmpty
                                        ? widget.order.customerNameSnapshot
                                        : (widget.customer?.name ??
                                              'عميل غير مسجل'),
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (widget
                                          .order
                                          .customerPhoneSnapshot
                                          .isNotEmpty ||
                                      widget.customer?.phone != null)
                                    Text(
                                      widget
                                              .order
                                              .customerPhoneSnapshot
                                              .isNotEmpty
                                          ? widget.order.customerPhoneSnapshot
                                          : widget.customer!.phone,
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'موعد الاستلام',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                  Text(
                                    DateFormatter.formatArabicDate(
                                      widget.order.expectedPickupDate
                                          .toDateTime(),
                                    ),
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.gapLg,

                        // Itemized Table
                        Builder(
                          builder: (context) {
                            final lines = InvoicePrinter.groupItems(
                              widget.items,
                            );
                            return Table(
                              columnWidths: const {
                                0: FlexColumnWidth(4),
                                1: FlexColumnWidth(1.5),
                                2: FlexColumnWidth(2),
                                3: FlexColumnWidth(2),
                              },
                              children: [
                                TableRow(
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: AppColors.border,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  children: [
                                    _tableHeader('البند والخدمة'),
                                    _tableHeader(
                                      'الكمية',
                                      align: TextAlign.center,
                                    ),
                                    _tableHeader(
                                      'سعر الوحدة',
                                      align: TextAlign.end,
                                    ),
                                    _tableHeader(
                                      'الإجمالي',
                                      align: TextAlign.end,
                                    ),
                                  ],
                                ),
                                ...lines.map((line) {
                                  return TableRow(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: AppSpacing.sm,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              line.title,
                                              style: AppTextStyles.bodyMedium,
                                            ),
                                            if (line.dimensionsSubtext != null)
                                              Text(
                                                line.dimensionsSubtext!,
                                                style: AppTextStyles.labelSmall
                                                    .copyWith(
                                                      color: AppColors
                                                          .textTertiary,
                                                    ),
                                              ),
                                            if (line.notes != null)
                                              Text(
                                                'ملاحظة: ${line.notes!}',
                                                style: AppTextStyles.labelSmall
                                                    .copyWith(
                                                      color: AppColors
                                                          .textTertiary,
                                                    ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: AppSpacing.sm,
                                        ),
                                        child: Text(
                                          line.quantityDisplay,
                                          style: AppTextStyles.bodyMedium,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: AppSpacing.sm,
                                        ),
                                        child: Text(
                                          '${line.unitPrice.toEgp.toStringAsFixed(2)} ج.م',
                                          style: AppTextStyles.bodyMedium,
                                          textAlign: TextAlign.end,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: AppSpacing.sm,
                                        ),
                                        child: Text(
                                          '${line.calculatedTotal.toEgp.toStringAsFixed(2)} ج.م',
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            );
                          },
                        ),
                        const Divider(
                          height: AppSpacing.xl,
                          color: AppColors.divider,
                        ),

                        // Financial Summary
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 280,
                            child: Column(
                              children: [
                                _summaryRow(
                                  'المجموع الفرعي:',
                                  '${widget.order.subtotal.toEgp.toStringAsFixed(2)} ج.م',
                                ),
                                if (widget.order.discount.isPositive)
                                  _summaryRow(
                                    'الخصم:',
                                    '- ${widget.order.discount.toEgp.toStringAsFixed(2)} ج.م',
                                    isNegative: true,
                                  ),
                                if (widget.order.customerPickupRequested &&
                                    widget.order.customerPickupFee.isPositive)
                                  _summaryRow(
                                    'استلام من العميل:',
                                    '+ ${widget.order.customerPickupFee.toEgp.toStringAsFixed(2)} ج.م',
                                  ),
                                if (widget.order.customerDeliveryRequested &&
                                    widget.order.customerDeliveryFee.isPositive)
                                  _summaryRow(
                                    'توصيل للعميل:',
                                    '+ ${widget.order.customerDeliveryFee.toEgp.toStringAsFixed(2)} ج.م',
                                  ),
                                if (widget.order.tax.isPositive)
                                  _summaryRow(
                                    'الضريبة:',
                                    '+ ${widget.order.tax.toEgp.toStringAsFixed(2)} ج.م',
                                  ),
                                const Divider(height: AppSpacing.md),
                                _summaryRow(
                                  'الإجمالي:',
                                  '${widget.order.total.toEgp.toStringAsFixed(2)} ج.م',
                                  isBold: true,
                                ),
                                _summaryRow(
                                  'المدفوع:',
                                  '${widget.totalPaid.toEgp.toStringAsFixed(2)} ج.م',
                                ),
                                _summaryRow(
                                  'المتبقي:',
                                  '${widget.remainingAmount.toEgp.toStringAsFixed(2)} ج.م',
                                  isBold: true,
                                  color: widget.remainingAmount.isZero
                                      ? AppColors.success
                                      : AppColors.warning,
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
                    onPressed: _isPrinting
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                  AppSpacing.gapHorizontalMd,
                  AppButton(
                    label: 'طباعة الفاتورة',
                    icon: Icons.print,
                    isLoading: _isPrinting,
                    onPressed: _isPrinting
                        ? null
                        : () => _showPrintMethodSheet(context),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      child: Text(
        text,
        style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.bold),
        textAlign: align,
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool isBold = false,
    bool isNegative = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: isBold
                  ? AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    )
                  : AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
            ),
          ),
          Text(
            value,
            style: isBold
                ? AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color ?? AppColors.primary,
                  )
                : AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isNegative
                        ? AppColors.error
                        : color ?? AppColors.textPrimary,
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widget for the print-method bottom sheet
// ---------------------------------------------------------------------------

class _PrintOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color? subtitleColor;
  final VoidCallback onTap;

  const _PrintOptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryLighter,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            AppSpacing.gapHorizontalMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: subtitleColor ?? AppColors.textTertiary,
                      ),
                      maxLines: 2,
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
