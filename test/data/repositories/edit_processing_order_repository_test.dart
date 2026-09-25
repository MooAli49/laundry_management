import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/application/use_cases/create_order_use_case.dart';
import 'package:laundry_management/application/use_cases/edit_processing_order_use_case.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/data/local/daos/customers_dao.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart' as db_pkg;
import 'package:laundry_management/data/repositories/customer_repository_impl.dart';
import 'package:laundry_management/data/repositories/order_repository_impl.dart';
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';

void main() {
  late db_pkg.AppDatabase db;
  late CustomersDao customersDao;
  late OrdersDao ordersDao;
  late PaymentsDao paymentsDao;
  late StorageRecordsDao storageRecordsDao;
  late SyncOperationsDao syncOperationsDao;

  late CustomerRepositoryImpl customerRepository;
  late OrderRepositoryImpl orderRepository;

  final now = DateTime(2026, 9, 23, 10, 0, 0);
  const testItemTypeId = '00000000-0000-0000-0001-000000000001'; // 'ملابس' from seed
  const testServiceId1 = 'srv-wash-iron';
  const testServiceId2 = 'srv-dry-clean';

  setUp(() async {
    db = db_pkg.AppDatabase(NativeDatabase.memory());
    customersDao = CustomersDao(db);
    ordersDao = OrdersDao(db);
    paymentsDao = PaymentsDao(db);
    storageRecordsDao = StorageRecordsDao(db);
    syncOperationsDao = SyncOperationsDao(db);

    customerRepository = CustomerRepositoryImpl(
      customersDao: customersDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    orderRepository = OrderRepositoryImpl(
      ordersDao: ordersDao,
      paymentsDao: paymentsDao,
      storageRecordsDao: storageRecordsDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    // Seed services and service_item_types compatibility
    await db.into(db.services).insert(
          db_pkg.ServicesCompanion.insert(
            id: testServiceId1,
            name: 'غسيل وكي',
            price: 2500, // 25 EGP
            pricingType: 'per_piece',
            isActive: const drift.Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db.into(db.services).insert(
          db_pkg.ServicesCompanion.insert(
            id: testServiceId2,
            name: 'تنظيف جاف',
            price: 4000, // 40 EGP
            pricingType: 'per_piece',
            isActive: const drift.Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db.into(db.serviceItemTypes).insert(
          db_pkg.ServiceItemTypesCompanion.insert(
            id: 'sit-1',
            serviceId: testServiceId1,
            itemTypeId: testItemTypeId,
            createdAt: now,
          ),
        );

    await db.into(db.serviceItemTypes).insert(
          db_pkg.ServiceItemTypesCompanion.insert(
            id: 'sit-2',
            serviceId: testServiceId2,
            itemTypeId: testItemTypeId,
            createdAt: now,
          ),
        );

    // Create a storage location
    await db.into(db.storageLocations).insert(
          db_pkg.StorageLocationsCompanion.insert(
            id: 'loc-1',
            name: 'رف A-1',
            createdAt: now,
            updatedAt: now,
          ),
        );

    // Create a customer
    await customerRepository.createCustomer(
      Customer(
        id: 'cust-1',
        name: 'عميل أولي',
        phone: '01011112222',
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<Order> createTestOrder({
    String orderId = 'order-test-1',
    String itemId = 'item-test-1',
    String? orderNumber,
    OrderStatus status = OrderStatus.processing,
  }) async {
    final order = Order(
      id: orderId,
      orderNumber: orderNumber ?? '26-${DateTime.now().microsecondsSinceEpoch % 100000}',
      customerId: 'cust-1',
      customerNameSnapshot: 'عميل أولي',
      customerPhoneSnapshot: '01011112222',
      status: status,
      expectedPickupDate: OrderDate.fromDate(now.add(const Duration(days: 2))),
      subtotal: Money.fromPiastres(2500),
      total: Money.fromPiastres(2500),
      createdAt: now,
      updatedAt: now,
    );

    final item = OrderItem(
      id: itemId,
      orderId: orderId,
      itemTypeId: testItemTypeId,
      serviceId: testServiceId1,
      itemTypeNameSnapshot: 'ملابس',
      serviceNameSnapshot: 'غسيل وكي',
      pricingType: PricingType.perPiece,
      quantity: 1,
      unitPrice: Money.fromPiastres(2500),
      calculatedTotal: Money.fromPiastres(2500),
      createdAt: now,
      updatedAt: now,
    );

    return await orderRepository.createOrder(order: order, items: [item]);
  }

  group('OrderRepositoryImpl.editProcessingOrder Phase 1 Drift & Transaction Tests', () {
    test('atomic success: persists order header, modified item, and new item atomically', () async {
      final initialOrder = await createTestOrder();

      final editInput = EditProcessingOrderInput(
        orderId: initialOrder.id,
        customerId: 'cust-1',
        expectedPickupDate: OrderDate.fromDate(now.add(const Duration(days: 3))),
        notes: 'ملاحظات معدلة للطلب',
        discount: Money.fromPiastres(500), // 5 EGP discount
        customerDeliveryRequested: true,
        customerDeliveryFee: Money.fromPiastres(1000), // 10 EGP delivery
        modifiedItems: [
          const OrderItemEditInput(
            id: 'item-test-1',
            serviceId: testServiceId2, // switched to dry clean: 40 EGP
            notes: 'ملاحظة على البند الأول',
          ),
        ],
        newItems: [
          const CreateOrderItemInput(
            itemTypeId: testItemTypeId,
            serviceId: testServiceId1, // wash: 25 EGP
            physicalQuantity: 1,
            notes: 'بند جديد مضاف',
          ),
        ],
      );

      final updatedOrder = await orderRepository.editProcessingOrder(editInput);

      // Verify returned domain model
      expect(updatedOrder.id, initialOrder.id);
      expect(updatedOrder.notes, 'ملاحظات معدلة للطلب');
      expect(updatedOrder.discount, Money.fromPiastres(500));
      expect(updatedOrder.customerDeliveryRequested, isTrue);
      expect(updatedOrder.customerDeliveryFee, Money.fromPiastres(1000));
      // Subtotal = 4000 (modified item) + 2500 (new item) = 6500 piastres (65 EGP)
      // Total = 6500 - 500 (discount) + 1000 (delivery) = 7000 piastres (70 EGP)
      expect(updatedOrder.subtotal, Money.fromPiastres(6500));
      expect(updatedOrder.total, Money.fromPiastres(7000));

      // Verify persistence directly in database
      final orderRow = await ordersDao.getOrderById(initialOrder.id);
      expect(orderRow?.subtotal, 6500);
      expect(orderRow?.total, 7000);
      expect(orderRow?.notes, 'ملاحظات معدلة للطلب');

      final items = await ordersDao.getOrderItemsRaw(initialOrder.id);
      expect(items.length, 2);

      final modifiedItemRow = items.firstWhere((i) => i.id == 'item-test-1');
      expect(modifiedItemRow.serviceId, testServiceId2);
      expect(modifiedItemRow.serviceNameSnapshot, 'تنظيف جاف');
      expect(modifiedItemRow.calculatedTotal, 4000);

      final newItemRow = items.firstWhere((i) => i.id != 'item-test-1');
      expect(newItemRow.serviceId, testServiceId1);
      expect(newItemRow.calculatedTotal, 2500);
    });

    test('rollback on failure: rolls back all changes if an item validation fails', () async {
      final initialOrder = await createTestOrder();

      // Clear sync operations to isolate this test
      await db.delete(db.syncOperations).go();

      // Attempt edit with an incompatible / non-existent service ID for modified item
      final failingInput = EditProcessingOrderInput(
        orderId: initialOrder.id,
        customerId: 'cust-1',
        expectedPickupDate: initialOrder.expectedPickupDate,
        notes: 'تعديل سيفشل',
        modifiedItems: [
          const OrderItemEditInput(
            id: 'item-test-1',
            serviceId: 'srv-incompatible-or-missing',
          ),
        ],
        newItems: [
          const CreateOrderItemInput(
            itemTypeId: testItemTypeId,
            serviceId: testServiceId1,
            physicalQuantity: 1,
          ),
        ],
      );

      await expectLater(
        () => orderRepository.editProcessingOrder(failingInput),
        throwsA(isA<ValidationFailure>()),
      );

      // Verify DB was NOT modified (rollback succeeded)
      final orderRow = await ordersDao.getOrderById(initialOrder.id);
      expect(orderRow?.notes, isNull);
      expect(orderRow?.subtotal, 2500);
      expect(orderRow?.total, 2500);

      final items = await ordersDao.getOrderItemsRaw(initialOrder.id);
      expect(items.length, 1);
      expect(items.first.id, 'item-test-1');
      expect(items.first.serviceId, testServiceId1);

      // Verify zero outbox operations created
      final ops = await syncOperationsDao.getPendingOperations();
      expect(ops.isEmpty, isTrue);
    });

    test('storage-record deletion guard: blocks deletion of item with storage records', () async {
      final initialOrder = await createTestOrder();

      // Add a storage record for item-test-1
      await db.into(db.storageRecords).insert(
            db_pkg.StorageRecordsCompanion.insert(
              id: 'sr-1',
              orderItemId: 'item-test-1',
              storageLocationId: 'loc-1',
              isActive: const drift.Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final deleteAttemptInput = EditProcessingOrderInput(
        orderId: initialOrder.id,
        customerId: 'cust-1',
        expectedPickupDate: initialOrder.expectedPickupDate,
        deletedItemIds: ['item-test-1'],
        newItems: [
          const CreateOrderItemInput(
            itemTypeId: testItemTypeId,
            serviceId: testServiceId1,
            physicalQuantity: 1,
          ),
        ],
      );

      await expectLater(
        () => orderRepository.editProcessingOrder(deleteAttemptInput),
        throwsA(
          isA<BusinessRuleFailure>().having(
            (e) => e.message,
            'message',
            contains('Cannot delete item with storage records'),
          ),
        ),
      );

      // Item must still exist
      final item = await orderRepository.getOrderItemById('item-test-1');
      expect(item, isNotNull);
    });

    test('outbox creation: creates an atomic outbox operation of type "edit" with full aggregate', () async {
      final initialOrder = await createTestOrder();

      // Clear sync operations before edit
      await db.delete(db.syncOperations).go();

      final editInput = EditProcessingOrderInput(
        orderId: initialOrder.id,
        customerId: 'cust-1',
        expectedPickupDate: initialOrder.expectedPickupDate,
        notes: 'ملاحظة المزامنة',
        modifiedItems: [
          const OrderItemEditInput(
            id: 'item-test-1',
            serviceId: testServiceId2,
          ),
        ],
      );

      await orderRepository.editProcessingOrder(editInput);

      final ops = await syncOperationsDao.getPendingOperations();
      expect(ops.length, 1);

      final op = ops.first;
      expect(op.entityType, 'order');
      expect(op.entityId, initialOrder.id);
      expect(op.operationType, 'edit');

      final payloadMap = jsonDecode(op.payload!) as Map<String, dynamic>;
      expect(payloadMap['id'], initialOrder.id);
      expect(payloadMap['notes'], 'ملاحظة المزامنة');
      expect(payloadMap['items'], isA<List>());
      final itemsPayload = payloadMap['items'] as List;
      expect(itemsPayload.length, 1);
      expect(itemsPayload.first['id'], 'item-test-1');
      expect(itemsPayload.first['service_id'], testServiceId2);
      // Ensure excluded fields are absent
      expect(payloadMap.containsKey('base_version'), isFalse);
      expect(payloadMap.containsKey('created_at'), isFalse);
      expect(payloadMap.containsKey('paid_amount'), isFalse);
      expect(payloadMap.containsKey('status'), isFalse);
    });

    test('readiness recalculation: sets status to ready if all items stored, processing otherwise', () async {
      // Case A: Order with 1 item, which is actively stored -> editing makes it ready
      final orderA = await createTestOrder(orderId: 'order-case-a', itemId: 'item-case-a');
      await db.into(db.storageRecords).insert(
            db_pkg.StorageRecordsCompanion.insert(
              id: 'sr-case-a',
              orderItemId: 'item-case-a',
              storageLocationId: 'loc-1',
              isActive: const drift.Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final editInputA = EditProcessingOrderInput(
        orderId: orderA.id,
        customerId: 'cust-1',
        expectedPickupDate: orderA.expectedPickupDate,
        notes: 'تعديل والقطع كلها مخزنة',
      );
      final updatedOrderA = await orderRepository.editProcessingOrder(editInputA);
      expect(updatedOrderA.status, OrderStatus.ready);

      // Case B: Order with 2 items, only 1 is stored -> editing leaves it processing
      final orderB = await createTestOrder(orderId: 'order-case-b', itemId: 'item-case-b-1');
      await db.into(db.storageRecords).insert(
            db_pkg.StorageRecordsCompanion.insert(
              id: 'sr-case-b',
              orderItemId: 'item-case-b-1',
              storageLocationId: 'loc-1',
              isActive: const drift.Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final editInputB = EditProcessingOrderInput(
        orderId: orderB.id,
        customerId: 'cust-1',
        expectedPickupDate: orderB.expectedPickupDate,
        newItems: [
          const CreateOrderItemInput(
            itemTypeId: testItemTypeId,
            serviceId: testServiceId1,
            physicalQuantity: 1,
          ),
        ],
      );
      final updatedOrderB = await orderRepository.editProcessingOrder(editInputB);
      expect(updatedOrderB.status, OrderStatus.processing);
    });

    test('customer change with totalPaid == 0 persists locally and generates exactly one outbox operation', () async {
      final initialOrder = await createTestOrder();

      await customerRepository.createCustomer(
        Customer(
          id: 'cust-2',
          name: 'عميل ثانٍ',
          phone: '01099998888',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Clear sync operations before edit
      await db.delete(db.syncOperations).go();

      final editInput = EditProcessingOrderInput(
        orderId: initialOrder.id,
        customerId: 'cust-2',
        expectedPickupDate: initialOrder.expectedPickupDate,
      );

      final updatedOrder = await orderRepository.editProcessingOrder(editInput);

      expect(updatedOrder.customerId, 'cust-2');
      expect(updatedOrder.customerNameSnapshot, 'عميل ثانٍ');
      expect(updatedOrder.customerPhoneSnapshot, '01099998888');

      final orderRow = await ordersDao.getOrderById(initialOrder.id);
      expect(orderRow?.customerId, 'cust-2');
      expect(orderRow?.customerNameSnapshot, 'عميل ثانٍ');
      expect(orderRow?.customerPhoneSnapshot, '01099998888');

      final pendingOps = await syncOperationsDao.getPendingOperations();
      expect(pendingOps.length, 1);
      final op = pendingOps.first;
      expect(op.operationType, 'edit');
      expect(op.entityId, initialOrder.id);
      final payload = jsonDecode(op.payload!) as Map<String, dynamic>;
      expect(payload['customer_id'], 'cust-2');
    });

    test('customer change with totalPaid > 0 throws BusinessRuleFailure and creates zero outbox operations', () async {
      final initialOrder = await createTestOrder();

      // Record payment so totalPaid > 0
      await paymentsDao.insertPayment(
        db_pkg.PaymentsCompanion.insert(
          id: 'pay-cust-block-1',
          orderId: initialOrder.id,
          amount: 1000,
          paymentMethod: 'cash',
          paidAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await db.delete(db.syncOperations).go();

      final editInput = EditProcessingOrderInput(
        orderId: initialOrder.id,
        customerId: 'cust-2',
        expectedPickupDate: initialOrder.expectedPickupDate,
      );

      await expectLater(
        () => orderRepository.editProcessingOrder(editInput),
        throwsA(
          isA<BusinessRuleFailure>().having(
            (e) => e.message,
            'message',
            contains('Cannot change customer on an order with recorded payments'),
          ),
        ),
      );

      final pendingOps = await syncOperationsDao.getPendingOperations();
      expect(pendingOps.isEmpty, isTrue);
    });
  });
}
