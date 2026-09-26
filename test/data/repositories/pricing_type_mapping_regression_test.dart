import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/services_dao.dart';
import 'package:laundry_management/data/local/daos/storage_locations_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/daos/sync_state_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart'
    as app_db;
import 'package:laundry_management/data/remote/dto/sync_change_dto.dart';
import 'package:laundry_management/data/repositories/order_repository_impl.dart';
import 'package:laundry_management/data/repositories/service_repository_impl.dart';
import 'package:laundry_management/data/repositories/storage_repository_impl.dart';
import 'package:laundry_management/data/sync/remote_change_applier.dart';
import 'package:laundry_management/domain/entities/carpet_item_data.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/entities/service.dart';
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
      expect(
        PricingType.fromValue('fixed_price'),
        equals(PricingType.fixedPrice),
      );
    });

    test('maps all Dart enum names (camelCase) correctly for backward compatibility', () {
      expect(PricingType.fromValue('perPiece'), equals(PricingType.perPiece));
      expect(
        PricingType.fromValue('perSquareMeter'),
        equals(PricingType.perSquareMeter),
      );
      expect(
        PricingType.fromValue('fixedPrice'),
        equals(PricingType.fixedPrice),
      );
    });

    test('throws ArgumentError on invalid pricing type value', () {
      expect(
        () => PricingType.fromValue('invalid_pricing_type'),
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
    late SyncStateDao syncStateDao;

    late OrderRepositoryImpl orderRepository;
    late ServiceRepositoryImpl serviceRepository;
    late StorageRepositoryImpl storageRepository;
    late RemoteChangeApplier remoteChangeApplier;

    setUp(() async {
      db = app_db.AppDatabase(NativeDatabase.memory());
      ordersDao = OrdersDao(db);
      storageRecordsDao = StorageRecordsDao(db);
      storageLocationsDao = StorageLocationsDao(db);
      servicesDao = ServicesDao(db);
      syncOperationsDao = SyncOperationsDao(db);
      syncStateDao = SyncStateDao(db);

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

      remoteChangeApplier = RemoteChangeApplier(
        db: db,
        syncStateDao: syncStateDao,
      );

      // Seed necessary foreign keys
      final now = DateTime.now();
      await db.customStatement(
        'INSERT OR REPLACE INTO customers (id, name, phone, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
        ['cust-1', 'عميل تجريبي', '01012345678', now.millisecondsSinceEpoch ~/ 1000, now.millisecondsSinceEpoch ~/ 1000],
      );

      await db.customStatement(
        'INSERT OR REPLACE INTO item_types (id, name, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
        ['type-carpet', 'سجاد', 1, now.millisecondsSinceEpoch ~/ 1000, now.millisecondsSinceEpoch ~/ 1000],
      );

      await db.customStatement(
        'INSERT OR REPLACE INTO services (id, name, pricing_type, price, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
        ['srv-1', 'غسيل سجاد', 'per_square_meter', 3000, 1, now.millisecondsSinceEpoch ~/ 1000, now.millisecondsSinceEpoch ~/ 1000],
      );

      await db.customStatement(
        'INSERT OR REPLACE INTO carpet_sizes (id, length, width, area, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
        ['size-1', 2.0, 3.0, 6.0, now.millisecondsSinceEpoch ~/ 1000, now.millisecondsSinceEpoch ~/ 1000],
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('OrderRepositoryImpl maps snake_case pricing types from SQLite correctly', () async {
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
          subtotal: 27000,
          total: 27000,
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

      // Item 3: fixed_price
      await ordersDao.insertOrderItem(
        app_db.OrderItemsCompanion.insert(
          id: 'item-fixed',
          orderId: 'ord-snake',
          itemTypeId: 'type-carpet',
          serviceId: 'srv-1',
          itemTypeNameSnapshot: 'سجاد',
          serviceNameSnapshot: 'غسيل سجاد',
          pricingType: 'fixed_price',
          quantity: 1.0,
          unitPrice: 5000,
          calculatedTotal: 5000,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final items = await orderRepository.getOrderItems('ord-snake');
      expect(items.length, equals(3));

      final pieceItem = items.firstWhere((i) => i.id == 'item-piece');
      final sqmItem = items.firstWhere((i) => i.id == 'item-sqm');
      final fixedItem = items.firstWhere((i) => i.id == 'item-fixed');

      expect(pieceItem.pricingType, equals(PricingType.perPiece));
      expect(sqmItem.pricingType, equals(PricingType.perSquareMeter));
      expect(fixedItem.pricingType, equals(PricingType.fixedPrice));
    });

    test('OrderRepositoryImpl maps camelCase pricing types for backward compatibility', () async {
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
    });

    test('Order creation writes canonical serialized pricing_type and can be read back', () async {
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
            id: 'carp-created',
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

      final created = await orderRepository.createOrder(
        order: orderToCreate,
        items: itemsToCreate,
      );

      expect(created.id, equals('ord-create'));

      // Verify what was stored in the SQLite column
      final row = await (db.select(db.orderItems)..where((t) => t.id.equals('item-created'))).getSingle();
      expect(row.pricingType, equals('per_square_meter'));

      // Re-read items via getOrderItems
      final retrievedItems = await orderRepository.getOrderItems('ord-create');
      expect(retrievedItems.length, equals(1));
      expect(retrievedItems.first.pricingType, equals(PricingType.perSquareMeter));
    });

    test('Remote-synchronized order item data (snake_case) applied via RemoteChangeApplier maps successfully in OrderRepository', () async {
      final now = DateTime.now().toUtc();
      final remotePayload = {
        'id': 'ord-remote',
        'order_number': 'ORD-REMOTE-01',
        'customer_id': 'cust-1',
        'customer_name_snapshot': 'عميل تجريبي',
        'customer_phone_snapshot': '01012345678',
        'status': 'processing',
        'expected_pickup_date': now.toIso8601String(),
        'subtotal': 18000,
        'discount': 0,
        'tax': 0,
        'total': 18000,
        'items': [
          {
            'id': 'item-remote-sqm',
            'order_id': 'ord-remote',
            'item_type_id': 'type-carpet',
            'service_id': 'srv-1',
            'item_type_name_snapshot': 'سجاد',
            'service_name_snapshot': 'غسيل سجاد',
            'pricing_type': 'per_square_meter', // Serialized snake_case from backend
            'quantity': 6.0,
            'unit_price': 3000,
            'calculated_total': 18000,
            'carpet_data': {
              'id': 'carp-remote-1',
              'order_item_id': 'item-remote-sqm',
              'carpet_size_id': 'size-1',
              'length': 2.0,
              'width': 3.0,
              'area': 6.0,
              'created_at': now.toIso8601String(),
              'updated_at': now.toIso8601String(),
            },
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          },
        ],
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      // Apply remote change
      await remoteChangeApplier.applyBatch([
        SyncChangeDto(
          sequence: 1,
          operationId: 'op-1',
          entityType: 'order',
          entityId: 'ord-remote',
          operationType: 'create',
          payload: remotePayload,
          createdAt: now,
        ),
      ]);

      // Read back via OrderRepositoryImpl
      final order = await orderRepository.getOrderById('ord-remote');
      expect(order, isNotNull);

      final items = await orderRepository.getOrderItems('ord-remote');
      expect(items.length, equals(1));
      expect(items.first.pricingType, equals(PricingType.perSquareMeter));
      expect(items.first.carpetData, isNotNull);
      expect(items.first.carpetData!.area, equals(6.0));
    });

    test('ServiceRepositoryImpl correctly maps snake_case and camelCase pricing_type', () async {
      final now = DateTime.now();

      // Insert service with snake_case
      await servicesDao.insertService(
        app_db.ServicesCompanion.insert(
          id: 'srv-snake',
          name: 'خدمة تسعير ثابت',
          pricingType: 'fixed_price',
          price: 5000,
          isActive: const drift.Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final serviceSnake = await serviceRepository.getServiceById('srv-snake');
      expect(serviceSnake, isNotNull);
      expect(serviceSnake!.pricingType, equals(PricingType.fixedPrice));

      // Insert service with camelCase
      await servicesDao.insertService(
        app_db.ServicesCompanion.insert(
          id: 'srv-camel',
          name: 'خدمة بالمتر',
          pricingType: 'perSquareMeter',
          price: 4000,
          isActive: const drift.Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final serviceCamel = await serviceRepository.getServiceById('srv-camel');
      expect(serviceCamel, isNotNull);
      expect(serviceCamel!.pricingType, equals(PricingType.perSquareMeter));

      // Create new service via repository writes canonical value
      final created = await serviceRepository.createService(
        Service(
          id: 'srv-new',
          name: 'خدمة بالقطعة جديدة',
          description: null,
          pricingType: PricingType.perPiece,
          price: const Money.fromPiastres(1500),
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
        supportedItemTypeIds: ['type-carpet'],
      );

      expect(created.pricingType, equals(PricingType.perPiece));
      final dbRow = await servicesDao.getServiceById('srv-new');
      expect(dbRow!.pricingType, equals('per_piece'));
    });

    test('StorageRepositoryImpl correctly maps order items requiring storage with snake_case and camelCase pricing_type', () async {
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

      final unstoredItems = await storageRepository.getItemsRequiringStorageWithDetails();
      expect(unstoredItems, isNotEmpty);
      final target = unstoredItems.firstWhere((i) => i.orderItem.id == 'item-st-sqm');
      expect(target.orderItem.pricingType, equals(PricingType.perSquareMeter));
      expect(target.orderStatus, equals(OrderStatus.ready));
    });
  });
}
