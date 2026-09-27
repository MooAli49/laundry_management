import 'dart:async';
import 'dart:developer' as dev;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../domain/entities/business_settings.dart';
import '../../../../../domain/entities/customer.dart';
import '../../../../../domain/entities/order.dart';
import '../../../../../domain/entities/order_item.dart';
import '../../../../../domain/value_objects/money.dart';
import '../invoice_printer.dart';
import 'printer_profile.dart';

/// Renders an invoice as a raster bitmap image suitable for thermal printer
/// transmission.
///
/// ## Arabic Support Strategy
///
/// Thermal printers like TSC printers do NOT have built-in Arabic glyphs.
/// Attempting to send raw UTF-8/Arabic text commands results in garbled output.
///
/// **Solution**: Render the invoice using Flutter's text engine (which
/// correctly handles Arabic RTL, ligatures, and fonts) into an off-screen
/// [RenderRepaintBoundary], capture it as a [ui.Image], then convert to raw
/// PNG bytes.
///
/// The PNG bytes are then wrapped in ESC/POS or TSPL raster commands and sent
/// to the printer.  This guarantees pixel-perfect Arabic regardless of the
/// printer's internal font set.
///
/// ## Paper Width
///
/// The rendered widget width is [ThermalPaperWidth.printablePixels] dots, which
/// respects the selected paper width configuration.
class ThermalInvoiceRenderer {
  ThermalInvoiceRenderer._();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Render the invoice to a PNG byte buffer sized for the given [profile].
  ///
  /// [pixelRatio] is the device-pixel ratio used when capturing the image.
  /// Higher values produce sharper output but larger data payloads.
  /// A value of 2.0 gives good results on 203-dpi thermal printers.
  static Future<Uint8List> renderToImage({
    required BuildContext context,
    required Order order,
    required List<OrderItem> items,
    required Money totalPaid,
    required Money remainingAmount,
    required PrinterProfile profile,
    Customer? customer,
    BusinessSettings? settings,
    double pixelRatio = 2.0,
  }) async {
    final stopwatch = Stopwatch()..start();
    final hasOverlay = context.findAncestorStateOfType<OverlayState>() != null;
    dev.log(
      'PRINT RENDER CONTEXT valid=$hasOverlay',
      name: 'BluetoothPrinterService',
    );
    dev.log('PRINT RENDER START', name: 'BluetoothPrinterService');
    // Load Arabic fonts
    final regularFontData = await rootBundle.load(
      'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    );
    final boldFontData = await rootBundle.load(
      'assets/fonts/IBMPlexSansArabic-Bold.ttf',
    );

    final paperWidthPx = profile.paperWidth.printablePixels.toDouble();

    // Build the invoice widget tree (off-screen)
    final invoiceWidget = _buildInvoiceWidget(
      order: order,
      items: items,
      totalPaid: totalPaid,
      remainingAmount: remainingAmount,
      customer: customer,
      settings: settings,
      paperWidthPx: paperWidthPx,
      regularFontData: regularFontData,
      boldFontData: boldFontData,
    );

    // Rasterise to image
    final imageBytes = await _rasterise(
      context,
      invoiceWidget,
      pixelRatio: pixelRatio,
    );
    dev.log(
      'PRINT RENDER SUCCESS bytes=${imageBytes.length} format=PNG '
      'durationMs=${stopwatch.elapsedMilliseconds}',
      name: 'BluetoothPrinterService',
    );
    return imageBytes;
  }

  // ---------------------------------------------------------------------------
  // Internal widget builder
  // ---------------------------------------------------------------------------

  static Widget _buildInvoiceWidget({
    required Order order,
    required List<OrderItem> items,
    required Money totalPaid,
    required Money remainingAmount,
    required double paperWidthPx,
    required ByteData regularFontData,
    required ByteData boldFontData,
    Customer? customer,
    BusinessSettings? settings,
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
    const baseFs =
        11.0; // base font-size (points) — scaled to pixels by Flutter
    const smallFs = 9.5;
    const tinyFs = 8.5;

    const regularFamily = 'IBM Plex Sans Arabic';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: Colors.white,
        child: SizedBox(
          width: paperWidthPx,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ──────────────────────────────────────────────────
                Center(
                  child: Text(
                    businessName,
                    style: TextStyle(
                      fontFamily: regularFamily,
                      fontSize: baseFs + 1,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (address != null && address.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Center(
                    child: Text(
                      address.trim(),
                      style: TextStyle(
                        fontFamily: regularFamily,
                        fontSize: tinyFs,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                if (phone != null && phone.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Center(
                    child: Text(
                      'هاتف: ${phone.trim()}',
                      style: TextStyle(
                        fontFamily: regularFamily,
                        fontSize: tinyFs,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                _divider(),
                const SizedBox(height: 6),

                // ── Order metadata ───────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'فاتورة رقم: ${order.orderNumber}',
                      style: TextStyle(
                        fontFamily: regularFamily,
                        fontSize: smallFs,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'التاريخ: ${InvoicePrinter.formatDateTime(order.createdAt)}',
                  style: TextStyle(
                    fontFamily: regularFamily,
                    fontSize: tinyFs,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'موعد الاستلام: ${InvoicePrinter.formatDate(order.expectedPickupDate.toDateTime())}',
                  style: TextStyle(
                    fontFamily: regularFamily,
                    fontSize: tinyFs,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'العميل: $customerName',
                  style: TextStyle(
                    fontFamily: regularFamily,
                    fontSize: tinyFs,
                    color: Colors.black87,
                  ),
                ),
                if (customerPhone.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    'الهاتف: $customerPhone',
                    style: TextStyle(
                      fontFamily: regularFamily,
                      fontSize: tinyFs,
                      color: Colors.black87,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                _divider(),
                const SizedBox(height: 4),

                // ── Items table ──────────────────────────────────────────────
                _ItemsTable(lines: lines, fontFamily: regularFamily),
                const SizedBox(height: 4),
                _divider(),
                const SizedBox(height: 4),

                // ── Financial summary ────────────────────────────────────────
                _summaryRow(
                  'المجموع الفرعي:',
                  '${order.subtotal.toEgp.toStringAsFixed(2)} ج.م',
                  fontFamily: regularFamily,
                ),
                if (order.discount.isPositive)
                  _summaryRow(
                    'الخصم:',
                    '- ${order.discount.toEgp.toStringAsFixed(2)} ج.م',
                    fontFamily: regularFamily,
                  ),
                if (order.customerPickupRequested &&
                    order.customerPickupFee.isPositive)
                  _summaryRow(
                    'استلام من العميل:',
                    '+ ${order.customerPickupFee.toEgp.toStringAsFixed(2)} ج.م',
                    fontFamily: regularFamily,
                  ),
                if (order.customerDeliveryRequested &&
                    order.customerDeliveryFee.isPositive)
                  _summaryRow(
                    'توصيل للعميل:',
                    '+ ${order.customerDeliveryFee.toEgp.toStringAsFixed(2)} ج.م',
                    fontFamily: regularFamily,
                  ),
                if (order.tax.isPositive)
                  _summaryRow(
                    'الضريبة:',
                    '+ ${order.tax.toEgp.toStringAsFixed(2)} ج.م',
                    fontFamily: regularFamily,
                  ),
                const SizedBox(height: 3),
                _dashedDivider(),
                const SizedBox(height: 3),
                _summaryRow(
                  'الإجمالي:',
                  '${order.total.toEgp.toStringAsFixed(2)} ج.م',
                  fontFamily: regularFamily,
                  bold: true,
                  fontSize: baseFs,
                ),
                _summaryRow(
                  'المدفوع:',
                  '${totalPaid.toEgp.toStringAsFixed(2)} ج.م',
                  fontFamily: regularFamily,
                ),
                _summaryRow(
                  'المتبقي:',
                  '${remainingAmount.toEgp.toStringAsFixed(2)} ج.م',
                  fontFamily: regularFamily,
                  bold: true,
                  fontSize: baseFs,
                  valueColor: remainingAmount.isZero
                      ? AppColors.success
                      : AppColors.warning,
                ),
                const SizedBox(height: 8),
                _dashedDivider(),
                const SizedBox(height: 8),

                // ── Footer ───────────────────────────────────────────────────
                Center(
                  child: Text(
                    footer,
                    style: TextStyle(
                      fontFamily: regularFamily,
                      fontSize: tinyFs,
                      color: Colors.black54,
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
  ///
  /// This is the canonical modern Flutter approach for off-screen rendering
  /// without any deprecated APIs.
  static Future<Uint8List> _rasterise(
    BuildContext context,
    Widget widget, {
    double pixelRatio = 2.0,
  }) async {
    // Use a Completer to return from a callback-based lifecycle
    final completer = Completer<Uint8List>();
    final repaintKey = GlobalKey();

    // We need an entry point into the widget tree.  We use a Navigator overlay
    // trick: push an Offstage widget onto the root overlay, wait for a frame
    // to complete layout, then capture.
    //
    // However, since we may not have access to a navigator here, we use a
    // simpler approach: build the widget standalone using a PipelineOwner +
    // RendererBinding-aware technique via Directionality + constraints.
    //
    // Modern clean approach: use a dummy WidgetsApp / runApp alternative.
    // The simplest method that avoids all deprecated APIs is:
    // - Create a WidgetsFlutterBinding-dependent overlay capture.
    //
    // We use the WidgetsBinding instance and inject a temporary
    // OverlayEntry into the root overlay.

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
          dev.log(
            'PRINT RENDER WAIT FRAME index=${frame + 1}',
            name: 'BluetoothPrinterService',
          );
          await SchedulerBinding.instance.endOfFrame;

          var needsPaint = false;
          assert(() {
            needsPaint = boundary.debugNeedsPaint;
            return true;
          }());
          paintReady = boundary.attached && boundary.hasSize && !needsPaint;
          dev.log(
            'PRINT RENDER PAINT READY=$paintReady attached=${boundary.attached} '
            'hasSize=${boundary.hasSize} needsPaint=$needsPaint',
            name: 'BluetoothPrinterService',
          );
          if (paintReady) break;
        }

        if (!paintReady) {
          var needsPaint = false;
          assert(() {
            needsPaint = boundary.debugNeedsPaint;
            return true;
          }());
          dev.log(
            'PRINT RENDER CAPTURE FAILED needsPaint=$needsPaint '
            'attached=${boundary.attached} hasSize=${boundary.hasSize}',
            name: 'BluetoothPrinterService',
          );
          completer.completeError(
            StateError('RenderRepaintBoundary was not paint-ready'),
          );
          return;
        }

        dev.log('PRINT RENDER CAPTURE START', name: 'BluetoothPrinterService');
        final image = await boundary.toImage(pixelRatio: pixelRatio);
        dev.log(
          'PRINT RENDER IMAGE width=${image.width} height=${image.height}',
          name: 'BluetoothPrinterService',
        );
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) {
          completer.completeError(StateError('toByteData returned null'));
          return;
        }
        final pngBytes = byteData.buffer.asUint8List();
        dev.log(
          'PRINT RENDER COMPLETE imageWidth=${image.width} '
          'imageHeight=${image.height} pngBytes=${pngBytes.length}',
          name: 'BluetoothPrinterService',
        );
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

    // Insert into the root overlay
    final overlayState = context.findAncestorStateOfType<OverlayState>();

    if (overlayState != null) {
      overlayState.insert(entry!);
      // Schedule capture after layout
      WidgetsBinding.instance.addPostFrameCallback((_) => capture());
    } else {
      // Fallback: if no overlay is available (e.g., unit test context),
      // use the naive PipelineOwner approach.  We call dispose in finally.
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

  static Widget _divider() => Container(height: 0.5, color: Colors.black54);

  static Widget _dashedDivider() =>
      Container(height: 0.5, color: Colors.black38);

  static Widget _summaryRow(
    String label,
    String value, {
    required String fontFamily,
    bool bold = false,
    double fontSize = 9.5,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: Colors.black,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: valueColor ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Items table widget
// ---------------------------------------------------------------------------

class _ItemsTable extends StatelessWidget {
  final List<InvoiceLineItem> lines;
  final String fontFamily;

  const _ItemsTable({required this.lines, required this.fontFamily});

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 8.5);
    const rowStyle = TextStyle(fontSize: 8.5);

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(4.0), // البند والخدمة
        1: FlexColumnWidth(1.5), // الكمية
        2: FlexColumnWidth(2.0), // سعر الوحدة
        3: FlexColumnWidth(2.0), // الإجمالي
      },
      children: [
        // Header row
        TableRow(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.black54, width: 0.5),
            ),
          ),
          children: [
            _cell('البند والخدمة', style: headerStyle, align: TextAlign.right),
            _cell('الكمية', style: headerStyle, align: TextAlign.center),
            _cell('السعر', style: headerStyle, align: TextAlign.left),
            _cell('الإجمالي', style: headerStyle, align: TextAlign.left),
          ],
        ),
        // Data rows
        ...lines.map((line) {
          return TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      line.title,
                      style: rowStyle.copyWith(fontFamily: fontFamily),
                      textAlign: TextAlign.right,
                    ),
                    if (line.dimensionsSubtext != null)
                      Text(
                        line.dimensionsSubtext!,
                        style: rowStyle.copyWith(
                          fontFamily: fontFamily,
                          fontSize: 7.5,
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    if (line.notes != null)
                      Text(
                        'ملاحظة: ${line.notes!}',
                        style: rowStyle.copyWith(
                          fontFamily: fontFamily,
                          fontSize: 7.5,
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.right,
                      ),
                  ],
                ),
              ),
              _cell(
                line.quantityDisplay,
                style: rowStyle.copyWith(fontFamily: fontFamily),
                align: TextAlign.center,
              ),
              _cell(
                line.unitPrice.toEgp.toStringAsFixed(2),
                style: rowStyle.copyWith(fontFamily: fontFamily),
                align: TextAlign.left,
              ),
              _cell(
                line.calculatedTotal.toEgp.toStringAsFixed(2),
                style: rowStyle.copyWith(
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.bold,
                ),
                align: TextAlign.left,
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
    TextAlign align = TextAlign.right,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 1),
      child: Text(text, style: style, textAlign: align),
    );
  }
}
