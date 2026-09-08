import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/di/injection.dart';
import 'package:laundry_management/core/theme/app_theme.dart';
import 'package:laundry_management/data/local/database/app_database.dart' as db_pkg;
import 'package:laundry_management/data/local/database/dev_test_data.dart';
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/repositories/customer_repository.dart';
import 'package:laundry_management/domain/repositories/order_repository.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';
import 'package:laundry_management/features/customers/presentation/screens/customer_detail_screen.dart';
import 'package:laundry_management/features/customers/presentation/widgets/customer_form_dialog.dart';

Widget testBoilerplate(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: child,
    ),
  );
}

void main() {
  setUp(() async {
    await getIt.reset();
    getIt.registerLazySingleton<db_pkg.AppDatabase>(
      () => db_pkg.AppDatabase(NativeDatabase.memory()),
    );
    await initDependencies();
    await DevTestData.seedDevData(getIt<db_pkg.AppDatabase>());
  });

  tearDown(() async {
    if (getIt.isRegistered<db_pkg.AppDatabase>()) {
      await getIt<db_pkg.AppDatabase>().close();
    }
    await getIt.reset();
  });

  group('CustomerDetailScreen Tests', () {
    testWidgets('renders customer details, KPI cards, and empty order state', (tester) async {
      final repo = getIt<CustomerRepository>();
      final now = DateTime.now();
      final customer = await repo.createCustomer(
        Customer(
          id: 'c-test-1',
          name: 'ياسر عرفات',
          phone: '01012345678',
          notes: 'ملاحظة تجريبية للعميل',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await tester.pumpWidget(testBoilerplate(
        CustomerDetailScreen(customerId: customer.id),
      ));
      await tester.pumpAndSettle();

      expect(find.text('ياسر عرفات'), findsOneWidget);
      expect(find.text('01012345678'), findsOneWidget);
      expect(find.text('ملاحظة تجريبية للعميل'), findsOneWidget);

      // KPI Cards (5 metrics)
      expect(find.text('إجمالي الطلبات'), findsOneWidget);
      expect(find.text('طلبات جارية'), findsOneWidget);
      expect(find.text('طلبات مكتملة'), findsOneWidget);
      expect(find.text('إجمالي المدفوع'), findsOneWidget);
      expect(find.text('إجمالي المتبقي'), findsOneWidget);

      // Empty Order State
      expect(find.text('لا توجد طلبات لهذا العميل'), findsOneWidget);

      // Actions
      expect(find.text('تعديل العميل'), findsOneWidget);
      expect(find.text('إنشاء طلب'), findsNWidgets(2)); // Header action + empty state action
    });

    testWidgets('renders order cards with status badges and totals', (tester) async {
      final custRepo = getIt<CustomerRepository>();
      final orderRepo = getIt<OrderRepository>();
      final db = getIt<db_pkg.AppDatabase>();
      final now = DateTime.now();

      final customer = await custRepo.createCustomer(
        Customer(
          id: 'c-test-2',
          name: 'عماد الدين',
          phone: '01055554444',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final itemTypes = await db.select(db.itemTypes).get();
      final services = await db.select(db.services).get();

      final order = Order(
        id: 'ord-test-2',
        orderNumber: '26-777',
        customerId: customer.id,
        customerNameSnapshot: customer.name,
        customerPhoneSnapshot: customer.phone,
        status: OrderStatus.processing,
        expectedPickupDate: OrderDate.fromDate(now.add(const Duration(days: 4))),
        subtotal: const Money.fromPiastres(12000),
        discount: Money.zero,
        tax: Money.zero,
        total: const Money.fromPiastres(12000),
        createdAt: now,
        updatedAt: now,
      );

      final item = OrderItem(
        id: 'item-test-2',
        orderId: order.id,
        itemTypeId: itemTypes.first.id,
        serviceId: services.first.id,
        itemTypeNameSnapshot: itemTypes.first.name,
        serviceNameSnapshot: services.first.name,
        pricingType: PricingType.fixedPrice,
        quantity: 1,
        unitPrice: const Money.fromPiastres(12000),
        calculatedTotal: const Money.fromPiastres(12000),
        createdAt: now,
        updatedAt: now,
      );

      await orderRepo.createOrder(order: order, items: [item]);

      await tester.pumpWidget(testBoilerplate(
        CustomerDetailScreen(customerId: customer.id),
      ));
      await tester.pumpAndSettle();

      expect(find.text('26-777'), findsOneWidget);
      expect(find.text('قيد التجهيز'), findsOneWidget);
      expect(find.text('120.00 ج.م'), findsNWidgets(2)); // Order total and KPI remaining total
      expect(find.text('المدفوع: 0.00 ج.م'), findsOneWidget);
      expect(find.text('المتبقي: 120.00 ج.م'), findsOneWidget);
    });

    testWidgets('tapping edit customer opens CustomerFormDialog', (tester) async {
      final custRepo = getIt<CustomerRepository>();
      final now = DateTime.now();

      final customer = await custRepo.createCustomer(
        Customer(
          id: 'c-test-3',
          name: 'خالد سليم',
          phone: '01066667777',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await tester.pumpWidget(testBoilerplate(
        CustomerDetailScreen(customerId: customer.id),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('تعديل العميل'));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerFormDialog), findsOneWidget);
      expect(find.text('تعديل بيانات العميل'), findsOneWidget);
    });

    testWidgets('editing customer displays success snackbar exactly once and not duplicate', (tester) async {
      final custRepo = getIt<CustomerRepository>();
      final now = DateTime.now();

      final customer = await custRepo.createCustomer(
        Customer(
          id: 'c-test-snack',
          name: 'سمير غانم',
          phone: '01011112222',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await tester.pumpWidget(testBoilerplate(
        CustomerDetailScreen(customerId: customer.id),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('تعديل العميل'));
      await tester.pumpAndSettle();

      // Enter new name and save
      final nameField = find.widgetWithText(TextField, 'سمير غانم');
      await tester.enterText(nameField, 'سمير غانم المعدل');
      await tester.pump();

      await tester.tap(find.text('حفظ التعديلات'));
      await tester.pumpAndSettle();

      // Ensure success snackbar appears exactly ONCE
      expect(find.text('تم تحديث بيانات العميل بنجاح'), findsOneWidget);
    });

    testWidgets('displays load-more button when customer has more than 20 orders', (tester) async {
      final custRepo = getIt<CustomerRepository>();
      final orderRepo = getIt<OrderRepository>();
      final db = getIt<db_pkg.AppDatabase>();
      final now = DateTime.now();

      final customer = await custRepo.createCustomer(
        Customer(
          id: 'c-test-paginated',
          name: 'عميل الصفحات',
          phone: '01099998888',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final itemTypes = await db.select(db.itemTypes).get();
      final services = await db.select(db.services).get();

      // Create 22 orders
      for (var i = 0; i < 22; i++) {
        final order = Order(
          id: 'ord-page-$i',
          orderNumber: '26-${(500 + i).toString()}',
          customerId: customer.id,
          customerNameSnapshot: customer.name,
          customerPhoneSnapshot: customer.phone,
          status: OrderStatus.processing,
          expectedPickupDate: OrderDate.fromDate(now.add(const Duration(days: 2))),
          subtotal: const Money.fromPiastres(1000),
          discount: Money.zero,
          tax: Money.zero,
          total: const Money.fromPiastres(1000),
          createdAt: now.subtract(Duration(minutes: 25 - i)),
          updatedAt: now,
        );
        final item = OrderItem(
          id: 'itm-page-$i',
          orderId: order.id,
          itemTypeId: itemTypes.first.id,
          serviceId: services.first.id,
          itemTypeNameSnapshot: itemTypes.first.name,
          serviceNameSnapshot: services.first.name,
          pricingType: PricingType.fixedPrice,
          quantity: 1,
          unitPrice: const Money.fromPiastres(1000),
          calculatedTotal: const Money.fromPiastres(1000),
          createdAt: now,
          updatedAt: now,
        );
        await orderRepo.createOrder(order: order, items: [item]);
      }

      await tester.pumpWidget(testBoilerplate(
        CustomerDetailScreen(customerId: customer.id),
      ));
      await tester.pumpAndSettle();

      // Authoritative count is displayed in header
      expect(find.text('سجل الطلبات (22)'), findsOneWidget);
      expect(find.text('22'), findsNWidgets(2));

      // Load-more button is present because 20 loaded < 22 total
      final loadMoreFinder = find.text('تحميل المزيد من الطلبات');
      await tester.scrollUntilVisible(
        loadMoreFinder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(loadMoreFinder, findsOneWidget);

      // Tap load more
      await tester.tap(loadMoreFinder);
      await tester.pumpAndSettle();

      // After loading more, all 22 orders are displayed and load-more button disappears
      expect(find.text('تحميل المزيد من الطلبات'), findsNothing);
    });
  });
}
