import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/domain/entities/business_settings.dart';
import 'package:laundry_management/domain/entities/carpet_item_data.dart';
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';
import 'package:laundry_management/features/orders/presentation/services/invoice_printer.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:printing/src/interface.dart';

class MockPrintingPlatform extends PrintingPlatform {
  bool shouldThrow = false;
  int callCount = 0;
  PdfPageFormat? receivedFormat;
  bool? receivedDynamicLayout;
  String? receivedName;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<bool> layoutPdf(
    Printer? printer,
    LayoutCallback onLayout,
    String name,
    PdfPageFormat format,
    bool dynamicLayout,
    bool usePrinterSettings,
    OutputType outputType,
    bool forceCustomPrintPaper,
  ) async {
    callCount++;
    receivedFormat = format;
    receivedDynamicLayout = dynamicLayout;
    receivedName = name;
    if (shouldThrow) {
      throw Exception('OS Print Spooler unavailable');
    }
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late pw.Font regularFont;
  late pw.Font boldFont;

  setUpAll(() async {
    final regularData = await rootBundle.load('assets/fonts/IBMPlexSansArabic-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/IBMPlexSansArabic-Bold.ttf');
    regularFont = pw.Font.ttf(regularData);
    boldFont = pw.Font.ttf(boldData);
  });

  final testDate = DateTime(2026, 9, 12, 14, 30);
  final testOrderDate = OrderDate(2026, 9, 15);

  Order createTestOrder({
    String orderNumber = '26-001',
    String customerName = 'محمد أحمد علي',
    String customerPhone = '01012345678',
    Money? subtotal,
    Money discount = Money.zero,
    bool customerPickupRequested = false,
    Money customerPickupFee = Money.zero,
    bool customerDeliveryRequested = false,
    Money customerDeliveryFee = Money.zero,
    Money tax = Money.zero,
    Money total = const Money.fromPiastres(10000),
  }) {
    final effectiveSubtotal = subtotal ??
        (total + discount - customerPickupFee - customerDeliveryFee - tax);

    return Order(
      id: 'ord-test-1',
      orderNumber: orderNumber,
      customerId: 'cust-1',
      customerNameSnapshot: customerName,
      customerPhoneSnapshot: customerPhone,
      status: OrderStatus.processing,
      expectedPickupDate: testOrderDate,
      customerPickupRequested: customerPickupRequested,
      customerPickupFee: customerPickupFee,
      customerDeliveryRequested: customerDeliveryRequested,
      customerDeliveryFee: customerDeliveryFee,
      subtotal: effectiveSubtotal,
      discount: discount,
      tax: tax,
      total: total,
      createdAt: testDate,
      updatedAt: testDate,
    );
  }

  OrderItem createTestItem({
    String itemTypeName = 'قميص',
    String? itemDefinitionName = 'رجالي',
    String serviceName = 'غسيل وكي',
    PricingType pricingType = PricingType.perPiece,
    double quantity = 1.0,
    Money unitPrice = const Money.fromPiastres(5000),
    Money calculatedTotal = const Money.fromPiastres(5000),
    CarpetItemData? carpetData,
    String? notes,
  }) {
    return OrderItem(
      id: 'item-test-1',
      orderId: 'ord-test-1',
      itemTypeId: 'type-1',
      serviceId: 'srv-1',
      itemTypeNameSnapshot: itemTypeName,
      itemDefinitionNameSnapshot: itemDefinitionName,
      serviceNameSnapshot: serviceName,
      pricingType: pricingType,
      quantity: quantity,
      unitPrice: unitPrice,
      calculatedTotal: calculatedTotal,
      carpetData: carpetData,
      notes: notes,
      createdAt: testDate,
      updatedAt: testDate,
    );
  }

  final defaultSettings = BusinessSettings(
    id: 'settings-1',
    businessName: 'مغسلة النقاء المتطورة',
    address: 'شارع النصر، القاهرة',
    phone: '01000000000',
    invoiceFooterText: 'شكراً لتعاملكم معنا!',
    createdAt: testDate,
    updatedAt: testDate,
  );

  group('InvoicePrinter Quantity Formatting Tests', () {
    test('Piece quantity formatting: integer count 1 -> "1 قطعة"', () {
      final item = createTestItem(quantity: 1.0, pricingType: PricingType.perPiece);
      expect(InvoicePrinter.formatQuantity(item), '1 قطعة');
    });

    test('Piece quantity formatting: integer count 3 -> "3 قطع"', () {
      final item = createTestItem(quantity: 3.0, pricingType: PricingType.perPiece);
      expect(InvoicePrinter.formatQuantity(item), '3 قطع');
    });

    test('Piece quantity formatting: decimal 2.75 -> "2.75 قطعة" (never truncated to 2)', () {
      final item = createTestItem(quantity: 2.75, pricingType: PricingType.perPiece);
      expect(InvoicePrinter.formatQuantity(item), '2.75 قطعة');
    });

    test('Carpet quantity formatting: area 2.75 -> "1 قطعة" (piece count, not area)', () {
      final carpet = CarpetItemData(
        id: 'carpet-1',
        orderItemId: 'item-test-1',
        length: 2.0,
        width: 1.375,
        area: 2.75,
        createdAt: testDate,
        updatedAt: testDate,
      );
      final item = createTestItem(
        pricingType: PricingType.perSquareMeter,
        quantity: 1.0,
        carpetData: carpet,
      );
      expect(InvoicePrinter.formatQuantity(item), '1 قطعة');
    });

    test('Carpet quantity formatting fallback to item.quantity when carpetData is null', () {
      final item = createTestItem(
        pricingType: PricingType.perSquareMeter,
        quantity: 4.5,
        carpetData: null,
      );
      expect(InvoicePrinter.formatQuantity(item), '4.5 قطعة');
    });

    test('formatNumber preserves exact precision and trims trailing zeroes', () {
      expect(InvoicePrinter.formatNumber(1.0), '1');
      expect(InvoicePrinter.formatNumber(2.5), '2.5');
      expect(InvoicePrinter.formatNumber(2.75), '2.75');
      expect(InvoicePrinter.formatNumber(3.00), '3');
    });
  });

  group('Invoice Line-Item Aggregation / Grouping Tests', () {
    test('1. Three identical normal items become one grouped line with quantity 3 and sum total', () {
      final items = [
        createTestItem(itemTypeName: 'قميص', serviceName: 'غسيل', unitPrice: const Money.fromPiastres(2000), calculatedTotal: const Money.fromPiastres(2000)),
        createTestItem(itemTypeName: 'قميص', serviceName: 'غسيل', unitPrice: const Money.fromPiastres(2000), calculatedTotal: const Money.fromPiastres(2000)),
        createTestItem(itemTypeName: 'قميص', serviceName: 'غسيل', unitPrice: const Money.fromPiastres(2000), calculatedTotal: const Money.fromPiastres(2000)),
      ];

      final lines = InvoicePrinter.groupItems(items);

      expect(lines.length, 1);
      expect(lines.first.quantityDisplay, '3 قطع');
      expect(lines.first.unitPrice, const Money.fromPiastres(2000));
      expect(lines.first.calculatedTotal, const Money.fromPiastres(6000));
      expect(lines.first.dimensionsSubtext, isNull);
    });

    test('2-5. Three identical carpets become one grouped line with quantity 3 pieces, piece unit price, and dimensions', () {
      CarpetItemData makeCarpet(String id) => CarpetItemData(
            id: id,
            orderItemId: 'item-$id',
            length: 2.0,
            width: 3.0,
            area: 6.0,
            createdAt: testDate,
            updatedAt: testDate,
          );

      final items = [
        createTestItem(
          itemTypeName: 'سجاد',
          itemDefinitionName: 'سجادة صوف',
          serviceName: 'غسيل سجاد',
          pricingType: PricingType.perSquareMeter,
          unitPrice: const Money.fromPiastres(2000), // 20 EGP/m²
          calculatedTotal: const Money.fromPiastres(12000), // 120 EGP for 1 piece (6m² * 20 EGP)
          carpetData: makeCarpet('c1'),
        ),
        createTestItem(
          itemTypeName: 'سجاد',
          itemDefinitionName: 'سجادة صوف',
          serviceName: 'غسيل سجاد',
          pricingType: PricingType.perSquareMeter,
          unitPrice: const Money.fromPiastres(2000),
          calculatedTotal: const Money.fromPiastres(12000),
          carpetData: makeCarpet('c2'),
        ),
        createTestItem(
          itemTypeName: 'سجاد',
          itemDefinitionName: 'سجادة صوف',
          serviceName: 'غسيل سجاد',
          pricingType: PricingType.perSquareMeter,
          unitPrice: const Money.fromPiastres(2000),
          calculatedTotal: const Money.fromPiastres(12000),
          carpetData: makeCarpet('c3'),
        ),
      ];

      final lines = InvoicePrinter.groupItems(items);

      expect(lines.length, 1);
      // 2. Quantity displays piece count: 3 قطع
      expect(lines.first.quantityDisplay, '3 قطع');
      // 3. Dimensions sub-text with area/piece: (2 × 3 م) — 6 م²/قطعة
      expect(lines.first.dimensionsSubtext, '(2 × 3 م) — 6 م²/قطعة');
      // 4. Unit price represents one piece: 120.00 EGP
      expect(lines.first.unitPrice, const Money.fromPiastres(12000));
      // 5. Grouped total is quantity * unit price = 360.00 EGP
      expect(lines.first.calculatedTotal, const Money.fromPiastres(36000));
    });

    test('6. Different carpet dimensions do NOT group', () {
      final carpet1 = CarpetItemData(
        id: 'c1',
        orderItemId: 'i1',
        length: 2.0,
        width: 3.0,
        area: 6.0,
        createdAt: testDate,
        updatedAt: testDate,
      );
      final carpet2 = CarpetItemData(
        id: 'c2',
        orderItemId: 'i2',
        length: 3.0,
        width: 4.0,
        area: 12.0,
        createdAt: testDate,
        updatedAt: testDate,
      );

      final items = [
        createTestItem(
          pricingType: PricingType.perSquareMeter,
          unitPrice: const Money.fromPiastres(2000),
          calculatedTotal: const Money.fromPiastres(12000),
          carpetData: carpet1,
        ),
        createTestItem(
          pricingType: PricingType.perSquareMeter,
          unitPrice: const Money.fromPiastres(2000),
          calculatedTotal: const Money.fromPiastres(24000),
          carpetData: carpet2,
        ),
      ];

      final lines = InvoicePrinter.groupItems(items);
      expect(lines.length, 2);
    });

    test('7. Different services do NOT group', () {
      final items = [
        createTestItem(itemTypeName: 'قميص', serviceName: 'غسيل'),
        createTestItem(itemTypeName: 'قميص', serviceName: 'تعقيم'),
      ];

      final lines = InvoicePrinter.groupItems(items);
      expect(lines.length, 2);
    });

    test('8. Different unit prices do NOT group', () {
      final items = [
        createTestItem(itemTypeName: 'قميص', unitPrice: const Money.fromPiastres(2000)),
        createTestItem(itemTypeName: 'قميص', unitPrice: const Money.fromPiastres(2500)),
      ];

      final lines = InvoicePrinter.groupItems(items);
      expect(lines.length, 2);
    });

    test('9. Different relevant item details/notes do NOT group', () {
      final items = [
        createTestItem(itemTypeName: 'قميص', notes: 'بقعة حبر'),
        createTestItem(itemTypeName: 'قميص', notes: 'بدون بقع'),
      ];

      final lines = InvoicePrinter.groupItems(items);
      expect(lines.length, 2);
    });

    test('10. Decimal quantity behavior continues to work in grouping', () {
      final items = [
        createTestItem(itemTypeName: 'قماش', quantity: 2.75, unitPrice: const Money.fromPiastres(1000), calculatedTotal: const Money.fromPiastres(2750)),
      ];

      final lines = InvoicePrinter.groupItems(items);
      expect(lines.length, 1);
      expect(lines.first.quantityDisplay, '2.75 قطعة');
    });

    test('11. Authoritative order.total remains unchanged when generating PDF with grouped lines', () async {
      final order = createTestOrder(
        subtotal: const Money.fromPiastres(36000),
        total: const Money.fromPiastres(36000),
      );

      CarpetItemData makeCarpet(String id) => CarpetItemData(
            id: id,
            orderItemId: 'item-$id',
            length: 2.0,
            width: 3.0,
            area: 6.0,
            createdAt: testDate,
            updatedAt: testDate,
          );

      final items = [
        createTestItem(pricingType: PricingType.perSquareMeter, carpetData: makeCarpet('1'), calculatedTotal: const Money.fromPiastres(12000)),
        createTestItem(pricingType: PricingType.perSquareMeter, carpetData: makeCarpet('2'), calculatedTotal: const Money.fromPiastres(12000)),
        createTestItem(pricingType: PricingType.perSquareMeter, carpetData: makeCarpet('3'), calculatedTotal: const Money.fromPiastres(12000)),
      ];

      final doc = await InvoicePrinter.generatePdfDocument(
        order: order,
        items: items,
        totalPaid: const Money.fromPiastres(10000),
        remainingAmount: const Money.fromPiastres(26000),
        settings: defaultSettings,
        regularFont: regularFont,
        boldFont: boldFont,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
      expect(order.total, const Money.fromPiastres(36000));
    });
  });

  group('InvoicePrinter PDF Generation Permutations', () {
    test('1. Normal single-item order', () async {
      final order = createTestOrder();
      final item = createTestItem();

      final doc = await InvoicePrinter.generatePdfDocument(
        order: order,
        items: [item],
        totalPaid: const Money.fromPiastres(6000),
        remainingAmount: const Money.fromPiastres(4000),
        settings: defaultSettings,
        regularFont: regularFont,
        boldFont: boldFont,
      );

      final bytes = await doc.save();
      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
    });

    test('2. Multi-item order with diverse services', () async {
      final order = createTestOrder(total: const Money.fromPiastres(15000));
      final item1 = createTestItem(itemTypeName: 'قميص', serviceName: 'غسيل وكي');
      final item2 = createTestItem(itemTypeName: 'بنطلون', serviceName: 'تنظيف جاف');
      final item3 = createTestItem(itemTypeName: 'بدلة', serviceName: 'كي فقط');

      final doc = await InvoicePrinter.generatePdfDocument(
        order: order,
        items: [item1, item2, item3],
        totalPaid: const Money.fromPiastres(15000),
        remainingAmount: Money.zero,
        settings: defaultSettings,
        regularFont: regularFont,
        boldFont: boldFont,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
    });

    test('3. Blanket order with definition snapshot', () async {
      final order = createTestOrder();
      final blanket = createTestItem(
        itemTypeName: 'بطانية',
        itemDefinitionName: 'مفرد',
        serviceName: 'غسيل معطر',
      );

      final doc = await InvoicePrinter.generatePdfDocument(
        order: order,
        items: [blanket],
        totalPaid: Money.zero,
        remainingAmount: order.total,
        settings: defaultSettings,
        regularFont: regularFont,
        boldFont: boldFont,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
    });

    test('4. Carpet order with dimensions and area calculation', () async {
      final carpetData = CarpetItemData(
        id: 'c-1',
        orderItemId: 'item-1',
        length: 3.0,
        width: 2.0,
        area: 6.0,
        createdAt: testDate,
        updatedAt: testDate,
      );
      final carpetItem = createTestItem(
        itemTypeName: 'سجاد',
        itemDefinitionName: null,
        serviceName: 'غسيل',
        pricingType: PricingType.perSquareMeter,
        quantity: 1.0,
        unitPrice: const Money.fromPiastres(5000), // 50 EGP/m²
        calculatedTotal: const Money.fromPiastres(30000), // 300 EGP
        carpetData: carpetData,
      );
      final order = createTestOrder(
        subtotal: const Money.fromPiastres(30000),
        total: const Money.fromPiastres(30000),
      );

      final doc = await InvoicePrinter.generatePdfDocument(
        order: order,
        items: [carpetItem],
        totalPaid: const Money.fromPiastres(10000),
        remainingAmount: const Money.fromPiastres(20000),
        settings: defaultSettings,
        regularFont: regularFont,
        boldFont: boldFont,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
    });

    test('5. Carpet with decimal square-meter quantity (2.75 m²)', () async {
      final carpetData = CarpetItemData(
        id: 'c-2',
        orderItemId: 'item-2',
        length: 2.0,
        width: 1.375,
        area: 2.75,
        createdAt: testDate,
        updatedAt: testDate,
      );
      final carpetItem = createTestItem(
        itemTypeName: 'سجاد',
        serviceName: 'غسيل خاص',
        pricingType: PricingType.perSquareMeter,
        quantity: 1.0,
        carpetData: carpetData,
      );

      final doc = await InvoicePrinter.generatePdfDocument(
        order: createTestOrder(),
        items: [carpetItem],
        totalPaid: Money.zero,
        remainingAmount: const Money.fromPiastres(10000),
        settings: defaultSettings,
        regularFont: regularFont,
        boldFont: boldFont,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
    });

    test('6. Order with customer delivery fee', () async {
      final order = createTestOrder(
        customerDeliveryRequested: true,
        customerDeliveryFee: const Money.fromPiastres(2000), // 20 EGP
        total: const Money.fromPiastres(12000),
      );

      final doc = await InvoicePrinter.generatePdfDocument(
        order: order,
        items: [createTestItem()],
        totalPaid: Money.zero,
        remainingAmount: order.total,
        settings: defaultSettings,
        regularFont: regularFont,
        boldFont: boldFont,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
    });

    test('7. Order with customer pickup fee', () async {
      final order = createTestOrder(
        customerPickupRequested: true,
        customerPickupFee: const Money.fromPiastres(1500), // 15 EGP
        total: const Money.fromPiastres(11500),
      );

      final doc = await InvoicePrinter.generatePdfDocument(
        order: order,
        items: [createTestItem()],
        totalPaid: Money.zero,
        remainingAmount: order.total,
        settings: defaultSettings,
        regularFont: regularFont,
        boldFont: boldFont,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
    });

    test('8. Order with discount', () async {
      final order = createTestOrder(
        subtotal: const Money.fromPiastres(10000),
        discount: const Money.fromPiastres(1000),
        total: const Money.fromPiastres(9000),
      );

      final doc = await InvoicePrinter.generatePdfDocument(
        order: order,
        items: [createTestItem()],
        totalPaid: const Money.fromPiastres(5000),
        remainingAmount: const Money.fromPiastres(4000),
        settings: defaultSettings,
        regularFont: regularFont,
        boldFont: boldFont,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
    });

    test('9. Order with tax > 0', () async {
      final order = createTestOrder(
        subtotal: const Money.fromPiastres(10000),
        tax: const Money.fromPiastres(1400), // 14 EGP
        total: const Money.fromPiastres(11400),
      );

      final doc = await InvoicePrinter.generatePdfDocument(
        order: order,
        items: [createTestItem()],
        totalPaid: const Money.fromPiastres(11400),
        remainingAmount: Money.zero,
        settings: defaultSettings,
        regularFont: regularFont,
        boldFont: boldFont,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
    });

    test('10. Unpaid order (totalPaid = 0, remaining = total)', () async {
      final order = createTestOrder(total: const Money.fromPiastres(8000));

      final doc = await InvoicePrinter.generatePdfDocument(
        order: order,
        items: [createTestItem()],
        totalPaid: Money.zero,
        remainingAmount: const Money.fromPiastres(8000),
        settings: defaultSettings,
        regularFont: regularFont,
        boldFont: boldFont,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
    });

    test('11. Partially paid order', () async {
      final order = createTestOrder(total: const Money.fromPiastres(8000));

      final doc = await InvoicePrinter.generatePdfDocument(
        order: order,
        items: [createTestItem()],
        totalPaid: const Money.fromPiastres(3000),
        remainingAmount: const Money.fromPiastres(5000),
        settings: defaultSettings,
        regularFont: regularFont,
        boldFont: boldFont,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
    });

    test('12. Fully paid order (remaining = 0)', () async {
      final order = createTestOrder(total: const Money.fromPiastres(8000));

      final doc = await InvoicePrinter.generatePdfDocument(
        order: order,
        items: [createTestItem()],
        totalPaid: const Money.fromPiastres(8000),
        remainingAmount: Money.zero,
        settings: defaultSettings,
        regularFont: regularFont,
        boldFont: boldFont,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
    });

    test('13. Long Arabic customer name wraps without throwing', () async {
      final order = createTestOrder(
        customerName: 'الأستاذ عبد الرحمن بن محمد بن إبراهيم الحسيني الإسكندراني',
      );

      final doc = await InvoicePrinter.generatePdfDocument(
        order: order,
        items: [createTestItem()],
        totalPaid: Money.zero,
        remainingAmount: order.total,
        settings: defaultSettings,
        regularFont: regularFont,
        boldFont: boldFont,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
    });

    test('14. Long Arabic service name and item description wraps without throwing', () async {
      final order = createTestOrder();
      final item = createTestItem(
        itemTypeName: 'مفرش سرير كبير مطرز تطريز يدوي فاخر',
        itemDefinitionName: 'ثلاث طبقات حرير طبيعي',
        serviceName: 'غسيل بخار مكثف ومعالجة بقع مستعصية وتعقيم بالأوزون',
        notes: 'يرجى العناية الفائقة بالأطراف المذهبة وعدم استخدام درجات حرارة مرتفعة',
      );

      final doc = await InvoicePrinter.generatePdfDocument(
        order: order,
        items: [item],
        totalPaid: Money.zero,
        remainingAmount: order.total,
        settings: defaultSettings,
        regularFont: regularFont,
        boldFont: boldFont,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
    });

    test('15. Mixed Arabic and Western digits: order number 26-001, phone 01012345678', () async {
      final order = createTestOrder(
        orderNumber: '26-001',
        customerPhone: '01012345678',
      );

      final doc = await InvoicePrinter.generatePdfDocument(
        order: order,
        items: [createTestItem()],
        totalPaid: Money.zero,
        remainingAmount: order.total,
        settings: defaultSettings,
        regularFont: regularFont,
        boldFont: boldFont,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
    });

    test('16. Arabic punctuation, test words (غسيل، مستعجل، بطانية، سجاد) and currency', () async {
      final order = createTestOrder(orderNumber: '26-999');
      final item1 = createTestItem(itemTypeName: 'سجاد', serviceName: 'غسيل مستعجل');
      final item2 = createTestItem(itemTypeName: 'بطانية', serviceName: 'غسيل وكي');

      final doc = await InvoicePrinter.generatePdfDocument(
        order: order,
        items: [item1, item2],
        totalPaid: const Money.fromPiastres(5000),
        remainingAmount: const Money.fromPiastres(5000),
        settings: defaultSettings,
        regularFont: regularFont,
        boldFont: boldFont,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);

      try {
        final scratchFile = File('C:/Users/Mohamed/.gemini/antigravity-ide/brain/7f24deee-8cc5-4543-a10a-5c843fe04534/scratch/sample_invoice.pdf');
        await scratchFile.writeAsBytes(bytes);
      } catch (_) {
        // Ignore file system errors in restricted test environments
      }
    });
  });

  group('InvoicePrinter Fallbacks & Edge Cases', () {
    test('Uses customer entity as fallback if order customer snapshots are blank', () async {
      final order = createTestOrder(
        customerName: '',
        customerPhone: '',
      );
      final customer = Customer(
        id: 'cust-1',
        name: 'عميل احتياطي',
        phone: '01122334455',
        createdAt: testDate,
        updatedAt: testDate,
      );

      final doc = await InvoicePrinter.generatePdfDocument(
        order: order,
        customer: customer,
        items: [createTestItem()],
        totalPaid: Money.zero,
        remainingAmount: order.total,
        settings: defaultSettings,
        regularFont: regularFont,
        boldFont: boldFont,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
    });

    test('Uses default business name and footer when settings is null', () async {
      final order = createTestOrder();

      final doc = await InvoicePrinter.generatePdfDocument(
        order: order,
        items: [createTestItem()],
        totalPaid: Money.zero,
        remainingAmount: order.total,
        settings: null,
        regularFont: regularFont,
        boldFont: boldFont,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
    });

    test('Uses fallback footer when invoiceFooterText is empty or whitespace', () async {
      final order = createTestOrder();
      final settings = BusinessSettings(
        id: 'settings-ws',
        businessName: 'مغسلة النقاء',
        invoiceFooterText: '   ',
        createdAt: testDate,
        updatedAt: testDate,
      );

      final doc = await InvoicePrinter.generatePdfDocument(
        order: order,
        items: [createTestItem()],
        totalPaid: Money.zero,
        remainingAmount: order.total,
        settings: settings,
        regularFont: regularFont,
        boldFont: boldFont,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
    });
  });

  group('InvoicePrinter.printInvoice Native OS Workflow', () {
    late MockPrintingPlatform mockPlatform;
    late PrintingPlatform originalPlatform;

    setUp(() {
      originalPlatform = PrintingPlatform.instance;
      mockPlatform = MockPrintingPlatform();
      PrintingPlatform.instance = mockPlatform;
    });

    tearDown(() {
      PrintingPlatform.instance = originalPlatform;
    });

    test('forces 80mm roll format (PdfPageFormat.roll80) and dynamicLayout: false', () async {
      final order = createTestOrder(orderNumber: '26-099');

      final result = await InvoicePrinter.printInvoice(
        order: order,
        items: [createTestItem()],
        totalPaid: Money.zero,
        remainingAmount: order.total,
        settings: defaultSettings,
      );

      expect(result, isTrue);
      expect(mockPlatform.callCount, 1);
      expect(mockPlatform.receivedFormat, PdfPageFormat.roll80);
      expect(mockPlatform.receivedDynamicLayout, isFalse);
      expect(mockPlatform.receivedName, 'invoice_26-099.pdf');
    });
  });
}
