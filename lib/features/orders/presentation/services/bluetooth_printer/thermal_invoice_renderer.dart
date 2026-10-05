import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../domain/entities/business_settings.dart';
import '../../../../../domain/entities/customer.dart';
import '../../../../../domain/entities/order.dart';
import '../../../../../domain/entities/order_item.dart';
import '../../../../../domain/enums/order_status.dart';
import '../../../../../domain/enums/pricing_type.dart';
import '../../../../../domain/value_objects/money.dart';
import '../../../../../domain/value_objects/order_date.dart';
import '../invoice_printer.dart';
import 'printer_profile.dart';

/// Renders an invoice as a raster bitmap image suitable for thermal printer
/// transmission.
///
/// ## Arabic Support Strategy
///
/// Thermal printers like TSC or ESC/POS printers do NOT have built-in Arabic glyphs.
/// Attempting to send raw UTF-8/Arabic text commands results in garbled output.
///
/// **Solution**: Render the invoice using Flutter's text engine (which
/// correctly handles Arabic RTL, ligatures, and fonts) into an off-screen
/// [RenderRepaintBoundary], capture it as a [ui.Image], then convert to raw
/// PNG bytes.
///
/// The PNG bytes are then converted to monochrome 1-bit raster and wrapped in
/// ESC/POS or TSPL raster commands and sent to the printer. This guarantees
/// sharp, readable Arabic regardless of the printer's internal font set.
///
/// ## Visual Hierarchy & 80mm Layout
///
/// The visual layout mirrors the Invoice Preview Dialog (the visual source of truth):
/// - Prominent Header (Business Name, Address, Phone)
/// - Order Metadata (Invoice #, Date, Status Badge)
/// - Bordered Customer & Expected Pickup Card
/// - Itemized Table with quantity, unit price, totals, and notes
/// - Clear Financial Summary with boxed Total and Remaining amounts
/// - Centered Footer
class ThermalInvoiceRenderer {
  ThermalInvoiceRenderer._();

  /// Standard printable width in pixels for 80mm thermal receipt printers
  /// (72mm printable line @ 203 DPI / 8 dots/mm = 576 dots / 72 bytes).
  static const double defaultTargetWidthPx = 576.0;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Render the invoice to a PNG byte buffer sized for the given [profile].
  ///
  /// [pixelRatio] is the device-pixel ratio used when capturing the image.
  /// Default is 1.0 so rendered pixel width matches printableDots exactly (576 px for 80mm).
  static Future<Uint8List> renderToImage({
    required BuildContext context,
    required Order order,
    required List<OrderItem> items,
    required Money totalPaid,
    required Money remainingAmount,
    required PrinterProfile profile,
    Customer? customer,
    BusinessSettings? settings,
    double pixelRatio = 1.0,
    double? targetWidthPx,
    double typographyScale = 1.0,
    bool solidBlackText = true,
  }) async {
    // Load Arabic fonts
    final regularFontData = await rootBundle.load(
      'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    );
    final boldFontData = await rootBundle.load(
      'assets/fonts/IBMPlexSansArabic-Bold.ttf',
    );

    final paperWidthPx =
        targetWidthPx ??
        (profile.paperWidth == ThermalPaperWidth.w80
            ? defaultTargetWidthPx
            : profile.paperWidth.printablePixels.toDouble());

    // Build the invoice widget tree (off-screen)
    final invoiceWidget = buildInvoiceWidget(
      order: order,
      items: items,
      totalPaid: totalPaid,
      remainingAmount: remainingAmount,
      customer: customer,
      settings: settings,
      paperWidthPx: paperWidthPx,
      regularFontData: regularFontData,
      boldFontData: boldFontData,
      typographyScale: typographyScale,
      solidBlackText: solidBlackText,
    );

    if (!context.mounted) {
      throw StateError(
        'BuildContext is no longer mounted for thermal rendering',
      );
    }

    // Rasterise to image
    final imageBytes = await _rasterise(
      context,
      invoiceWidget,
      pixelRatio: pixelRatio,
    );
    return imageBytes;
  }

  /// Render a sample test receipt to PNG image bytes for verifying physical printer output.
  static Future<Uint8List> renderTestReceiptToImage({
    required BuildContext context,
    required PrinterProfile profile,
    double pixelRatio = 1.0,
    double? targetWidthPx,
    double typographyScale = 1.0,
    bool solidBlackText = true,
  }) async {
    final now = DateTime.now();
    final sampleOrder = Order(
      id: 'test-order-sample',
      orderNumber: '001',
      customerId: 'sample-customer',
      customerNameSnapshot: 'عميل تجريبي',
      customerPhoneSnapshot: '01000000000',
      status: OrderStatus.ready,
      subtotal: Money.fromEgp(100),
      discount: Money.zero,
      customerPickupFee: Money.zero,
      customerDeliveryFee: Money.zero,
      tax: Money.zero,
      total: Money.fromEgp(100),
      createdAt: now,
      updatedAt: now,
      expectedPickupDate: OrderDate.fromDate(now.add(const Duration(days: 2))),
    );

    final sampleItems = [
      OrderItem(
        id: 'item-1',
        orderId: 'test-order-sample',
        serviceId: 'srv-1',
        itemTypeId: 'type-1',
        quantity: 2,
        unitPrice: Money.fromEgp(20),
        calculatedTotal: Money.fromEgp(40),
        serviceNameSnapshot: 'غسيل وكوي',
        itemTypeNameSnapshot: 'قميص رجالي',
        pricingType: PricingType.perPiece,
        createdAt: now,
        updatedAt: now,
      ),
      OrderItem(
        id: 'item-2',
        orderId: 'test-order-sample',
        serviceId: 'srv-2',
        itemTypeId: 'type-2',
        quantity: 1,
        unitPrice: Money.fromEgp(60),
        calculatedTotal: Money.fromEgp(60),
        notes: 'تسليم سريع',
        serviceNameSnapshot: 'تنظيف جاف',
        itemTypeNameSnapshot: 'بدلة كاملة',
        pricingType: PricingType.perPiece,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    return renderToImage(
      context: context,
      order: sampleOrder,
      items: sampleItems,
      totalPaid: Money.fromEgp(100),
      remainingAmount: Money.zero,
      profile: profile,
      pixelRatio: pixelRatio,
      targetWidthPx: targetWidthPx ?? defaultTargetWidthPx,
      typographyScale: typographyScale,
      solidBlackText: solidBlackText,
    );
  }

  // ---------------------------------------------------------------------------
  // Widget builder (available for testing and widget rendering)
  // ---------------------------------------------------------------------------

  @visibleForTesting
  static Widget buildInvoiceWidget({
    required Order order,
    required List<OrderItem> items,
    required Money totalPaid,
    required Money remainingAmount,
    required double paperWidthPx,
    ByteData? regularFontData,
    ByteData? boldFontData,
    Customer? customer,
    BusinessSettings? settings,
    double typographyScale = 1.0,
    bool solidBlackText = true,
  }) {
    final businessName =
        (settings?.businessName != null &&
            settings!.businessName.trim().isNotEmpty)
        ? settings.businessName
        : 'مغسلة الأمل الحديثة';

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

    final lines = InvoicePrinter.groupItems(items);

    // ── Typography scale ─────────────────────────────────────────────────────
    //
    // Physics: pixelRatio=1.0, printer DPI=203 (8 dots/mm).
    // 1 Flutter logical px = 1 thermal dot = 1/8 mm = 0.125 mm.
    // Physical em height = fontSize / 8 mm.
    // Capital letter ≈ 70% of em = fontSize / 8 * 0.7 mm.
    //
    // Target physical sizes:
    //   Headline (business name): ~6.5 mm em  → 52 px
    //   Invoice number:           ~5.0 mm em  → 40 px
    //   Customer name:            ~4.5 mm em  → 36 px
    //   Pickup date:              ~4.0 mm em  → 32 px
    //   Table headers:            ~3.75 mm em → 30 px
    //   Table body / financial:   ~3.5 mm em  → 28 px
    //   Secondary meta / labels:  ~3.0 mm em  → 24 px
    //   Total / remaining box:    ~5.5 mm em  → 44 px
    //   Footer:                   ~3.0 mm em  → 24 px
    //   Notes / subtext:          ~2.75 mm em → 22 px
    final businessNameFs = 52.0 * typographyScale;
    final headerMetaFs = 24.0 * typographyScale;
    final invoiceNumberFs = 40.0 * typographyScale;
    final orderDateFs = 24.0 * typographyScale;
    final statusBadgeFs = 22.0 * typographyScale;
    final cardLabelFs = 22.0 * typographyScale;
    final customerNameFs = 36.0 * typographyScale;
    final customerPhoneFs = 24.0 * typographyScale;
    final pickupDateFs = 32.0 * typographyScale;
    final financialFs = 28.0 * typographyScale;
    final totalHighlightFs = 44.0 * typographyScale;
    final footerFs = 24.0 * typographyScale;

    const regularFamily = 'IBM Plex Sans Arabic';

    final textColorPrimary = solidBlackText ? Colors.black : Colors.black87;
    final textColorSecondary = solidBlackText ? Colors.black : Colors.black54;
    final dividerColor = solidBlackText ? Colors.black : Colors.black54;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: Colors.white,
        child: SizedBox(
          width: paperWidthPx,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── 1. Laundry Info Header ───────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      Text(
                        businessName,
                        style: TextStyle(
                          fontFamily: regularFamily,
                          fontSize: businessNameFs,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (address != null && address.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          address.trim(),
                          style: TextStyle(
                            fontFamily: regularFamily,
                            fontSize: headerMetaFs,
                            fontWeight: FontWeight.w600,
                            color: textColorPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (phone != null && phone.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'هاتف: ${phone.trim()}',
                          style: TextStyle(
                            fontFamily: regularFamily,
                            fontSize: headerMetaFs,
                            fontWeight: FontWeight.w600,
                            color: textColorPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _divider(dividerColor, 1.5),
                const SizedBox(height: 8),

                // ── 2. Order & Customer Meta Row ─────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'فاتورة ',
                                style: AppTextStyles.titleLarge.copyWith(
                                  fontFamily: regularFamily,
                                  fontSize: invoiceNumberFs,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                '#${order.orderNumber}',
                                textDirection: TextDirection.ltr,
                                style: AppTextStyles.titleLarge.copyWith(
                                  fontFamily: regularFamily,
                                  fontSize: invoiceNumberFs,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'التاريخ: ${InvoicePrinter.formatDateTime(order.createdAt)}',
                            style: TextStyle(
                              fontFamily: regularFamily,
                              fontSize: orderDateFs,
                              fontWeight: FontWeight.w600,
                              color: textColorPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
                      child: Text(
                        _statusLabel(order.status),
                        style: TextStyle(
                          fontFamily: regularFamily,
                          fontSize: statusBadgeFs,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── 3. Customer Data & Expected Pickup Date Card ─────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: dividerColor, width: 1.2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'بيانات العميل',
                              style: TextStyle(
                                fontFamily: regularFamily,
                                fontSize: cardLabelFs,
                                fontWeight: FontWeight.bold,
                                color: textColorPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              customerName,
                              style: TextStyle(
                                fontFamily: regularFamily,
                                fontSize: customerNameFs,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            if (customerPhone.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                customerPhone,
                                style: TextStyle(
                                  fontFamily: regularFamily,
                                  fontSize: customerPhoneFs,
                                  fontWeight: FontWeight.w600,
                                  color: textColorPrimary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'موعد الاستلام',
                            style: TextStyle(
                              fontFamily: regularFamily,
                              fontSize: cardLabelFs,
                              fontWeight: FontWeight.bold,
                              color: textColorPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            InvoicePrinter.formatDate(
                              order.expectedPickupDate.toDateTime(),
                            ),
                            style: TextStyle(
                              fontFamily: regularFamily,
                              fontSize: pickupDateFs,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // ── 4. Itemized Table ────────────────────────────────────────
                _ItemsTable(
                  lines: lines,
                  fontFamily: regularFamily,
                  typographyScale: typographyScale,
                  solidBlackText: solidBlackText,
                ),
                const SizedBox(height: 8),
                _divider(dividerColor, 1.5),
                const SizedBox(height: 8),

                // ── 5. Financial Summary ─────────────────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _summaryRow(
                      'المجموع الفرعي:',
                      '${order.subtotal.toEgp.toStringAsFixed(2)} ج.م',
                      fontFamily: regularFamily,
                      fontSize: financialFs,
                      bold: true,
                    ),
                    if (order.discount.isPositive)
                      _summaryRow(
                        'الخصم:',
                        '- ${order.discount.toEgp.toStringAsFixed(2)} ج.م',
                        fontFamily: regularFamily,
                        fontSize: financialFs,
                      ),
                    if (order.customerPickupRequested &&
                        order.customerPickupFee.isPositive)
                      _summaryRow(
                        'استلام من العميل:',
                        '+ ${order.customerPickupFee.toEgp.toStringAsFixed(2)} ج.م',
                        fontFamily: regularFamily,
                        fontSize: financialFs,
                      ),
                    if (order.customerDeliveryRequested &&
                        order.customerDeliveryFee.isPositive)
                      _summaryRow(
                        'توصيل للعميل:',
                        '+ ${order.customerDeliveryFee.toEgp.toStringAsFixed(2)} ج.م',
                        fontFamily: regularFamily,
                        fontSize: financialFs,
                      ),
                    if (order.tax.isPositive)
                      _summaryRow(
                        'الضريبة:',
                        '+ ${order.tax.toEgp.toStringAsFixed(2)} ج.م',
                        fontFamily: regularFamily,
                        fontSize: financialFs,
                      ),
                    const SizedBox(height: 3),
                    _divider(dividerColor, 1.0),
                    const SizedBox(height: 3),
                    // Prominent Total Highlight Box
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 1.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'الإجمالي:',
                              style: TextStyle(
                                fontFamily: regularFamily,
                                fontSize: totalHighlightFs,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${order.total.toEgp.toStringAsFixed(2)} ج.م',
                            style: TextStyle(
                              fontFamily: regularFamily,
                              fontSize: totalHighlightFs,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _summaryRow(
                      'المدفوع:',
                      '${totalPaid.toEgp.toStringAsFixed(2)} ج.م',
                      fontFamily: regularFamily,
                      fontSize: financialFs,
                    ),
                    // Prominent Remaining Highlight Box
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 1.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              remainingAmount.isZero
                                  ? 'المتبقي (خالص):'
                                  : 'المتبقي:',
                              style: TextStyle(
                                fontFamily: regularFamily,
                                fontSize: totalHighlightFs,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${remainingAmount.toEgp.toStringAsFixed(2)} ج.م',
                            style: TextStyle(
                              fontFamily: regularFamily,
                              fontSize: totalHighlightFs,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _divider(dividerColor, 1.0),
                const SizedBox(height: 6),

                // ── 6. Footer ────────────────────────────────────────────────
                Center(
                  child: Text(
                    footer,
                    style: TextStyle(
                      fontFamily: regularFamily,
                      fontSize: footerFs,
                      fontWeight: FontWeight.w600,
                      color: textColorSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Rasterisation — using the correct modern Flutter approach
  // ---------------------------------------------------------------------------

  /// Render [widget] off-screen using an [OffstageWidgetCapture] approach:
  /// 1. Wrap the widget in a [RepaintBoundary] keyed with a [GlobalKey].
  /// 2. Insert it as an Overlay entry with [Offstage] so it layouts but
  ///    never appears visually.
  /// 3. Wait one frame so the layout pass has run.
  /// 4. Call [toImage] on the boundary.
  /// 5. Remove the Overlay entry and return PNG bytes.
  static Future<Uint8List> _rasterise(
    BuildContext context,
    Widget widget, {
    double pixelRatio = 1.0,
  }) async {
    final completer = Completer<Uint8List>();
    final repaintKey = GlobalKey();

    OverlayEntry? entry;

    void capture() async {
      try {
        final captureContext = repaintKey.currentContext;
        if (captureContext == null) {
          completer.completeError(
            StateError('RepaintBoundary context is null after mount'),
          );
          return;
        }
        final boundary =
            captureContext.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) {
          completer.completeError(
            StateError('Could not find RenderRepaintBoundary'),
          );
          return;
        }

        var paintReady = false;
        for (var frame = 0; frame < 2; frame++) {
          await SchedulerBinding.instance.endOfFrame;

          var needsPaint = false;
          assert(() {
            needsPaint = boundary.debugNeedsPaint;
            return true;
          }());
          paintReady = boundary.attached && boundary.hasSize && !needsPaint;
          if (paintReady) break;
        }

        if (!paintReady) {
          completer.completeError(
            StateError('RenderRepaintBoundary was not paint-ready'),
          );
          return;
        }

        final image = await boundary.toImage(pixelRatio: pixelRatio);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) {
          completer.completeError(StateError('toByteData returned null'));
          return;
        }
        final pngBytes = byteData.buffer.asUint8List();
        completer.complete(pngBytes);
      } catch (e, s) {
        completer.completeError(e, s);
      } finally {
        if (entry != null) entry!.remove();
        entry = null;
      }
    }

    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -100000,
        top: -100000,
        child: IgnorePointer(
          child: RepaintBoundary(key: repaintKey, child: widget),
        ),
      ),
    );

    final overlayState = context.findAncestorStateOfType<OverlayState>();

    if (overlayState != null) {
      overlayState.insert(entry!);
      WidgetsBinding.instance.addPostFrameCallback((_) => capture());
    } else {
      entry = null;
      completer.completeError(
        StateError(
          'No OverlayState available. Ensure renderToImage is called from '
          'within a running Flutter widget tree.',
        ),
      );
    }

    return completer.future;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static Widget _divider([
    Color color = Colors.black,
    double thickness = 1.0,
  ]) => Container(height: thickness, color: color);

  static Widget _summaryRow(
    String label,
    String value, {
    required String fontFamily,
    bool bold = false,
    double fontSize = 14.5,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: fontSize,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  static String _statusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.processing:
        return 'قيد التجهيز';
      case OrderStatus.ready:
        return 'جاهز';
      case OrderStatus.completed:
        return 'مكتمل';
      case OrderStatus.cancelled:
        return 'ملغي';
    }
  }
}

// ---------------------------------------------------------------------------
// Items table widget
// ---------------------------------------------------------------------------

class _ItemsTable extends StatelessWidget {
  final List<InvoiceLineItem> lines;
  final String fontFamily;
  final double typographyScale;
  final bool solidBlackText;

  const _ItemsTable({
    required this.lines,
    required this.fontFamily,
    this.typographyScale = 1.0,
    this.solidBlackText = true,
  });

  @override
  Widget build(BuildContext context) {
    final secondaryColor = solidBlackText ? Colors.black : Colors.black87;

    final headerStyle = TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.bold,
      fontSize: 30.0 * typographyScale,
      color: Colors.black,
    );
    final rowStyle = TextStyle(
      fontFamily: fontFamily,
      fontSize: 28.0 * typographyScale,
      color: Colors.black,
    );

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(4.5), // البند والخدمة — wider for Arabic item names
        1: FlexColumnWidth(1.2), // الكمية — narrower
        2: FlexColumnWidth(2.0), // سعر الوحدة
        3: FlexColumnWidth(2.0), // الإجمالي
      },
      children: [
        // Header row
        TableRow(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.black, width: 1.5)),
          ),
          children: [
            _cell('البند والخدمة', style: headerStyle, align: TextAlign.start),
            _cell('الكمية', style: headerStyle, align: TextAlign.center),
            _cell('سعر الوحدة', style: headerStyle, align: TextAlign.end),
            _cell('الإجمالي', style: headerStyle, align: TextAlign.end),
          ],
        ),
        // Data rows
        ...lines.map((line) {
          return TableRow(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.black, width: 0.5),
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.title,
                      style: rowStyle.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.start,
                    ),
                    if (line.dimensionsSubtext != null)
                      Text(
                        line.dimensionsSubtext!,
                        style: rowStyle.copyWith(
                          fontSize: 22.0 * typographyScale,
                          color: secondaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.start,
                      ),
                    if (line.notes != null)
                      Text(
                        'ملاحظة: ${line.notes!}',
                        style: rowStyle.copyWith(
                          fontSize: 22.0 * typographyScale,
                          color: secondaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.start,
                      ),
                  ],
                ),
              ),
              _cell(
                line.quantityDisplay,
                style: rowStyle.copyWith(fontWeight: FontWeight.bold),
                align: TextAlign.center,
              ),
              _cell(
                '${line.unitPrice.toEgp.toStringAsFixed(2)} ج.م',
                style: rowStyle.copyWith(fontWeight: FontWeight.w600),
                align: TextAlign.end,
              ),
              _cell(
                '${line.calculatedTotal.toEgp.toStringAsFixed(2)} ج.م',
                style: rowStyle.copyWith(fontWeight: FontWeight.bold),
                align: TextAlign.end,
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _cell(
    String text, {
    TextStyle? style,
    TextAlign align = TextAlign.start,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Text(text, style: style, textAlign: align),
    );
  }
}
