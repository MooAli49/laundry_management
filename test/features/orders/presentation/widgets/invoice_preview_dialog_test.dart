import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/domain/entities/business_settings.dart';
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';
import 'package:laundry_management/features/orders/presentation/widgets/invoice_preview_dialog.dart';

void main() {
  group('InvoicePreviewDialog Tests', () {
    testWidgets('renders business header, customer info, item table and totals', (tester) async {
      final now = DateTime(2026, 9, 5);
      final order = Order(
        id: 'ord-1',
        orderNumber: '26-001',
        customerId: 'cust-1',
        status: OrderStatus.ready,
        expectedPickupDate: OrderDate(2026, 9, 12),
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
    });
  });
}
