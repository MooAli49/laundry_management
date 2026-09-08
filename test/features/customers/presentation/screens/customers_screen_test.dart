import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/di/injection.dart';
import 'package:laundry_management/core/theme/app_theme.dart';
import 'package:laundry_management/data/local/database/app_database.dart' as db_pkg;
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/domain/repositories/customer_repository.dart';
import 'package:laundry_management/features/customers/presentation/screens/customers_screen.dart';
import 'package:laundry_management/features/customers/presentation/widgets/customer_card.dart';

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
  });

  tearDown(() async {
    if (getIt.isRegistered<db_pkg.AppDatabase>()) {
      await getIt<db_pkg.AppDatabase>().close();
    }
    await getIt.reset();
  });

  group('CustomersScreen Tests', () {
    testWidgets('renders header, search bar, and empty state when no customers exist', (tester) async {
      await tester.pumpWidget(testBoilerplate(const CustomersScreen()));
      await tester.pumpAndSettle();

      expect(find.text('العملاء'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('لا يوجد عملاء حتى الآن'), findsOneWidget);
      expect(find.text('إضافة عميل'), findsNWidgets(2)); // Header action + empty state action
    });

    testWidgets('renders list of customer cards when customers exist', (tester) async {
      final repo = getIt<CustomerRepository>();
      final now = DateTime.now();
      await repo.createCustomer(
        Customer(
          id: 'c-1',
          name: 'عميل رقم واحد',
          phone: '01011111111',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repo.createCustomer(
        Customer(
          id: 'c-2',
          name: 'عميل رقم اثنين',
          phone: '01022222222',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await tester.pumpWidget(testBoilerplate(const CustomersScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerCard), findsNWidgets(2));
      expect(find.text('عميل رقم واحد'), findsOneWidget);
      expect(find.text('عميل رقم اثنين'), findsOneWidget);
    });

    testWidgets('filters list when searching by name or phone', (tester) async {
      final repo = getIt<CustomerRepository>();
      final now = DateTime.now();
      await repo.createCustomer(
        Customer(
          id: 'c-1',
          name: 'محمد فتحي',
          phone: '01011112222',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repo.createCustomer(
        Customer(
          id: 'c-2',
          name: 'سارة أحمد',
          phone: '01033334444',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await tester.pumpWidget(testBoilerplate(const CustomersScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerCard), findsNWidgets(2));

      // Search for 'سارة'
      await tester.enterText(find.byType(TextField), 'سارة');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerCard), findsOneWidget);
      expect(find.text('سارة أحمد'), findsOneWidget);
      expect(find.text('محمد فتحي'), findsNothing);

      // Search for non-matching
      await tester.enterText(find.byType(TextField), 'لايوجد');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerCard), findsNothing);
      expect(find.text('لا توجد نتائج مطابقة'), findsOneWidget);
    });

    testWidgets('renders 2-column grid on tablet and 1-column on narrow width', (tester) async {
      final repo = getIt<CustomerRepository>();
      final now = DateTime.now();
      await repo.createCustomer(
        Customer(
          id: 'c-1',
          name: 'عميل أول',
          phone: '01011111111',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Tablet width (1024x768)
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(testBoilerplate(const CustomersScreen()));
      await tester.pumpAndSettle();

      final tabletGrid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      final tabletDelegate = tabletGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(tabletDelegate.crossAxisCount, equals(2));

      // Narrow / mobile width (400x800)
      tester.view.physicalSize = const Size(400, 800);
      await tester.pumpWidget(testBoilerplate(const CustomersScreen()));
      await tester.pumpAndSettle();

      final narrowGrid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      final narrowDelegate = narrowGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(narrowDelegate.crossAxisCount, equals(1));
    });

    testWidgets('creates a customer and refreshes list via Cubit without direct Repository access', (tester) async {
      await tester.pumpWidget(testBoilerplate(const CustomersScreen()));
      await tester.pumpAndSettle();

      expect(find.text('لا يوجد عملاء حتى الآن'), findsOneWidget);

      // Open add customer dialog
      await tester.tap(find.text('إضافة عميل').first);
      await tester.pumpAndSettle();

      expect(find.text('إضافة عميل جديد'), findsOneWidget);

      // Fill in customer data
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(1), 'جمال عبد الناصر'); // First field in dialog (0 is search bar)
      await tester.enterText(textFields.at(2), '01019283746');

      await tester.tap(find.text('حفظ العميل'));
      await tester.pumpAndSettle();

      expect(find.text('إضافة عميل جديد'), findsNothing);
      expect(find.text('جمال عبد الناصر'), findsOneWidget);
      expect(find.text('01019283746'), findsOneWidget);
      expect(find.text('إجمالي 1 عميل'), findsOneWidget);
    });

    testWidgets('displays load-more button when customer count > 50 and appends next page on tap', (tester) async {
      final repo = getIt<CustomerRepository>();
      final now = DateTime.now();
      for (var i = 1; i <= 55; i++) {
        final phoneSuffix = i.toString().padLeft(8, '0');
        await repo.createCustomer(
          Customer(
            id: 'c-page-$i',
            name: 'عميل رقم $i',
            phone: '010$phoneSuffix',
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      await tester.pumpWidget(testBoilerplate(const CustomersScreen()));
      await tester.pumpAndSettle();

      expect(find.text('إجمالي 55 عميل'), findsOneWidget);
      expect(find.byType(CustomerCard), findsWidgets);

      // Drag until load-more button is built and visible
      await tester.dragUntilVisible(
        find.text('تحميل المزيد من العملاء'),
        find.byType(CustomScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(find.text('تحميل المزيد من العملاء'), findsOneWidget);

      // Tap load more
      await tester.tap(find.text('تحميل المزيد من العملاء'));
      await tester.pumpAndSettle();

      // Drag until customer 55 is built and visible
      await tester.dragUntilVisible(
        find.text('عميل رقم 55'),
        find.byType(CustomScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(find.text('عميل رقم 55'), findsOneWidget);
      expect(find.text('تحميل المزيد من العملاء'), findsNothing);
    });
  });
}
