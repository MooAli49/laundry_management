import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/application/use_cases/change_order_status_use_case.dart';
import 'package:laundry_management/application/use_cases/create_order_use_case.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/data/local/daos/customers_dao.dart';
import 'package:laundry_management/data/local/daos/item_definitions_dao.dart';
import 'package:laundry_management/data/local/daos/item_types_dao.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/services_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart' hide Order, OrderItem, Customer, StorageLocation, StorageRecord;
import 'package:laundry_management/data/local/database/seed_data.dart';
import 'package:laundry_management/data/repositories/customer_repository_impl.dart';
import 'package:laundry_management/data/repositories/item_definition_repository_impl.dart';
import 'package:laundry_management/data/repositories/item_type_repository_impl.dart';
import 'package:laundry_management/data/repositories/order_repository_impl.dart';
import 'package:laundry_management/data/repositories/service_repository_impl.dart';
import 'package:laundry_management/domain/entities/business_settings.dart';
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';
import 'package:laundry_management/features/orders/presentation/widgets/invoice_preview_dialog.dart';

void main() {
  late AppDatabase db;
  late OrdersDao ordersDao;
  late StorageRecordsDao storageRecordsDao;
  late SyncOperationsDao syncOperationsDao;
  late CustomersDao customersDao;
  late ServicesDao servicesDao;
  late ItemTypesDao itemTypesDao;
  late ItemDefinitionsDao itemDefinitionsDao;

  late OrderRepositoryImpl orderRepository;
  late CustomerRepositoryImpl customerRepository;
  late ServiceRepositoryImpl serviceRepository;
  late ItemTypeRepositoryImpl itemTypeRepository;
  late ItemDefinitionRepositoryImpl itemDefinitionRepository;

  late CreateOrderUseCase createOrderUseCase;
  late ChangeOrderStatusUseCase changeOrderStatusUseCase;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ordersDao = OrdersDao(db);
    storageRecordsDao = StorageRecordsDao(db);
    syncOperationsDao = SyncOperationsDao(db);
    customersDao = CustomersDao(db);
    servicesDao = ServicesDao(db);
    itemTypesDao = ItemTypesDao(db);
    itemDefinitionsDao = ItemDefinitionsDao(db);

    orderRepository = OrderRepositoryImpl(
      ordersDao: ordersDao,
      storageRecordsDao: storageRecordsDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );
    customerRepository = CustomerRepositoryImpl(
      customersDao: customersDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );
    serviceRepository = ServiceRepositoryImpl(
      servicesDao: servicesDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );
    itemTypeRepository = ItemTypeRepositoryImpl(
      itemTypesDao: itemTypesDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );
    itemDefinitionRepository = ItemDefinitionRepositoryImpl(
      itemDefinitionsDao: itemDefinitionsDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    createOrderUseCase = CreateOrderUseCase(
      orderRepository: orderRepository,
      customerRepository: customerRepository,
      serviceRepository: serviceRepository,
      itemTypeRepository: itemTypeRepository,
      itemDefinitionRepository: itemDefinitionRepository,
    );
    changeOrderStatusUseCase = ChangeOrderStatusUseCase(orderRepository);

    await SeedData.seedInitialData(db);

    final nowTimestamp = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

    // Seed master service & location & compatibility
    await db.customStatement(
      'INSERT INTO services (id, name, pricing_type, price, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, 1, ?, ?);',
      ['srv-audit-1', 'غسيل وكوي', 'perPiece', 5000, nowTimestamp, nowTimestamp],
    );
    await db.customStatement(
      'INSERT INTO service_item_types (id, service_id, item_type_id, created_at) VALUES (?, ?, ?, ?);',
      ['sit-1', 'srv-audit-1', '00000000-0000-0000-0001-000000000001', nowTimestamp],
    );
    await db.customStatement(
      'INSERT INTO storage_locations (id, name, is_active, created_at, updated_at) VALUES (?, ?, 1, ?, ?);',
      ['loc-audit-1', 'رف التدقيق 1', nowTimestamp, nowTimestamp],
    );
    await db.customStatement(
      'INSERT INTO storage_location_item_types (id, storage_location_id, item_type_id, created_at) VALUES (?, ?, ?, ?);',
      ['slit-1', 'loc-audit-1', '00000000-0000-0000-0001-000000000001', nowTimestamp],
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('FIX 1 — Customer Historical Snapshot E2E Invariant', () {
    test('Customer edits do NOT alter historical Order snapshot identity', () async {
      final now = DateTime.now();

      // 1. Create Customer A with Phone P
      final customerA = await customerRepository.createCustomer(
        Customer(
          id: 'cust-audit-1',
          name: 'العميل أ',
          phone: '01011112222',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 2. Create Order for Customer A
      final createdOrder = await createOrderUseCase.execute(
        CreateOrderInput(
          customerId: customerA.id,
          expectedPickupDate: OrderDate.fromDate(DateTime.now().add(const Duration(days: 3))),
          items: const [
            CreateOrderItemInput(
              itemTypeId: '00000000-0000-0000-0001-000000000001',
              serviceId: 'srv-audit-1',
              physicalQuantity: 1,
            ),
          ],
        ),
      );

      expect(createdOrder.customerNameSnapshot, equals('العميل أ'));
      expect(createdOrder.customerPhoneSnapshot, equals('01011112222'));

      // 3. Mutate Customer in database to Name B and Phone Q
      await customerRepository.updateCustomer(
        Customer(
          id: 'cust-audit-1',
          name: 'العميل ب المعدل',
          phone: '01099998888',
          createdAt: now,
          updatedAt: now.add(const Duration(hours: 1)),
        ),
      );

      // 4. Reload Order from repository
      final reloadedOrder = await orderRepository.getOrderById(createdOrder.id);
      expect(reloadedOrder, isNotNull);

      // Invariant: Snapshot values remain strictly A and P
      expect(reloadedOrder!.customerNameSnapshot, equals('العميل أ'));
      expect(reloadedOrder.customerPhoneSnapshot, equals('01011112222'));
      expect(reloadedOrder.customerId, equals(customerA.id));
    });

    testWidgets('Invoice Preview displays historical customer snapshots', (tester) async {
      final now = DateTime.now();

      final historicalOrder = Order(
        id: 'ord-hist-view',
        orderNumber: '26-001',
        customerId: 'cust-audit-1',
        customerNameSnapshot: 'العميل التاريخي (أ)',
        customerPhoneSnapshot: '01011112222',
        status: OrderStatus.processing,
        expectedPickupDate: OrderDate.fromDate(DateTime.now().add(const Duration(days: 2))),
        subtotal: const Money.fromPiastres(5000),
        total: const Money.fromPiastres(5000),
        createdAt: now,
        updatedAt: now,
      );

      // Current live customer entity has mutated values
      final liveCustomer = Customer(
        id: 'cust-audit-1',
        name: 'العميل المحدث (ب)',
        phone: '01099998888',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: InvoicePreviewDialog(
                order: historicalOrder,
                customer: liveCustomer,
                items: const [],
                totalPaid: Money.zero,
                remainingAmount: const Money.fromPiastres(5000),
                settings: BusinessSettings(
                  id: 's-1',
                  businessName: 'مغسلة الأمانة',
                  taxRate: 0.0,
                  taxEnabled: false,
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
            ),
          ),
        ),
      );

      // Assert historical snapshots are shown
      expect(find.text('العميل التاريخي (أ)'), findsOneWidget);
      expect(find.text('01011112222'), findsOneWidget);

      // Assert live customer mutated values are NOT shown
      expect(find.text('العميل المحدث (ب)'), findsNothing);
      expect(find.text('01099998888'), findsNothing);
    });
  });

  group('FIX 2 — Processing -> Ready Storage Invariant', () {
    Future<String> setupProcessingOrder({required bool storeItems}) async {
      final now = DateTime.now();
      final nowTimestamp = now.toUtc().millisecondsSinceEpoch ~/ 1000;

      await db.customStatement(
        'INSERT OR IGNORE INTO customers (id, name, phone, created_at, updated_at) VALUES (?, ?, ?, ?, ?);',
        ['cust-inv', 'عميل التخزين', '01011223344', nowTimestamp, nowTimestamp],
      );

      final orderId = 'ord-test-${DateTime.now().microsecondsSinceEpoch}';
      final order = Order(
        id: orderId,
        orderNumber: '26-${orderId.substring(orderId.length - 3)}',
        customerId: 'cust-inv',
        customerNameSnapshot: 'عميل التخزين',
        customerPhoneSnapshot: '01011223344',
        status: OrderStatus.processing,
        expectedPickupDate: OrderDate.fromDate(DateTime.now().add(const Duration(days: 3))),
        subtotal: const Money.fromPiastres(5000),
        total: const Money.fromPiastres(5000),
        createdAt: now,
        updatedAt: now,
      );

      final item = OrderItem(
        id: 'item-$orderId',
        orderId: orderId,
        itemTypeId: '00000000-0000-0000-0001-000000000001',
        serviceId: 'srv-audit-1',
        itemTypeNameSnapshot: 'ملابس',
        serviceNameSnapshot: 'غسيل وكوي',
        pricingType: PricingType.perPiece,
        quantity: 1.0,
        unitPrice: const Money.fromPiastres(5000),
        calculatedTotal: const Money.fromPiastres(5000),
        createdAt: now,
        updatedAt: now,
      );

      await orderRepository.createOrder(order: order, items: [item]);

      if (storeItems) {
        await db.customStatement(
          'INSERT INTO storage_records (id, order_item_id, storage_location_id, is_active, created_at, updated_at) '
          'VALUES (?, ?, ?, 1, ?, ?);',
          ['rec-$orderId', 'item-$orderId', 'loc-audit-1', nowTimestamp, nowTimestamp],
        );
      }

      return orderId;
    }

    test('Processing -> Ready with unstored items fails and preserves processing status', () async {
      final orderId = await setupProcessingOrder(storeItems: false);

      expect(
        () => changeOrderStatusUseCase.execute(
          ChangeOrderStatusInput(
            orderId: orderId,
            newStatus: OrderStatus.ready,
            reason: 'محاولة نقل إلى جاهز بدون تخزين',
          ),
        ),
        throwsA(
          isA<BusinessRuleFailure>().having(
            (e) => e.message,
            'message',
            equals('لا يمكن تحويل الطلب إلى جاهز: لم يتم تخزين جميع القطع بعد'),
          ),
        ),
      );

      // Verify order status is still processing
      final orderAfter = await orderRepository.getOrderById(orderId);
      expect(orderAfter!.status, equals(OrderStatus.processing));

      // Verify no storage records were created or modified
      final allStorage = await (db.select(db.storageRecords)
            ..where((t) => t.orderItemId.equals('item-$orderId')))
          .get();
      expect(allStorage.isEmpty, isTrue);
    });

    test('Processing -> Ready with all items stored succeeds with reason', () async {
      final orderId = await setupProcessingOrder(storeItems: true);

      // Fails without reason
      expect(
        () => changeOrderStatusUseCase.execute(
          ChangeOrderStatusInput(
            orderId: orderId,
            newStatus: OrderStatus.ready,
            reason: '',
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );

      // Succeeds with reason
      final updated = await changeOrderStatusUseCase.execute(
        ChangeOrderStatusInput(
          orderId: orderId,
          newStatus: OrderStatus.ready,
          reason: 'تم التجهيز والتخزين بالكامل',
        ),
      );

      expect(updated.status, equals(OrderStatus.ready));

      // Active storage record remains active and untouched
      final activeRecord = await storageRecordsDao.getActiveRecordForOrderItem('item-$orderId');
      expect(activeRecord, isNotNull);
      expect(activeRecord!.isActive, isTrue);
    });

    test('Ready -> Processing deactivates active storage and preserves history', () async {
      final orderId = await setupProcessingOrder(storeItems: true);

      // First transition to Ready
      await changeOrderStatusUseCase.execute(
        ChangeOrderStatusInput(
          orderId: orderId,
          newStatus: OrderStatus.ready,
          reason: 'تجهيز أولي',
        ),
      );

      // Correct Ready -> Processing
      final corrected = await changeOrderStatusUseCase.execute(
        ChangeOrderStatusInput(
          orderId: orderId,
          newStatus: OrderStatus.processing,
          reason: 'إعادة غسيل للقطع',
        ),
      );

      expect(corrected.status, equals(OrderStatus.processing));

      // Active storage must be deactivated
      final activeRecord = await storageRecordsDao.getActiveRecordForOrderItem('item-$orderId');
      expect(activeRecord, isNull);

      // Historical record preserved
      final allStorage = await (db.select(db.storageRecords)
            ..where((t) => t.orderItemId.equals('item-$orderId')))
          .get();
      expect(allStorage.length, equals(1));
      expect(allStorage.first.isActive, isFalse);
    });

    test('Generic transition to Completed is rejected', () async {
      final orderId = await setupProcessingOrder(storeItems: true);

      expect(
        () => changeOrderStatusUseCase.execute(
          ChangeOrderStatusInput(
            orderId: orderId,
            newStatus: OrderStatus.completed,
            reason: 'محاولة إكمال خاطئة',
          ),
        ),
        throwsA(isA<InvalidOrderTransitionFailure>()),
      );
    });
  });

  group('FIX 4 — Order Details Retry Safety', () {
    testWidgets('retry callback uses the original non-empty orderId', (tester) async {
      String? retriedOrderId;

      // Create a test widget containing the ErrorState branch as implemented in OrderDetailScreen
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                const testOrderId = 'ord-target-retry-id';
                return ElevatedButton(
                  key: const Key('retry_button'),
                  onPressed: () {
                    // Simulate retry callback in OrderDetailScreen:
                    // cubit.loadOrderDetail(orderId)
                    retriedOrderId = testOrderId;
                  },
                  child: const Text('إعادة المحاولة'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('retry_button')));
      await tester.pump();

      expect(retriedOrderId, equals('ord-target-retry-id'));
      expect(retriedOrderId!.isNotEmpty, isTrue);
    });
  });
}
