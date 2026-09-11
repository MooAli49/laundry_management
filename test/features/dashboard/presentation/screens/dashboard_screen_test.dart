import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/di/injection.dart';
import 'package:laundry_management/data/local/database/app_database.dart';
import 'package:laundry_management/features/customers/presentation/widgets/customer_form_dialog.dart';
import 'package:laundry_management/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:laundry_management/features/expenses/presentation/widgets/add_expense_dialog.dart';

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

  group('DashboardScreen Widget & Quick Action Tests', () {
    testWidgets('renders all approved quick actions with correct priority', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const DashboardScreen()));
      await tester.pumpAndSettle();

      expect(find.text('الرئيسية'), findsOneWidget);
      expect(find.text('الإجراءات السريعة'), findsOneWidget);

      // Verify the 4 approved quick actions
      expect(find.byKey(const ValueKey('dashboard_add_order_button')), findsOneWidget);
      expect(find.text('إضافة طلب'), findsOneWidget);

      expect(find.byKey(const ValueKey('dashboard_add_customer_button')), findsOneWidget);
      expect(find.text('إضافة عميل'), findsOneWidget);

      expect(find.byKey(const ValueKey('dashboard_record_payment_button')), findsOneWidget);
      expect(find.text('تسجيل دفعة'), findsOneWidget);

      expect(find.byKey(const ValueKey('dashboard_add_expense_button')), findsOneWidget);
      expect(find.text('إضافة مصروف'), findsOneWidget);
    });

    testWidgets('tapping إضافة مصروف opens AddExpenseDialog', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const DashboardScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('dashboard_add_expense_button')));
      await tester.pumpAndSettle();

      expect(find.byType(AddExpenseDialog), findsOneWidget);
      expect(find.text('حفظ المصروف'), findsOneWidget);
    });

    testWidgets('tapping إضافة عميل opens CustomerFormDialog', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const DashboardScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('dashboard_add_customer_button')));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerFormDialog), findsOneWidget);
    });

    testWidgets('renders operational summary cards for today', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const DashboardScreen()));
      await tester.pumpAndSettle();

      expect(find.text('ملخص اليوم'), findsOneWidget);
      expect(find.text('طلبات اليوم'), findsOneWidget);
      expect(find.text('قيد التنفيذ'), findsOneWidget);
      expect(find.text('جاهزة للتسليم'), findsOneWidget);
      expect(find.text('مبيعات اليوم'), findsOneWidget);
      expect(find.text('مصروفات اليوم'), findsOneWidget);
      expect(find.text('مبالغ متبقية'), findsOneWidget);
    });
  });
}
