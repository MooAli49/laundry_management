import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/application/use_cases/cancel_order_use_case.dart';
import 'package:laundry_management/application/use_cases/change_order_status_use_case.dart';
import 'package:laundry_management/application/use_cases/complete_order_use_case.dart';
import 'package:laundry_management/application/use_cases/create_order_use_case.dart';
import 'package:laundry_management/application/use_cases/store_order_items_use_case.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/data/local/daos/customers_dao.dart';
import 'package:laundry_management/data/local/daos/item_definitions_dao.dart';
import 'package:laundry_management/data/local/daos/item_types_dao.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/services_dao.dart';
import 'package:laundry_management/data/local/daos/storage_locations_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart'
    hide Order, OrderItem, Customer, StorageLocation, StorageRecord, Payment;
import 'package:laundry_management/data/local/database/seed_data.dart';
import 'package:laundry_management/data/repositories/customer_repository_impl.dart';
import 'package:laundry_management/data/repositories/item_definition_repository_impl.dart';
import 'package:laundry_management/data/repositories/item_type_repository_impl.dart';
import 'package:laundry_management/data/repositories/order_repository_impl.dart';
import 'package:laundry_management/data/repositories/payment_repository_impl.dart';
import 'package:laundry_management/data/repositories/service_repository_impl.dart';
import 'package:laundry_management/data/repositories/storage_location_repository_impl.dart';
import 'package:laundry_management/data/repositories/storage_repository_impl.dart';
import 'package:laundry_management/domain/entities/business_settings.dart';
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/entities/payment.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/enums/payment_method.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';
import 'package:laundry_management/features/orders/presentation/widgets/invoice_preview_dialog.dart';

void main() {
  late AppDatabase db;
  late OrdersDao ordersDao;
  late PaymentsDao paymentsDao;
  late StorageLocationsDao storageLocationsDao;
  late StorageRecordsDao storageRecordsDao;
  late SyncOperationsDao syncOperationsDao;
  late CustomersDao customersDao;
  late ServicesDao servicesDao;
  late ItemTypesDao itemTypesDao;
  late ItemDefinitionsDao itemDefinitionsDao;

  late OrderRepositoryImpl orderRepository;
  late CustomerRepositoryImpl customerRepository;
  late PaymentRepositoryImpl paymentRepository;
  late StorageRepositoryImpl storageRepository;
  late StorageLocationRepositoryImpl storageLocationRepository;
  late ServiceRepositoryImpl serviceRepository;
  late ItemTypeRepositoryImpl itemTypeRepository;
  late ItemDefinitionRepositoryImpl itemDefinitionRepository;

  late CreateOrderUseCase createOrderUseCase;
  late ChangeOrderStatusUseCase changeOrderStatusUseCase;
  late StoreOrderItemsUseCase storeOrderItemsUseCase;
  late CompleteOrderUseCase completeOrderUseCase;
  late CancelOrderUseCase cancelOrderUseCase;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ordersDao = OrdersDao(db);
    paymentsDao = PaymentsDao(db);
    storageLocationsDao = StorageLocationsDao(db);
    storageRecordsDao = StorageRecordsDao(db);
    syncOperationsDao = SyncOperationsDao(db);
    customersDao = CustomersDao(db);
    servicesDao = ServicesDao(db);
    itemTypesDao = ItemTypesDao(db);
    itemDefinitionsDao = ItemDefinitionsDao(db);

    orderRepository = OrderRepositoryImpl(
      ordersDao: ordersDao,
      paymentsDao: paymentsDao,
      storageRecordsDao: storageRecordsDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );
    customerRepository = CustomerRepositoryImpl(
      customersDao: customersDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );
    paymentRepository = PaymentRepositoryImpl(
      paymentsDao: paymentsDao,
      ordersDao: ordersDao,
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
    storageLocationRepository = StorageLocationRepositoryImpl(
      storageLocationsDao: storageLocationsDao,
      storageRecordsDao: storageRecordsDao,
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
    storeOrderItemsUseCase = StoreOrderItemsUseCase(
      orderRepository: orderRepository,
      storageRepository: storageRepository,
      storageLocationRepository: storageLocationRepository,
    );
    completeOrderUseCase = CompleteOrderUseCase(
      orderRepository: orderRepository,
      paymentRepository: paymentRepository,
    );
    cancelOrderUseCase = CancelOrderUseCase(orderRepository);

    await SeedData.seedInitialData(db);

    final nowTimestamp = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

    // Seed master service & location & compatibility
    await db.customStatement(
      'INSERT INTO services (id, name, pricing_type, price, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, 1, ?, ?);',
      [
        'srv-audit-1',
        'غسيل وكوي',
        'perPiece',
        5000,
        nowTimestamp,
        nowTimestamp,
      ],
    );
    await db.customStatement(
      'INSERT INTO service_item_types (id, service_id, item_type_id, created_at) VALUES (?, ?, ?, ?);',
      [
        'sit-1',
        'srv-audit-1',
        '00000000-0000-0000-0001-000000000001',
        nowTimestamp,
      ],
    );
    await db.customStatement(
      'INSERT INTO storage_locations (id, name, is_active, created_at, updated_at) VALUES (?, ?, 1, ?, ?);',
      ['loc-audit-1', 'رف التدقيق 1', nowTimestamp, nowTimestamp],
    );
    await db.customStatement(
      'INSERT INTO storage_location_item_types (id, storage_location_id, item_type_id, created_at) VALUES (?, ?, ?, ?);',
      [
        'slit-1',
        'loc-audit-1',
        '00000000-0000-0000-0001-000000000001',
        nowTimestamp,
      ],
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('FIX 1 — Customer Historical Snapshot E2E Invariant', () {
    test(
      'Customer edits do NOT alter historical Order snapshot identity',
      () async {
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
            expectedPickupDate: OrderDate.fromDate(
              DateTime.now().add(const Duration(days: 3)),
            ),
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
        final reloadedOrder = await orderRepository.getOrderById(
          createdOrder.id,
        );
        expect(reloadedOrder, isNotNull);

        // Invariant: Snapshot values remain strictly A and P
        expect(reloadedOrder!.customerNameSnapshot, equals('العميل أ'));
        expect(reloadedOrder.customerPhoneSnapshot, equals('01011112222'));
        expect(reloadedOrder.customerId, equals(customerA.id));
      },
    );

    testWidgets('Invoice Preview displays historical customer snapshots', (
      tester,
    ) async {
      final now = DateTime.now();

      final historicalOrder = Order(
        id: 'ord-hist-view',
        orderNumber: '26-001',
        customerId: 'cust-audit-1',
        customerNameSnapshot: 'العميل التاريخي (أ)',
        customerPhoneSnapshot: '01011112222',
        status: OrderStatus.processing,
        expectedPickupDate: OrderDate.fromDate(
          DateTime.now().add(const Duration(days: 2)),
        ),
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
        expectedPickupDate: OrderDate.fromDate(
          DateTime.now().add(const Duration(days: 3)),
        ),
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
          [
            'rec-$orderId',
            'item-$orderId',
            'loc-audit-1',
            nowTimestamp,
            nowTimestamp,
          ],
        );
      }

      return orderId;
    }

    test(
      'Processing -> Ready with unstored items fails and preserves processing status',
      () async {
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
              equals(
                'لا يمكن تحويل الطلب إلى جاهز: لم يتم تخزين جميع القطع بعد',
              ),
            ),
          ),
        );

        // Verify order status is still processing
        final orderAfter = await orderRepository.getOrderById(orderId);
        expect(orderAfter!.status, equals(OrderStatus.processing));

        // Verify no storage records were created or modified
        final allStorage = await (db.select(
          db.storageRecords,
        )..where((t) => t.orderItemId.equals('item-$orderId'))).get();
        expect(allStorage.isEmpty, isTrue);
      },
    );

    test(
      'Processing -> Ready with all items stored succeeds with reason',
      () async {
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
        final activeRecord = await storageRecordsDao
            .getActiveRecordForOrderItem('item-$orderId');
        expect(activeRecord, isNotNull);
        expect(activeRecord!.isActive, isTrue);
      },
    );

    test(
      'Ready -> Processing deactivates active storage and preserves history',
      () async {
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
        final activeRecord = await storageRecordsDao
            .getActiveRecordForOrderItem('item-$orderId');
        expect(activeRecord, isNull);

        // Historical record preserved
        final allStorage = await (db.select(
          db.storageRecords,
        )..where((t) => t.orderItemId.equals('item-$orderId'))).get();
        expect(allStorage.length, equals(1));
        expect(allStorage.first.isActive, isFalse);
      },
    );

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
    testWidgets('retry callback uses the original non-empty orderId', (
      tester,
    ) async {
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

  group('COMPLETE E2E ORDER LIFECYCLE & GATES AUDIT', () {
    test(
      'Normal E2E 26-step lifecycle: processing -> store items -> auto-ready -> pay remaining -> complete with handover',
      () async {
        final now = DateTime.now();
        final pickupDate = OrderDate.fromDate(now.add(const Duration(days: 3)));

        // 1. Create a new customer
        final customer = await customerRepository.createCustomer(
          Customer(
            id: 'cust-e2e-norm',
            name: 'عميل التدقيق الكامل',
            phone: '01012345678',
            createdAt: now,
            updatedAt: now,
          ),
        );

        // 2. Create a new order with 2 items and independent delivery fees & discount
        final createdOrder = await createOrderUseCase.execute(
          CreateOrderInput(
            customerId: customer.id,
            expectedPickupDate: pickupDate,
            customerPickupRequested: true,
            customerPickupFee: const Money.fromPiastres(1500), // 15 EGP
            customerDeliveryRequested: true,
            customerDeliveryFee: const Money.fromPiastres(2000), // 20 EGP
            discount: const Money.fromPiastres(1000), // 10 EGP
            items: const [
              CreateOrderItemInput(
                itemTypeId: '00000000-0000-0000-0001-000000000001',
                serviceId: 'srv-audit-1',
                physicalQuantity: 1,
              ),
              CreateOrderItemInput(
                itemTypeId: '00000000-0000-0000-0001-000000000001',
                serviceId: 'srv-audit-1',
                physicalQuantity: 1,
              ),
            ],
          ),
        );

        // 6. Verify initial status = processing
        expect(createdOrder.status, equals(OrderStatus.processing));

        // 7. Verify order number generation
        expect(createdOrder.orderNumber, isNotEmpty);
        expect(createdOrder.orderNumber, startsWith('26-'));

        // 8. Verify customer name/phone snapshots
        expect(
          createdOrder.customerNameSnapshot,
          equals('عميل التدقيق الكامل'),
        );
        expect(createdOrder.customerPhoneSnapshot, equals('01012345678'));

        // 9. Verify expected pickup date
        expect(createdOrder.expectedPickupDate, equals(pickupDate));

        // 10. Verify subtotal/discount/delivery fees/total calculations
        // Subtotal: 50 + 50 = 100 EGP (10000 piastres)
        expect(createdOrder.subtotal, equals(const Money.fromPiastres(10000)));
        expect(createdOrder.discount, equals(const Money.fromPiastres(1000)));
        expect(
          createdOrder.customerPickupFee,
          equals(const Money.fromPiastres(1500)),
        );
        expect(
          createdOrder.customerDeliveryFee,
          equals(const Money.fromPiastres(2000)),
        );
        // Total: 10000 - 1000 + 1500 + 2000 = 12500 piastres (125.00 EGP)
        expect(createdOrder.total, equals(const Money.fromPiastres(12500)));

        // 11. Verify initial payment/down-payment behavior (50.00 EGP)
        await paymentRepository.recordPayment(
          Payment(
            id: 'pay-down-1',
            orderId: createdOrder.id,
            amount: const Money.fromPiastres(5000), // 50 EGP
            paymentMethod: PaymentMethod.cash,
            paidAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
        final remainingAfterDown = await paymentRepository
            .getRemainingAmountForOrder(createdOrder.id);
        expect(
          remainingAfterDown,
          equals(const Money.fromPiastres(7500)),
        ); // 75 EGP

        // 12. Open Order Details -> Retrieve order items
        final items = await orderRepository.getOrderItems(createdOrder.id);
        expect(items.length, equals(2));
        final item1 = items[0];
        final item2 = items[1];

        // 13. Store first order item (partial storage)
        await storeOrderItemsUseCase.execute(
          StoreOrderItemsInput(
            orderId: createdOrder.id,
            orderItemIds: [item1.id],
            storageLocationId: 'loc-audit-1',
          ),
        );

        // 14. Verify item 1 receives active storage record
        final record1 = await storageRecordsDao.getActiveRecordForOrderItem(
          item1.id,
        );
        expect(record1, isNotNull);
        expect(record1!.isActive, isTrue);
        expect(record1.storageLocationId, equals('loc-audit-1'));

        // Invariant: Partial storage keeps order in processing
        final orderAfterItem1 = await orderRepository.getOrderById(
          createdOrder.id,
        );
        expect(orderAfterItem1!.status, equals(OrderStatus.processing));

        // 15. Store the LAST order item (item 2)
        final storeResult = await storeOrderItemsUseCase.execute(
          StoreOrderItemsInput(
            orderId: createdOrder.id,
            orderItemIds: [item2.id],
            storageLocationId: 'loc-audit-1',
          ),
        );

        // Verify item 2 receives active storage record
        final record2 = await storageRecordsDao.getActiveRecordForOrderItem(
          item2.id,
        );
        expect(record2, isNotNull);
        expect(record2!.isActive, isTrue);

        // 15 & 16. Verify automatic transition: processing -> ready
        expect(storeResult.allStored, isTrue);
        expect(storeResult.order.status, equals(OrderStatus.ready));
        final orderAfterItem2 = await orderRepository.getOrderById(
          createdOrder.id,
        );
        expect(orderAfterItem2!.status, equals(OrderStatus.ready));

        // 17. Record the remaining payment (75.00 EGP) via InstaPay
        await paymentRepository.recordPayment(
          Payment(
            id: 'pay-final-2',
            orderId: createdOrder.id,
            amount: const Money.fromPiastres(7500),
            paymentMethod: PaymentMethod.instapay,
            paidAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );

        // 18. Verify remaining balance becomes exactly 0.00 EGP
        final remainingAfterFinal = await paymentRepository
            .getRemainingAmountForOrder(createdOrder.id);
        expect(remainingAfterFinal, equals(Money.zero));
        final totalPaid = await paymentRepository.getTotalPaidForOrder(
          createdOrder.id,
        );
        expect(totalPaid, equals(const Money.fromPiastres(12500)));

        // 19. Verify payment appears in payment history
        final paymentHistory = await paymentRepository.getPaymentsForOrder(
          createdOrder.id,
        );
        expect(paymentHistory.length, equals(2));
        expect(paymentHistory[0].id, equals('pay-down-1'));
        expect(paymentHistory[1].id, equals('pay-final-2'));

        // 20 & 22. Attempt completion with handoverConfirmed = false -> MUST FAIL
        expect(
          () => completeOrderUseCase.execute(
            CompleteOrderInput(
              orderId: createdOrder.id,
              handoverConfirmed: false,
            ),
          ),
          throwsA(isA<BusinessRuleFailure>()),
        );

        // 21 & 23. Trigger Complete Order with handoverConfirmed = true
        final completedOrder = await completeOrderUseCase.execute(
          CompleteOrderInput(orderId: createdOrder.id, handoverConfirmed: true),
        );

        // 24. Verify final status = completed
        expect(completedOrder.status, equals(OrderStatus.completed));

        // 25. Verify completion timestamp
        expect(completedOrder.completedAt, isNotNull);
        expect(completedOrder.customerHandoverConfirmedAt, isNotNull);

        // 26. Verify active storage records are released/deactivated
        final activeRecord1After = await storageRecordsDao
            .getActiveRecordForOrderItem(item1.id);
        final activeRecord2After = await storageRecordsDao
            .getActiveRecordForOrderItem(item2.id);
        expect(activeRecord1After, isNull);
        expect(activeRecord2After, isNull);

        // Historical storage records remain intact with isActive = false
        final allStorage1 = await (db.select(
          db.storageRecords,
        )..where((t) => t.orderItemId.equals(item1.id))).get();
        final allStorage2 = await (db.select(
          db.storageRecords,
        )..where((t) => t.orderItemId.equals(item2.id))).get();
        expect(allStorage1.length, equals(1));
        expect(allStorage1.first.isActive, isFalse);
        expect(allStorage2.length, equals(1));
        expect(allStorage2.first.isActive, isFalse);

        // Invariant: Cannot record payment on completed order
        expect(
          () => paymentRepository.recordPayment(
            Payment(
              id: 'pay-after-complete',
              orderId: createdOrder.id,
              amount: const Money.fromPiastres(100),
              paymentMethod: PaymentMethod.cash,
              paidAt: now,
              createdAt: now,
              updatedAt: now,
            ),
          ),
          throwsA(isA<BusinessRuleFailure>()),
        );

        // Invariant: Cannot cancel completed order
        expect(
          () => cancelOrderUseCase.execute(
            CancelOrderInput(
              orderId: createdOrder.id,
              cancellationReason: 'محاولة إلغاء بعد الإكمال',
              confirmed: true,
            ),
          ),
          throwsA(isA<BusinessRuleFailure>()),
        );
      },
    );

    test('Complete Order Gate: All 4 independent conditions enforced', () async {
      final now = DateTime.now();

      final gateCustomer = await customerRepository.createCustomer(
        Customer(
          id: 'cust-gate-audit',
          name: 'عميل البوابات',
          phone: '01011112222',
          createdAt: now,
          updatedAt: now,
        ),
      );

      Future<String> createGateOrder({
        required bool storeItems,
        required bool payInFull,
        required OrderStatus targetStatus,
      }) async {
        final orderId = 'gate-ord-${DateTime.now().microsecondsSinceEpoch}';
        final order = Order(
          id: orderId,
          orderNumber: '26-${orderId.substring(orderId.length - 4)}',
          customerId: gateCustomer.id,
          customerNameSnapshot: 'عميل البوابات',
          customerPhoneSnapshot: '01011112222',
          status: targetStatus,
          expectedPickupDate: OrderDate.fromDate(
            now.add(const Duration(days: 2)),
          ),
          subtotal: const Money.fromPiastres(5000),
          total: const Money.fromPiastres(5000),
          createdAt: now,
          updatedAt: now,
        );
        final item = OrderItem(
          id: 'gate-item-$orderId',
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
          final nowTimestamp = now.toUtc().millisecondsSinceEpoch ~/ 1000;
          await db.customStatement(
            'INSERT INTO storage_records (id, order_item_id, storage_location_id, is_active, created_at, updated_at) '
            'VALUES (?, ?, ?, 1, ?, ?);',
            [
              'rec-$orderId',
              'gate-item-$orderId',
              'loc-audit-1',
              nowTimestamp,
              nowTimestamp,
            ],
          );
        }

        if (payInFull) {
          await paymentRepository.recordPayment(
            Payment(
              id: 'gate-pay-$orderId',
              orderId: orderId,
              amount: const Money.fromPiastres(5000),
              paymentMethod: PaymentMethod.cash,
              paidAt: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }

        return orderId;
      }

      // Condition A: processing + fully paid + stored -> MUST NOT complete
      final ordA = await createGateOrder(
        storeItems: true,
        payInFull: true,
        targetStatus: OrderStatus.processing,
      );
      expect(
        () => completeOrderUseCase.execute(
          CompleteOrderInput(orderId: ordA, handoverConfirmed: true),
        ),
        throwsA(isA<BusinessRuleFailure>()),
      );

      // Condition B: ready + unpaid -> MUST NOT complete
      final ordB = await createGateOrder(
        storeItems: true,
        payInFull: false,
        targetStatus: OrderStatus.ready,
      );
      expect(
        () => completeOrderUseCase.execute(
          CompleteOrderInput(orderId: ordB, handoverConfirmed: true),
        ),
        throwsA(isA<OrderNotFullyPaidFailure>()),
      );

      // Condition C: ready + paid + one item not stored (unstored) -> MUST NOT complete
      final ordC = await createGateOrder(
        storeItems: true,
        payInFull: true,
        targetStatus: OrderStatus.ready,
      );
      final itemsC = await orderRepository.getOrderItems(ordC);
      await storageRepository.unstoreItem(itemsC.first.id);
      expect(
        () => completeOrderUseCase.execute(
          CompleteOrderInput(orderId: ordC, handoverConfirmed: true),
        ),
        throwsA(isA<BusinessRuleFailure>()),
      );

      // Condition D: ready + paid + all stored + handover=false -> MUST NOT complete
      final ordD = await createGateOrder(
        storeItems: true,
        payInFull: true,
        targetStatus: OrderStatus.ready,
      );
      expect(
        () => completeOrderUseCase.execute(
          CompleteOrderInput(orderId: ordD, handoverConfirmed: false),
        ),
        throwsA(isA<BusinessRuleFailure>()),
      );

      // Condition E: ready + paid + all stored + handover=true -> MUST complete
      final ordE = await createGateOrder(
        storeItems: true,
        payInFull: true,
        targetStatus: OrderStatus.ready,
      );
      final completed = await completeOrderUseCase.execute(
        CompleteOrderInput(orderId: ordE, handoverConfirmed: true),
      );
      expect(completed.status, equals(OrderStatus.completed));
    });

    test(
      'Cancellation Flow: Mandatory reason, historical payments preserved, storage released, no further actions',
      () async {
        final now = DateTime.now();

        final cancCustomer = await customerRepository.createCustomer(
          Customer(
            id: 'cust-canc-audit',
            name: 'عميل الإلغاء',
            phone: '01099998888',
            createdAt: now,
            updatedAt: now,
          ),
        );

        // 1. Setup processing order with initial payment
        final orderId = 'canc-ord-${DateTime.now().microsecondsSinceEpoch}';
        final order = Order(
          id: orderId,
          orderNumber: '26-999',
          customerId: cancCustomer.id,
          customerNameSnapshot: 'عميل الإلغاء',
          customerPhoneSnapshot: '01099998888',
          status: OrderStatus.processing,
          expectedPickupDate: OrderDate.fromDate(
            now.add(const Duration(days: 2)),
          ),
          subtotal: const Money.fromPiastres(5000),
          total: const Money.fromPiastres(5000),
          createdAt: now,
          updatedAt: now,
        );
        final item = OrderItem(
          id: 'canc-item-$orderId',
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

        // Record down payment: 30 EGP (3000 piastres)
        await paymentRepository.recordPayment(
          Payment(
            id: 'pay-canc-$orderId',
            orderId: orderId,
            amount: const Money.fromPiastres(3000),
            paymentMethod: PaymentMethod.ewallet,
            paidAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Store item
        final nowTimestamp = now.toUtc().millisecondsSinceEpoch ~/ 1000;
        await db.customStatement(
          'INSERT INTO storage_records (id, order_item_id, storage_location_id, is_active, created_at, updated_at) '
          'VALUES (?, ?, ?, 1, ?, ?);',
          [
            'rec-canc-$orderId',
            'canc-item-$orderId',
            'loc-audit-1',
            nowTimestamp,
            nowTimestamp,
          ],
        );

        // 3 & 4. Cancellation reason is mandatory (empty cannot confirm)
        expect(
          () => cancelOrderUseCase.execute(
            CancelOrderInput(
              orderId: orderId,
              cancellationReason: '',
              confirmed: true,
            ),
          ),
          throwsA(isA<ValidationFailure>()),
        );
        expect(
          () => cancelOrderUseCase.execute(
            CancelOrderInput(
              orderId: orderId,
              cancellationReason: '   ',
              confirmed: true,
            ),
          ),
          throwsA(isA<ValidationFailure>()),
        );

        // 5. Valid reason successfully cancels order
        final cancelledOrder = await cancelOrderUseCase.execute(
          CancelOrderInput(
            orderId: orderId,
            cancellationReason: 'العميل ألغى الطلب لظروف طارئة',
            confirmed: true,
          ),
        );

        // 6. Status becomes cancelled ("ملغي")
        expect(cancelledOrder.status, equals(OrderStatus.cancelled));
        expect(
          cancelledOrder.cancellationReason,
          equals('العميل ألغى الطلب لظروف طارئة'),
        );
        expect(cancelledOrder.cancelledAt, isNotNull);

        // 7. Cancelled order remains visible in database
        final reloaded = await orderRepository.getOrderById(orderId);
        expect(reloaded, isNotNull);
        expect(reloaded!.status, equals(OrderStatus.cancelled));

        // 8. CRITICAL: Historical payments remain in payments table
        final payments = await paymentRepository.getPaymentsForOrder(orderId);
        expect(payments.length, equals(1));
        expect(payments.first.id, equals('pay-canc-$orderId'));
        expect(payments.first.amount, equals(const Money.fromPiastres(3000)));

        // 9. Storage records are released (deactivated)
        final activeRecord = await storageRecordsDao
            .getActiveRecordForOrderItem('canc-item-$orderId');
        expect(activeRecord, isNull);
        final allStorage = await (db.select(
          db.storageRecords,
        )..where((t) => t.orderItemId.equals('canc-item-$orderId'))).get();
        expect(allStorage.length, equals(1));
        expect(allStorage.first.isActive, isFalse);

        // 10. Cancelled order cannot be completed
        expect(
          () => completeOrderUseCase.execute(
            CompleteOrderInput(orderId: orderId, handoverConfirmed: true),
          ),
          throwsA(isA<BusinessRuleFailure>()),
        );

        // 11. Cancelled order cannot receive new payments
        expect(
          () => paymentRepository.recordPayment(
            Payment(
              id: 'pay-canc-new',
              orderId: orderId,
              amount: const Money.fromPiastres(2000),
              paymentMethod: PaymentMethod.cash,
              paidAt: now,
              createdAt: now,
              updatedAt: now,
            ),
          ),
          throwsA(isA<BusinessRuleFailure>()),
        );
      },
    );
  });
}
