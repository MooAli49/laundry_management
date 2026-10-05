import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/di/injection.dart';
import 'package:laundry_management/core/localization/app_strings.dart';
import 'package:laundry_management/data/local/daos/expense_categories_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart'
    hide Expense, ExpenseCategory;
import 'package:laundry_management/domain/entities/expense.dart';
import 'package:laundry_management/domain/repositories/expense_repository.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';
import 'package:laundry_management/features/expenses/presentation/screens/expenses_screen.dart';
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
      home: Scaffold(body: child),
    );
  }

  group('ExpensesScreen Widget Tests', () {
    testWidgets('renders header, metric cards, filter bar, and empty state when no expenses exist', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableWidget(const ExpensesScreen()));
      await tester.pumpAndSettle();

      // Page Header
      expect(find.text(AppStrings.expenses), findsOneWidget);
      expect(find.text(AppStrings.expensesSubtitle), findsOneWidget);
      expect(find.text(AppStrings.addExpense), findsWidgets);

      // KPI Metric Cards
      expect(find.text(AppStrings.totalExpensesAmount), findsOneWidget);
      expect(find.text(AppStrings.expensesCount), findsOneWidget);
      expect(find.text(AppStrings.topCategory), findsOneWidget);

      // Empty State
      expect(find.text(AppStrings.noExpenses), findsOneWidget);
      expect(find.text(AppStrings.noExpensesPrompt), findsOneWidget);
    });

    testWidgets('renders expenses data table when expenses exist', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Get existing category or insert a uniquely named test category
      final categoriesDao = getIt<ExpenseCategoriesDao>();
      final existingCategories = await categoriesDao.getActiveCategories();
      final catId = existingCategories.isNotEmpty ? existingCategories.first.id : 'cat-test-1';
      final catName = existingCategories.isNotEmpty ? existingCategories.first.name : 'كهرباء تجريبية';

      if (existingCategories.isEmpty) {
        await categoriesDao.insertCategory(
          ExpenseCategoriesCompanion.insert(
            id: catId,
            name: catName,
            isActive: const Value(true),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }

      // Insert an expense for current month
      final expenseRepo = getIt<ExpenseRepository>();
      final today = OrderDate.today();
      await expenseRepo.createExpense(
        Expense(
          id: 'exp-test-1',
          expenseCategoryId: catId,
          amount: Money.fromPiastres(35000), // 350 EGP
          expenseName: 'فاتورة الكهرباء الشهرية',
          expenseDate: today,
          notes: 'تم السداد',
          categoryNameSnapshot: catName,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(buildTestableWidget(const ExpensesScreen()));
      await tester.pumpAndSettle();

      // Verify table rows and values
      expect(find.text('350.00 ج.م'), findsWidgets);
      expect(find.text('فاتورة الكهرباء الشهرية (تم السداد)'), findsOneWidget);
      expect(find.text(catName), findsWidgets);
      expect(find.text('1 مصروف'), findsOneWidget);
    });

    testWidgets('clicking add expense button opens AddExpenseDialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableWidget(const ExpensesScreen()));
      await tester.pumpAndSettle();

      // Tap header add expense button
      final addBtn = find.byKey(const ValueKey('add_expense_screen_button'));
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Verify AddExpenseDialog opened
      expect(find.byType(AddExpenseDialog), findsOneWidget);
    });
  });
}
