import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/di/injection.dart';
import 'package:laundry_management/data/local/database/app_database.dart';

void main() {
  group('Dependency Injection & Release Safety Tests', () {
    tearDown(() async {
      if (getIt.isRegistered<AppDatabase>()) {
        await getIt<AppDatabase>().close();
      }
      await getIt.reset();
    });

    test(
      'initDependencies executes and registers core dependencies without throwing',
      () async {
        expect(getIt.isRegistered<AppDatabase>(), isFalse);

        getIt.registerLazySingleton<AppDatabase>(
          () => AppDatabase(NativeDatabase.memory()),
        );

        await initDependencies(enableDevTestData: false);

        expect(getIt.isRegistered<AppDatabase>(), isTrue);
      },
    );

    test(
      'Release/profile configuration (enableDevTestData: false) does NOT seed development test data',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        getIt.registerSingleton<AppDatabase>(db);

        await initDependencies(enableDevTestData: false);

        // Verify strictly 0 transactional entities exist
        final customers = await db.select(db.customers).get();
        expect(customers, isEmpty, reason: 'Must not seed customers in release/profile mode');

        final orders = await db.select(db.orders).get();
        expect(orders, isEmpty, reason: 'Must not seed orders in release/profile mode');

        final orderItems = await db.select(db.orderItems).get();
        expect(orderItems, isEmpty, reason: 'Must not seed order items in release/profile mode');

        final payments = await db.select(db.payments).get();
        expect(payments, isEmpty, reason: 'Must not seed payments in release/profile mode');

        final storageRecords = await db.select(db.storageRecords).get();
        expect(storageRecords, isEmpty, reason: 'Must not seed storage records in release/profile mode');

        final expenses = await db.select(db.expenses).get();
        expect(expenses, isEmpty, reason: 'Must not seed expenses in release/profile mode');
      },
    );

    test(
      'Debug configuration (enableDevTestData: true) seeds development test data',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        getIt.registerSingleton<AppDatabase>(db);

        await initDependencies(enableDevTestData: true);

        // Verify development test data is populated
        final customers = await db.select(db.customers).get();
        expect(customers, isNotEmpty, reason: 'Debug configuration should seed customers');

        final orders = await db.select(db.orders).get();
        expect(orders, isNotEmpty, reason: 'Debug configuration should seed orders');

        final orderItems = await db.select(db.orderItems).get();
        expect(orderItems, isNotEmpty, reason: 'Debug configuration should seed order items');

        final payments = await db.select(db.payments).get();
        expect(payments, isNotEmpty, reason: 'Debug configuration should seed payments');
      },
    );

    test(
      'Default configuration (no enableDevTestData argument) respects DevTestData.isEnabled (false in test/release)',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        getIt.registerSingleton<AppDatabase>(db);

        await initDependencies();

        final customers = await db.select(db.customers).get();
        expect(customers, isEmpty, reason: 'Default without argument should not seed dev data');

        final orders = await db.select(db.orders).get();
        expect(orders, isEmpty, reason: 'Default without argument should not seed dev data');
      },
    );
  });
}
