import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/di/injection.dart';
import 'package:laundry_management/data/local/database/app_database.dart' hide Order;
import 'package:laundry_management/domain/entities/dashboard_data.dart';
import 'package:laundry_management/domain/entities/dashboard_order_item.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/repositories/dashboard_repository.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';
import 'package:laundry_management/features/customers/presentation/widgets/customer_form_dialog.dart';
import 'package:laundry_management/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:laundry_management/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:laundry_management/features/dashboard/presentation/widgets/record_payment_dialog.dart';
import 'package:laundry_management/features/expenses/presentation/widgets/add_expense_dialog.dart';

class FakeDashboardRepository implements DashboardRepository {
  DashboardData mockData = const DashboardData(
    todayOrdersCount: 5,
    processingOrdersCount: 2,
    readyOrdersCount: 3,
    totalRemainingAmount: Money.fromPiastres(12000),
    unpaidOrdersCount: 2,
    storageAttentionCount: 4,
    overdueOrdersCount: 1,
    todayPickupOrdersCount: 1,
    todayPickupOrders: [],
    recentOrders: [],
  );

  @override
  Future<DashboardData> getDashboardData() async {
    return mockData;
  }
}

void main() {
  late AppDatabase db;
  late FakeDashboardRepository fakeDashboardRepository;

  setUp(() async {
    await getIt.reset();
    db = AppDatabase(NativeDatabase.memory());
    getIt.registerLazySingleton<AppDatabase>(() => db);
    await initDependencies();

    fakeDashboardRepository = FakeDashboardRepository();
    if (getIt.isRegistered<DashboardRepository>()) {
      await getIt.unregister<DashboardRepository>();
    }
    getIt.registerLazySingleton<DashboardRepository>(() => fakeDashboardRepository);

    if (getIt.isRegistered<DashboardCubit>()) {
      await getIt.unregister<DashboardCubit>();
    }
    getIt.registerFactory<DashboardCubit>(
      () => DashboardCubit(dashboardRepository: fakeDashboardRepository),
    );
  });

  tearDown(() async {
    if (getIt.isRegistered<AppDatabase>()) {
      await getIt<AppDatabase>().close();
    }
    await getIt.reset();
  });

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      locale: const Locale('ar'),
      home: child,
    );
  }

  group('DashboardScreen Widget & Specification Tests', () {
    testWidgets('renders header, quick actions, operational summary, attention, and sections', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const DashboardScreen()));
      await tester.pumpAndSettle();

      // 1. Header
      expect(find.text('الرئيسية'), findsOneWidget);
      expect(find.text('الإجراءات السريعة'), findsOneWidget);

      // 2. Exactly 4 Approved Quick Actions
      expect(find.byKey(const ValueKey('dashboard_add_order_button')), findsOneWidget);
      expect(find.text('إضافة طلب'), findsWidgets); // quick action and possible empty state button

      expect(find.byKey(const ValueKey('dashboard_add_customer_button')), findsOneWidget);
      expect(find.text('إضافة عميل'), findsOneWidget);

      expect(find.byKey(const ValueKey('dashboard_record_payment_button')), findsOneWidget);
      expect(find.text('تسجيل دفعة'), findsOneWidget);

      expect(find.byKey(const ValueKey('dashboard_add_expense_button')), findsOneWidget);
      expect(find.text('إضافة مصروف'), findsOneWidget);

      // 3. Exactly 4 Approved Operational Summary Cards
      expect(find.text('ملخص اليوم'), findsOneWidget);
      expect(find.text('طلبات اليوم'), findsOneWidget);
      expect(find.text('قيد التنفيذ'), findsOneWidget);
      expect(find.text('جاهزة للتسليم'), findsOneWidget);
      expect(find.text('مبالغ متبقية'), findsOneWidget);

      // 4. Verification of Exclusions: NO unapproved financial metrics
      expect(find.text('مبيعات اليوم'), findsNothing);
      expect(find.text('مصروفات اليوم'), findsNothing);
      expect(find.text('صافي الربح'), findsNothing);
      expect(find.text('إجمالي المصروفات'), findsNothing);

      // 5. Attention Required Section
      expect(find.text('يحتاج انتباه'), findsOneWidget);
      expect(find.byKey(const ValueKey('attention_storage_item')), findsOneWidget);
      expect(find.byKey(const ValueKey('attention_unpaid_item')), findsOneWidget);
      expect(find.byKey(const ValueKey('attention_overdue_item')), findsOneWidget);
      expect(find.byKey(const ValueKey('attention_today_pickup_item')), findsOneWidget);

      // 6. Today's Pickups Section
      expect(find.text('استلام اليوم'), findsWidgets); // inside attention and as section title

      // 7. Recent Orders Section
      expect(find.text('أحدث الطلبات'), findsOneWidget);
    });

    testWidgets('tapping إضافة مصروف opens AddExpenseDialog', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const DashboardScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('dashboard_add_expense_button')));
      await tester.pumpAndSettle();

      expect(find.byType(AddExpenseDialog), findsOneWidget);
      expect(find.text('حفظ'), findsOneWidget);
      expect(find.byKey(const ValueKey('save_expense_button')), findsOneWidget);
    });

    testWidgets('tapping إضافة عميل opens CustomerFormDialog', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const DashboardScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('dashboard_add_customer_button')));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerFormDialog), findsOneWidget);
      expect(find.text('إضافة عميل جديد'), findsOneWidget);
    });

    testWidgets('tapping تسجيل دفعة opens RecordPaymentDialog', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const DashboardScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('dashboard_record_payment_button')));
      await tester.pumpAndSettle();

      expect(find.byType(RecordPaymentDialog), findsOneWidget);
      expect(find.text('تسجيل دفعة'), findsWidgets);
    });

    testWidgets('displays orders in today pickups and recent orders when populated', (tester) async {
      final now = DateTime.now();
      final orderItem = DashboardOrderItem(
        order: Order(
          id: 'ord-test-1',
          orderNumber: '26-101',
          customerId: 'c1',
          customerNameSnapshot: 'محمود خليل',
          customerPhoneSnapshot: '01122334455',
          status: OrderStatus.processing,
          expectedPickupDate: OrderDate.today(),
          subtotal: const Money.fromPiastres(8000),
          total: const Money.fromPiastres(8000),
          createdAt: now,
          updatedAt: now,
        ),
        totalPaid: const Money.fromPiastres(3000),
        remainingAmount: const Money.fromPiastres(5000),
      );

      fakeDashboardRepository.mockData = DashboardData(
        todayOrdersCount: 1,
        processingOrdersCount: 1,
        readyOrdersCount: 0,
        totalRemainingAmount: const Money.fromPiastres(5000),
        unpaidOrdersCount: 1,
        storageAttentionCount: 0,
        overdueOrdersCount: 0,
        todayPickupOrdersCount: 1,
        todayPickupOrders: [orderItem],
        recentOrders: [orderItem],
      );

      await tester.pumpWidget(buildTestableWidget(const DashboardScreen()));
      await tester.pumpAndSettle();

      expect(find.text('26-101'), findsWidgets);
      expect(find.text('محمود خليل'), findsWidgets);
      expect(find.text('قيد التجهيز'), findsWidgets);
    });

    testWidgets('displays meaningful empty states when attention items and lists are empty', (tester) async {
      fakeDashboardRepository.mockData = DashboardData.empty;

      await tester.pumpWidget(buildTestableWidget(const DashboardScreen()));
      await tester.pumpAndSettle();

      expect(find.text('لا توجد طلبات تحتاج تخزين'), findsOneWidget);
      expect(find.text('لا توجد مبالغ متبقية'), findsOneWidget);
      expect(find.text('لا توجد طلبات متأخرة'), findsOneWidget);
      expect(find.text('لا توجد طلبات مستحقة اليوم'), findsOneWidget);
      expect(find.text('لا توجد طلبات للاستلام اليوم'), findsOneWidget);
      expect(find.text('لا توجد طلبات حتى الآن'), findsOneWidget);
    });
  });
}
