import 'package:flutter/material.dart';
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
import 'package:laundry_management/features/orders/presentation/widgets/invoice_preview_dialog.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:printing/src/interface.dart';

class MockPrintingPlatform extends PrintingPlatform {
  bool shouldThrow = false;
  int callCount = 0;
  Duration delay = Duration.zero;
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
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    if (shouldThrow) {
      throw Exception('OS Print Spooler unavailable');
    }
    return true;
  }
}

void main() {
  final now = DateTime(2026, 9, 5);
  final orderDate = OrderDate(2026, 9, 12);
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

  group('InvoicePreviewDialog Tests', () {
    testWidgets('renders business header, customer info, item table and totals', (tester) async {
      final order = Order(
        id: 'ord-1',
        orderNumber: '26-001',
        customerId: 'cust-1',
        customerNameSnapshot: 'عميل الفاتورة',
        customerPhoneSnapshot: '01012345678',
        status: OrderStatus.ready,
        expectedPickupDate: orderDate,
        subtotal: const Money.fromPiastres(10000), // 100 EGP
        total: const Money.fromPiastres(10000),
        createdAt: now,
        updatedAt: now,
      );

      final customer = Customer(
        id: 'cust-1',
        name: 'عميل الفاتورة',
        phone: '01012345678',
        createdAt: now,
        updatedAt: now,
      );

      final item = OrderItem(
        id: 'item-1',
        orderId: 'ord-1',
        itemTypeId: 'type-1',
        serviceId: 'srv-1',
        itemTypeNameSnapshot: 'قميص',
        serviceNameSnapshot: 'غسيل',
        pricingType: PricingType.perPiece,
        quantity: 1.0,
        unitPrice: const Money.fromPiastres(10000),
        calculatedTotal: const Money.fromPiastres(10000),
        createdAt: now,
        updatedAt: now,
      );

      final settings = BusinessSettings(
        id: 'settings-1',
        businessName: 'مغسلة النقاء المتطورة',
        address: 'شارع النصر، القاهرة',
        phone: '01000000000',
        invoiceFooterText: 'شكراً لزيارتكم',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: InvoicePreviewDialog(
                order: order,
                customer: customer,
                items: [item],
                totalPaid: const Money.fromPiastres(6000),
                remainingAmount: const Money.fromPiastres(4000),
                settings: settings,
              ),
            ),
          ),
        ),
      );

      expect(find.text('مغسلة النقاء المتطورة'), findsOneWidget);
      expect(find.text('فاتورة #26-001'), findsOneWidget);
      expect(find.text('عميل الفاتورة'), findsOneWidget);
      expect(find.text('قميص - غسيل'), findsOneWidget);
      expect(find.text('100.00 ج.م'), findsWidgets);
      expect(find.text('60.00 ج.م'), findsOneWidget);
      expect(find.text('40.00 ج.م'), findsOneWidget);
      expect(find.text('طباعة الفاتورة'), findsOneWidget);
      expect(find.text('إغلاق'), findsOneWidget);
    });

    testWidgets('displays historical snapshot even if current customer is mutated', (tester) async {
      final historicalOrder = Order(
        id: 'ord-hist',
        orderNumber: '26-005',
        customerId: 'cust-1',
        customerNameSnapshot: 'العميل الأصلي (أ)',
        customerPhoneSnapshot: '01011112222',
        status: OrderStatus.processing,
        expectedPickupDate: orderDate,
        subtotal: const Money.fromPiastres(5000),
        total: const Money.fromPiastres(5000),
        createdAt: now,
        updatedAt: now,
      );

      final mutatedCustomer = Customer(
        id: 'cust-1',
        name: 'العميل الجديد (ب)',
        phone: '01099998888',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: InvoicePreviewDialog(
                order: historicalOrder,
                customer: mutatedCustomer,
                items: const [],
                totalPaid: Money.zero,
                remainingAmount: const Money.fromPiastres(5000),
              ),
            ),
          ),
        ),
      );

      // Must display historical snapshots
      expect(find.text('العميل الأصلي (أ)'), findsOneWidget);
      expect(find.text('01011112222'), findsOneWidget);

      // Must NOT display mutated current customer info
      expect(find.text('العميل الجديد (ب)'), findsNothing);
      expect(find.text('01099998888'), findsNothing);
    });

    testWidgets('displays piece quantity correctly as integer count (e.g. 2, not hardcoded 1)', (tester) async {
      final order = Order(
        id: 'ord-piece',
        orderNumber: '26-010',
        customerId: 'cust-1',
        customerNameSnapshot: 'أحمد',
        customerPhoneSnapshot: '01011111111',
        status: OrderStatus.processing,
        expectedPickupDate: orderDate,
        subtotal: const Money.fromPiastres(6000),
        total: const Money.fromPiastres(6000),
        createdAt: now,
        updatedAt: now,
      );

      final item = OrderItem(
        id: 'item-2',
        orderId: 'ord-piece',
        itemTypeId: 't-1',
        serviceId: 's-1',
        itemTypeNameSnapshot: 'بنطلون',
        serviceNameSnapshot: 'غسيل',
        pricingType: PricingType.perPiece,
        quantity: 2.0,
        unitPrice: const Money.fromPiastres(3000),
        calculatedTotal: const Money.fromPiastres(6000),
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: InvoicePreviewDialog(
                order: order,
                items: [item],
                totalPaid: Money.zero,
                remainingAmount: const Money.fromPiastres(6000),
              ),
            ),
          ),
        ),
      );

      // Quantity column must show '2'
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsNothing);
    });

    testWidgets('displays carpet quantity with square meter area and dimensions', (tester) async {
      final order = Order(
        id: 'ord-carpet',
        orderNumber: '26-020',
        customerId: 'cust-1',
        customerNameSnapshot: 'محمود',
        customerPhoneSnapshot: '01022222222',
        status: OrderStatus.processing,
        expectedPickupDate: orderDate,
        subtotal: const Money.fromPiastres(13750),
        total: const Money.fromPiastres(13750),
        createdAt: now,
        updatedAt: now,
      );

      final carpetData = CarpetItemData(
        id: 'c-1',
        orderItemId: 'item-carpet',
        length: 2.0,
        width: 1.375,
        area: 2.75,
        createdAt: now,
        updatedAt: now,
      );

      final carpetItem = OrderItem(
        id: 'item-carpet',
        orderId: 'ord-carpet',
        itemTypeId: 't-carpet',
        serviceId: 's-carpet',
        itemTypeNameSnapshot: 'سجاد',
        serviceNameSnapshot: 'غسيل',
        pricingType: PricingType.perSquareMeter,
        quantity: 1.0,
        unitPrice: const Money.fromPiastres(5000),
        calculatedTotal: const Money.fromPiastres(13750),
        carpetData: carpetData,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: InvoicePreviewDialog(
                order: order,
                items: [carpetItem],
                totalPaid: Money.zero,
                remainingAmount: const Money.fromPiastres(13750),
              ),
            ),
          ),
        ),
      );

      // Area in quantity column
      expect(find.text('2.75 م²'), findsOneWidget);
      // Dimensions sub-text
      expect(find.text('(2 × 1.375 م)'), findsOneWidget);
    });

    testWidgets('displays decimal quantity preserving precision (e.g. 2.75 is never truncated to 2)', (tester) async {
      final order = Order(
        id: 'ord-dec',
        orderNumber: '26-030',
        customerId: 'cust-1',
        customerNameSnapshot: 'خالد',
        customerPhoneSnapshot: '01033333333',
        status: OrderStatus.processing,
        expectedPickupDate: orderDate,
        subtotal: const Money.fromPiastres(10000),
        total: const Money.fromPiastres(10000),
        createdAt: now,
        updatedAt: now,
      );

      final decimalItem = OrderItem(
        id: 'item-dec',
        orderId: 'ord-dec',
        itemTypeId: 't-1',
        serviceId: 's-1',
        itemTypeNameSnapshot: 'قماش',
        serviceNameSnapshot: 'تنظيف',
        pricingType: PricingType.perPiece,
        quantity: 2.75,
        unitPrice: const Money.fromPiastres(10000),
        calculatedTotal: const Money.fromPiastres(10000),
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: InvoicePreviewDialog(
                order: order,
                items: [decimalItem],
                totalPaid: Money.zero,
                remainingAmount: const Money.fromPiastres(10000),
              ),
            ),
          ),
        ),
      );

      expect(find.text('2.75'), findsOneWidget);
      expect(find.text('2'), findsNothing);
    });

    testWidgets('tax row is hidden when tax is zero', (tester) async {
      final order = Order(
        id: 'ord-notax',
        orderNumber: '26-040',
        customerId: 'cust-1',
        customerNameSnapshot: 'سامي',
        customerPhoneSnapshot: '01044444444',
        status: OrderStatus.processing,
        expectedPickupDate: orderDate,
        subtotal: const Money.fromPiastres(5000),
        tax: Money.zero,
        total: const Money.fromPiastres(5000),
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: InvoicePreviewDialog(
                order: order,
                items: const [],
                totalPaid: Money.zero,
                remainingAmount: const Money.fromPiastres(5000),
              ),
            ),
          ),
        ),
      );

      expect(find.text('الضريبة:'), findsNothing);
    });

    testWidgets('tax row is visible when tax is positive', (tester) async {
      final order = Order(
        id: 'ord-tax',
        orderNumber: '26-050',
        customerId: 'cust-1',
        customerNameSnapshot: 'سامي',
        customerPhoneSnapshot: '01044444444',
        status: OrderStatus.processing,
        expectedPickupDate: orderDate,
        subtotal: const Money.fromPiastres(5000),
        tax: const Money.fromPiastres(700), // 7 EGP
        total: const Money.fromPiastres(5700),
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: InvoicePreviewDialog(
                order: order,
                items: const [],
                totalPaid: Money.zero,
                remainingAmount: const Money.fromPiastres(5700),
              ),
            ),
          ),
        ),
      );

      expect(find.text('الضريبة:'), findsOneWidget);
      expect(find.text('+ 7.00 ج.م'), findsOneWidget);
      expect(find.text('5700.00 ج.م'), findsNothing);
      expect(find.text('57.00 ج.م'), findsNWidgets(2)); // total and remaining
    });

    testWidgets('close button dismisses the dialog', (tester) async {
      final order = Order(
        id: 'ord-close',
        orderNumber: '26-060',
        customerId: 'cust-1',
        customerNameSnapshot: 'عميل',
        customerPhoneSnapshot: '01055555555',
        status: OrderStatus.processing,
        expectedPickupDate: orderDate,
        subtotal: const Money.fromPiastres(5000),
        total: const Money.fromPiastres(5000),
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => InvoicePreviewDialog(
                          order: order,
                          items: const [],
                          totalPaid: Money.zero,
                          remainingAmount: const Money.fromPiastres(5000),
                        ),
                      );
                    },
                    child: const Text('افتح'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('افتح'));
      await tester.pumpAndSettle();

      expect(find.byType(InvoicePreviewDialog), findsOneWidget);

      await tester.tap(find.text('إغلاق'));
      await tester.pumpAndSettle();

      expect(find.byType(InvoicePreviewDialog), findsNothing);
    });

    testWidgets('print workflow success: invokes printing and keeps dialog open', (tester) async {
      final order = Order(
        id: 'ord-print-ok',
        orderNumber: '26-070',
        customerId: 'cust-1',
        customerNameSnapshot: 'عميل',
        customerPhoneSnapshot: '01055555555',
        status: OrderStatus.processing,
        expectedPickupDate: orderDate,
        subtotal: const Money.fromPiastres(5000),
        total: const Money.fromPiastres(5000),
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: InvoicePreviewDialog(
                order: order,
                items: const [],
                totalPaid: Money.zero,
                remainingAmount: const Money.fromPiastres(5000),
              ),
            ),
          ),
        ),
      );

      expect(find.text('طباعة الفاتورة'), findsOneWidget);

      // Tap print button
      await tester.tap(find.text('طباعة الفاتورة'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(mockPlatform.callCount, 1);
      expect(mockPlatform.receivedFormat, PdfPageFormat.roll80);
      expect(mockPlatform.receivedDynamicLayout, isFalse);

      // Dialog must remain open
      expect(find.byType(InvoicePreviewDialog), findsOneWidget);
      expect(find.text('طباعة الفاتورة'), findsOneWidget);
      // No error SnackBar
      expect(find.text('تعذر بدء عملية الطباعة. حاول مرة أخرى.'), findsNothing);
    });

    testWidgets('print workflow duplicate taps are prevented while busy', (tester) async {
      mockPlatform.delay = const Duration(milliseconds: 200);

      final order = Order(
        id: 'ord-print-dup',
        orderNumber: '26-071',
        customerId: 'cust-1',
        customerNameSnapshot: 'عميل',
        customerPhoneSnapshot: '01055555555',
        status: OrderStatus.processing,
        expectedPickupDate: orderDate,
        subtotal: const Money.fromPiastres(5000),
        total: const Money.fromPiastres(5000),
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: InvoicePreviewDialog(
                order: order,
                items: const [],
                totalPaid: Money.zero,
                remainingAmount: const Money.fromPiastres(5000),
              ),
            ),
          ),
        ),
      );

      // First tap starts printing
      await tester.tap(find.text('طباعة الفاتورة'));
      await tester.pump(); // enters busy state

      // Second tap while busy (button disabled / busy flag active)
      await tester.tap(find.byType(ElevatedButton).last, warnIfMissed: false);
      await tester.pump();

      // Complete async delay
      await tester.pump(const Duration(milliseconds: 250));

      // Should only have called layoutPdf once
      expect(mockPlatform.callCount, 1);
    });

    testWidgets('print workflow handles platform exception with Arabic SnackBar and keeps dialog open', (tester) async {
      mockPlatform.shouldThrow = true;

      final order = Order(
        id: 'ord-print-err',
        orderNumber: '26-072',
        customerId: 'cust-1',
        customerNameSnapshot: 'عميل',
        customerPhoneSnapshot: '01055555555',
        status: OrderStatus.processing,
        expectedPickupDate: orderDate,
        subtotal: const Money.fromPiastres(5000),
        total: const Money.fromPiastres(5000),
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: InvoicePreviewDialog(
                order: order,
                items: const [],
                totalPaid: Money.zero,
                remainingAmount: const Money.fromPiastres(5000),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('طباعة الفاتورة'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Error SnackBar shown
      expect(find.text('تعذر بدء عملية الطباعة. حاول مرة أخرى.'), findsOneWidget);

      // Dialog must remain open
      expect(find.byType(InvoicePreviewDialog), findsOneWidget);
      expect(find.text('طباعة الفاتورة'), findsOneWidget);
    });

    testWidgets('uses fallback footer when invoiceFooterText is empty or whitespace', (tester) async {
      final order = Order(
        id: 'ord-footer',
        orderNumber: '26-080',
        customerId: 'cust-1',
        customerNameSnapshot: 'عميل',
        customerPhoneSnapshot: '01055555555',
        status: OrderStatus.processing,
        expectedPickupDate: orderDate,
        subtotal: const Money.fromPiastres(5000),
        total: const Money.fromPiastres(5000),
        createdAt: now,
        updatedAt: now,
      );

      final settingsWithWhitespaceFooter = BusinessSettings(
        id: 'settings-2',
        businessName: 'مغسلة النقاء',
        invoiceFooterText: '   ',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: InvoicePreviewDialog(
                order: order,
                items: const [],
                totalPaid: Money.zero,
                remainingAmount: const Money.fromPiastres(5000),
                settings: settingsWithWhitespaceFooter,
              ),
            ),
          ),
        ),
      );

      // Must fall back to default footer
      expect(find.text('شكراً لتعاملكم معنا!'), findsOneWidget);
    });
  });
}
