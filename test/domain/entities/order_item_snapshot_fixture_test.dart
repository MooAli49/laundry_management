import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/storage_locations_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart' as db_pkg;
import 'package:laundry_management/data/repositories/order_repository_impl.dart';
import 'package:laundry_management/data/repositories/storage_repository_impl.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/value_objects/money.dart';

void main() {
  group('Finding 1 — OrderItem Snapshot Fixture Validity Tests', () {
    final now = DateTime.now();

    test('OrderItem strictly enforces non-empty itemTypeNameSnapshot', () {
      expect(
        () => OrderItem(
          id: 'item-1',
          orderId: 'order-1',
          itemTypeId: 'type-1',
          itemTypeNameSnapshot: '', // Empty - must throw ArgumentError
          serviceId: 'srv-1',
          serviceNameSnapshot: 'غسيل',
          pricingType: PricingType.perPiece,
          quantity: 2,
          unitPrice: const Money.fromPiastres(2500),
          calculatedTotal: const Money.fromPiastres(5000),
          createdAt: now,
          updatedAt: now,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('OrderItem itemTypeNameSnapshot cannot be empty'),
        )),
      );
    });

    test('OrderItem strictly enforces non-empty serviceNameSnapshot', () {
      expect(
        () => OrderItem(
          id: 'item-1',
          orderId: 'order-1',
          itemTypeId: 'type-1',
          itemTypeNameSnapshot: 'قميص',
          serviceId: 'srv-1',
          serviceNameSnapshot: '', // Empty - must throw ArgumentError
          pricingType: PricingType.perPiece,
          quantity: 2,
          unitPrice: const Money.fromPiastres(2500),
          calculatedTotal: const Money.fromPiastres(5000),
          createdAt: now,
          updatedAt: now,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('OrderItem serviceNameSnapshot cannot be empty'),
        )),
      );
    });

    test('Valid OrderItem with populated snapshots succeeds and preserves values', () {
      final item = OrderItem(
        id: 'item-valid',
        orderId: 'order-valid',
        itemTypeId: 'type-shirt',
        itemTypeNameSnapshot: 'قميص رجالي',
        serviceId: 'srv-wash',
        serviceNameSnapshot: 'غسيل ومكواة',
        pricingType: PricingType.perPiece,
        quantity: 3,
        unitPrice: const Money.fromPiastres(3000),
        calculatedTotal: const Money.fromPiastres(9000),
        createdAt: now,
        updatedAt: now,
      );

      expect(item.itemTypeNameSnapshot, 'قميص رجالي');
      expect(item.serviceNameSnapshot, 'غسيل ومكواة');
      expect(item.calculatedTotal, const Money.fromPiastres(9000));
    });

    test('Synthetic test fixture builder must always provide non-empty snapshot fields', () {
      // Simulates how integration test fixtures should safely construct item payload
      Map<String, dynamic> buildSyntheticItemPayload({
        required String id,
        required String itemTypeId,
        String? itemTypeNameSnapshot,
        required String serviceId,
        String? serviceNameSnapshot,
        required int quantity,
        required int unitPrice,
      }) {
        final finalItemTypeName = itemTypeNameSnapshot ?? 'ملابس';
        final finalServiceName = serviceNameSnapshot ?? 'غسيل';

        if (finalItemTypeName.trim().isEmpty) {
          throw ArgumentError('itemTypeNameSnapshot cannot be empty');
        }
        if (finalServiceName.trim().isEmpty) {
          throw ArgumentError('serviceNameSnapshot cannot be empty');
        }

        return {
          'id': id,
          'item_type_id': itemTypeId,
          'item_type_name_snapshot': finalItemTypeName,
          'service_id': serviceId,
          'service_name_snapshot': finalServiceName,
          'quantity': quantity,
          'unit_price': unitPrice,
          'calculated_total': quantity * unitPrice,
        };
      }

      final payload = buildSyntheticItemPayload(
        id: 'synthetic-item-1',
        itemTypeId: 'type-carpet',
        itemTypeNameSnapshot: 'سجاد',
        serviceId: 'srv-deep',
        serviceNameSnapshot: 'غسيل عميق',
        quantity: 2,
        unitPrice: 5000,
      );

      expect(payload['item_type_name_snapshot'], 'سجاد');
      expect(payload['service_name_snapshot'], 'غسيل عميق');
    });
  });

  group('OrderItem Defensive Fallback & Recovery Tests', () {
    late db_pkg.AppDatabase db;
    late OrdersDao ordersDao;
    late PaymentsDao paymentsDao;
    late StorageRecordsDao storageRecordsDao;
    late SyncOperationsDao syncOperationsDao;
    late OrderRepositoryImpl orderRepository;
    late StorageRepositoryImpl storageRepository;

    setUp(() async {
      db = db_pkg.AppDatabase(NativeDatabase.memory());
      ordersDao = OrdersDao(db);
      paymentsDao = PaymentsDao(db);
      storageRecordsDao = StorageRecordsDao(db);
      syncOperationsDao = SyncOperationsDao(db);

      orderRepository = OrderRepositoryImpl(
        ordersDao: ordersDao,
        storageRecordsDao: storageRecordsDao,
        syncOperationsDao: syncOperationsDao,
        paymentsDao: paymentsDao,
        db: db,
      );

      storageRepository = StorageRepositoryImpl(
        storageRecordsDao: storageRecordsDao,
        storageLocationsDao: StorageLocationsDao(db),
        syncOperationsDao: syncOperationsDao,
        ordersDao: ordersDao,
        db: db,
      );

      // Seed necessary references
      await db.into(db.customers).insert(
            db_pkg.CustomersCompanion.insert(
              id: 'cust-fallback-1',
              name: 'عميل الفحص',
              phone: '01012345678',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      await db.into(db.services).insert(
            db_pkg.ServicesCompanion.insert(
              id: 'srv-fallback-1',
              name: 'غسيل',
              pricingType: 'fixed_price',
              price: 2000,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      await db.into(db.itemTypes).insert(
            db_pkg.ItemTypesCompanion.insert(
              id: 'item-type-fallback-1',
              name: 'قميص',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
    });

    tearDown(() async {
      await db.close();
    });

    test('Raw database row with empty snapshots strictly fails domain invariant and does not fabricate data', () async {
      final now = DateTime.now();

      // Insert raw order
      await db.into(db.orders).insert(
            db_pkg.OrdersCompanion.insert(
              id: 'ord-corrupted-sim',
              orderNumber: '26-99999',
              customerId: 'cust-fallback-1',
              customerNameSnapshot: const Value('عميل الفحص'),
              customerPhoneSnapshot: const Value('01012345678'),
              status: const Value('processing'),
              expectedPickupDate: now,
              subtotal: 5000,
              discount: const Value(0),
              tax: const Value(0),
              total: 5000,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Insert raw order item with EMPTY snapshots (simulating contaminated legacy test data)
      await db.into(db.orderItems).insert(
            db_pkg.OrderItemsCompanion(
              id: const Value('item-corrupted-sim'),
              orderId: const Value('ord-corrupted-sim'),
              itemTypeId: const Value('item-type-fallback-1'),
              itemTypeNameSnapshot: const Value(''), // Empty snapshot
              serviceId: const Value('srv-fallback-1'),
              serviceNameSnapshot: const Value(''), // Empty snapshot
              pricingType: const Value('fixed_price'),
              quantity: const Value(1.0),
              unitPrice: const Value(5000),
              calculatedTotal: const Value(5000),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      // Verify getOrderItems strictly throws DatabaseFailure and does NOT silently fabricate 'ملابس'/'غسيل'
      expect(
        () => orderRepository.getOrderItems('ord-corrupted-sim'),
        throwsA(isA<DatabaseFailure>().having(
          (e) => e.message,
          'message',
          contains('OrderItem itemTypeNameSnapshot cannot be empty'),
        )),
      );

      // Verify StorageRepository also strictly fails and does NOT fabricate fake fallback values
      expect(
        () => storageRepository.getItemsRequiringStorageWithDetails(),
        throwsA(isA<DatabaseFailure>().having(
          (e) => e.message,
          'message',
          contains('OrderItem itemTypeNameSnapshot cannot be empty'),
        )),
      );
    });

    test('Valid order retains its exact historical snapshot names', () async {
      final now = DateTime.now();

      await db.into(db.orders).insert(
            db_pkg.OrdersCompanion.insert(
              id: 'ord-valid-sim',
              orderNumber: '26-88888',
              customerId: 'cust-fallback-1',
              customerNameSnapshot: const Value('عميل الفحص'),
              customerPhoneSnapshot: const Value('01012345678'),
              status: const Value('processing'),
              expectedPickupDate: now,
              subtotal: 7000,
              discount: const Value(0),
              tax: const Value(0),
              total: 7000,
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db.into(db.orderItems).insert(
            db_pkg.OrderItemsCompanion(
              id: const Value('item-valid-sim'),
              orderId: const Value('ord-valid-sim'),
              itemTypeId: const Value('item-type-fallback-1'),
              itemTypeNameSnapshot: const Value('بدلة كاملة فاخرة'),
              serviceId: const Value('srv-fallback-1'),
              serviceNameSnapshot: const Value('تنظيف جاف وكي'),
              pricingType: const Value('fixed_price'),
              quantity: const Value(1.0),
              unitPrice: const Value(7000),
              calculatedTotal: const Value(7000),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      final items = await orderRepository.getOrderItems('ord-valid-sim');
      expect(items.length, 1);
      expect(items.first.itemTypeNameSnapshot, 'بدلة كاملة فاخرة');
      expect(items.first.serviceNameSnapshot, 'تنظيف جاف وكي');
    });
  });
}
