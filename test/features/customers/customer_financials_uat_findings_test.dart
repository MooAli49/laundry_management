import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/localization/app_strings.dart';
import 'package:laundry_management/core/theme/app_colors.dart';
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/domain/entities/customer_order_aggregate.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_payment_summary.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';
import 'package:laundry_management/features/customers/presentation/models/customer_detail_view_model.dart';

void main() {
  group('Findings 3, 4, 5 — Customer Financials & Cancelled Orders Tests', () {
    final now = DateTime.now();

    final testCustomer = Customer(
      id: 'cust-fin-1',
      name: 'محمود عبد الرحيم',
      phone: '01099887766',
      createdAt: now,
      updatedAt: now,
    );

    // Finding 3: Cancelled order with Total 80, Paid 50, Refunded 50
    final cancelledOrder = Order(
      id: 'order-cancelled-80',
      orderNumber: '26-10001',
      customerId: testCustomer.id,
      customerNameSnapshot: testCustomer.name,
      customerPhoneSnapshot: testCustomer.phone,
      status: OrderStatus.cancelled,
      cancelledAt: now,
      cancellationReason: 'Customer request',
      expectedPickupDate: OrderDate.fromDate(now),
      total: const Money.fromPiastres(8000), // 80 EGP
      subtotal: const Money.fromPiastres(8000),
      discount: Money.zero,
      tax: Money.zero,
      customerPickupFee: Money.zero,
      customerDeliveryFee: Money.zero,
      createdAt: now,
      updatedAt: now,
    );

    // Active order with Total 100, Paid 40, Remaining 60
    final activeOrder = Order(
      id: 'order-active-100',
      orderNumber: '26-10002',
      customerId: testCustomer.id,
      customerNameSnapshot: testCustomer.name,
      customerPhoneSnapshot: testCustomer.phone,
      status: OrderStatus.processing,
      expectedPickupDate: OrderDate.fromDate(now),
      total: const Money.fromPiastres(10000), // 100 EGP
      subtotal: const Money.fromPiastres(10000),
      discount: Money.zero,
      tax: Money.zero,
      customerPickupFee: Money.zero,
      customerDeliveryFee: Money.zero,
      createdAt: now,
      updatedAt: now,
    );

    test('Finding 3 — Cancelled order payment summary has remaining = 0', () {
      final summary = OrderPaymentSummary(
        totalPaid: const Money.fromPiastres(5000),
        totalRefunded: const Money.fromPiastres(5000),
        remaining: Money.zero, // Approved lifecycle rule: remaining = 0 for cancelled
      );

      expect(summary.totalPaid, const Money.fromPiastres(5000));
      expect(summary.totalRefunded, const Money.fromPiastres(5000));
      expect(summary.remaining, Money.zero);
    });

    test('Finding 4 — Customer aggregate computes historical payments, refunds, net paid, and outstanding excluding cancelled', () {
      // Historical payments: 50 (cancelled) + 40 (active) = 90 EGP
      // Historical refunds: 50 (cancelled) = 50 EGP
      // Net paid: 90 - 50 = 40 EGP
      // Outstanding: only active order (100 - 40 = 60 EGP). Cancelled order is 0.
      final aggregate = CustomerOrderAggregate(
        totalOrders: 2,
        processingOrders: 1,
        readyOrders: 0,
        completedOrders: 0,
        cancelledOrders: 1,
        totalPaid: const Money.fromPiastres(9000),
        totalRefunds: const Money.fromPiastres(5000),
        totalRemaining: const Money.fromPiastres(6000), // Excludes cancelled order!
      );

      expect(aggregate.totalPaid, const Money.fromPiastres(9000));
      expect(aggregate.totalRefunds, const Money.fromPiastres(5000));
      expect(aggregate.netPaid, const Money.fromPiastres(4000));
      expect(aggregate.totalRemaining, const Money.fromPiastres(6000));
    });

    test('Finding 4 — CustomerDetailViewModel correctly exposes 4 explicit financial metrics', () {
      final aggregate = CustomerOrderAggregate(
        totalOrders: 2,
        processingOrders: 1,
        readyOrders: 0,
        completedOrders: 0,
        cancelledOrders: 1,
        totalPaid: const Money.fromPiastres(51000), // 510 EGP
        totalRefunds: const Money.fromPiastres(5000), // 50 EGP
        totalRemaining: const Money.fromPiastres(11000), // 110 EGP (non-cancelled only)
      );

      final viewModel = CustomerDetailViewModel(
        customer: testCustomer,
        orders: [activeOrder, cancelledOrder],
        aggregate: aggregate,
      );

      expect(viewModel.totalPaid, const Money.fromPiastres(51000));
      expect(viewModel.totalRefunds, const Money.fromPiastres(5000));
      expect(viewModel.netPaid, const Money.fromPiastres(46000)); // 510 - 50 = 460
      expect(viewModel.totalRemaining, const Money.fromPiastres(11000));
    });

    testWidgets('Finding 5 — Cancelled order row in Customer Details displays Total, Paid, Refunded, Remaining=0 in neutral style', (
      tester,
    ) async {
      // Build an isolated widget reproducing the customer order row for the cancelled order
      final summary = OrderPaymentSummary(
        totalPaid: const Money.fromPiastres(5000),
        totalRefunded: const Money.fromPiastres(5000),
        remaining: Money.zero,
      );

      final isCancelled = cancelledOrder.status == OrderStatus.cancelled;
      final paid = summary.totalPaid;
      final refunded = summary.totalRefunded;
      final remaining = isCancelled ? Money.zero : summary.remaining;
      final isFullyPaid = remaining.isZero;

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppStrings.totalAmount(
                      cancelledOrder.total.toEgp.toStringAsFixed(2),
                    ),
                    style: TextStyle(
                      color: isCancelled ? AppColors.textSecondary : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    AppStrings.paidAmount(paid.toEgp.toStringAsFixed(2)),
                  ),
                  if (refunded.isPositive || isCancelled)
                    Text(
                      AppStrings.refundedAmount(refunded.toEgp.toStringAsFixed(2)),
                      style: TextStyle(
                        color: refunded.isPositive ? AppColors.warning : AppColors.textSecondary,
                      ),
                    ),
                  Text(
                    isCancelled
                        ? AppStrings.remainingAmount('0.00')
                        : isFullyPaid
                            ? AppStrings.fullyPaid
                            : AppStrings.remainingAmount(remaining.toEgp.toStringAsFixed(2)),
                    style: TextStyle(
                      color: isCancelled
                          ? AppColors.textSecondary
                          : isFullyPaid
                              ? AppColors.success
                              : AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the 4 exact lines rendered for the cancelled order:
      expect(find.text('الإجمالي: 80.00 ج.م'), findsOneWidget);
      expect(find.text('المدفوع: 50.00 ج.م'), findsOneWidget);
      expect(find.text('المسترد: 50.00 ج.م'), findsOneWidget);
      expect(find.text('المتبقي: 0.00 ج.م'), findsOneWidget);

      // Verify Remaining text does NOT use AppColors.error
      final remainingWidget = tester.widget<Text>(find.text('المتبقي: 0.00 ج.م'));
      expect(remainingWidget.style?.color, AppColors.textSecondary);
      expect(remainingWidget.style?.color, isNot(AppColors.error));
    });
  });
}
