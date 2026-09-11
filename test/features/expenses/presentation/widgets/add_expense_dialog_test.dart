import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/di/injection.dart';
import 'package:laundry_management/data/local/database/app_database.dart' hide Expense, ExpenseCategory;
import 'package:laundry_management/domain/entities/expense.dart';
import 'package:laundry_management/domain/entities/expense_category.dart';
import 'package:laundry_management/domain/repositories/expense_category_repository.dart';
import 'package:laundry_management/domain/repositories/expense_repository.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
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
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('AddExpenseDialog Widget Tests', () {
    testWidgets('renders all initial fields, labels, and action buttons', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const AddExpenseDialog(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('إضافة مصروف'), findsOneWidget);
      expect(find.text('المبلغ (ج.م) *'), findsOneWidget);
      expect(find.text('فئة المصروف *'), findsOneWidget);
      expect(find.text('التاريخ *'), findsOneWidget);
      expect(find.text('ملاحظات'), findsOneWidget);
      expect(find.text('حفظ'), findsOneWidget);
      expect(find.text('إلغاء'), findsOneWidget);
    });

    testWidgets('shows validation error when amount is empty or non-positive', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const AddExpenseDialog(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap save without filling amount
      await tester.tap(find.byKey(const ValueKey('save_expense_button')));
      await tester.pumpAndSettle();

      expect(find.text('يرجى إدخال مبلغ صحيح أكبر من الصفر'), findsOneWidget);
    });

    testWidgets('selecting category أخرى reveals expense name field and enforces validation', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildTestableWidget(
          const AddExpenseDialog(),
        ),
      );
      await tester.pumpAndSettle();

      // Initially expense name field is not present
      expect(find.byKey(const ValueKey('expense_name_field')), findsNothing);

      // Enter amount
      await tester.enterText(find.widgetWithText(TextField, '0.00'), '75.50');
      await tester.pumpAndSettle();

      // Select 'أخرى' from dropdown
      final catRepo = getIt<ExpenseCategoryRepository>();
      final cats = await catRepo.getActiveCategories();
      final otherCat = cats.firstWhere((c) => c.name == 'أخرى');

      final dropdown = tester.widget<DropdownButtonFormField<ExpenseCategory>>(
        find.byKey(const ValueKey('expense_category_dropdown')),
      );
      dropdown.onChanged!(otherCat);
      await tester.pumpAndSettle();

      // Expense name field should now appear
      expect(find.byKey(const ValueKey('expense_name_field')), findsOneWidget);

      // Try to save with empty expense name
      await tester.ensureVisible(find.byKey(const ValueKey('save_expense_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save_expense_button')));
      await tester.pumpAndSettle();

      expect(find.text('يرجى إدخال اسم المصروف عند اختيار تصنيف أخرى'), findsOneWidget);

      // Fill expense name
      await tester.enterText(find.byKey(const ValueKey('expense_name_field')), 'قهوة وشاي للعاملين');
      await tester.pumpAndSettle();

      // Save successfully
      await tester.ensureVisible(find.byKey(const ValueKey('save_expense_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save_expense_button')));
      await tester.pumpAndSettle();

      // Verify saved in repository
      final repo = getIt<ExpenseRepository>();
      final expenses = await repo.getExpenses();
      expect(expenses.isNotEmpty, isTrue);
      final saved = expenses.first;
      expect(saved.amount, Money.fromEgp(75.50));
      expect(saved.categoryNameSnapshot, 'أخرى');
      expect(saved.expenseName, 'قهوة وشاي للعاملين');
    });

    testWidgets('creates standard expense with notes and triggers onExpenseCreated callback', (tester) async {
      Expense? createdExpense;

      await tester.pumpWidget(
        buildTestableWidget(
          AddExpenseDialog(
            onExpenseCreated: (exp) async {
              createdExpense = exp;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Fill amount
      await tester.enterText(find.widgetWithText(TextField, '0.00'), '250');
      await tester.pumpAndSettle();

      // Fill notes
      await tester.enterText(
        find.widgetWithText(TextField, 'أي ملاحظات إضافية حول المصروف'),
        'فاتورة كهرباء شهر أغسطس',
      );
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.byKey(const ValueKey('save_expense_button')));
      await tester.pumpAndSettle();

      expect(createdExpense, isNotNull);
      expect(createdExpense!.amount, Money.fromEgp(250));
      expect(createdExpense!.notes, 'فاتورة كهرباء شهر أغسطس');
    });
  });
}
