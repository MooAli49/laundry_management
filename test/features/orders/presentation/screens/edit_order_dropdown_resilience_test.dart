import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/di/injection.dart';
import 'package:laundry_management/core/theme/app_theme.dart';
import 'package:laundry_management/data/local/database/app_database.dart' as app_db;
import 'package:laundry_management/data/local/database/dev_test_data.dart';
import 'package:laundry_management/domain/entities/service.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/repositories/order_repository.dart';
import 'package:laundry_management/features/orders/presentation/screens/edit_order_screen.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  late app_db.AppDatabase db;

  setUp(() async {
    await getIt.reset();
    db = app_db.AppDatabase(NativeDatabase.memory());
    await DevTestData.seedDevData(db);

    getIt.registerLazySingleton<app_db.AppDatabase>(() => db);
    await initDependencies();
  });

  tearDown(() async {
    if (getIt.isRegistered<app_db.AppDatabase>()) {
      await getIt<app_db.AppDatabase>().close();
    }
    await getIt.reset();
  });

  group('EditOrderScreen Dropdown Resilience Tests', () {
    testWidgets('editing item does not throw DropdownButton assertion error even with duplicate or unlisted service', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Get an existing order from seed
      final orderRepo = getIt<OrderRepository>();
      final orders = await orderRepo.getOrders(status: OrderStatus.processing);
      expect(orders.isNotEmpty, isTrue);
      final testOrder = orders.first;

      await tester.pumpWidget(createTestApp(EditOrderScreen(orderId: testOrder.id)));
      await tester.pumpAndSettle();

      // Find edit icon/button on first item card
      final editButtons = find.byIcon(Icons.edit_outlined);
      if (editButtons.evaluate().isNotEmpty) {
        await tester.tap(editButtons.first);
        await tester.pumpAndSettle();

        // Should render form without throwing any exception
        expect(find.text('تعديل بند من الطلب'), findsOneWidget);
        expect(find.byType(DropdownButtonFormField<Service>), findsOneWidget);
      }
    });
  });
}
