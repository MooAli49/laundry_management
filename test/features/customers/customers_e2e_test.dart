import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/di/injection.dart';
import 'package:laundry_management/core/theme/app_theme.dart';
import 'package:laundry_management/data/local/database/app_database.dart' as db_pkg;
import 'package:laundry_management/data/local/database/dev_test_data.dart';
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/repositories/customer_repository.dart';
import 'package:laundry_management/features/customers/presentation/screens/customer_detail_screen.dart';
import 'package:laundry_management/features/customers/presentation/screens/customers_screen.dart';
import 'package:laundry_management/features/customers/presentation/widgets/customer_card.dart';
import 'package:laundry_management/features/orders/presentation/cubit/create_order_cubit.dart';
import 'package:uuid/uuid.dart';

Widget testBoilerplate(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  late db_pkg.AppDatabase db;

  setUp(() async {
    await getIt.reset();
    db = db_pkg.AppDatabase(NativeDatabase.memory());
    getIt.registerLazySingleton<db_pkg.AppDatabase>(() => db);
    await initDependencies();
    await DevTestData.seedDevData(db);
  });

  tearDown(() async {
    await db.close();
    await getIt.reset();
  });

  group('Task #07 — Customers E2E Workflow', () {
    testWidgets(
      'Full flow: Customer Creation -> Customers List -> Customer Details -> Create Order with preselected Customer -> Saved Order -> Customer Order History',
      (WidgetTester tester) async {
        final custRepo = getIt<CustomerRepository>();
        final now = DateTime.now();

        // -------------------------------------------------------------
        // STEP 1: Create a Customer
        // -------------------------------------------------------------
        final customerId = const Uuid().v4();
        final customer = await custRepo.createCustomer(
          Customer(
            id: customerId,
            name: 'عمر المختار',
            phone: '01011119999',
            notes: 'عميل دائم ومميز',
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(customer.id, equals(customerId));
        expect(customer.name, equals('عمر المختار'));
        expect(customer.phone, equals('01011119999'));

        // -------------------------------------------------------------
        // STEP 2: View Customer in Customers List Screen
        // -------------------------------------------------------------
        await tester.pumpWidget(testBoilerplate(const CustomersScreen()));
        await tester.pumpAndSettle();

        expect(find.byType(CustomerCard), findsAtLeastNWidgets(1));
        expect(find.text('عمر المختار'), findsOneWidget);
        expect(find.text('01011119999'), findsOneWidget);
        expect(find.text('لا توجد طلبات'), findsAtLeastNWidgets(1));

        // -------------------------------------------------------------
        // STEP 3: View Customer Details Screen (0 Orders initial)
        // -------------------------------------------------------------
        await tester.pumpWidget(testBoilerplate(
          CustomerDetailScreen(customerId: customer.id),
        ));
        await tester.pumpAndSettle();

        expect(find.text('عمر المختار'), findsOneWidget);
        expect(find.text('01011119999'), findsOneWidget);
        expect(find.text('عميل دائم ومميز'), findsOneWidget);

        // Verify initial KPI cards
        expect(find.text('إجمالي الطلبات'), findsOneWidget);
        expect(find.text('طلبات جارية'), findsOneWidget);
        expect(find.text('طلبات مكتملة'), findsOneWidget);

        // Initially 0 orders
        expect(find.text('لا توجد طلبات لهذا العميل'), findsOneWidget);

        // -------------------------------------------------------------
        // STEP 4: Create Order with preselected Customer
        // -------------------------------------------------------------
        final createOrderCubit = getIt<CreateOrderCubit>();
        await createOrderCubit.initialize(initialCustomerId: customer.id);

        // Verify that the customer was preselected
        expect(createOrderCubit.state.selectedCustomer, isNotNull);
        expect(createOrderCubit.state.selectedCustomer!.id, equals(customer.id));
        expect(createOrderCubit.state.selectedCustomer!.name, equals('عمر المختار'));

        // Add an item to the order
        final itemType = createOrderCubit.state.itemTypes.first;
        await createOrderCubit.selectItemType(itemType);

        final service = createOrderCubit.state.compatibleServices.first;
        createOrderCubit.selectService(service);
        createOrderCubit.updateQuantity(2);
        createOrderCubit.addItemDraftToOrder();

        expect(createOrderCubit.state.items.length, equals(1));

        // Submit the order
        await createOrderCubit.submitOrder();
        final createdOrder = createOrderCubit.state.createdOrder;
        expect(createdOrder, isNotNull);
        expect(createdOrder!.customerId, equals(customer.id));
        expect(createdOrder.customerNameSnapshot, equals('عمر المختار'));
        expect(createdOrder.customerPhoneSnapshot, equals('01011119999'));
        expect(createdOrder.status, equals(OrderStatus.processing));

        // -------------------------------------------------------------
        // STEP 5: Re-render Customer Details Screen & Verify History
        // -------------------------------------------------------------
        await tester.pumpWidget(testBoilerplate(
          CustomerDetailScreen(
            key: const ValueKey('customer-detail-reloaded'),
            customerId: customer.id,
          ),
        ));
        await tester.pumpAndSettle();

        // Empty state is now gone
        expect(find.text('لا توجد طلبات لهذا العميل'), findsNothing);

        // The order appears in the history
        expect(find.text(createdOrder.orderNumber), findsOneWidget);
        expect(find.text('قيد التجهيز'), findsOneWidget);

        // Verify KPI stats: 1 total, 1 active, 0 completed
        expect(find.text('1'), findsNWidgets(2)); // Total = 1, Active = 1
        expect(find.text('0'), findsOneWidget);   // Completed = 0
      },
    );
  });
}
