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
      await tester.pumpAndSettle();

      expect(find.byType(CustomerCard), findsOneWidget);
      expect(find.text('سارة أحمد'), findsOneWidget);
      expect(find.text('محمد فتحي'), findsNothing);

      // Search for non-matching
      await tester.enterText(find.byType(TextField), 'لايوجد');
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

      final tabletGrid = tester.widget<GridView>(find.byType(GridView));
      final tabletDelegate = tabletGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(tabletDelegate.crossAxisCount, equals(2));

      // Narrow / mobile width (400x800)
      tester.view.physicalSize = const Size(400, 800);
      await tester.pumpWidget(testBoilerplate(const CustomersScreen()));
      await tester.pumpAndSettle();

      final narrowGrid = tester.widget<GridView>(find.byType(GridView));
      final narrowDelegate = narrowGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(narrowDelegate.crossAxisCount, equals(1));
    });
  });
}
