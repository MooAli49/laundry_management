import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/di/injection.dart';
import 'package:laundry_management/data/local/daos/customers_dao.dart';
import 'package:laundry_management/data/local/daos/expense_categories_dao.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart' hide Expense, ExpenseCategory;
import 'package:laundry_management/domain/entities/expense.dart';
import 'package:laundry_management/domain/enums/payment_method.dart';
import 'package:laundry_management/domain/repositories/expense_repository.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';
import 'package:laundry_management/features/expenses/presentation/widgets/add_expense_dialog.dart';
import 'package:laundry_management/features/reports/presentation/screens/reports_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    await getIt.reset();
    db = AppDatabase(NativeDatabase.memory());
    getIt.registerLazySingleton<AppDatabase>(() => db);
    await initDependencies();
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

  group('ReportsScreen Widget Tests', () {
    testWidgets('renders header, tabs, and period selector', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const ReportsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('التقارير'), findsOneWidget);
      expect(find.text('تقرير الطلبات'), findsOneWidget);
      expect(find.text('التقرير المالي'), findsOneWidget);

      // Period selector chips
      expect(find.text('اليوم'), findsOneWidget);
      expect(find.text('أمس'), findsOneWidget);
      expect(find.text('آخر 7 أيام'), findsOneWidget);
      expect(find.text('هذا الشهر'), findsOneWidget);
      expect(find.text('الشهر السابق'), findsOneWidget);
      expect(find.text('مخصص'), findsOneWidget);
    });

    testWidgets('shows empty state when no orders exist in selected period', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const ReportsScreen()));
      await tester.pumpAndSettle();

      // Orders tab is default
      expect(find.text('لا توجد طلبات خلال هذه الفترة'), findsOneWidget);
    });

    testWidgets('switches to Financial Report tab and displays metrics and breakdowns', (tester) async {
      final now = DateTime.now();

      // Seed customer
      final customersDao = getIt<CustomersDao>();
      await customersDao.insertCustomer(
        CustomersCompanion.insert(
          id: 'cust-rep-1',
          name: 'عميل التقارير',
          phone: '01000000001',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Seed Order
      final ordersDao = getIt<OrdersDao>();
      await ordersDao.insertOrder(
        OrdersCompanion.insert(
          id: 'ord-rep-1',
          orderNumber: '26-999',
          customerId: 'cust-rep-1',
          customerNameSnapshot: const Value('عميل التقارير'),
          customerPhoneSnapshot: const Value('01000000001'),
          status: const Value('ready'),
          expectedPickupDate: now.add(const Duration(days: 1)),
          subtotal: 50000,
          total: 50000, // 500 EGP
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Seed Payment: 300 EGP Cash
      final paymentsDao = getIt<PaymentsDao>();
      await paymentsDao.insertPayment(
        PaymentsCompanion.insert(
          id: 'pay-rep-1',
          orderId: 'ord-rep-1',
          amount: 30000,
          paymentMethod: PaymentMethod.cash.value,
          paidAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Seed Expense: 100 EGP
      final catsDao = getIt<ExpenseCategoriesDao>();
      final cats = await catsDao.getAllCategories();
      final cleaningCat = cats.firstWhere((c) => c.name == 'منظفات');

      final expenseRepo = getIt<ExpenseRepository>();
      await expenseRepo.createExpense(
        Expense(
          id: 'exp-w-1',
          expenseCategoryId: cleaningCat.id,
          amount: const Money.fromPiastres(10000), // 100 EGP
          expenseDate: OrderDate.fromDate(now),
          notes: 'صابون',
          categoryNameSnapshot: cleaningCat.name,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await tester.pumpWidget(buildTestableWidget(const ReportsScreen()));
      await tester.pumpAndSettle();

      // Switch to Financial tab
      await tester.tap(find.text('التقرير المالي'));
      await tester.pumpAndSettle();

      // Check Financial Summary Cards
      expect(find.text('الملخص المالي'), findsOneWidget);
      expect(find.text('إجمالي المبيعات'), findsOneWidget);
      expect(find.text('500.00 ج.م'), findsWidgets); // Sales
      expect(find.text('إجمالي المدفوعات'), findsOneWidget);
      expect(find.text('300.00 ج.م'), findsWidgets); // Payments
      expect(find.text('إجمالي المصروفات'), findsOneWidget);
      expect(find.text('100.00 ج.م'), findsWidgets); // Expenses
      expect(find.text('صافي الربح'), findsOneWidget);
      expect(find.text('400.00 ج.م'), findsOneWidget); // Net profit: 500 - 100 = 400
      expect(find.text('المبالغ المتبقية'), findsOneWidget);
      expect(find.text('200.00 ج.م'), findsWidgets); // Remaining: 500 - 300 = 200

      // Check Payment Methods section
      expect(find.text('طرق الدفع'), findsOneWidget);
      expect(find.text('كاش'), findsWidgets);

      // Check Expenses by Category section
      expect(find.text('المصروفات حسب التصنيف'), findsOneWidget);
      expect(find.text('منظفات'), findsWidgets);

      // Check Outstanding orders section
      expect(find.text('طلبات عليها مبالغ متبقية'), findsOneWidget);
      expect(find.text('26-999'), findsOneWidget);

      // Check Expense transactions table
      expect(find.text('سجل المصروفات'), findsOneWidget);
      expect(find.text('صابون'), findsOneWidget);
    });

    testWidgets('tapping إضافة مصروف button in Financial Report opens AddExpenseDialog', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const ReportsScreen()));
      await tester.pumpAndSettle();

      // Switch to Financial tab
      await tester.tap(find.text('التقرير المالي'));
      await tester.pumpAndSettle();

      // Tap the quick action button
      await tester.tap(find.byKey(const ValueKey('add_expense_quick_action_button')));
      await tester.pumpAndSettle();

      expect(find.byType(AddExpenseDialog), findsOneWidget);
    });
  });
}
