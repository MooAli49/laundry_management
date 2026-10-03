import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/application/use_cases/edit_processing_order_use_case.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/daos/sync_state_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart'
    hide Order, OrderItem;
import 'package:laundry_management/data/local/database/app_database.dart'
    as app_db;
import 'package:laundry_management/data/remote/dto/sync_change_dto.dart';
import 'package:laundry_management/data/repositories/order_repository_impl.dart';
import 'package:laundry_management/data/sync/remote_change_applier.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';

void main() {
  group('Single-Terminal Order Numbering & Sync Integration Tests', () {
    late AppDatabase db;
    late OrdersDao ordersDao;
    late PaymentsDao paymentsDao;
    late StorageRecordsDao storageRecordsDao;
    late SyncOperationsDao syncOperationsDao;
    late SyncStateDao syncStateDao;
    late OrderRepositoryImpl orderRepository;
    late RemoteChangeApplier remoteChangeApplier;

    final now = DateTime.now();
    final yearPrefix = (now.year % 100).toString().padLeft(2, '0');

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory(), true);
      ordersDao = OrdersDao(db);
      paymentsDao = PaymentsDao(db);
      storageRecordsDao = StorageRecordsDao(db);
      syncOperationsDao = SyncOperationsDao(db);
      syncStateDao = SyncStateDao(db);

      orderRepository = OrderRepositoryImpl(
        ordersDao: ordersDao,
        paymentsDao: paymentsDao,
        storageRecordsDao: storageRecordsDao,
        syncOperationsDao: syncOperationsDao,
        db: db,
      );

      remoteChangeApplier = RemoteChangeApplier(
        db: db,
        syncStateDao: syncStateDao,
      );

      // Foreign key dependencies
      final nowTimestamp = now.toUtc().millisecondsSinceEpoch ~/ 1000;
      await db.customStatement(
        'INSERT INTO customers (id, name, phone, created_at, updated_at) VALUES (?, ?, ?, ?, ?);',
        ['cust-terminal-1', 'عميل المحل', '01011112222', nowTimestamp, nowTimestamp],
      );
      await db.customStatement(
        'INSERT INTO services (id, name, is_active, created_at, updated_at) VALUES (?, ?, 1, ?, ?);',
        ['srv-wash', 'غسيل وكوي', nowTimestamp, nowTimestamp],
      );
      await db.customStatement(
        'INSERT INTO service_item_types (id, service_id, item_type_id, pricing_type, price, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?);',
        [
          'sit-shirt',
          'srv-wash',
          '00000000-0000-0000-0001-000000000001',
          'per_piece',
          2500,
          nowTimestamp,
          nowTimestamp,
        ],
      );
    });

    tearDown(() async {
      await db.close();
    });

    Order createDraftOrder({required String id, String orderNumber = ''}) {
      return Order(
        id: id,
        orderNumber: orderNumber,
        customerId: 'cust-terminal-1',
        customerNameSnapshot: 'عميل المحل',
        customerPhoneSnapshot: '01011112222',
        status: OrderStatus.processing,
        expectedPickupDate: OrderDate.fromDate(now.add(const Duration(days: 2))),
        notes: null,
        customerPickupRequested: false,
        customerPickupFee: Money.zero,
        customerDeliveryRequested: false,
        customerDeliveryFee: Money.zero,
        subtotal: const Money.fromPiastres(2500),
        discount: Money.zero,
        tax: Money.zero,
        total: const Money.fromPiastres(2500),
        completedAt: null,
        cancelledAt: null,
        cancellationReason: null,
        createdAt: now,
        updatedAt: now,
      );
    }

    OrderItem createOrderItem({required String id, required String orderId}) {
      return OrderItem(
        id: id,
        orderId: orderId,
        itemTypeId: '00000000-0000-0000-0001-000000000001',
        serviceId: 'srv-wash',
        itemTypeNameSnapshot: 'قميص',
        serviceNameSnapshot: 'غسيل وكوي',
        pricingType: PricingType.perPiece,
        quantity: 1.0,
        unitPrice: const Money.fromPiastres(2500),
        calculatedTotal: const Money.fromPiastres(2500),
        createdAt: now,
        updatedAt: now,
      );
    }

    test('1. Sequential order creation follows canonical format: 26-001, 26-002', () async {
      final order1 = await orderRepository.createOrder(
        order: createDraftOrder(id: 'ord-101'),
        items: [createOrderItem(id: 'item-101', orderId: 'ord-101')],
      );
      expect(order1.orderNumber, '$yearPrefix-001');

      final order2 = await orderRepository.createOrder(
        order: createDraftOrder(id: 'ord-102'),
        items: [createOrderItem(id: 'item-102', orderId: 'ord-102')],
      );
      expect(order2.orderNumber, '$yearPrefix-002');
    });

    test('2. Boundary progression smoothly handles 26-999 -> 26-1000 without overflow issues', () async {
      // Seed boundary order 26-999
      await db.into(db.orders).insert(
        app_db.OrdersCompanion.insert(
          id: 'ord-pre-999',
          orderNumber: '$yearPrefix-999',
          customerId: 'cust-terminal-1',
          expectedPickupDate: now,
          subtotal: 2500,
          total: 2500,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final nextNumber = await ordersDao.generateNextOrderNumber();
      expect(nextNumber, '$yearPrefix-1000');

      final order1000 = await orderRepository.createOrder(
        order: createDraftOrder(id: 'ord-1000'),
        items: [createOrderItem(id: 'item-1000', orderId: 'ord-1000')],
      );
      expect(order1000.orderNumber, '$yearPrefix-1000');
    });

    test('3. Offline order creation persists order and records outbox payload with exact order number', () async {
      final order = await orderRepository.createOrder(
        order: createDraftOrder(id: 'ord-offline-1'),
        items: [createOrderItem(id: 'item-offline-1', orderId: 'ord-offline-1')],
      );

      expect(order.orderNumber, '$yearPrefix-001');

      // Verify stored row in SQLite
      final storedRow = await ordersDao.getOrderById('ord-offline-1');
      expect(storedRow, isNotNull);
      expect(storedRow!.orderNumber, '$yearPrefix-001');

      // Verify outbox operation
      final pendingOps = await syncOperationsDao.getEligibleOperations();
      expect(pendingOps.length, 1);
      final op = pendingOps.first;
      expect(op.entityType, 'order');
      expect(op.entityId, 'ord-offline-1');
      expect(op.operationType, 'create');

      final payload = jsonDecode(op.payload!) as Map<String, dynamic>;
      expect(payload['order_number'], '$yearPrefix-001');
      expect(payload['id'], 'ord-offline-1');
    });

    test('4. Order number immutability (BR-018): Order updates preserve order_number', () async {
      final order = await orderRepository.createOrder(
        order: createDraftOrder(id: 'ord-immut-1'),
        items: [createOrderItem(id: 'item-immut-1', orderId: 'ord-immut-1')],
      );
      expect(order.orderNumber, '$yearPrefix-001');

      // Update order status/notes
      final updatedOrder = await orderRepository.editProcessingOrder(
        EditProcessingOrderInput(
          orderId: 'ord-immut-1',
          customerId: 'cust-terminal-1',
          expectedPickupDate: OrderDate.fromDate(now.add(const Duration(days: 3))),
          notes: 'ملاحظة محدثة',
        ),
      );

      // Order number MUST be identical
      expect(updatedOrder.orderNumber, '$yearPrefix-001');

      final rowAfterEdit = await ordersDao.getOrderById('ord-immut-1');
      expect(rowAfterEdit!.orderNumber, '$yearPrefix-001');
    });

    test('5. Remote pull applies remote orders cleanly and increments local sequence', () async {
      // Simulate remote order created and pulled
      final remoteChange = SyncChangeDto(
        sequence: 1,
        operationId: 'op-remote-1',
        entityType: 'order',
        entityId: 'ord-remote-1',
        operationType: 'create',
        payload: {
          'id': 'ord-remote-1',
          'order_number': '$yearPrefix-001',
          'customer_id': 'cust-terminal-1',
          'customer_name_snapshot': 'عميل المحل',
          'customer_phone_snapshot': '01011112222',
          'status': 'processing',
          'expected_pickup_date': now.toIso8601String(),
          'subtotal': 2500,
          'discount': 0,
          'tax': 0,
          'total': 2500,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
          'items': [
            {
              'id': 'item-remote-1',
              'item_type_id': '00000000-0000-0000-0001-000000000001',
              'service_id': 'srv-wash',
              'item_type_name_snapshot': 'قميص',
              'service_name_snapshot': 'غسيل وكوي',
              'pricing_type': 'per_piece',
              'quantity': 1,
              'unit_price': 2500,
              'calculated_total': 2500,
              'created_at': now.toIso8601String(),
              'updated_at': now.toIso8601String(),
            }
          ],
        },
        createdAt: now,
      );

      await remoteChangeApplier.applyBatch([remoteChange]);

      // Verify remote order ingested
      final pulledOrder = await ordersDao.getOrderById('ord-remote-1');
      expect(pulledOrder, isNotNull);
      expect(pulledOrder!.orderNumber, '$yearPrefix-001');

      // Next local order generation MUST see the pulled order and generate 002
      final nextLocalNum = await ordersDao.generateNextOrderNumber();
      expect(nextLocalNum, '$yearPrefix-002');

      final localOrder = await orderRepository.createOrder(
        order: createDraftOrder(id: 'ord-local-after-pull'),
        items: [createOrderItem(id: 'item-local-2', orderId: 'ord-local-after-pull')],
      );
      expect(localOrder.orderNumber, '$yearPrefix-002');
    });

    test('6. Historical orders (26-001..26-022) remain valid and generator continues cleanly to 26-023', () async {
      for (int i = 1; i <= 22; i++) {
        final padded = i.toString().padLeft(3, '0');
        await db.into(db.orders).insert(
          app_db.OrdersCompanion.insert(
            id: 'hist-$i',
            orderNumber: '$yearPrefix-$padded',
            customerId: 'cust-terminal-1',
            expectedPickupDate: now,
            subtotal: 2500,
            total: 2500,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      // Verify generator continues cleanly from highest existing order
      final nextNumber = await ordersDao.generateNextOrderNumber();
      expect(nextNumber, '$yearPrefix-023');

      // Verify historical orders are intact
      final firstHist = await ordersDao.getOrderByNumber('$yearPrefix-001');
      final lastHist = await ordersDao.getOrderByNumber('$yearPrefix-022');
      expect(firstHist?.id, 'hist-1');
      expect(lastHist?.id, 'hist-22');
    });

    test(
      '7. BUG-04 Invariant: Different UUID with duplicate order_number is rejected by UNIQUE constraint and does not advance cursor',
      () async {
        // 1. Local terminal creates order 26-001 with UUID-A
        final localOrder = await orderRepository.createOrder(
          order: createDraftOrder(id: 'ord-uuid-A'),
          items: [createOrderItem(id: 'item-uuid-A', orderId: 'ord-uuid-A')],
        );
        expect(localOrder.orderNumber, '$yearPrefix-001');

        final initialCursor = await syncStateDao.getLastAppliedSequence();
        expect(initialCursor, 0);

        // 2. Incoming remote change arrives with different UUID-B but identical order_number '26-001'
        final collidingRemoteChange = SyncChangeDto(
          sequence: 42,
          operationId: 'op-colliding-1',
          entityType: 'order',
          entityId: 'ord-uuid-B',
          operationType: 'create',
          payload: {
            'id': 'ord-uuid-B',
            'order_number': '$yearPrefix-001',
            'customer_id': 'cust-terminal-1',
            'customer_name_snapshot': 'عميل محطة أخرى',
            'customer_phone_snapshot': '01099998888',
            'status': 'processing',
            'expected_pickup_date': now.toIso8601String(),
            'subtotal': 2500,
            'discount': 0,
            'tax': 0,
            'total': 2500,
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
            'items': [
              {
                'id': 'item-uuid-B',
                'item_type_id': '00000000-0000-0000-0001-000000000001',
                'service_id': 'srv-wash',
                'item_type_name_snapshot': 'قميص',
                'service_name_snapshot': 'غسيل وكوي',
                'pricing_type': 'per_piece',
                'quantity': 1,
                'unit_price': 2500,
                'calculated_total': 2500,
                'created_at': now.toIso8601String(),
                'updated_at': now.toIso8601String(),
              }
            ],
          },
          createdAt: now,
        );

        // 3. Applying the colliding change MUST fail due to SQLite UNIQUE constraint
        expect(
          () => remoteChangeApplier.applyBatch([collidingRemoteChange]),
          throwsA(isA<Exception>()),
        );

        // 4. Verify invariants after the failed transaction:
        // A. Local order remains completely intact and was not overwritten
        final localStored = await ordersDao.getOrderById('ord-uuid-A');
        expect(localStored, isNotNull);
        expect(localStored!.orderNumber, '$yearPrefix-001');

        // B. Colliding remote order was NOT inserted
        final remoteStored = await ordersDao.getOrderById('ord-uuid-B');
        expect(remoteStored, isNull);

        // C. Sync cursor did NOT advance past the failed change
        final cursorAfterFailure = await syncStateDao.getLastAppliedSequence();
        expect(cursorAfterFailure, initialCursor);
      },
    );

    test(
      '8. Multi-Change Lifecycle Replication: Create, Edit, Payment on Terminal 1 replicate to Terminal 2 with stable order_number',
      () async {
        // Simulate Terminal 2 receiving full sequence from Terminal 1:
        // Change 1: Order Create
        final change1 = SyncChangeDto(
          sequence: 10,
          operationId: 'op-create-10',
          entityType: 'order',
          entityId: 'ord-multi-1',
          operationType: 'create',
          payload: {
            'id': 'ord-multi-1',
            'order_number': '$yearPrefix-001',
            'customer_id': 'cust-terminal-1',
            'customer_name_snapshot': 'عميل المحل',
            'customer_phone_snapshot': '01011112222',
            'status': 'processing',
            'expected_pickup_date': now.toIso8601String(),
            'subtotal': 2500,
            'discount': 0,
            'tax': 0,
            'total': 2500,
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
            'items': [
              {
                'id': 'item-m-1',
                'item_type_id': '00000000-0000-0000-0001-000000000001',
                'service_id': 'srv-wash',
                'item_type_name_snapshot': 'قميص',
                'service_name_snapshot': 'غسيل وكوي',
                'pricing_type': 'per_piece',
                'quantity': 1,
                'unit_price': 2500,
                'calculated_total': 2500,
                'created_at': now.toIso8601String(),
                'updated_at': now.toIso8601String(),
              }
            ],
          },
          createdAt: now,
        );

        // Change 2: Order Edit (notes modified, price updated to 5000)
        final change2 = SyncChangeDto(
          sequence: 11,
          operationId: 'op-edit-11',
          entityType: 'order',
          entityId: 'ord-multi-1',
          operationType: 'edit',
          payload: {
            'id': 'ord-multi-1',
            'order_number': '$yearPrefix-001',
            'customer_id': 'cust-terminal-1',
            'status': 'processing',
            'expected_pickup_date': now.toIso8601String(),
            'notes': 'ملاحظة بعد التعديل',
            'subtotal': 5000,
            'discount': 0,
            'tax': 0,
            'total': 5000,
            'updated_at': now.add(const Duration(minutes: 5)).toIso8601String(),
            'items': [
              {
                'id': 'item-m-1',
                'item_type_id': '00000000-0000-0000-0001-000000000001',
                'service_id': 'srv-wash',
                'item_type_name_snapshot': 'قميص',
                'service_name_snapshot': 'غسيل وكوي',
                'pricing_type': 'per_piece',
                'quantity': 2,
                'unit_price': 2500,
                'calculated_total': 5000,
                'created_at': now.toIso8601String(),
                'updated_at': now.add(const Duration(minutes: 5)).toIso8601String(),
              }
            ],
          },
          createdAt: now.add(const Duration(minutes: 5)),
        );

        // Change 3: Payment Create
        final change3 = SyncChangeDto(
          sequence: 12,
          operationId: 'op-pay-12',
          entityType: 'payment',
          entityId: 'pay-multi-1',
          operationType: 'create',
          payload: {
            'id': 'pay-multi-1',
            'order_id': 'ord-multi-1',
            'amount': 5000,
            'payment_method': 'cash',
            'paid_at': now.add(const Duration(minutes: 6)).toIso8601String(),
            'created_at': now.add(const Duration(minutes: 6)).toIso8601String(),
            'updated_at': now.add(const Duration(minutes: 6)).toIso8601String(),
          },
          createdAt: now.add(const Duration(minutes: 6)),
        );

        // Apply changes in batch to simulate Terminal 2 pull
        await remoteChangeApplier.applyBatch([change1, change2, change3]);

        // Verify Terminal 2 local state
        final orderOnT2 = await ordersDao.getOrderById('ord-multi-1');
        expect(orderOnT2, isNotNull);
        expect(orderOnT2!.orderNumber, '$yearPrefix-001'); // Immutable
        expect(orderOnT2.total, 5000);
        expect(orderOnT2.notes, 'ملاحظة بعد التعديل');

        // Verify payment stored
        final paymentsOnT2 = await paymentsDao.getPaymentsForOrder('ord-multi-1');
        expect(paymentsOnT2.length, 1);
        expect(paymentsOnT2.first.id, 'pay-multi-1');
        expect(paymentsOnT2.first.amount, 5000);
        expect(paymentsOnT2.first.orderId, 'ord-multi-1');

        // Verify cursor advanced to 12
        final cursor = await syncStateDao.getLastAppliedSequence();
        expect(cursor, 12);
      },
    );

    test(
      '9. Replacement Terminal Bootstrap: Fresh device hydrates remote orders and continues sequence correctly',
      () async {
        // Fresh terminal starts with 0 orders and cursor at 0
        final initialRows = await ordersDao.getOrders();
        expect(initialRows, isEmpty);
        expect(await syncStateDao.getLastAppliedSequence(), 0);

        // Scenario 10 invariant: An un-hydrated fresh device generates 26-001
        final unhydratedCandidate = await ordersDao.generateNextOrderNumber();
        expect(unhydratedCandidate, '$yearPrefix-001');

        // Perform initial sync/bootstrap: hydrate remote historical orders (e.g. 26-001 through 26-005)
        final bootstrapChanges = List.generate(5, (index) {
          final seq = index + 1;
          final padded = seq.toString().padLeft(3, '0');
          return SyncChangeDto(
            sequence: seq,
            operationId: 'op-boot-$seq',
            entityType: 'order',
            entityId: 'ord-boot-$seq',
            operationType: 'create',
            payload: {
              'id': 'ord-boot-$seq',
              'order_number': '$yearPrefix-$padded',
              'customer_id': 'cust-terminal-1',
              'customer_name_snapshot': 'عميل المحل',
              'customer_phone_snapshot': '01011112222',
              'status': 'processing',
              'expected_pickup_date': now.toIso8601String(),
              'subtotal': 2500,
              'discount': 0,
              'tax': 0,
              'total': 2500,
              'created_at': now.toIso8601String(),
              'updated_at': now.toIso8601String(),
              'items': [],
            },
            createdAt: now,
          );
        });

        await remoteChangeApplier.applyBatch(bootstrapChanges);

        // Verify all 5 orders are hydrated
        expect(await syncStateDao.getLastAppliedSequence(), 5);
        final fifthOrder = await ordersDao.getOrderByNumber('$yearPrefix-005');
        expect(fifthOrder, isNotNull);

        // Now that initial sync has completed, the replacement device generates 26-006!
        final hydratedCandidate = await ordersDao.generateNextOrderNumber();
        expect(hydratedCandidate, '$yearPrefix-006');

        final newOrder = await orderRepository.createOrder(
          order: createDraftOrder(id: 'ord-boot-6'),
          items: [createOrderItem(id: 'item-boot-6', orderId: 'ord-boot-6')],
        );
        expect(newOrder.orderNumber, '$yearPrefix-006');
      },
    );
  });
}
