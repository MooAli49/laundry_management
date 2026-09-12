import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../domain/entities/business_settings.dart';
import '../../../../domain/entities/customer.dart';
import '../../../../domain/entities/order.dart';
import '../../../../domain/entities/order_item.dart';
import '../../../../domain/enums/pricing_type.dart';
import '../../../../domain/value_objects/money.dart';

/// Concrete presentation/output utility responsible for building 80mm thermal
/// receipt PDF documents and dispatching them to the operating system's print subsystem.
class InvoicePrinter {
  InvoicePrinter._();

  /// Formats item quantity according to historical pricing semantics.
  ///
  /// - [PricingType.perSquareMeter]: Displays `${area} م²` where area is `carpetData?.area ?? item.quantity`.
  /// - [PricingType.perPiece] or [PricingType.fixedPrice]:
  ///   - Integer counts render as whole numbers (`1`, `2`, `3`).
  ///   - Fractional quantities preserve exact decimal precision without truncation (`2.75`).
  static String formatQuantity(OrderItem item) {
    if (item.pricingType == PricingType.perSquareMeter) {
      final area = item.carpetData?.area ?? item.quantity;
      return '${formatNumber(area)} م²';
    } else {
      if (item.quantity % 1 == 0) {
        return item.quantity.toInt().toString();
      } else {
        return formatNumber(item.quantity);
      }
    }
  }

  /// Formats a double preserving decimal precision without trailing zeroes.
  static String formatNumber(double val) {
    if (val % 1 == 0) {
      return val.toInt().toString();
    }
    final s = val.toString();
    if (s.contains('.')) {
      return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }

  /// Formats DateTime as YYYY/MM/DD
  static String formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  /// Formats DateTime as YYYY/MM/DD - HH:MM AM/PM in Arabic
  static String formatDateTime(DateTime dt) {
    final date = formatDate(dt);
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final hStr = h.toString().padLeft(2, '0');
    final mStr = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'م' : 'ص';
    return '$date - $hStr:$mStr $ampm';
  }

  /// Generates the printable 80mm thermal receipt PDF document in memory.
  ///
  /// Consumes strictly historical transaction snapshots provided by the caller.
  /// Does NOT query repositories, DAOs, or the database.
  static Future<pw.Document> generatePdfDocument({
    required Order order,
    required List<OrderItem> items,
    required Money totalPaid,
    required Money remainingAmount,
    Customer? customer,
    BusinessSettings? settings,
    pw.Font? regularFont,
    pw.Font? boldFont,
  }) async {
    // 1. Resolve embedded fonts (100% offline via rootBundle if not injected)
    final resolvedRegular = regularFont ??
        pw.Font.ttf(await rootBundle.load('assets/fonts/IBMPlexSansArabic-Regular.ttf'));
    final resolvedBold = boldFont ??
        pw.Font.ttf(await rootBundle.load('assets/fonts/IBMPlexSansArabic-Bold.ttf'));

    final doc = pw.Document();

    final theme = pw.ThemeData.withFont(
      base: resolvedRegular,
      bold: resolvedBold,
      italic: resolvedRegular,
      boldItalic: resolvedBold,
    );

    // 2. Geometry: 80mm thermal roll format with compact margins (~72mm printable width)
    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.roll80,
      theme: theme,
      textDirection: pw.TextDirection.rtl,
      margin: const pw.EdgeInsets.symmetric(horizontal: 11.34, vertical: 17.0),
    );

    final businessName = (settings?.businessName != null && settings!.businessName.trim().isNotEmpty)
        ? settings.businessName
        : AppStrings.defaultBusinessName;
    final address = settings?.address;
    final phone = settings?.phone;
    final footer = settings?.invoiceFooterText?.trim().isNotEmpty == true
        ? settings!.invoiceFooterText!
        : 'شكراً لتعاملكم معنا!';

    final customerName = order.customerNameSnapshot.isNotEmpty
        ? order.customerNameSnapshot
        : (customer?.name ?? 'عميل غير مسجل');
    final customerPhone = order.customerPhoneSnapshot.isNotEmpty
        ? order.customerPhoneSnapshot
        : (customer?.phone ?? '');

    doc.addPage(
      pw.Page(
        pageTheme: pageTheme,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Business Header
              pw.Text(
                businessName,
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              if (address != null && address.trim().isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  address.trim(),
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ],
              if (phone != null && phone.trim().isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text('هاتف: ', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(
                      phone.trim(),
                      style: const pw.TextStyle(fontSize: 8),
                      textDirection: pw.TextDirection.ltr,
                    ),
                  ],
                ),
              ],
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),

              // Order Metadata
              pw.Row(
                children: [
                  pw.Text(
                    'فاتورة رقم: ',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    order.orderNumber,
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                    textDirection: pw.TextDirection.ltr,
                  ),
                ],
              ),
              pw.SizedBox(height: 2.5),
              pw.Text(
                'التاريخ: ${formatDateTime(order.createdAt)}',
                style: const pw.TextStyle(fontSize: 8.5),
              ),
              pw.SizedBox(height: 2.5),
              pw.Text(
                'تاريخ الاستلام المتوقع: ${formatDate(order.expectedPickupDate.toDateTime())}',
                style: const pw.TextStyle(fontSize: 8.5),
              ),
              pw.SizedBox(height: 2.5),
              pw.Text(
                'العميل: $customerName',
                style: const pw.TextStyle(fontSize: 8.5),
              ),
              if (customerPhone.isNotEmpty) ...[
                pw.SizedBox(height: 2.5),
                pw.Row(
                  children: [
                    pw.Text('الهاتف: ', style: const pw.TextStyle(fontSize: 8.5)),
                    pw.Text(
                      customerPhone,
                      style: const pw.TextStyle(fontSize: 8.5),
                      textDirection: pw.TextDirection.ltr,
                    ),
                  ],
                ),
              ],
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 4),

              // Itemized Table
              pw.Table(
                columnWidths: const {
                  0: pw.FlexColumnWidth(5.0),
                  1: pw.FlexColumnWidth(1.8),
                  2: pw.FlexColumnWidth(1.6),
                  3: pw.FlexColumnWidth(1.6),
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                        child: pw.Text(
                          'البند / الخدمة',
                          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                        child: pw.Text(
                          'الكمية',
                          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                        child: pw.Text(
                          'السعر',
                          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.left,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                        child: pw.Text(
                          'الإجمالي',
                          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.left,
                        ),
                      ),
                    ],
                  ),
                  // Items
                  ...items.map((item) {
                    final itemTitle = item.itemDefinitionNameSnapshot != null
                        ? '${item.itemTypeNameSnapshot} (${item.itemDefinitionNameSnapshot}) - ${item.serviceNameSnapshot}'
                        : '${item.itemTypeNameSnapshot} - ${item.serviceNameSnapshot}';

                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(itemTitle, style: const pw.TextStyle(fontSize: 8.5)),
                              if (item.carpetData != null)
                                pw.Text(
                                  '(${formatNumber(item.carpetData!.length)} × ${formatNumber(item.carpetData!.width)} م)',
                                  style: const pw.TextStyle(fontSize: 7.5),
                                ),
                              if (item.notes != null && item.notes!.trim().isNotEmpty)
                                pw.Text(
                                  'ملاحظة: ${item.notes!.trim()}',
                                  style: const pw.TextStyle(fontSize: 7.5),
                                ),
                            ],
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                          child: pw.Text(
                            formatQuantity(item),
                            style: const pw.TextStyle(fontSize: 8.5),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                          child: pw.Text(
                            item.unitPrice.toEgp.toStringAsFixed(2),
                            style: const pw.TextStyle(fontSize: 8.5),
                            textAlign: pw.TextAlign.left,
                            textDirection: pw.TextDirection.ltr,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                          child: pw.Text(
                            item.calculatedTotal.toEgp.toStringAsFixed(2),
                            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.left,
                            textDirection: pw.TextDirection.ltr,
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 4),

              // Financial Summary (Authoritative historical values)
              _summaryRow('المجموع الفرعي:', order.subtotal.toEgp.toStringAsFixed(2)),
              if (order.discount.isPositive)
                _summaryRow('الخصم:', order.discount.toEgp.toStringAsFixed(2), prefix: '-'),
              if (order.customerPickupRequested && order.customerPickupFee.isPositive)
                _summaryRow('استلام من العميل:', order.customerPickupFee.toEgp.toStringAsFixed(2), prefix: '+'),
              if (order.customerDeliveryRequested && order.customerDeliveryFee.isPositive)
                _summaryRow('توصيل للعميل:', order.customerDeliveryFee.toEgp.toStringAsFixed(2), prefix: '+'),
              if (order.tax.isPositive)
                _summaryRow('الضريبة:', order.tax.toEgp.toStringAsFixed(2), prefix: '+'),
              pw.SizedBox(height: 2),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 2),
              // Authoritative total (Never recalculated)
              _summaryRow('الإجمالي:', order.total.toEgp.toStringAsFixed(2), isBold: true, fontSize: 10.0),
              _summaryRow('المدفوع:', totalPaid.toEgp.toStringAsFixed(2), fontSize: 8.5),
              _summaryRow('المتبقي:', remainingAmount.toEgp.toStringAsFixed(2), isBold: true, fontSize: 10.0),

              pw.SizedBox(height: 5),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 5),

              // Footer Note
              pw.Text(
                footer,
                style: const pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );

    return doc;
  }

  /// Builds a financial summary row with explicit numeric LTR isolation and uniform currency placement.
  static pw.Widget _summaryRow(
    String label,
    String amount, {
    String? prefix,
    bool isBold = false,
    double fontSize = 8.5,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: isBold ? 1.5 : 1.0),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              if (prefix != null) ...[
                pw.Text(
                  prefix,
                  style: pw.TextStyle(
                    fontSize: fontSize,
                    fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  ),
                ),
                pw.SizedBox(width: 2),
              ],
              pw.Text(
                amount,
                style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
                textDirection: pw.TextDirection.ltr,
              ),
              pw.SizedBox(width: 3),
              pw.Text(
                'ج.م',
                style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Triggers the native system print workflow via [Printing.layoutPdf].
  ///
  /// Returns `true` if the print job was submitted, or `false` if cancelled.
  /// Throws an exception if an underlying OS/driver failure occurs.
  static Future<bool> printInvoice({
    required Order order,
    required List<OrderItem> items,
    required Money totalPaid,
    required Money remainingAmount,
    Customer? customer,
    BusinessSettings? settings,
  }) async {
    final doc = await generatePdfDocument(
      order: order,
      items: items,
      totalPaid: totalPaid,
      remainingAmount: remainingAmount,
      customer: customer,
      settings: settings,
    );

    return await Printing.layoutPdf(
      name: 'invoice_${order.orderNumber}.pdf',
      onLayout: (format) async => doc.save(),
    );
  }
}
