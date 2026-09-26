import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/theme/app_colors.dart';
import 'package:laundry_management/domain/entities/expense.dart';
import 'package:laundry_management/domain/entities/expense_category_breakdown_item.dart';
import 'package:laundry_management/domain/entities/financial_report_data.dart';
import 'package:laundry_management/domain/entities/outstanding_order_summary.dart';
import 'package:laundry_management/domain/entities/payment_method_breakdown_item.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/enums/payment_method.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';
import 'package:laundry_management/features/reports/presentation/widgets/financial_report_view.dart';

void main() {
  group('Finding 6 — Financial Report UX Hierarchy Tests', () {
    final now = DateTime.now();

    final testData = FinancialReportData(
      totalSales: const Money.fromPiastres(603000), // 6030.00 ج.م
      totalPayments: const Money.fromPiastres(603000), // 6030.00 ج.م
      totalRefunds: const Money.fromPiastres(189700), // 1897.00 ج.م
      netPayments: const Money.fromPiastres(413300), // 4133.00 ج.م
      totalOperatingExpenses: const Money.fromPiastres(150000), // 1500.00 ج.م
      netProfit: const Money.fromPiastres(453000), // 4530.00 ج.م
      outstandingAmount: const Money.fromPiastres(45000), // 450.00 ج.م
      totalDiscounts: const Money.fromPiastres(20000), // 200.00 ج.م
      paymentMethodsBreakdown: [
        const PaymentMethodBreakdownItem(
          method: PaymentMethod.cash,
          totalAmount: Money.fromPiastres(603000),
          count: 10,
          percentage: 100.0,
        ),
      ],
      expenseCategoriesBreakdown: [
        const ExpenseCategoryBreakdownItem(
          categoryName: 'منظفات',
          totalAmount: Money.fromPiastres(150000),
          count: 5,
          percentage: 100.0,
        ),
      ],
      outstandingOrders: [
        OutstandingOrderSummary(
          orderId: 'ord-1',
          orderNumber: '26-9993240',
          createdAt: now,
          customerName: 'عميل تجريبي',
          customerPhone: '01011112222',
          totalAmount: const Money.fromPiastres(10000),
          paidAmount: const Money.fromPiastres(5500),
          remainingAmount: const Money.fromPiastres(4500),
        ),
      ],
      expenseTransactions: [
        Expense(
          id: 'exp-1',
          expenseCategoryId: 'cat-1',
          categoryNameSnapshot: 'منظفات',
          expenseName: 'شراء مسحوق غسيل',
          notes: 'فاتورة رقم 102',
          amount: const Money.fromPiastres(150000),
          expenseDate: OrderDate(now.year, now.month, now.day),
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    test('Financial formulas verification: Net Payments & Net Profit', () {
      // Net Payments = Payments - Refunds (6030 - 1897 = 4133 EGP)
      expect(testData.netPayments, const Money.fromPiastres(413300));
      expect(testData.netPayments.toEgp, 4133.0);

      // Net Profit = Sales - Expenses (6030 - 1500 = 4530 EGP)
      expect(testData.netProfit, const Money.fromPiastres(453000));
      expect(testData.netProfit.toEgp, 4530.0);
    });

    test('Important Financial Example: Cancelled order Total=115, Paid=35, Refunded=35', () {
      // Model the lifecycle contribution of the cancelled order:
      // Sales contribution = 0
      // Payments contribution = +35
      // Refunds contribution = +35
      // Net Payments contribution = 35 - 35 = 0
      // Outstanding contribution = 0
      // Net Profit contribution = 0
      const cancelledTotal = Money.fromPiastres(11500);
      const cancelledPaid = Money.fromPiastres(3500);
      const cancelledRefunded = Money.fromPiastres(3500);
      final status = OrderStatus.cancelled;
      final isCancelled = status == OrderStatus.cancelled;

      final salesContribution = isCancelled ? Money.zero : cancelledTotal;
      final paymentsContribution = cancelledPaid;
      final refundsContribution = cancelledRefunded;
      final netPaymentsContribution = paymentsContribution - refundsContribution;
      final outstandingContribution = isCancelled ? Money.zero : (cancelledTotal - cancelledPaid);

      expect(salesContribution, Money.zero);
      expect(paymentsContribution, const Money.fromPiastres(3500));
      expect(refundsContribution, const Money.fromPiastres(3500));
      expect(netPaymentsContribution, Money.zero);
      expect(outstandingContribution, Money.zero);
    });

    testWidgets('FinancialReportView renders Section 1 with 4 primary metrics', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SingleChildScrollView(
                child: FinancialReportView(
                  data: testData,
                  onRefresh: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Section 1 Header
      expect(find.text('أهم المؤشرات'), findsOneWidget);

      // The 4 Primary Metrics
      expect(find.text('إجمالي المبيعات'), findsOneWidget);
      expect(find.text('صافي المدفوعات'), findsWidgets); // Found in Section 1 and Section 2
      expect(find.text('المصروفات التشغيلية'), findsOneWidget);
      expect(find.text('صافي الربح'), findsOneWidget);

      // Primary Metric Subtitles
      expect(find.text('قيمة الطلبات غير الملغاة خلال الفترة'), findsOneWidget);
      expect(find.text('المبيعات − المصروفات التشغيلية'), findsOneWidget);
    });

    testWidgets('FinancialReportView renders Section 2 (حركة المدفوعات) with grouped formula block', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SingleChildScrollView(
                child: FinancialReportView(
                  data: testData,
                  onRefresh: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Section 2 Grouped Header
      expect(find.text('حركة المدفوعات'), findsOneWidget);

      // Elements within Payment Movement block
      expect(find.text('إجمالي المدفوعات'), findsOneWidget);
      expect(find.text('جميع المدفوعات المسجلة خلال الفترة'), findsOneWidget);
      expect(find.text('طرح الاستردادات'), findsOneWidget);
      expect(find.text('إجمالي الاستردادات'), findsOneWidget);
      expect(find.text('مبالغ تم ردها للعملاء خلال الفترة'), findsOneWidget);
      expect(find.text('المدفوعات − الاستردادات'), findsWidgets);
    });

    testWidgets('FinancialReportView renders Section 3 (التحصيل) with lifecycle explanation subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SingleChildScrollView(
                child: FinancialReportView(
                  data: testData,
                  onRefresh: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Section 3 Header & Outstanding Card
      expect(find.text('التحصيل والخصومات'), findsOneWidget);
      expect(find.text('المبالغ المستحقة'), findsOneWidget);
      expect(find.text('المبالغ المتبقية على الطلبات غير الملغاة'), findsOneWidget);
      expect(find.text('إجمالي الخصومات'), findsOneWidget);
      expect(find.text('الخصومات الممنوحة على الطلبات خلال الفترة'), findsOneWidget);
    });

    testWidgets('FinancialReportView renders Section 4 (تفاصيل إضافية) secondary breakdowns', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SingleChildScrollView(
                child: FinancialReportView(
                  data: testData,
                  onRefresh: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Section 4: Secondary Breakdowns
      expect(find.text('طرق الدفع'), findsOneWidget);
      expect(find.text('المصروفات حسب التصنيف'), findsOneWidget);

      // Section 5: سجل المصروفات (Expense History) & Section 6: طلبات عليها مبالغ متبقية (Outstanding Orders)
      expect(find.text('سجل المصروفات'), findsOneWidget);
      expect(find.text('طلبات عليها مبالغ متبقية'), findsOneWidget);

      // Section 5 (سجل المصروفات) MUST appear BEFORE Section 6 (طلبات عليها مبالغ متبقية)
      final expensePos = tester.getTopLeft(find.text('سجل المصروفات')).dy;
      final outstandingPos =
          tester.getTopLeft(find.text('طلبات عليها مبالغ متبقية')).dy;
      expect(expensePos, lessThan(outstandingPos));

      // Order number rendered with # and LTR
      expect(find.text('#26-9993240'), findsOneWidget);
      final orderText = tester.widget<Text>(find.text('#26-9993240'));
      expect(orderText.textDirection, TextDirection.ltr);

      // Outstanding remaining amount in Section 6 uses warning/amber styling
      final remainingFinder = find.text('45.00 ج.م');
      expect(remainingFinder, findsOneWidget);
      final remainingWidget = tester.widget<Text>(remainingFinder);
      expect(remainingWidget.style?.color, AppColors.warning);
    });

    testWidgets(
      'Outstanding Orders table layout preserves readability of remaining amount with long customer names and large values',
      (tester) async {
        final now = DateTime.now();
        final layoutTestData = FinancialReportData(
          totalSales: const Money.fromPiastres(250000000),
          totalPayments: const Money.fromPiastres(150000000),
          totalRefunds: Money.zero,
          netPayments: const Money.fromPiastres(150000000),
          totalOperatingExpenses: Money.zero,
          netProfit: const Money.fromPiastres(250000000),
          outstandingAmount: const Money.fromPiastres(100000000),
          totalDiscounts: Money.zero,
          paymentMethodsBreakdown: const [],
          expenseCategoriesBreakdown: const [],
          outstandingOrders: [
            OutstandingOrderSummary(
              orderId: 'ord-long',
              orderNumber: 'ORD-EXTENDED-LONG-NUMBER-2026-9993240',
              createdAt: now,
              customerName:
                  'عبد الرحمن محمد عبد السلام الشناوي الدسوقي إبراهيم أحمد حسن',
              customerPhone: '01011112222',
              totalAmount: const Money.fromPiastres(150000000), // 1,500,000.00 EGP
              paidAmount: const Money.fromPiastres(51235000), // 512,350.00 EGP
              remainingAmount:
                  const Money.fromPiastres(98765000), // 987,650.00 EGP
            ),
            OutstandingOrderSummary(
              orderId: 'ord-short',
              orderNumber: '26-101',
              createdAt: now,
              customerName: 'علي',
              customerPhone: '01011112222',
              totalAmount: const Money.fromPiastres(24000),
              paidAmount: const Money.fromPiastres(10000),
              remainingAmount: const Money.fromPiastres(14000),
            ),
          ],
          expenseTransactions: const [],
        );

        // Tablet viewport (1000x800)
        tester.view.physicalSize = const Size(1000, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: SingleChildScrollView(
                  child: FinancialReportView(
                    data: layoutTestData,
                    onRefresh: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Order numbers are rendered
        expect(
          find.text('#ORD-EXTENDED-LONG-NUMBER-2026-9993240'),
          findsOneWidget,
        );
        expect(find.text('#26-101'), findsOneWidget);

        // 2. Remaining amounts are rendered
        final largeRemainingFinder = find.text('987650.00 ج.م');
        final shortRemainingFinder = find.text('140.00 ج.م');
        expect(largeRemainingFinder, findsOneWidget);
        expect(shortRemainingFinder, findsOneWidget);

        // 3. Verify horizontal positions: remaining column is at the left, order number at the right
        final largeRemainingRect = tester.getRect(largeRemainingFinder);
        final orderRect = tester.getRect(
          find.text('#ORD-EXTENDED-LONG-NUMBER-2026-9993240'),
        );
        expect(largeRemainingRect.left, greaterThanOrEqualTo(0.0));
        expect(orderRect.right, lessThanOrEqualTo(1000.0));
        expect(orderRect.left, greaterThan(largeRemainingRect.right));

        // 4. Verify customer name text has ellipsis overflow
        final customerFinder = find.text(
          'عبد الرحمن محمد عبد السلام الشناوي الدسوقي إبراهيم أحمد حسن',
        );
        expect(customerFinder, findsOneWidget);
        final customerWidget = tester.widget<Text>(customerFinder);
        expect(customerWidget.overflow, TextOverflow.ellipsis);
        expect(customerWidget.maxLines, 1);

        // 5. Verify remaining text styling
        final largeRemainingWidget = tester.widget<Text>(largeRemainingFinder);
        expect(largeRemainingWidget.style?.color, AppColors.warning);
        expect(largeRemainingWidget.style?.fontWeight, FontWeight.bold);
        expect(largeRemainingWidget.maxLines, 1);
        expect(largeRemainingWidget.softWrap, false);
      },
    );
  });
}
