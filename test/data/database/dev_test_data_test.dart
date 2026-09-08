import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/storage_locations_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart';
import 'package:laundry_management/data/local/database/dev_test_data.dart';
import 'package:laundry_management/data/repositories/payment_repository_impl.dart';
import 'package:laundry_management/data/repositories/storage_repository_impl.dart';
import 'package:laundry_management/domain/enums/payment_method.dart';

void main() {
  group('DevTestData & Production Seed Safety Tests', () {
    test('production seed initializes with 0 customers/orders/payments/storage records', () async {
      final db = AppDatabase(NativeDatabase.memory());
      // On creation, beforeOpen runs SeedData.seedInitialData
      // Trigger database open by running a simple query
      final itemTypes = await db.select(db.itemTypes).get();
      expect(itemTypes.length, 4);

      final expenseCategories = await db.select(db.expenseCategories).get();
      expect(expenseCategories.length, 7);

      final businessSettings = await db.select(db.businessSettings).get();
      expect(businessSettings.length, 1);

      // Verify STRICTLY 0 transactional entities
      final customers = await db.select(db.customers).get();
      expect(customers.isEmpty, isTrue, reason: 'Production seed must NOT create customers');

      final orders = await db.select(db.orders).get();
      expect(orders.isEmpty, isTrue, reason: 'Production seed must NOT create orders');

      final orderItems = await db.select(db.orderItems).get();
      expect(orderItems.isEmpty, isTrue, reason: 'Production seed must NOT create order items');

      final payments = await db.select(db.payments).get();
      expect(payments.isEmpty, isTrue, reason: 'Production seed must NOT create payments');

      final storageRecords = await db.select(db.storageRecords).get();
      expect(storageRecords.isEmpty, isTrue, reason: 'Production seed must NOT create storage records');

      final expenses = await db.select(db.expenses).get();
      expect(expenses.isEmpty, isTrue, reason: 'Production seed must NOT create expenses');

      final syncOperations = await db.select(db.syncOperations).get();
      expect(syncOperations.isEmpty, isTrue, reason: 'Production seed must NOT create sync operations');

      await db.close();
    });

    test('DevTestData is disabled by default via bool.fromEnvironment', () {
      // Unless explicitly passed at compile time via --dart-define, isEnabled is false
      expect(DevTestData.isEnabled, isFalse);
    });

    test('DevTestData populates required scenarios with exactly 12 customers and 18 orders', () async {
      final db = AppDatabase(NativeDatabase.memory());

      // Explicitly run DevTestData seeding
      await DevTestData.seedDevData(db);

      // Verify 12 customers
      final customers = await db.select(db.customers).get();
      expect(customers.length, 12);
      for (final c in customers) {
        expect(c.phone.startsWith('010000000'), isTrue);
      }

      // Verify 18 orders
      final orders = await db.select(db.orders).get();
      expect(orders.length, 18);

      // Verify statuses coverage
      final statuses = orders.map((o) => o.status).toSet();
      expect(statuses, containsAll(['processing', 'ready', 'completed', 'cancelled']));

      // Scenario 1: Processing — no stored items
      final ord1 = orders.firstWhere((o) => o.orderNumber == '26-001');
      expect(ord1.status, 'processing');

      // Scenario 2: Processing — partially stored items
      final ord2 = orders.firstWhere((o) => o.orderNumber == '26-002');
      expect(ord2.status, 'processing');
      final ord2Items = await (db.select(db.orderItems)..where((t) => t.orderId.equals(ord2.id))).get();
      expect(ord2Items.length, 2);

      // Scenario 4: Ready — fully paid
      final ord4 = orders.firstWhere((o) => o.orderNumber == '26-004');
      expect(ord4.status, 'ready');
      final ord4Payments = await (db.select(db.payments)..where((t) => t.orderId.equals(ord4.id))).get();
      final ord4Paid = ord4Payments.fold(0, (sum, p) => sum + p.amount);
      expect(ord4Paid, ord4.total);

      // Scenario 5: Ready — remaining balance
      final ord5 = orders.firstWhere((o) => o.orderNumber == '26-005');
      expect(ord5.status, 'ready');
      final ord5Payments = await (db.select(db.payments)..where((t) => t.orderId.equals(ord5.id))).get();
      final ord5Paid = ord5Payments.fold(0, (sum, p) => sum + p.amount);
      expect(ord5.total - ord5Paid, greaterThan(0));

      // Scenario 6: Completed
      final ord6 = orders.firstWhere((o) => o.orderNumber == '26-006');
      expect(ord6.status, 'completed');
      expect(ord6.completedAt, isNotNull);

      // Scenario 7: Cancelled
      final ord7 = orders.firstWhere((o) => o.orderNumber == '26-007');
      expect(ord7.status, 'cancelled');
      expect(ord7.cancelledAt, isNotNull);
      expect(ord7.cancellationReason, isNotNull);

      // Scenario 8: Discounted
      final ord8 = orders.firstWhere((o) => o.orderNumber == '26-008');
      expect(ord8.discount, greaterThan(0));

      // Scenario 9: Delivery to Laundry only
      final ord9 = orders.firstWhere((o) => o.orderNumber == '26-009');
      expect(ord9.customerPickupRequested, isTrue);
      expect(ord9.customerPickupFee, greaterThan(0));
      expect(ord9.customerDeliveryRequested, isFalse);

      // Scenario 10: Delivery to Customer only
      final ord10 = orders.firstWhere((o) => o.orderNumber == '26-010');
      expect(ord10.customerPickupRequested, isFalse);
      expect(ord10.customerDeliveryRequested, isTrue);
      expect(ord10.customerDeliveryFee, greaterThan(0));

      // Scenario 11: Both delivery directions enabled
      final ord11 = orders.firstWhere((o) => o.orderNumber == '26-011');
      expect(ord11.customerPickupRequested, isTrue);
      expect(ord11.customerDeliveryRequested, isTrue);

      // Scenario 12: No delivery fees
      final ord12 = orders.firstWhere((o) => o.orderNumber == '26-012');
      expect(ord12.customerPickupRequested, isFalse);
      expect(ord12.customerDeliveryRequested, isFalse);

      // Verify multiple payment methods
      final allPayments = await db.select(db.payments).get();
      final methods = allPayments.map((p) => p.paymentMethod).toSet();
      expect(methods, containsAll(['cash', 'instapay', 'ewallet']));

      // Verify carpet with dimensions
      final carpets = await db.select(db.orderItemCarpets).get();
      expect(carpets.isNotEmpty, isTrue);

      await db.close();
    });

    test('repeated execution of DevTestData is idempotent and does NOT duplicate records', () async {
      final db = AppDatabase(NativeDatabase.memory());

      // First execution
      await DevTestData.seedDevData(db);
      final custCount1 = (await db.select(db.customers).get()).length;
      final orderCount1 = (await db.select(db.orders).get()).length;
      final itemCount1 = (await db.select(db.orderItems).get()).length;
      final payCount1 = (await db.select(db.payments).get()).length;

      // Second execution
      await DevTestData.seedDevData(db);
      final custCount2 = (await db.select(db.customers).get()).length;
      final orderCount2 = (await db.select(db.orders).get()).length;
      final itemCount2 = (await db.select(db.orderItems).get()).length;
      final payCount2 = (await db.select(db.payments).get()).length;

      expect(custCount2, custCount1);
      expect(orderCount2, orderCount1);
      expect(itemCount2, itemCount1);
      expect(payCount2, payCount1);

      await db.close();
    });

    test('E-Wallet payment from DevTestData successfully travels through domain mapping to PaymentMethod.ewallet', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await DevTestData.seedDevData(db);

      final paymentRepository = PaymentRepositoryImpl(
        paymentsDao: PaymentsDao(db),
        ordersDao: OrdersDao(db),
        syncOperationsDao: SyncOperationsDao(db),
        db: db,
      );

      // Order 16 (26-016) is fully paid with E-Wallet in DevTestData
      final orders = await db.select(db.orders).get();
      final ord16 = orders.firstWhere((o) => o.orderNumber == '26-016');

      final ord16Payments = await paymentRepository.getPaymentsForOrder(ord16.id);
      expect(ord16Payments, isNotEmpty);
      expect(ord16Payments.first.paymentMethod, equals(PaymentMethod.ewallet));
      expect(ord16Payments.first.amount.piastres, equals(8000));

      // Order 11 (26-011) also includes an E-Wallet payment
      final ord11 = orders.firstWhere((o) => o.orderNumber == '26-011');
      final ord11Payments = await paymentRepository.getPaymentsForOrder(ord11.id);
      final ewalletPayments11 = ord11Payments.where((p) => p.paymentMethod == PaymentMethod.ewallet).toList();
      expect(ewalletPayments11, isNotEmpty);
      expect(ewalletPayments11.first.paymentMethod, equals(PaymentMethod.ewallet));
      expect(ewalletPayments11.first.amount.piastres, equals(15000));

      // Order 18 (26-018) also includes an E-Wallet payment
      final ord18 = orders.firstWhere((o) => o.orderNumber == '26-018');
      final ord18Payments = await paymentRepository.getPaymentsForOrder(ord18.id);
      final ewalletPayments18 = ord18Payments.where((p) => p.paymentMethod == PaymentMethod.ewallet).toList();
      expect(ewalletPayments18, isNotEmpty);
      expect(ewalletPayments18.first.paymentMethod, equals(PaymentMethod.ewallet));
      expect(ewalletPayments18.first.amount.piastres, equals(10000));

      await db.close();
    });

    test('DevTestData storage location compatibility is internally consistent and seeded', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await DevTestData.seedDevData(db);

      // Verify storage_location_item_types has been populated
      final mappings = await db.select(db.storageLocationItemTypes).get();
      expect(mappings, isNotEmpty);
      expect(mappings.length, 9);

      final storageLocationsDao = StorageLocationsDao(db);

      // Regression Test for Task #06.3 runtime error:
      // StorageLocation 00000000-0000-0000-0006-000000000001 must be compatible with ItemType 00000000-0000-0000-0001-000000000001
      final supportedTypes = await storageLocationsDao.getSupportedItemTypeIds(DevTestData.locRackA1Id);
      expect(supportedTypes.contains(DevTestData.typeClothingId), isTrue,
          reason: 'locRackA1Id must be compatible with typeClothingId');

      // Verify clothes compatible locations (Rack A1, Rack A2, Rack B1)
      final clothingLocations = await storageLocationsDao.getCompatibleLocationsForItemType(DevTestData.typeClothingId);
      final clothingLocIds = clothingLocations.map((l) => l.id).toList();
      expect(clothingLocIds, containsAll([DevTestData.locRackA1Id, DevTestData.locRackA2Id, DevTestData.locRackB1Id]));
      expect(clothingLocIds, isNot(contains(DevTestData.locCarpetSectionId)));

      // Verify carpet compatible locations (Carpet section only)
      final carpetLocations = await storageLocationsDao.getCompatibleLocationsForItemType(DevTestData.typeCarpetsId);
      final carpetLocIds = carpetLocations.map((l) => l.id).toList();
      expect(carpetLocIds, contains(DevTestData.locCarpetSectionId));
      expect(carpetLocIds, isNot(contains(DevTestData.locRackA1Id)));

      // Verify blanket compatible locations (Blanket section)
      final blanketLocations = await storageLocationsDao.getCompatibleLocationsForItemType(DevTestData.typeBlanketsId);
      final blanketLocIds = blanketLocations.map((l) => l.id).toList();
      expect(blanketLocIds, contains(DevTestData.locBlanketSectionId));
      expect(blanketLocIds, isNot(contains(DevTestData.locRackA1Id)));

      // Verify storing an item with compatible location succeeds
      final storageRecordsDao = StorageRecordsDao(db);
      final syncDao = SyncOperationsDao(db);
      final storageRepo = StorageRepositoryImpl(
        storageRecordsDao: storageRecordsDao,
        storageLocationsDao: storageLocationsDao,
        syncOperationsDao: syncDao,
        db: db,
      );

      // Order 26-001 has no stored items
      final orders = await db.select(db.orders).get();
      final ord1 = orders.firstWhere((o) => o.orderNumber == '26-001');
      final ord1Items = await (db.select(db.orderItems)..where((t) => t.orderId.equals(ord1.id))).get();
      final unstoredClothing = ord1Items.firstWhere((i) => i.itemTypeId == DevTestData.typeClothingId);

      // Compatible location storage succeeds
      await storageRepo.bulkStoreItems(
        orderItemIds: [unstoredClothing.id],
        storageLocationId: DevTestData.locRackA1Id,
      );
      final record = await storageRepo.getActiveRecordForOrderItem(unstoredClothing.id);
      expect(record, isNotNull);
      expect(record!.storageLocationId, DevTestData.locRackA1Id);

      await db.close();
    });

    test('StorageRepository rejects incompatible storage location with Arabic error message', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await DevTestData.seedDevData(db);

      final storageLocationsDao = StorageLocationsDao(db);
      final storageRecordsDao = StorageRecordsDao(db);
      final syncDao = SyncOperationsDao(db);
      final storageRepo = StorageRepositoryImpl(
        storageRecordsDao: storageRecordsDao,
        storageLocationsDao: storageLocationsDao,
        syncOperationsDao: syncDao,
        db: db,
      );

      // Attempting to store clothing into carpet section must throw IncompatibleStorageLocationFailure
      final orders = await db.select(db.orders).get();
      final ord1 = orders.firstWhere((o) => o.orderNumber == '26-001');
      final ord1Items = await (db.select(db.orderItems)..where((t) => t.orderId.equals(ord1.id))).get();
      final clothingItem = ord1Items.firstWhere((i) => i.itemTypeId == DevTestData.typeClothingId);

      await expectLater(
        () => storageRepo.bulkStoreItems(
          orderItemIds: [clothingItem.id],
          storageLocationId: DevTestData.locCarpetSectionId,
        ),
        throwsA(
          isA<IncompatibleStorageLocationFailure>()
              .having((f) => f.message, 'message', equals('الموقع المحدد غير متوافق مع نوع العنصر')),
        ),
      );

      await db.close();
    });
  });
}
