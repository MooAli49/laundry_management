import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/services_dao.dart';
import 'package:laundry_management/data/local/daos/storage_locations_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart'
    as app_db;
import 'package:laundry_management/data/repositories/order_repository_impl.dart';
import 'package:laundry_management/data/repositories/service_repository_impl.dart';
import 'package:laundry_management/data/repositories/storage_repository_impl.dart';
import 'package:laundry_management/domain/entities/carpet_item_data.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/entities/service.dart';
import 'package:laundry_management/domain/entities/service_item_type.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';

void main() {
  group('PricingType Domain Enum Mapping', () {
    test('maps all serialized snake_case values correctly', () {
      expect(PricingType.fromValue('per_piece'), equals(PricingType.perPiece));
      expect(
        PricingType.fromValue('per_square_meter'),
        equals(PricingType.perSquareMeter),
      );
    });

    test(
      'maps all Dart enum names (camelCase) correctly for backward compatibility',
      () {
        expect(PricingType.fromValue('perPiece'), equals(PricingType.perPiece));
        expect(
          PricingType.fromValue('perSquareMeter'),
          equals(PricingType.perSquareMeter),
        );
      },
    );

    test('throws ArgumentError on invalid pricing type value or removed fixedPrice', () {
      expect(
        () => PricingType.fromValue('invalid_pricing_type'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => PricingType.fromValue('fixed_price'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => PricingType.fromValue('fixedPrice'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('OrderRepositoryImpl & PricingType Mapping Regression', () {
    late app_db.AppDatabase db;
    late OrdersDao ordersDao;
    late StorageRecordsDao storageRecordsDao;
    late StorageLocationsDao storageLocationsDao;
    late ServicesDao servicesDao;
    late SyncOperationsDao syncOperationsDao;

    late OrderRepositoryImpl orderRepository;
    late ServiceRepositoryImpl serviceRepository;
    late StorageRepositoryImpl storageRepository;

    setUp(() async {
      db = app_db.AppDatabase(NativeDatabase.memory());
      ordersDao = OrdersDao(db);
      storageRecordsDao = StorageRecordsDao(db);
      storageLocationsDao = StorageLocationsDao(db);
      servicesDao = ServicesDao(db);
      syncOperationsDao = SyncOperationsDao(db);

      orderRepository = OrderRepositoryImpl(
        ordersDao: ordersDao,
        paymentsDao: PaymentsDao(db),
        storageRecordsDao: storageRecordsDao,
        syncOperationsDao: syncOperationsDao,
        db: db,
      );

      serviceRepository = ServiceRepositoryImpl(
        servicesDao: servicesDao,
        syncOperationsDao: syncOperationsDao,
        db: db,
      );

      storageRepository = StorageRepositoryImpl(
        storageRecordsDao: storageRecordsDao,
        storageLocationsDao: storageLocationsDao,
        syncOperationsDao: syncOperationsDao,
        ordersDao: ordersDao,
        db: db,
      );

      // Seed necessary foreign keys
      final now = DateTime.now();
      await db.customStatement(
        'INSERT OR REPLACE INTO customers (id, name, phone, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
        [
          'cust-1',
          'عميل تجريبي',
          '01012345678',
          now.millisecondsSinceEpoch ~/ 1000,
          now.millisecondsSinceEpoch ~/ 1000,
        ],
      );

      await db.customStatement(
        'INSERT OR REPLACE INTO item_types (id, name, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
        [
          'type-carpet',
          'سجاد',
          1,
          now.millisecondsSinceEpoch ~/ 1000,
          now.millisecondsSinceEpoch ~/ 1000,
        ],
      );

      await db.customStatement(
        'INSERT OR REPLACE INTO services (id, name, is_active, created_at, updated_at) VALUES (?, ?, 1, ?, ?)',
        [
          'srv-1',
          'غسيل سجاد',
          now.millisecondsSinceEpoch ~/ 1000,
          now.millisecondsSinceEpoch ~/ 1000,
        ],
      );

      await db.customStatement(
        'INSERT OR REPLACE INTO service_item_types (id, service_id, item_type_id, pricing_type, price, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          'sit-srv1-carpet',
          'srv-1',
          'type-carpet',
          'per_square_meter',
          3000,
          now.millisecondsSinceEpoch ~/ 1000,
          now.millisecondsSinceEpoch ~/ 1000,
        ],
      );

      await db.customStatement(
        'INSERT OR REPLACE INTO carpet_sizes (id, length, width, area, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
        [
          'size-1',
          2.0,
          3.0,
          6.0,
          now.millisecondsSinceEpoch ~/ 1000,
          now.millisecondsSinceEpoch ~/ 1000,
        ],
      );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'OrderRepositoryImpl maps snake_case pricing types from SQLite correctly',
      () async {
        final now = DateTime.now();

        // Insert order directly with snake_case order items
        await ordersDao.insertOrder(
          app_db.OrdersCompanion.insert(
            id: 'ord-snake',
            orderNumber: 'ORD-001',
            customerId: 'cust-1',
            customerNameSnapshot: const drift.Value('عميل تجريبي'),
            customerPhoneSnapshot: const drift.Value('01012345678'),
            status: const drift.Value('processing'),
            expectedPickupDate: now,
            subtotal: 22000,
            total: 22000,
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Item 1: per_piece
        await ordersDao.insertOrderItem(
          app_db.OrderItemsCompanion.insert(
            id: 'item-piece',
            orderId: 'ord-snake',
            itemTypeId: 'type-carpet',
            serviceId: 'srv-1',
            itemTypeNameSnapshot: 'سجاد',
            serviceNameSnapshot: 'غسيل سجاد',
            pricingType: 'per_piece',
            quantity: 2.0,
            unitPrice: 2000,
            calculatedTotal: 4000,
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Item 2: per_square_meter
        await ordersDao.insertOrderItem(
          app_db.OrderItemsCompanion.insert(
            id: 'item-sqm',
            orderId: 'ord-snake',
            itemTypeId: 'type-carpet',
            serviceId: 'srv-1',
            itemTypeNameSnapshot: 'سجاد',
            serviceNameSnapshot: 'غسيل سجاد',
            pricingType: 'per_square_meter',
            quantity: 6.0,
            unitPrice: 3000,
            calculatedTotal: 18000,
            createdAt: now,
            updatedAt: now,
          ),
        );

        final items = await orderRepository.getOrderItems('ord-snake');
        expect(items.length, equals(2));

        final pieceItem = items.firstWhere((i) => i.id == 'item-piece');
        final sqmItem = items.firstWhere((i) => i.id == 'item-sqm');

        expect(pieceItem.pricingType, equals(PricingType.perPiece));
        expect(sqmItem.pricingType, equals(PricingType.perSquareMeter));
      },
    );

    test(
      'OrderRepositoryImpl maps camelCase pricing types for backward compatibility',
      () async {
        final now = DateTime.now();

        await ordersDao.insertOrder(
          app_db.OrdersCompanion.insert(
            id: 'ord-camel',
            orderNumber: 'ORD-002',
            customerId: 'cust-1',
            customerNameSnapshot: const drift.Value('عميل تجريبي'),
            customerPhoneSnapshot: const drift.Value('01012345678'),
            status: const drift.Value('processing'),
            expectedPickupDate: now,
            subtotal: 18000,
            total: 18000,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await ordersDao.insertOrderItem(
          app_db.OrderItemsCompanion.insert(
            id: 'item-camel-sqm',
            orderId: 'ord-camel',
            itemTypeId: 'type-carpet',
            serviceId: 'srv-1',
            itemTypeNameSnapshot: 'سجاد',
            serviceNameSnapshot: 'غسيل سجاد',
            pricingType: 'perSquareMeter',
            quantity: 6.0,
            unitPrice: 3000,
            calculatedTotal: 18000,
            createdAt: now,
            updatedAt: now,
          ),
        );

        final items = await orderRepository.getOrderItems('ord-camel');
        expect(items.length, equals(1));
        expect(items.first.pricingType, equals(PricingType.perSquareMeter));
      },
    );

    test(
      'Order creation writes canonical serialized pricing_type and can be read back',
      () async {
        final now = DateTime.now();
        final orderToCreate = Order(
          id: 'ord-create',
          orderNumber: 'ORD-003',
          customerId: 'cust-1',
          customerNameSnapshot: 'عميل تجريبي',
          customerPhoneSnapshot: '01012345678',
          status: OrderStatus.processing,
          expectedPickupDate: OrderDate.fromDate(now),
          subtotal: const Money.fromPiastres(18000),
          discount: Money.zero,
          tax: Money.zero,
          total: const Money.fromPiastres(18000),
          createdAt: now,
          updatedAt: now,
        );

        final itemsToCreate = [
          OrderItem(
            id: 'item-created',
            orderId: 'ord-create',
            itemTypeId: 'type-carpet',
            serviceId: 'srv-1',
            itemTypeNameSnapshot: 'سجاد',
            serviceNameSnapshot: 'غسيل سجاد',
            pricingType: PricingType.perSquareMeter,
            quantity: 6.0,
            unitPrice: const Money.fromPiastres(3000),
            calculatedTotal: const Money.fromPiastres(18000),
            carpetData: CarpetItemData(
              id: 'carpet-data-1',
              orderItemId: 'item-created',
              carpetSizeId: 'size-1',
              length: 2.0,
              width: 3.0,
              area: 6.0,
              createdAt: now,
              updatedAt: now,
            ),
            createdAt: now,
            updatedAt: now,
          ),
        ];

        await orderRepository.createOrder(
          order: orderToCreate,
          items: itemsToCreate,
        );

        final dbRow = await (db.select(db.orderItems)
              ..where((t) => t.orderId.equals('ord-create')))
            .get();
        expect(dbRow.length, equals(1));
        expect(dbRow.first.pricingType, equals('per_square_meter'));

        final items = await orderRepository.getOrderItems('ord-create');
        expect(items.length, equals(1));
        expect(items.first.pricingType, equals(PricingType.perSquareMeter));
        expect(items.first.carpetData, isNotNull);
        expect(items.first.carpetData!.area, equals(6.0));
      },
    );

    test(
      'ServiceRepositoryImpl correctly handles service with ServiceItemType pricing',
      () async {
        final now = DateTime.now();

        // Create new service via repository writes canonical values
        final created = await serviceRepository.createService(
          Service(
            id: 'srv-new',
            name: 'خدمة بالقطعة جديدة',
            description: null,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ),
          serviceItemTypes: [
            ServiceItemType(
              id: 'sit-new',
              serviceId: 'srv-new',
              itemTypeId: 'type-carpet',
              pricingType: PricingType.perPiece,
              price: const Money.fromPiastres(1500),
              createdAt: now,
              updatedAt: now,
            ),
          ],
        );

        expect(created.name, equals('خدمة بالقطعة جديدة'));
        final sits = await serviceRepository.getServiceItemTypes('srv-new');
        expect(sits.length, equals(1));
        expect(sits.first.pricingType, equals(PricingType.perPiece));
        expect(sits.first.price, equals(const Money.fromPiastres(1500)));

        final compatible = await serviceRepository.getServicesForItemType('type-carpet');
        expect(compatible.any((s) => s.id == 'srv-new'), isTrue);
        final swp = compatible.firstWhere((s) => s.id == 'srv-new');
        expect(swp.pricingType, equals(PricingType.perPiece));
        expect(swp.price, equals(const Money.fromPiastres(1500)));
      },
    );

    test(
      'StorageRepositoryImpl correctly maps order items requiring storage with snake_case and camelCase pricing_type',
      () async {
        final now = DateTime.now();

        // Create order with ready status
        await ordersDao.insertOrder(
          app_db.OrdersCompanion.insert(
            id: 'ord-storage-test',
            orderNumber: 'ORD-ST-01',
            customerId: 'cust-1',
            customerNameSnapshot: const drift.Value('عميل تجريبي'),
            customerPhoneSnapshot: const drift.Value('01012345678'),
            status: const drift.Value('ready'),
            expectedPickupDate: now,
            subtotal: 18000,
            total: 18000,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await ordersDao.insertOrderItem(
          app_db.OrderItemsCompanion.insert(
            id: 'item-st-sqm',
            orderId: 'ord-storage-test',
            itemTypeId: 'type-carpet',
            serviceId: 'srv-1',
            itemTypeNameSnapshot: 'سجاد',
            serviceNameSnapshot: 'غسيل سجاد',
            pricingType: 'per_square_meter',
            quantity: 6.0,
            unitPrice: 3000,
            calculatedTotal: 18000,
            createdAt: now,
            updatedAt: now,
          ),
        );

        final unstoredItems = await storageRepository
            .getItemsRequiringStorageWithDetails();
        expect(unstoredItems, isNotEmpty);
        final target = unstoredItems.firstWhere(
          (i) => i.orderItem.id == 'item-st-sqm',
        );
        expect(
          target.orderItem.pricingType,
          equals(PricingType.perSquareMeter),
        );
        expect(target.orderStatus, equals(OrderStatus.ready));
      },
    );
  });
}
