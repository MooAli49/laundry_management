import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/data/local/daos/business_settings_dao.dart';
import 'package:laundry_management/data/local/daos/customers_dao.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/services_dao.dart';
import 'package:laundry_management/data/local/daos/storage_locations_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart' as db_pkg;
import 'package:laundry_management/data/repositories/customer_repository_impl.dart';
import 'package:laundry_management/data/repositories/order_repository_impl.dart';
import 'package:laundry_management/data/repositories/payment_repository_impl.dart';
import 'package:laundry_management/data/repositories/settings_repository_impl.dart';
import 'package:laundry_management/data/repositories/storage_location_repository_impl.dart';
import 'package:laundry_management/data/repositories/storage_repository_impl.dart';
import 'package:laundry_management/domain/entities/carpet_item_data.dart';
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/entities/payment.dart';
import 'package:laundry_management/domain/entities/storage_location.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/enums/payment_method.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';

void main() {
  late db_pkg.AppDatabase db;
  late CustomersDao customersDao;
  late OrdersDao ordersDao;
  late PaymentsDao paymentsDao;
  late StorageLocationsDao storageLocationsDao;
  late StorageRecordsDao storageRecordsDao;
  late ServicesDao servicesDao;
  late BusinessSettingsDao businessSettingsDao;
  late SyncOperationsDao syncOperationsDao;

  late CustomerRepositoryImpl customerRepository;
  late OrderRepositoryImpl orderRepository;
  late PaymentRepositoryImpl paymentRepository;
  late StorageRepositoryImpl storageRepository;
  late StorageLocationRepositoryImpl storageLocationRepository;
  late SettingsRepositoryImpl settingsRepository;

  setUp(() {
    db = db_pkg.AppDatabase(NativeDatabase.memory());
    customersDao = CustomersDao(db);
    ordersDao = OrdersDao(db);
    paymentsDao = PaymentsDao(db);
    storageLocationsDao = StorageLocationsDao(db);
    storageRecordsDao = StorageRecordsDao(db);
    servicesDao = ServicesDao(db);
    businessSettingsDao = BusinessSettingsDao(db);
    syncOperationsDao = SyncOperationsDao(db);

    customerRepository = CustomerRepositoryImpl(
      customersDao: customersDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );
    orderRepository = OrderRepositoryImpl(
      ordersDao: ordersDao,
      storageRecordsDao: storageRecordsDao,
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
      db: db,
    );
    storageLocationRepository = StorageLocationRepositoryImpl(
      storageLocationsDao: storageLocationsDao,
      storageRecordsDao: storageRecordsDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );
    settingsRepository = SettingsRepositoryImpl(
      settingsDao: businessSettingsDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('OrderRepositoryImpl Workflow & Business Invariants', () {
    test('creates order atomically with items, carpet data, and sync operation', () async {
      final now = DateTime.now();

      // Create customer
      final customer = await customerRepository.createCustomer(
        Customer(
          id: 'cust-1',
          name: 'علي حسن',
          phone: '01001122334',
          createdAt: now,
          updatedAt: now,
        ),
      );
      expect(customer.id, 'cust-1');

      // Setup service
      final itemTypes = await db.select(db.itemTypes).get();
      final carpetType = itemTypes.firstWhere((t) => t.name == 'سجاد');

      await servicesDao.insertService(
        db_pkg.ServicesCompanion.insert(
          id: 'srv-1',
          name: 'غسيل سجاد يدوي',
          pricingType: 'perSquareMeter',
          price: 2500, // 25 EGP / m2
          createdAt: now,
          updatedAt: now,
        ),
      );

      final carpetData = CarpetItemData(
        id: 'carp-1',
        orderItemId: 'item-1',
        length: 2.0,
        width: 3.0,
        area: 6.0,
        createdAt: now,
        updatedAt: now,
      );

      final item = OrderItem(
        id: 'item-1',
        orderId: 'ord-1',
        itemTypeId: carpetType.id,
        serviceId: 'srv-1',
        itemTypeNameSnapshot: 'سجاد',
        serviceNameSnapshot: 'غسيل سجاد يدوي',
        pricingType: PricingType.perSquareMeter,
        quantity: 6.0,
        unitPrice: const Money.fromPiastres(2500),
        calculatedTotal: const Money.fromPiastres(15000), // 150 EGP
        carpetData: carpetData,
        createdAt: now,
        updatedAt: now,
      );

      final order = Order(
        id: 'ord-1',
        orderNumber: '26-001',
        customerId: 'cust-1',
        status: OrderStatus.processing,
        expectedPickupDate: OrderDate(2026, 9, 15),
        subtotal: const Money.fromPiastres(15000),
        total: const Money.fromPiastres(15000),
        createdAt: now,
        updatedAt: now,
      );

      final createdOrder = await orderRepository.createOrder(
        order: order,
        items: [item],
      );

      expect(createdOrder.id, 'ord-1');

      // Verify items were persisted
      final items = await orderRepository.getOrderItems('ord-1');
      expect(items.length, 1);
      expect(items.first.carpetData, isNotNull);
      expect(items.first.carpetData!.area, 6.0);

      // Verify sync operation was recorded atomically
      final pendingSync = await syncOperationsDao.getPendingOperations();
      expect(pendingSync.any((op) => op.entityType == 'order' && op.entityId == 'ord-1'), isTrue);
    });

    test('completeOrder strictly requires handoverConfirmed and deactivates storage', () async {
      final now = DateTime.now();
      await customerRepository.createCustomer(
        Customer(
          id: 'cust-1',
          name: 'سمير',
          phone: '01055556666',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final itemTypes = await db.select(db.itemTypes).get();
      await servicesDao.insertService(
        db_pkg.ServicesCompanion.insert(
          id: 'srv-1',
          name: 'مكواة',
          pricingType: 'perPiece',
          price: 1000,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final order = Order(
        id: 'ord-2',
        orderNumber: '26-002',
        customerId: 'cust-1',
        expectedPickupDate: OrderDate(2026, 9, 10),
        subtotal: const Money.fromPiastres(1000),
        total: const Money.fromPiastres(1000),
        createdAt: now,
        updatedAt: now,
      );
      final item = OrderItem(
        id: 'item-2',
        orderId: 'ord-2',
        itemTypeId: itemTypes.first.id,
        serviceId: 'srv-1',
        itemTypeNameSnapshot: 'قميص',
        serviceNameSnapshot: 'مكواة',
        pricingType: PricingType.perPiece,
        quantity: 1.0,
        unitPrice: const Money.fromPiastres(1000),
        calculatedTotal: const Money.fromPiastres(1000),
        createdAt: now,
        updatedAt: now,
      );
      await orderRepository.createOrder(order: order, items: [item]);

      // Create storage location and store item
      final location = await storageLocationRepository.createStorageLocation(
        StorageLocation(
          id: 'loc-1',
          name: 'مكان 1',
          createdAt: now,
          updatedAt: now,
        ),
        supportedItemTypeIds: [],
      );
      await storageRepository.storeItem(
        orderItemId: 'item-2',
        storageLocationId: location.id,
      );

      // Verify active storage record exists
      final activeBefore = await storageRepository.getActiveRecordForOrderItem('item-2');
      expect(activeBefore, isNotNull);

      // Attempt completeOrder directly on Processing order -> rejected
      expect(
        () => orderRepository.completeOrder(
          orderId: 'ord-2',
          handoverConfirmed: true,
        ),
        throwsA(
          isA<BusinessRuleFailure>().having(
            (e) => e.message,
            'message',
            contains('Only Ready orders can be completed'),
          ),
        ),
      );

      // Move order to Ready before completion
      await orderRepository.markOrderReady('ord-2');

      // Attempt completeOrder without handover confirmation
      expect(
        () => orderRepository.completeOrder(
          orderId: 'ord-2',
          handoverConfirmed: false,
        ),
        throwsA(isA<BusinessRuleFailure>()),
      );

      // Complete order with handover confirmed -> allowed
      final completedOrder = await orderRepository.completeOrder(
        orderId: 'ord-2',
        handoverConfirmed: true,
      );

      expect(completedOrder.status, OrderStatus.completed);
      expect(completedOrder.completedAt, isNotNull);
      expect(completedOrder.customerHandoverConfirmedAt, completedOrder.completedAt);

      // Attempt completeOrder on already Completed order -> rejected
      expect(
        () => orderRepository.completeOrder(
          orderId: 'ord-2',
          handoverConfirmed: true,
        ),
        throwsA(
          isA<BusinessRuleFailure>().having(
            (e) => e.message,
            'message',
            contains('already completed'),
          ),
        ),
      );

      // Active storage record should be deactivated
      final activeAfter = await storageRepository.getActiveRecordForOrderItem('item-2');
      expect(activeAfter, isNull);
    });

    test('cancelOrder requires cancellation reason and releases active storage', () async {
      final now = DateTime.now();
      await customerRepository.createCustomer(
        Customer(
          id: 'cust-1',
          name: 'ياسر',
          phone: '01077778888',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final itemTypes = await db.select(db.itemTypes).get();
      await servicesDao.insertService(
        db_pkg.ServicesCompanion.insert(
          id: 'srv-1',
          name: 'غسيل',
          pricingType: 'perPiece',
          price: 2000,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final order = Order(
        id: 'ord-3',
        orderNumber: '26-003',
        customerId: 'cust-1',
        expectedPickupDate: OrderDate(2026, 9, 10),
        subtotal: const Money.fromPiastres(2000),
        total: const Money.fromPiastres(2000),
        createdAt: now,
        updatedAt: now,
      );
      final item = OrderItem(
        id: 'item-3',
        orderId: 'ord-3',
        itemTypeId: itemTypes.first.id,
        serviceId: 'srv-1',
        itemTypeNameSnapshot: 'بنطلون',
        serviceNameSnapshot: 'غسيل',
        pricingType: PricingType.perPiece,
        quantity: 1.0,
        unitPrice: const Money.fromPiastres(2000),
        calculatedTotal: const Money.fromPiastres(2000),
        createdAt: now,
        updatedAt: now,
      );
      await orderRepository.createOrder(order: order, items: [item]);

      // Attempt cancel with empty reason
      expect(
        () => orderRepository.cancelOrder(
          orderId: 'ord-3',
          cancellationReason: '   ',
        ),
        throwsA(isA<ValidationFailure>()),
      );

      // Cancel with valid reason
      final cancelledOrder = await orderRepository.cancelOrder(
        orderId: 'ord-3',
        cancellationReason: 'طلب العميل إلغاء الطلب',
      );

      expect(cancelledOrder.status, OrderStatus.cancelled);
      expect(cancelledOrder.cancelledAt, isNotNull);
      expect(cancelledOrder.cancellationReason, 'طلب العميل إلغاء الطلب');

      // Attempt completeOrder on Cancelled order -> rejected
      expect(
        () => orderRepository.completeOrder(
          orderId: 'ord-3',
          handoverConfirmed: true,
        ),
        throwsA(
          isA<BusinessRuleFailure>().having(
            (e) => e.message,
            'message',
            contains('Cannot complete a cancelled order'),
          ),
        ),
      );
    });

    test('correctOrderStatus moves from completed to processing without reactivating storage (BR-034)', () async {
      final now = DateTime.now();
      await customerRepository.createCustomer(
        Customer(
          id: 'cust-1',
          name: 'طارق',
          phone: '01066667777',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final itemTypes = await db.select(db.itemTypes).get();
      await servicesDao.insertService(
        db_pkg.ServicesCompanion.insert(
          id: 'srv-1',
          name: 'غسيل',
          pricingType: 'perPiece',
          price: 2000,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final order = Order(
        id: 'ord-4',
        orderNumber: '26-004',
        customerId: 'cust-1',
        expectedPickupDate: OrderDate(2026, 9, 10),
        subtotal: const Money.fromPiastres(2000),
        total: const Money.fromPiastres(2000),
        createdAt: now,
        updatedAt: now,
      );
      final item = OrderItem(
        id: 'item-4',
        orderId: 'ord-4',
        itemTypeId: itemTypes.first.id,
        serviceId: 'srv-1',
        itemTypeNameSnapshot: 'جاكيت',
        serviceNameSnapshot: 'غسيل',
        pricingType: PricingType.perPiece,
        quantity: 1.0,
        unitPrice: const Money.fromPiastres(2000),
        calculatedTotal: const Money.fromPiastres(2000),
        createdAt: now,
        updatedAt: now,
      );
      await orderRepository.createOrder(order: order, items: [item]);
      await orderRepository.markOrderReady('ord-4');
      await orderRepository.completeOrder(orderId: 'ord-4', handoverConfirmed: true);

      // Correct order status back to processing
      final corrected = await orderRepository.correctOrderStatus(
        orderId: 'ord-4',
        newStatus: OrderStatus.processing,
        reason: 'تم اكتمال الطلب بالخطأ',
      );

      expect(corrected.status, OrderStatus.processing);
      expect(corrected.completedAt, isNull);

      // Verify storage was NOT reactivated (BR-034)
      final activeRecord = await storageRepository.getActiveRecordForOrderItem('item-4');
      expect(activeRecord, isNull);
    });
  });

  group('PaymentRepositoryImpl & Remaining Amount', () {
    test('records payments and accurately computes remaining balance', () async {
      final now = DateTime.now();
      await customerRepository.createCustomer(
        Customer(
          id: 'cust-1',
          name: 'منير',
          phone: '01088889999',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final itemTypes = await db.select(db.itemTypes).get();
      await servicesDao.insertService(
        db_pkg.ServicesCompanion.insert(
          id: 'srv-1',
          name: 'غسيل',
          pricingType: 'perPiece',
          price: 5000,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final order = Order(
        id: 'ord-5',
        orderNumber: '26-005',
        customerId: 'cust-1',
        expectedPickupDate: OrderDate(2026, 9, 10),
        subtotal: const Money.fromPiastres(5000), // 50 EGP
        total: const Money.fromPiastres(5000),
        createdAt: now,
        updatedAt: now,
      );
      final item = OrderItem(
        id: 'item-5',
        orderId: 'ord-5',
        itemTypeId: itemTypes.first.id,
        serviceId: 'srv-1',
        itemTypeNameSnapshot: 'بدلة',
        serviceNameSnapshot: 'غسيل',
        pricingType: PricingType.perPiece,
        quantity: 1.0,
        unitPrice: const Money.fromPiastres(5000),
        calculatedTotal: const Money.fromPiastres(5000),
        createdAt: now,
        updatedAt: now,
      );
      await orderRepository.createOrder(order: order, items: [item]);

      // Initial remaining amount
      var remaining = await paymentRepository.getRemainingAmountForOrder('ord-5');
      expect(remaining, const Money.fromPiastres(5000));

      // Partial payment: 20 EGP (2000 piastres)
      await paymentRepository.recordPayment(
        Payment(
          id: 'pay-1',
          orderId: 'ord-5',
          amount: const Money.fromPiastres(2000),
          paymentMethod: PaymentMethod.cash,
          paidAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      var totalPaid = await paymentRepository.getTotalPaidForOrder('ord-5');
      expect(totalPaid, const Money.fromPiastres(2000));

      remaining = await paymentRepository.getRemainingAmountForOrder('ord-5');
      expect(remaining, const Money.fromPiastres(3000));

      // Second payment: 30 EGP (3000 piastres via InstaPay)
      await paymentRepository.recordPayment(
        Payment(
          id: 'pay-2',
          orderId: 'ord-5',
          amount: const Money.fromPiastres(3000),
          paymentMethod: PaymentMethod.instapay,
          paidAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      totalPaid = await paymentRepository.getTotalPaidForOrder('ord-5');
      expect(totalPaid, const Money.fromPiastres(5000));

      remaining = await paymentRepository.getRemainingAmountForOrder('ord-5');
      expect(remaining, Money.zero);
    });
  });

  group('StorageRepositoryImpl Move and Bulk Store', () {
    test('moveItem deactivates old location and activates new location', () async {
      final now = DateTime.now();
      await storageLocationRepository.createStorageLocation(
        StorageLocation(id: 'loc-A', name: 'رف A', createdAt: now, updatedAt: now),
        supportedItemTypeIds: [],
      );
      await storageLocationRepository.createStorageLocation(
        StorageLocation(id: 'loc-B', name: 'رف B', createdAt: now, updatedAt: now),
        supportedItemTypeIds: [],
      );

      // Create prerequisite customer, order, and item
      await customerRepository.createCustomer(
        Customer(
          id: 'cust-100',
          name: 'عميل التخزين',
          phone: '01000000000',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final itemTypes = await db.select(db.itemTypes).get();
      await servicesDao.insertService(
        db_pkg.ServicesCompanion.insert(
          id: 'srv-100',
          name: 'غسيل',
          pricingType: 'perPiece',
          price: 1000,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await orderRepository.createOrder(
        order: Order(
          id: 'ord-100',
          orderNumber: '26-100',
          customerId: 'cust-100',
          expectedPickupDate: OrderDate(2026, 9, 10),
          subtotal: const Money.fromPiastres(1000),
          total: const Money.fromPiastres(1000),
          createdAt: now,
          updatedAt: now,
        ),
        items: [
          OrderItem(
            id: 'item-100',
            orderId: 'ord-100',
            itemTypeId: itemTypes.first.id,
            serviceId: 'srv-100',
            itemTypeNameSnapshot: 'ملابس',
            serviceNameSnapshot: 'غسيل',
            pricingType: PricingType.perPiece,
            quantity: 1.0,
            unitPrice: const Money.fromPiastres(1000),
            calculatedTotal: const Money.fromPiastres(1000),
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      // Store in loc-A
      await storageRepository.storeItem(
        orderItemId: 'item-100',
        storageLocationId: 'loc-A',
      );

      var record = await storageRepository.getActiveRecordForOrderItem('item-100');
      expect(record!.storageLocationId, 'loc-A');

      // Move to loc-B
      final moved = await storageRepository.moveItem(
        orderItemId: 'item-100',
        newStorageLocationId: 'loc-B',
      );
      expect(moved.storageLocationId, 'loc-B');

      // Verify active record is now loc-B
      record = await storageRepository.getActiveRecordForOrderItem('item-100');
      expect(record!.storageLocationId, 'loc-B');

      // Loc-A should now have 0 active records
      final locARecords = await storageRepository.getActiveRecordsForLocation('loc-A');
      expect(locARecords.isEmpty, isTrue);

      // Loc-B should have 1 active record
      final locBRecords = await storageRepository.getActiveRecordsForLocation('loc-B');
      expect(locBRecords.length, 1);
    });
  });

  group('SettingsRepositoryImpl', () {
    test('retrieves default seeded settings and allows updates', () async {
      final settings = await settingsRepository.getSettings();
      expect(settings.id, '00000000-0000-0000-0000-000000000001');

      final updated = await settingsRepository.updateSettings(
        settings.copyWith(
          businessName: 'مغسلة النور والصفا',
          taxEnabled: true,
          taxRate: 14.0,
        ),
      );

      expect(updated.businessName, 'مغسلة النور والصفا');
      expect(updated.taxEnabled, isTrue);
      expect(updated.taxRate, 14.0);

      final retrievedAgain = await settingsRepository.getSettings();
      expect(retrievedAgain.businessName, 'مغسلة النور والصفا');
      expect(retrievedAgain.taxRate, 14.0);
    });
  });
}
