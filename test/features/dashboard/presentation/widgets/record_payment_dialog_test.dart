import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_payment_summary.dart';
import 'package:laundry_management/domain/entities/payment.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/enums/payment_method.dart';
import 'package:laundry_management/domain/repositories/order_repository.dart';
import 'package:laundry_management/domain/repositories/payment_repository.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';
import 'package:laundry_management/features/dashboard/presentation/cubit/record_payment_cubit.dart';
import 'package:laundry_management/features/dashboard/presentation/widgets/record_payment_dialog.dart';

class MockOrderRepository implements OrderRepository {
  List<Order> ordersToReturn = [];
  String? lastQuery;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<Order>> getOrders({
    OrderStatus? status,
    OrderDate? expectedPickupDate,
    String? customerId,
    bool? hasRemaining,
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    lastQuery = query;
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim();
      return ordersToReturn.where((o) =>
        o.orderNumber.contains(q) ||
        o.customerNameSnapshot.contains(q) ||
        o.customerPhoneSnapshot.contains(q)
      ).toList();
    }
    return ordersToReturn;
  }
}

class MockPaymentRepository implements PaymentRepository {
  Payment? recordedPayment;
  Map<String, OrderPaymentSummary> summariesToReturn = {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Payment> recordPayment(Payment payment) async {
    recordedPayment = payment;
    return payment;
  }

  @override
  Future<Map<String, OrderPaymentSummary>> getPaymentSummariesForOrders(List<String> orderIds) async {
    return summariesToReturn;
  }
}

void main() {
  late MockOrderRepository orderRepo;
  late MockPaymentRepository paymentRepo;
  late RecordPaymentCubit cubit;

  final now = DateTime(2026, 9, 12);
  final testOrder = Order(
    id: 'ord-1',
    orderNumber: '26-001',
    customerId: 'cust-1',
    customerNameSnapshot: 'أحمد محمود',
    customerPhoneSnapshot: '01012345678',
    status: OrderStatus.processing,
    expectedPickupDate: OrderDate(2026, 9, 15),
    subtotal: const Money.fromPiastres(10000),
    total: const Money.fromPiastres(10000),
    createdAt: now,
    updatedAt: now,
  );

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      locale: const Locale('ar'),
      home: Scaffold(
        body: child,
      ),
    );
  }

  setUp(() {
    orderRepo = MockOrderRepository();
    paymentRepo = MockPaymentRepository();
    orderRepo.ordersToReturn = [testOrder];
    paymentRepo.summariesToReturn = {
      'ord-1': const OrderPaymentSummary(
        totalPaid: Money.fromPiastres(4000),
        remaining: Money.fromPiastres(6000),
      ),
    };
    cubit = RecordPaymentCubit(
      orderRepository: orderRepo,
      paymentRepository: paymentRepo,
    );
  });

  tearDown(() {
    cubit.close();
  });

  testWidgets('RecordPaymentDialog renders Step 1 (search & order list) and allows selecting an order', (tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        RecordPaymentDialog(cubit: cubit),
      ),
    );
    await tester.pumpAndSettle();

    // Step 1 title & search field with phone support placeholder
    expect(find.text('تسجيل دفعة'), findsOneWidget);
    expect(find.text('ابحث برقم الطلب أو اسم العميل أو رقم الهاتف'), findsOneWidget);
    expect(find.byKey(const ValueKey('payment_order_search_field')), findsOneWidget);

    // Order item is visible with # prefix, customer name, and remaining balance
    expect(find.text('#26-001'), findsOneWidget);
    expect(find.text('أحمد محمود'), findsOneWidget);
    expect(find.text('المتبقي'), findsOneWidget);
    expect(find.text('60.00 ج.م'), findsOneWidget);

    // Cancel text button exists
    expect(find.text('إلغاء'), findsOneWidget);

    // Tap order to proceed to Step 2
    await tester.tap(find.byKey(const ValueKey('payment_order_item_ord-1')));
    await tester.pumpAndSettle();

    // Step 2 elements
    expect(find.text('فتح الطلب'), findsOneWidget);
    expect(find.text('المتبقي: 60.00 ج.م'), findsOneWidget);
    // Amount starts at 0.00
    final amountField = tester.widget<TextField>(find.descendant(
      of: find.byKey(const ValueKey('record_payment_amount_field')),
      matching: find.byType(TextField),
    ));
    expect(amountField.controller?.text, '0.00');
    expect(find.text('المبلغ كامل'), findsOneWidget);
    expect(find.text('طريقة الدفع *'), findsOneWidget);
    expect(find.text('كاش'), findsOneWidget);
    expect(find.text('InstaPay'), findsOneWidget);
    expect(find.text('محفظة إلكترونية'), findsOneWidget);
    expect(find.text('اختيار طلب آخر'), findsOneWidget);
    expect(find.text('تأكيد الدفع'), findsOneWidget);
  });

  testWidgets('Step 2: "اختيار طلب آخر" navigates back to Step 1', (tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        RecordPaymentDialog(cubit: cubit),
      ),
    );
    await tester.pumpAndSettle();

    // Select order
    await tester.tap(find.byKey(const ValueKey('payment_order_item_ord-1')));
    await tester.pumpAndSettle();

    expect(find.text('اختيار طلب آخر'), findsOneWidget);

    // Tap back button
    await tester.tap(find.byKey(const ValueKey('record_payment_back_button')));
    await tester.pumpAndSettle();

    // Back to Step 1
    expect(find.byKey(const ValueKey('payment_order_search_field')), findsOneWidget);
    expect(find.byKey(const ValueKey('payment_order_item_ord-1')), findsOneWidget);
  });

  testWidgets('Step 2: "المبلغ كامل" fills remaining balance, switches method, and confirms payment', (tester) async {
    bool paymentSuccessCalled = false;

    await tester.pumpWidget(
      buildTestableWidget(
        RecordPaymentDialog(
          cubit: cubit,
          onPaymentSuccess: () => paymentSuccessCalled = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Select order
    await tester.tap(find.byKey(const ValueKey('payment_order_item_ord-1')));
    await tester.pumpAndSettle();

    // Tap "المبلغ كامل"
    await tester.tap(find.byKey(const ValueKey('record_payment_full_amount_button')));
    await tester.pumpAndSettle();

    final filledAmountField = tester.widget<TextField>(find.descendant(
      of: find.byKey(const ValueKey('record_payment_amount_field')),
      matching: find.byType(TextField),
    ));
    expect(filledAmountField.controller?.text, '60.00');

    // Select E-wallet method
    await tester.tap(find.byKey(const ValueKey('payment_method_ewallet')));
    await tester.pumpAndSettle();

    // Confirm Payment
    await tester.tap(find.byKey(const ValueKey('record_payment_confirm_button')));
    await tester.pumpAndSettle();

    expect(paymentSuccessCalled, isTrue);
    expect(paymentRepo.recordedPayment, isNotNull);
    expect(paymentRepo.recordedPayment?.amount, const Money.fromPiastres(6000));
    expect(paymentRepo.recordedPayment?.paymentMethod, PaymentMethod.ewallet);
  });

  testWidgets('Step 1: debounced live search filters orders or shows empty state', (tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        RecordPaymentDialog(cubit: cubit),
      ),
    );
    await tester.pumpAndSettle();

    // Enter search that does not match
    await tester.enterText(find.byKey(const ValueKey('payment_order_search_field')), 'غير موجود');
    // Wait for 250ms debounce
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('لا توجد طلبات مطابقة للبحث'), findsOneWidget);
    expect(find.byKey(const ValueKey('payment_order_item_ord-1')), findsNothing);
  });
}
