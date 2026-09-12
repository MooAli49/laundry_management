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

/// Represents an aggregated/grouped invoice line item for presentation & printing.
class InvoiceLineItem {
  final String title;
  final String quantityDisplay;
  final Money unitPrice;
  final Money calculatedTotal;
  final String? dimensionsSubtext;
  final String? notes;

  const InvoiceLineItem({
    required this.title,
    required this.quantityDisplay,
    required this.unitPrice,
    required this.calculatedTotal,
    this.dimensionsSubtext,
    this.notes,
  });
}

/// Concrete presentation/output utility responsible for building 80mm thermal
/// receipt PDF documents and dispatching them to the operating system's print subsystem.
class InvoicePrinter {
  InvoicePrinter._();

  /// Formats a quantity using natural Arabic wording:
  /// - 1 -> "1 قطعة"
  /// - 2 -> "2 قطع"
  /// - 3..10 -> "$count قطع"
  /// - >10 -> "$count قطعة"
  /// - decimal (e.g. 2.75) -> "2.75 قطعة"
  static String formatPieceCount(double quantity) {
    if (quantity % 1 == 0) {
      final count = quantity.toInt();
      if (count == 1) return '1 قطعة';
      if (count >= 2 && count <= 10) return '$count قطع';
      return '$count قطعة';
    } else {
      return '${formatNumber(quantity)} قطعة';
    }
  }

  /// Formats item quantity for display.
  static String formatQuantity(OrderItem item) {
    return groupItems([item]).first.quantityDisplay;
  }

  /// Internal grouping key for aggregating semantically identical invoice lines.
  static String _groupingKey(OrderItem item) {
    final def = '${item.itemDefinitionId ?? ''}_${item.itemDefinitionNameSnapshot ?? ''}';
    final notes = (item.notes ?? '').trim();
    final carpetKey = item.carpetData != null
        ? '${formatNumber(item.carpetData!.length)}x${formatNumber(item.carpetData!.width)}'
        : 'none';
    return '${item.itemTypeId}|${item.itemTypeNameSnapshot}|$def|${item.serviceId}|${item.serviceNameSnapshot}|${item.pricingType.name}|${item.unitPrice.piastres}|$carpetKey|$notes';
  }

  /// Aggregates semantically identical order items into presentation-level invoice lines.
  ///
  /// Grouping criteria (all must match):
  /// - Same item type and definition snapshot
  /// - Same service
  /// - Same pricing type
  /// - Same unit price
  /// - Same carpet dimensions (length × width) when applicable
  /// - Same notes / special instructions
  ///
  /// Semantics:
  /// - For carpet items:
  ///   - Quantity displays the total piece count (e.g. "3 قطع").
  ///   - Unit price displays the price for ONE carpet piece.
  ///   - Line total displays total for all pieces in the group.
  ///   - Supporting detail displays dimensions and unit area: "(2 × 3 م) — 6 م²/قطعة".
  /// - For normal items:
  ///   - Quantity displays the total piece count (e.g. "3 قطع", "1 قطعة").
  ///   - Unit price displays the standard unit price.
  ///   - Line total displays total for all pieces in the group.
  static List<InvoiceLineItem> groupItems(List<OrderItem> items) {
    final map = <String, List<OrderItem>>{};
    for (final item in items) {
      final key = _groupingKey(item);
      map.putIfAbsent(key, () => []).add(item);
    }

    return map.values.map((group) {
      final first = group.first;
      final isCarpet = first.pricingType == PricingType.perSquareMeter;

      final itemTitle = first.itemDefinitionNameSnapshot != null
          ? '${first.itemTypeNameSnapshot} (${first.itemDefinitionNameSnapshot}) - ${first.serviceNameSnapshot}'
          : '${first.itemTypeNameSnapshot} - ${first.serviceNameSnapshot}';

      final notes = first.notes?.trim().isNotEmpty == true ? first.notes!.trim() : null;

      if (isCarpet) {
        final totalPieces = group.fold<double>(0.0, (sum, item) => sum + item.quantity);
        final pieceCount = totalPieces > 0 ? totalPieces : group.length.toDouble();
        final quantityDisplay = formatPieceCount(pieceCount);

        // Price for ONE carpet piece
        final unitPrice = first.carpetData != null
            ? Money.fromPiastres((first.unitPrice.piastres * first.carpetData!.area).round())
            : first.calculatedTotal;

        // Sum of calculated totals across all carpet pieces in this group
        final totalPiastres = group.fold<int>(0, (sum, item) => sum + item.calculatedTotal.piastres);
        final calculatedTotal = Money.fromPiastres(totalPiastres);

        String? dimensionsSubtext;
        if (first.carpetData != null) {
          final length = formatNumber(first.carpetData!.length);
          final width = formatNumber(first.carpetData!.width);
          final area = formatNumber(first.carpetData!.area);
          dimensionsSubtext = '($length × $width م) — $area م²/قطعة';
        }

        return InvoiceLineItem(
          title: itemTitle,
          quantityDisplay: quantityDisplay,
          unitPrice: unitPrice,
          calculatedTotal: calculatedTotal,
          dimensionsSubtext: dimensionsSubtext,
          notes: notes,
        );
      } else {
        final totalQuantity = group.fold<double>(0.0, (sum, item) => sum + item.quantity);
        final quantityDisplay = formatPieceCount(totalQuantity);
        final unitPrice = first.unitPrice;

        final totalPiastres = group.fold<int>(0, (sum, item) => sum + item.calculatedTotal.piastres);
        final calculatedTotal = Money.fromPiastres(totalPiastres);

        return InvoiceLineItem(
          title: itemTitle,
          quantityDisplay: quantityDisplay,
          unitPrice: unitPrice,
          calculatedTotal: calculatedTotal,
          dimensionsSubtext: null,
          notes: notes,
        );
      }
    }).toList();
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

    final lines = groupItems(items);

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
                  ...lines.map((line) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(line.title, style: const pw.TextStyle(fontSize: 8.5)),
                              if (line.dimensionsSubtext != null)
                                pw.Text(
                                  line.dimensionsSubtext!,
                                  style: const pw.TextStyle(fontSize: 7.5),
                                ),
                              if (line.notes != null)
                                pw.Text(
                                  'ملاحظة: ${line.notes!}',
                                  style: const pw.TextStyle(fontSize: 7.5),
                                ),
                            ],
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                          child: pw.Text(
                            line.quantityDisplay,
                            style: const pw.TextStyle(fontSize: 8.5),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                          child: pw.Text(
                            line.unitPrice.toEgp.toStringAsFixed(2),
                            style: const pw.TextStyle(fontSize: 8.5),
                            textAlign: pw.TextAlign.left,
                            textDirection: pw.TextDirection.ltr,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                          child: pw.Text(
                            line.calculatedTotal.toEgp.toStringAsFixed(2),
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
      format: PdfPageFormat.roll80,
      dynamicLayout: false,
      onLayout: (format) async => doc.save(),
    );
  }
}
