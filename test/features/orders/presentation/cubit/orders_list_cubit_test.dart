import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/local/daos/customers_dao.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/services_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart'
    as db_pkg;
import 'package:laundry_management/data/repositories/customer_repository_impl.dart';
import 'package:laundry_management/data/repositories/order_repository_impl.dart';
import 'package:laundry_management/data/repositories/payment_repository_impl.dart';
import 'package:laundry_management/domain/repositories/order_repository.dart';
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/entities/payment.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/enums/payment_method.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';
import 'package:laundry_management/features/orders/presentation/cubit/orders_list_cubit.dart';
import 'package:laundry_management/features/orders/presentation/models/order_list_filter.dart';

void main() {
  late db_pkg.AppDatabase db;
  late CustomersDao customersDao;
  late OrdersDao ordersDao;
  late PaymentsDao paymentsDao;
  late StorageRecordsDao storageRecordsDao;
  late ServicesDao servicesDao;
  late SyncOperationsDao syncOperationsDao;

  late CustomerRepositoryImpl customerRepository;
  late OrderRepositoryImpl orderRepository;
  late PaymentRepositoryImpl paymentRepository;
  late OrdersListCubit cubit;

  setUp(() async {
    db = db_pkg.AppDatabase(NativeDatabase.memory());
    customersDao = CustomersDao(db);
    ordersDao = OrdersDao(db);
    paymentsDao = PaymentsDao(db);
    storageRecordsDao = StorageRecordsDao(db);
    servicesDao = ServicesDao(db);
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

    paymentRepository = PaymentRepositoryImpl(
      paymentsDao: paymentsDao,
      ordersDao: ordersDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    cubit = OrdersListCubit(
      orderRepository: orderRepository,
      customerRepository: customerRepository,
      paymentRepository: paymentRepository,
    );
  });

  tearDown(() async {
    await cubit.close();
    await db.close();
  });

  Future<void> seedOrder({
    required String orderId,
    required String orderNumber,
    required String customerId,
    required String customerName,
    required String phone,
    required OrderStatus status,
    required int totalPiastres,
    int paidPiastres = 0,
    OrderDate? expectedPickupDate,
    DateTime? expectedPickupDateTime,
    DateTime? createdAt,
  }) async {
    final now = createdAt ?? DateTime.now();
    await customerRepository.createCustomer(
      Customer(
        id: customerId,
        name: customerName,
        phone: phone,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final itemTypes = await db.select(db.itemTypes).get();
    await servicesDao.insertService(
      db_pkg.ServicesCompanion.insert(
        id: 'srv-$orderId',
        name: 'خدمة $orderId',
        pricingType: 'perPiece',
        price: totalPiastres,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final order = Order(
      id: orderId,
      orderNumber: orderNumber,
      customerId: customerId,
      customerNameSnapshot: 'عميل القائمة',
      customerPhoneSnapshot: '01012345678',
      status: status,
      expectedPickupDate: expectedPickupDate ??
          (expectedPickupDateTime != null
              ? OrderDate.fromDate(expectedPickupDateTime)
              : OrderDate(2026, 9, 20)),
      subtotal: Money.fromPiastres(totalPiastres),
      total: Money.fromPiastres(totalPiastres),
      completedAt: status == OrderStatus.completed ? now : null,
      cancelledAt: status == OrderStatus.cancelled ? now : null,
      cancellationReason: status == OrderStatus.cancelled
          ? 'سبب الإلغاء'
          : null,
      createdAt: now,
      updatedAt: now,
    );

    final item = OrderItem(
      id: 'item-$orderId',
      orderId: orderId,
      itemTypeId: itemTypes.first.id,
      serviceId: 'srv-$orderId',
      itemTypeNameSnapshot: 'قطعة',
      serviceNameSnapshot: 'خدمة',
      pricingType: PricingType.perPiece,
      quantity: 1.0,
      unitPrice: Money.fromPiastres(totalPiastres),
      calculatedTotal: Money.fromPiastres(totalPiastres),
      createdAt: now,
      updatedAt: now,
    );

    await orderRepository.createOrder(order: order, items: [item]);

    if (expectedPickupDateTime != null) {
      await (db.update(db.orders)..where((t) => t.id.equals(orderId))).write(
        db_pkg.OrdersCompanion(
          expectedPickupDate: Value(expectedPickupDateTime),
        ),
      );
    }

    if (paidPiastres > 0) {
      await paymentRepository.recordPayment(
        Payment(
          id: 'pay-$orderId',
          orderId: orderId,
          amount: Money.fromPiastres(paidPiastres),
          paymentMethod: PaymentMethod.cash,
          paidAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }

  group('OrdersListCubit', () {
    test('initial state is default empty', () {
      expect(cubit.state.orders, isEmpty);
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.activeFilter, OrderListFilter.all);
    });

    test(
      'loadOrders enriches items with customer details and remaining balances',
      () async {
        await seedOrder(
          orderId: 'ord-1',
          orderNumber: '26-001',
          customerId: 'cust-1',
          customerName: 'محمد أحمد',
          phone: '01011111111',
          status: OrderStatus.processing,
          totalPiastres: 5000,
          paidPiastres: 2000,
        );

        await cubit.loadOrders();

        expect(cubit.state.orders.length, 1);
        final vm = cubit.state.orders.first;
        expect(vm.order.orderNumber, '26-001');
        expect(vm.customer?.name, 'محمد أحمد');
        expect(vm.totalPaid, const Money.fromPiastres(2000));
        expect(vm.remainingAmount, const Money.fromPiastres(3000));
        expect(vm.isFullyPaid, isFalse);
      },
    );

    test('setFilter applies filter and reloads list', () async {
      await seedOrder(
        orderId: 'ord-1',
        orderNumber: '26-001',
        customerId: 'cust-1',
        customerName: 'عميل 1',
        phone: '01011111111',
        status: OrderStatus.processing,
        totalPiastres: 5000,
      );

      await seedOrder(
        orderId: 'ord-2',
        orderNumber: '26-002',
        customerId: 'cust-2',
        customerName: 'عميل 2',
        phone: '01022222222',
        status: OrderStatus.ready,
        totalPiastres: 3000,
      );

      // Filter by ready
      cubit.setFilter(OrderListFilter.ready);
      await pumpEventQueue();

      expect(cubit.state.activeFilter, OrderListFilter.ready);
      expect(cubit.state.orders.length, 1);
      expect(cubit.state.orders.first.order.id, 'ord-2');
    });

    group('Completed and Cancelled Filters & Resilience', () {
      test(
        'completed filter returns only completed orders and excludes ready/processing/cancelled',
        () async {
          await seedOrder(
            orderId: 'ord-proc',
            orderNumber: '26-P01',
            customerId: 'cust-1',
            customerName: 'عميل 1',
            phone: '01011111111',
            status: OrderStatus.processing,
            totalPiastres: 5000,
          );
          await seedOrder(
            orderId: 'ord-ready',
            orderNumber: '26-R01',
            customerId: 'cust-2',
            customerName: 'عميل 2',
            phone: '01022222222',
            status: OrderStatus.ready,
            totalPiastres: 3000,
          );
          await seedOrder(
            orderId: 'ord-comp',
            orderNumber: '26-C01',
            customerId: 'cust-3',
            customerName: 'عميل 3',
            phone: '01033333333',
            status: OrderStatus.completed,
            totalPiastres: 4000,
          );
          await seedOrder(
            orderId: 'ord-canc',
            orderNumber: '26-X01',
            customerId: 'cust-4',
            customerName: 'عميل 4',
            phone: '01044444444',
            status: OrderStatus.cancelled,
            totalPiastres: 2000,
          );

          cubit.setFilter(OrderListFilter.completed);
          await pumpEventQueue();

          expect(cubit.state.activeFilter, OrderListFilter.completed);
          expect(cubit.state.orders.length, 1);
          expect(cubit.state.orders.first.order.id, 'ord-comp');
          expect(cubit.state.orders.first.order.status, OrderStatus.completed);
          expect(
            cubit.state.orders.any((o) => o.order.status == OrderStatus.ready),
            isFalse,
          );
          expect(
            cubit.state.orders.any(
              (o) => o.order.status == OrderStatus.processing,
            ),
            isFalse,
          );
          expect(
            cubit.state.orders.any(
              (o) => o.order.status == OrderStatus.cancelled,
            ),
            isFalse,
          );
        },
      );

      test(
        'cancelled filter returns only cancelled orders and excludes ready/processing/completed',
        () async {
          await seedOrder(
            orderId: 'ord-proc',
            orderNumber: '26-P01',
            customerId: 'cust-1',
            customerName: 'عميل 1',
            phone: '01011111111',
            status: OrderStatus.processing,
            totalPiastres: 5000,
          );
          await seedOrder(
            orderId: 'ord-ready',
            orderNumber: '26-R01',
            customerId: 'cust-2',
            customerName: 'عميل 2',
            phone: '01022222222',
            status: OrderStatus.ready,
            totalPiastres: 3000,
          );
          await seedOrder(
            orderId: 'ord-comp',
            orderNumber: '26-C01',
            customerId: 'cust-3',
            customerName: 'عميل 3',
            phone: '01033333333',
            status: OrderStatus.completed,
            totalPiastres: 4000,
          );
          await seedOrder(
            orderId: 'ord-canc',
            orderNumber: '26-X01',
            customerId: 'cust-4',
            customerName: 'عميل 4',
            phone: '01044444444',
            status: OrderStatus.cancelled,
            totalPiastres: 2000,
          );

          cubit.setFilter(OrderListFilter.cancelled);
          await pumpEventQueue();

          expect(cubit.state.activeFilter, OrderListFilter.cancelled);
          expect(cubit.state.orders.length, 1);
          expect(cubit.state.orders.first.order.id, 'ord-canc');
          expect(cubit.state.orders.first.order.status, OrderStatus.cancelled);
          expect(
            cubit.state.orders.any((o) => o.order.status == OrderStatus.ready),
            isFalse,
          );
          expect(
            cubit.state.orders.any(
              (o) => o.order.status == OrderStatus.processing,
            ),
            isFalse,
          );
          expect(
            cubit.state.orders.any(
              (o) => o.order.status == OrderStatus.completed,
            ),
            isFalse,
          );
        },
      );

      test(
        'changing from one filter to another actually refreshes the list',
        () async {
          await seedOrder(
            orderId: 'ord-proc',
            orderNumber: '26-P01',
            customerId: 'cust-1',
            customerName: 'عميل 1',
            phone: '01011111111',
            status: OrderStatus.processing,
            totalPiastres: 5000,
          );
          await seedOrder(
            orderId: 'ord-ready',
            orderNumber: '26-R01',
            customerId: 'cust-2',
            customerName: 'عميل 2',
            phone: '01022222222',
            status: OrderStatus.ready,
            totalPiastres: 3000,
          );
          await seedOrder(
            orderId: 'ord-comp',
            orderNumber: '26-C01',
            customerId: 'cust-3',
            customerName: 'عميل 3',
            phone: '01033333333',
            status: OrderStatus.completed,
            totalPiastres: 4000,
          );
          await seedOrder(
            orderId: 'ord-canc',
            orderNumber: '26-X01',
            customerId: 'cust-4',
            customerName: 'عميل 4',
            phone: '01044444444',
            status: OrderStatus.cancelled,
            totalPiastres: 2000,
          );

          // 1. Filter by Ready
          cubit.setFilter(OrderListFilter.ready);
          await pumpEventQueue();
          expect(cubit.state.activeFilter, OrderListFilter.ready);
          expect(cubit.state.orders.length, 1);
          expect(cubit.state.orders.first.order.id, 'ord-ready');

          // 2. Change to Completed -> Must refresh to completed order
          cubit.setFilter(OrderListFilter.completed);
          await pumpEventQueue();
          expect(cubit.state.activeFilter, OrderListFilter.completed);
          expect(cubit.state.orders.length, 1);
          expect(cubit.state.orders.first.order.id, 'ord-comp');

          // 3. Change to Cancelled -> Must refresh to cancelled order
          cubit.setFilter(OrderListFilter.cancelled);
          await pumpEventQueue();
          expect(cubit.state.activeFilter, OrderListFilter.cancelled);
          expect(cubit.state.orders.length, 1);
          expect(cubit.state.orders.first.order.id, 'ord-canc');

          // 4. Change to All -> Must refresh to all 4 orders
          cubit.setFilter(OrderListFilter.all);
          await pumpEventQueue();
          expect(cubit.state.activeFilter, OrderListFilter.all);
          expect(cubit.state.orders.length, 4);
        },
      );

      test(
        'search combined with completed and cancelled filters works correctly',
        () async {
          await seedOrder(
            orderId: 'ord-comp-1',
            orderNumber: '26-C01',
            customerId: 'cust-hassan',
            customerName: 'حسن كمال',
            phone: '01011119999',
            status: OrderStatus.completed,
            totalPiastres: 4000,
          );
          await seedOrder(
            orderId: 'ord-comp-2',
            orderNumber: '26-C02',
            customerId: 'cust-ali',
            customerName: 'علي كمال',
            phone: '01022229999',
            status: OrderStatus.completed,
            totalPiastres: 4000,
          );
          await seedOrder(
            orderId: 'ord-canc-1',
            orderNumber: '26-X01',
            customerId: 'cust-hassan-canc',
            customerName: 'حسن نصر',
            phone: '01033339999',
            status: OrderStatus.cancelled,
            totalPiastres: 2000,
          );

          // Completed + search "حسن"
          cubit.setFilter(OrderListFilter.completed);
          await pumpEventQueue();
          expect(cubit.state.orders.length, 2);

          cubit.search('حسن');
          await pumpEventQueue();
          expect(cubit.state.orders.length, 1);
          expect(cubit.state.orders.first.order.id, 'ord-comp-1');

          // Cancelled + search "حسن"
          cubit.setFilter(OrderListFilter.cancelled);
          await pumpEventQueue();
          expect(cubit.state.orders.length, 1);
          expect(cubit.state.orders.first.order.id, 'ord-canc-1');

          // Cancelled + search "علي" (Ali has completed ord-comp-2, no cancelled)
          cubit.search('علي');
          await pumpEventQueue();
          expect(cubit.state.orders.isEmpty, true);
        },
      );

      test(
        'completed orders with null completed_at from database/sync are safely mapped and loaded',
        () async {
          final now = DateTime.now();
          // Insert customer
          await customerRepository.createCustomer(
            Customer(
              id: 'cust-sync-comp',
              name: 'عميل مزامنة مكتمل',
              phone: '01077777777',
              createdAt: now,
              updatedAt: now,
            ),
          );

          // Insert raw SQLite row directly with status = 'completed' and completedAt = null
          await db.into(db.orders).insert(
            db_pkg.OrdersCompanion.insert(
              id: 'ord-sync-comp',
              orderNumber: '26-SC01',
              customerId: 'cust-sync-comp',
              customerNameSnapshot: const Value('عميل مزامنة مكتمل'),
              customerPhoneSnapshot: const Value('01077777777'),
              status: Value(OrderStatus.completed.value),
              expectedPickupDate: DateTime(2026, 9, 20),
              subtotal: 6000,
              total: 6000,
              completedAt: const Value(null),
              createdAt: DateTime(2026, 9, 1, 10, 0),
              updatedAt: DateTime(2026, 9, 1, 12, 0),
            ),
          );

          cubit.setFilter(OrderListFilter.completed);
          await pumpEventQueue();

          expect(cubit.state.errorMessage, isNull);
          expect(cubit.state.orders.length, 1);
          final loaded = cubit.state.orders.first.order;
          expect(loaded.id, 'ord-sync-comp');
          expect(loaded.status, OrderStatus.completed);
          expect(loaded.completedAt, isNotNull);
          expect(loaded.completedAt, loaded.updatedAt);
        },
      );

      test(
        'cancelled orders with null cancelled_at and null/empty cancellation_reason from database/sync are safely mapped and loaded',
        () async {
          final now = DateTime.now();
          await customerRepository.createCustomer(
            Customer(
              id: 'cust-sync-canc',
              name: 'عميل مزامنة ملغي',
              phone: '01088888888',
              createdAt: now,
              updatedAt: now,
            ),
          );

          // Insert raw SQLite row directly with status = 'cancelled', cancelledAt = null, cancellationReason = null
          await db.into(db.orders).insert(
            db_pkg.OrdersCompanion.insert(
              id: 'ord-sync-canc',
              orderNumber: '26-SX01',
              customerId: 'cust-sync-canc',
              customerNameSnapshot: const Value('عميل مزامنة ملغي'),
              customerPhoneSnapshot: const Value('01088888888'),
              status: Value(OrderStatus.cancelled.value),
              expectedPickupDate: DateTime(2026, 9, 20),
              notes: const Value('ملاحظة سبب يدوي'),
              subtotal: 4500,
              total: 4500,
              cancelledAt: const Value(null),
              cancellationReason: const Value(null),
              createdAt: DateTime(2026, 9, 2, 10, 0),
              updatedAt: DateTime(2026, 9, 2, 11, 0),
            ),
          );

          cubit.setFilter(OrderListFilter.cancelled);
          await pumpEventQueue();

          expect(cubit.state.errorMessage, isNull);
          expect(cubit.state.orders.length, 1);
          final loaded = cubit.state.orders.first.order;
          expect(loaded.id, 'ord-sync-canc');
          expect(loaded.status, OrderStatus.cancelled);
          expect(loaded.cancelledAt, isNotNull);
          expect(loaded.cancelledAt, loaded.updatedAt);
          expect(loaded.cancellationReason, 'ملاحظة سبب يدوي');
        },
      );
    });

    test('search updates query and queries database', () async {
      await seedOrder(
        orderId: 'ord-1',
        orderNumber: '26-001',
        customerId: 'cust-1',
        customerName: 'عميل خاص',
        phone: '01055555555',
        status: OrderStatus.processing,
        totalPiastres: 5000,
      );

      cubit.search('خاص');
      await pumpEventQueue();

      expect(cubit.state.searchQuery, 'خاص');
      expect(cubit.state.orders.length, 1);
      expect(cubit.state.orders.first.customer?.name, 'عميل خاص');
    });

    test(
      'todayPickup filter returns active orders due today and excludes completed/cancelled or other dates',
      () async {
        final today = OrderDate.today();
        final tomorrow = OrderDate.fromDate(
          DateTime.now().add(const Duration(days: 1)),
        );

        // Active due today -> should be included
        await seedOrder(
          orderId: 'ord-today-active',
          orderNumber: '26-101',
          customerId: 'cust-101',
          customerName: 'عميل اليوم نشط',
          phone: '01010000001',
          status: OrderStatus.processing,
          expectedPickupDate: today,
          totalPiastres: 5000,
        );

        // Completed due today -> should be excluded
        await seedOrder(
          orderId: 'ord-today-completed',
          orderNumber: '26-102',
          customerId: 'cust-102',
          customerName: 'عميل اليوم مكتمل',
          phone: '01010000002',
          status: OrderStatus.completed,
          expectedPickupDate: today,
          totalPiastres: 4000,
        );

        // Cancelled due today -> should be excluded
        await seedOrder(
          orderId: 'ord-today-cancelled',
          orderNumber: '26-103',
          customerId: 'cust-103',
          customerName: 'عميل اليوم ملغي',
          phone: '01010000003',
          status: OrderStatus.cancelled,
          expectedPickupDate: today,
          totalPiastres: 3000,
        );

        // Active due tomorrow -> should be excluded
        await seedOrder(
          orderId: 'ord-tomorrow-active',
          orderNumber: '26-104',
          customerId: 'cust-104',
          customerName: 'عميل الغد',
          phone: '01010000004',
          status: OrderStatus.processing,
          expectedPickupDate: tomorrow,
          totalPiastres: 6000,
        );

        cubit.setFilter(OrderListFilter.todayPickup);
        await pumpEventQueue();

        expect(cubit.state.orders.length, 1);
        expect(cubit.state.orders.first.order.id, 'ord-today-active');
      },
    );

    test(
      'overdue filter returns active overdue orders and excludes completed or due today',
      () async {
        final yesterday = OrderDate.fromDate(
          DateTime.now().subtract(const Duration(days: 1)),
        );
        final today = OrderDate.today();

        // Active due yesterday -> should be included
        await seedOrder(
          orderId: 'ord-overdue-active',
          orderNumber: '26-201',
          customerId: 'cust-201',
          customerName: 'عميل متأخر نشط',
          phone: '01020000001',
          status: OrderStatus.processing,
          expectedPickupDate: yesterday,
          totalPiastres: 5000,
        );

        // Completed due yesterday -> should be excluded
        await seedOrder(
          orderId: 'ord-overdue-completed',
          orderNumber: '26-202',
          customerId: 'cust-202',
          customerName: 'عميل متأخر مكتمل',
          phone: '01020000002',
          status: OrderStatus.completed,
          expectedPickupDate: yesterday,
          totalPiastres: 5000,
        );

        // Active due today -> should be excluded from overdue
        await seedOrder(
          orderId: 'ord-due-today',
          orderNumber: '26-203',
          customerId: 'cust-203',
          customerName: 'عميل مستحق اليوم',
          phone: '01020000003',
          status: OrderStatus.processing,
          expectedPickupDate: today,
          totalPiastres: 5000,
        );

        cubit.setFilter(OrderListFilter.overdue);
        await pumpEventQueue();

        expect(cubit.state.orders.length, 1);
        expect(cubit.state.orders.first.order.id, 'ord-overdue-active');
      },
    );

    group('Deterministic Date-based Filters (Today Pickup vs Overdue)', () {
      late OrdersListCubit testCubit;
      final fixedNow = DateTime(2026, 9, 26, 12, 0, 0); // Saturday 2026-09-26 12:00:00

      setUp(() async {
        testCubit = OrdersListCubit(
          orderRepository: orderRepository,
          customerRepository: customerRepository,
          paymentRepository: paymentRepository,
          clock: () => fixedNow,
        );

        // 1. Expected pickup = yesterday UTC midnight (2026-09-25 00:00:00 UTC)
        await seedOrder(
          orderId: 'ord-det-yesterday-utc',
          orderNumber: '26-DET01',
          customerId: 'cust-det-1',
          customerName: 'عميل أمس UTC',
          phone: '01090000001',
          status: OrderStatus.processing,
          expectedPickupDateTime: DateTime.utc(2026, 9, 25, 0, 0, 0),
          totalPiastres: 5000,
        );

        // 2. Expected pickup = yesterday afternoon (2026-09-25 15:30:00)
        await seedOrder(
          orderId: 'ord-det-yesterday-afternoon',
          orderNumber: '26-DET02',
          customerId: 'cust-det-2',
          customerName: 'عميل أمس بعد الظهر',
          phone: '01090000002',
          status: OrderStatus.processing,
          expectedPickupDateTime: DateTime(2026, 9, 25, 15, 30, 0),
          totalPiastres: 5000,
        );

        // 3. Expected pickup = today midnight (2026-09-26 00:00:00)
        await seedOrder(
          orderId: 'ord-det-today-midnight',
          orderNumber: '26-DET03',
          customerId: 'cust-det-3',
          customerName: 'عميل اليوم منتصف الليل',
          phone: '01090000003',
          status: OrderStatus.processing,
          expectedPickupDateTime: DateTime(2026, 9, 26, 0, 0, 0),
          totalPiastres: 5000,
        );

        // 4. Expected pickup = today afternoon (2026-09-26 14:30:00)
        await seedOrder(
          orderId: 'ord-det-today-afternoon',
          orderNumber: '26-DET04',
          customerId: 'cust-det-4',
          customerName: 'عميل اليوم بعد الظهر',
          phone: '01090000004',
          status: OrderStatus.ready,
          expectedPickupDateTime: DateTime(2026, 9, 26, 14, 30, 0),
          totalPiastres: 5000,
        );

        // 5. Expected pickup = today end-of-day (2026-09-26 23:59:59)
        await seedOrder(
          orderId: 'ord-det-today-end-of-day',
          orderNumber: '26-DET05',
          customerId: 'cust-det-5',
          customerName: 'عميل اليوم نهاية اليوم',
          phone: '01090000005',
          status: OrderStatus.processing,
          expectedPickupDateTime: DateTime(2026, 9, 26, 23, 59, 59),
          totalPiastres: 5000,
        );

        // 6. Expected pickup = today but completed
        await seedOrder(
          orderId: 'ord-det-today-completed',
          orderNumber: '26-DET06',
          customerId: 'cust-det-6',
          customerName: 'عميل اليوم مكتمل',
          phone: '01090000006',
          status: OrderStatus.completed,
          expectedPickupDateTime: DateTime(2026, 9, 26, 11, 0, 0),
          totalPiastres: 5000,
        );

        // 7. Expected pickup = tomorrow midnight (2026-09-27 00:00:00)
        await seedOrder(
          orderId: 'ord-det-tomorrow-midnight',
          orderNumber: '26-DET07',
          customerId: 'cust-det-7',
          customerName: 'عميل الغد منتصف الليل',
          phone: '01090000007',
          status: OrderStatus.processing,
          expectedPickupDateTime: DateTime(2026, 9, 27, 0, 0, 0),
          totalPiastres: 5000,
        );

        // 8. Expected pickup = tomorrow afternoon (2026-09-27 16:00:00)
        await seedOrder(
          orderId: 'ord-det-tomorrow-afternoon',
          orderNumber: '26-DET08',
          customerId: 'cust-det-8',
          customerName: 'عميل الغد بعد الظهر',
          phone: '01090000008',
          status: OrderStatus.processing,
          expectedPickupDateTime: DateTime(2026, 9, 27, 16, 0, 0),
          totalPiastres: 5000,
        );
      });

      tearDown(() async {
        await testCubit.close();
      });

      test(
        'Case 1 & 2 & 4: Today Pickup filter includes all today active orders across different times, excludes yesterday/tomorrow/completed',
        () async {
          testCubit.setFilter(OrderListFilter.todayPickup);
          await pumpEventQueue();

          final ids = testCubit.state.orders.map((o) => o.order.id).toSet();

          // Must include all active orders for today (midnight, afternoon, end-of-day)
          expect(ids, contains('ord-det-today-midnight'));
          expect(ids, contains('ord-det-today-afternoon'));
          expect(ids, contains('ord-det-today-end-of-day'));
          expect(ids.length, 3);

          // Must NOT include yesterday
          expect(ids.contains('ord-det-yesterday-utc'), isFalse);
          expect(ids.contains('ord-det-yesterday-afternoon'), isFalse);

          // Must NOT include tomorrow
          expect(ids.contains('ord-det-tomorrow-midnight'), isFalse);
          expect(ids.contains('ord-det-tomorrow-afternoon'), isFalse);

          // Must NOT include completed
          expect(ids.contains('ord-det-today-completed'), isFalse);
        },
      );

      test(
        'Case 1 & 2 & 3: Overdue filter includes strictly yesterday orders, never today or tomorrow',
        () async {
          testCubit.setFilter(OrderListFilter.overdue);
          await pumpEventQueue();

          final ids = testCubit.state.orders.map((o) => o.order.id).toSet();

          // Must include yesterday's orders
          expect(ids, contains('ord-det-yesterday-utc'));
          expect(ids, contains('ord-det-yesterday-afternoon'));
          expect(ids.length, 2);

          // Must NOT include today's orders (neither midnight, afternoon, end-of-day, nor completed)
          expect(ids.contains('ord-det-today-midnight'), isFalse);
          expect(ids.contains('ord-det-today-afternoon'), isFalse);
          expect(ids.contains('ord-det-today-end-of-day'), isFalse);
          expect(ids.contains('ord-det-today-completed'), isFalse);

          // Must NOT include tomorrow's orders
          expect(ids.contains('ord-det-tomorrow-midnight'), isFalse);
          expect(ids.contains('ord-det-tomorrow-afternoon'), isFalse);
        },
      );

      test(
        'Case 3: Tomorrow orders appear in neither todayPickup nor overdue filter',
        () async {
          testCubit.setFilter(OrderListFilter.todayPickup);
          await pumpEventQueue();
          final todayIds = testCubit.state.orders.map((o) => o.order.id).toSet();

          testCubit.setFilter(OrderListFilter.overdue);
          await pumpEventQueue();
          final overdueIds = testCubit.state.orders.map((o) => o.order.id).toSet();

          expect(todayIds.contains('ord-det-tomorrow-midnight'), isFalse);
          expect(todayIds.contains('ord-det-tomorrow-afternoon'), isFalse);
          expect(overdueIds.contains('ord-det-tomorrow-midnight'), isFalse);
          expect(overdueIds.contains('ord-det-tomorrow-afternoon'), isFalse);
        },
      );
    });

    test(
      'remaining filter returns only orders with unpaid balance at query level',
      () async {
        // Unpaid order -> included
        await seedOrder(
          orderId: 'ord-unpaid',
          orderNumber: '26-301',
          customerId: 'cust-301',
          customerName: 'عميل غير مسدد',
          phone: '01030000001',
          status: OrderStatus.processing,
          totalPiastres: 5000,
          paidPiastres: 2000,
        );

        // Fully paid order -> excluded
        await seedOrder(
          orderId: 'ord-paid',
          orderNumber: '26-302',
          customerId: 'cust-302',
          customerName: 'عميل مسدد بالكامل',
          phone: '01030000002',
          status: OrderStatus.processing,
          totalPiastres: 5000,
          paidPiastres: 5000,
        );

        cubit.setFilter(OrderListFilter.hasRemaining);
        await pumpEventQueue();

        expect(cubit.state.orders.length, 1);
        expect(cubit.state.orders.first.order.id, 'ord-unpaid');
      },
    );

    group('Outstanding Payment Filter (hasRemaining) Invariants & Precision', () {
      test(
        'returns only orders with remaining amount > 0; strictly excludes fully paid, overpaid, and cancelled orders',
        () async {
          // 1. Partially paid order: Total 240, Paid 100, Remaining 140 (SHOULD APPEAR)
          await seedOrder(
            orderId: 'ord-rem-partial',
            orderNumber: '26-REM01',
            customerId: 'cust-rem-1',
            customerName: 'عميل جزئي',
            phone: '01061111111',
            status: OrderStatus.processing,
            totalPiastres: 24000,
            paidPiastres: 10000,
          );

          // 2. Completely unpaid order: Total 240, Paid 0, Remaining 240 (SHOULD APPEAR)
          await seedOrder(
            orderId: 'ord-rem-unpaid',
            orderNumber: '26-REM02',
            customerId: 'cust-rem-2',
            customerName: 'عميل غير مسدد',
            phone: '01062222222',
            status: OrderStatus.processing,
            totalPiastres: 24000,
            paidPiastres: 0,
          );

          // 3. 1 piastre remaining: Total 240, Paid 239, Remaining 1 (SHOULD APPEAR)
          await seedOrder(
            orderId: 'ord-rem-almost',
            orderNumber: '26-REM03',
            customerId: 'cust-rem-3',
            customerName: 'عميل شبه مسدد',
            phone: '01063333333',
            status: OrderStatus.ready,
            totalPiastres: 24000,
            paidPiastres: 23900,
          );

          // 4. Fully paid ready order: Total 240, Paid 240, Remaining 0 (SHOULD NOT APPEAR)
          await seedOrder(
            orderId: 'ord-rem-full-ready',
            orderNumber: '26-REM04',
            customerId: 'cust-rem-4',
            customerName: 'عميل مسدد جاهز',
            phone: '01064444444',
            status: OrderStatus.ready,
            totalPiastres: 24000,
            paidPiastres: 24000,
          );

          // 5. Overpaid processing order: Total 240, Paid 250, Remaining -10 -> 0 (SHOULD NOT APPEAR)
          await seedOrder(
            orderId: 'ord-rem-overpaid',
            orderNumber: '26-REM05',
            customerId: 'cust-rem-5',
            customerName: 'عميل مسدد بزيادة',
            phone: '01065555555',
            status: OrderStatus.processing,
            totalPiastres: 24000,
            paidPiastres: 0,
          );
          await paymentsDao.insertPayment(
            db_pkg.PaymentsCompanion.insert(
              id: 'pay-overpaid',
              orderId: 'ord-rem-overpaid',
              amount: 25000,
              paymentMethod: 'cash',
              paidAt: DateTime.now(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

          // 6. Completed fully-paid order: Total 200, Paid 200, Remaining 0 (SHOULD NOT APPEAR)
          await seedOrder(
            orderId: 'ord-rem-completed',
            orderNumber: '26-REM06',
            customerId: 'cust-rem-6',
            customerName: 'عميل مكتمل مسدد',
            phone: '01066666666',
            status: OrderStatus.completed,
            totalPiastres: 20000,
            paidPiastres: 0,
          );
          await paymentsDao.insertPayment(
            db_pkg.PaymentsCompanion.insert(
              id: 'pay-completed',
              orderId: 'ord-rem-completed',
              amount: 20000,
              paymentMethod: 'cash',
              paidAt: DateTime.now(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

          // 7. Cancelled fully-paid order: Total 15, Paid 15, Remaining 0 (SHOULD NOT APPEAR)
          await seedOrder(
            orderId: 'ord-rem-canc-paid',
            orderNumber: '26-REM07',
            customerId: 'cust-rem-7',
            customerName: 'عميل ملغي مسدد',
            phone: '01067777777',
            status: OrderStatus.cancelled,
            totalPiastres: 1500,
            paidPiastres: 0,
          );
          await paymentsDao.insertPayment(
            db_pkg.PaymentsCompanion.insert(
              id: 'pay-canc-paid',
              orderId: 'ord-rem-canc-paid',
              amount: 1500,
              paymentMethod: 'cash',
              paidAt: DateTime.now(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

          // 8. Cancelled unpaid order: Total 100, Paid 0, Remaining 0 in domain (SHOULD NOT APPEAR)
          await seedOrder(
            orderId: 'ord-rem-canc-unpaid',
            orderNumber: '26-REM08',
            customerId: 'cust-rem-8',
            customerName: 'عميل ملغي غير مسدد',
            phone: '01068888888',
            status: OrderStatus.cancelled,
            totalPiastres: 10000,
            paidPiastres: 0,
          );

          cubit.setFilter(OrderListFilter.hasRemaining);
          await pumpEventQueue();

          final returnedIds = cubit.state.orders.map((o) => o.order.id).toSet();

          // MUST contain orders with remaining > 0
          expect(returnedIds, contains('ord-rem-partial'));
          expect(returnedIds, contains('ord-rem-unpaid'));
          expect(returnedIds, contains('ord-rem-almost'));
          expect(cubit.state.orders.length, 3);

          // MUST NOT contain fully paid, overpaid, or cancelled orders
          expect(returnedIds.contains('ord-rem-full-ready'), isFalse);
          expect(returnedIds.contains('ord-rem-overpaid'), isFalse);
          expect(returnedIds.contains('ord-rem-completed'), isFalse);
          expect(returnedIds.contains('ord-rem-canc-paid'), isFalse);
          expect(returnedIds.contains('ord-rem-canc-unpaid'), isFalse);

          // Verify all returned orders have remainingAmount > 0 and match domain calculation
          for (final item in cubit.state.orders) {
            expect(item.remainingAmount.isPositive, isTrue);
            expect(item.isFullyPaid, isFalse);
            expect(item.order.status, isNot(equals(OrderStatus.cancelled)));
            final domainRemaining = await paymentRepository.getRemainingAmountForOrder(item.order.id);
            expect(item.remainingAmount, domainRemaining);
          }
        },
      );

      test(
        'search combined with outstanding filter filters accurately and excludes non-matching / cancelled',
        () async {
          await seedOrder(
            orderId: 'ord-rem-s1',
            orderNumber: '26-SRCH1',
            customerId: 'cust-srch-1',
            customerName: 'طارق عبد الله',
            phone: '01091111111',
            status: OrderStatus.processing,
            totalPiastres: 15000,
            paidPiastres: 5000,
          );
          await seedOrder(
            orderId: 'ord-rem-s2',
            orderNumber: '26-SRCH2',
            customerId: 'cust-srch-2',
            customerName: 'طارق مسدد',
            phone: '01092222222',
            status: OrderStatus.ready,
            totalPiastres: 15000,
            paidPiastres: 15000, // fully paid
          );
          await seedOrder(
            orderId: 'ord-rem-s3',
            orderNumber: '26-SRCH3',
            customerId: 'cust-srch-3',
            customerName: 'طارق ملغي',
            phone: '01093333333',
            status: OrderStatus.cancelled,
            totalPiastres: 15000,
            paidPiastres: 0, // cancelled
          );

          cubit.setFilter(OrderListFilter.hasRemaining);
          await pumpEventQueue();

          cubit.search('طارق');
          await pumpEventQueue();

          expect(cubit.state.orders.length, 1);
          expect(cubit.state.orders.first.order.id, 'ord-rem-s1');
          expect(cubit.state.orders.first.remainingAmount.toEgp, 100.0);
        },
      );

      test(
        'switching between other filters and outstanding filter refreshes the list dynamically',
        () async {
          await seedOrder(
            orderId: 'ord-sw-proc-unpaid',
            orderNumber: '26-SW01',
            customerId: 'cust-sw-1',
            customerName: 'عميل تبديل غير مسدد',
            phone: '01081111111',
            status: OrderStatus.processing,
            totalPiastres: 5000,
            paidPiastres: 0,
          );
          await seedOrder(
            orderId: 'ord-sw-proc-paid',
            orderNumber: '26-SW02',
            customerId: 'cust-sw-2',
            customerName: 'عميل تبديل مسدد',
            phone: '01082222222',
            status: OrderStatus.processing,
            totalPiastres: 5000,
            paidPiastres: 5000,
          );

          // 1. All -> 2 orders
          cubit.setFilter(OrderListFilter.all);
          await pumpEventQueue();
          expect(cubit.state.orders.length, 2);

          // 2. Switch to hasRemaining -> 1 order (unpaid only)
          cubit.setFilter(OrderListFilter.hasRemaining);
          await pumpEventQueue();
          expect(cubit.state.orders.length, 1);
          expect(cubit.state.orders.first.order.id, 'ord-sw-proc-unpaid');

          // 3. Switch back to all -> 2 orders
          cubit.setFilter(OrderListFilter.all);
          await pumpEventQueue();
          expect(cubit.state.orders.length, 2);
        },
      );
    });

    test(
      'pagination loadMore loads subsequent pages and updates hasMore flag',
      () async {
        for (var i = 1; i <= 25; i++) {
          await seedOrder(
            orderId: 'ord-page-$i',
            orderNumber: '26-${i.toString().padLeft(3, '0')}',
            customerId: 'cust-page-$i',
            customerName: 'عميل $i',
            phone: '0104000${i.toString().padLeft(4, '0')}',
            status: OrderStatus.processing,
            totalPiastres: 1000 * i,
          );
        }

        await cubit.loadOrders();
        expect(cubit.state.orders.length, 20);
        expect(cubit.state.hasMore, isTrue);

        await cubit.loadMore();
        expect(cubit.state.orders.length, 25);
        expect(cubit.state.hasMore, isFalse);
      },
    );

    test(
      'search combined with active filter applies both SQLite predicates',
      () async {
        await seedOrder(
          orderId: 'ord-match-both',
          orderNumber: '26-501',
          customerId: 'cust-501',
          customerName: 'محمود طارق',
          phone: '01050000001',
          status: OrderStatus.processing,
          totalPiastres: 5000,
        );

        await seedOrder(
          orderId: 'ord-match-name-only',
          orderNumber: '26-502',
          customerId: 'cust-502',
          customerName: 'محمود سامي',
          phone: '01050000002',
          status: OrderStatus.ready,
          totalPiastres: 5000,
        );

        cubit.setFilter(OrderListFilter.processing);
        await pumpEventQueue();
        expect(cubit.state.orders.length, 1);

        cubit.search('محمود');
        await pumpEventQueue();

        expect(cubit.state.orders.length, 1);
        expect(cubit.state.orders.first.order.id, 'ord-match-both');
      },
    );

    group('Reactive SQLite Signal & Concurrency', () {
      test('1. DB signal triggers reload while list is empty / first page', () async {
        expect(cubit.state.orders, isEmpty);

        await seedOrder(
          orderId: 'ord-signal-1',
          orderNumber: '26-901',
          customerId: 'cust-901',
          customerName: 'عميل التحديث التلقائي',
          phone: '01090000001',
          status: OrderStatus.processing,
          totalPiastres: 3000,
        );

        await pumpEventQueue();

        expect(cubit.state.orders.length, 1);
        expect(cubit.state.orders.first.order.orderNumber, '26-901');
      });

      test('2. Current filter and search state are preserved on DB signal', () async {
        cubit.setFilter(OrderListFilter.ready);
        cubit.search('26-902');
        await pumpEventQueue();
        expect(cubit.state.orders, isEmpty);

        // Seed an order that matches both filter (ready) and search (26-902)
        await seedOrder(
          orderId: 'ord-signal-ready',
          orderNumber: '26-902',
          customerId: 'cust-902',
          customerName: 'عميل جاهز',
          phone: '01090000002',
          status: OrderStatus.ready,
          totalPiastres: 4000,
        );

        // Seed an order that does NOT match (processing)
        await seedOrder(
          orderId: 'ord-signal-processing',
          orderNumber: '26-903',
          customerId: 'cust-903',
          customerName: 'عميل تجهيز',
          phone: '01090000003',
          status: OrderStatus.processing,
          totalPiastres: 4000,
        );

        await pumpEventQueue();

        expect(cubit.state.orders.length, 1);
        expect(cubit.state.orders.first.order.orderNumber, '26-902');
        expect(cubit.state.activeFilter, OrderListFilter.ready);
        expect(cubit.state.searchQuery, '26-902');
      });

      test('3. DB signal does NOT reset a paginated list where length > _pageSize', () async {
        for (var i = 1; i <= 25; i++) {
          await seedOrder(
            orderId: 'ord-pag-$i',
            orderNumber: '26-${i.toString().padLeft(3, '0')}',
            customerId: 'cust-pag-$i',
            customerName: 'عميل $i',
            phone: '0108000${i.toString().padLeft(4, '0')}',
            status: OrderStatus.processing,
            totalPiastres: 1000 * i,
          );
        }

        await cubit.loadOrders();
        expect(cubit.state.orders.length, 20);

        await cubit.loadMore();
        expect(cubit.state.orders.length, 25);

        // Write a 26th order to trigger DB signal
        await seedOrder(
          orderId: 'ord-pag-26',
          orderNumber: '26-026',
          customerId: 'cust-pag-26',
          customerName: 'عميل 26',
          phone: '01080000026',
          status: OrderStatus.processing,
          totalPiastres: 26000,
        );

        await pumpEventQueue();

        // Must still have 25 orders; first-page guard dropped the signal and preserved pagination
        expect(cubit.state.orders.length, 25);
      });

      test('4. A stale earlier async load cannot overwrite a newer load', () async {
        final delayedRepo = DelayedOrderRepository(orderRepository);
        final testCubit = OrdersListCubit(
          orderRepository: delayedRepo,
          customerRepository: customerRepository,
          paymentRepository: paymentRepository,
        );
        addTearDown(testCubit.close);

        await seedOrder(
          orderId: 'ord-stale-1',
          orderNumber: '26-777',
          customerId: 'cust-777',
          customerName: 'قديم',
          phone: '01077777777',
          status: OrderStatus.processing,
          totalPiastres: 1000,
        );

        // Request 1 starts with delayed completer
        final completer = Completer<List<Order>>();
        delayedRepo.getOrdersCompleter = completer;
        final firstLoadFuture = testCubit.loadOrders();

        // Request 2 (e.g. search or reload) starts immediately and supersedes request 1
        delayedRepo.getOrdersCompleter = null;
        await seedOrder(
          orderId: 'ord-stale-2',
          orderNumber: '26-888',
          customerId: 'cust-888',
          customerName: 'جديد',
          phone: '01088888888',
          status: OrderStatus.processing,
          totalPiastres: 2000,
        );
        final secondLoadFuture = testCubit.loadOrders(refresh: true);
        await secondLoadFuture;

        expect(testCubit.state.orders.any((vm) => vm.order.id == 'ord-stale-2'), isTrue);

        // Now complete the stale request 1 with only the old order
        final now = DateTime.now();
        completer.complete([
          Order(
            id: 'ord-stale-1',
            orderNumber: '26-777',
            customerId: 'cust-777',
            customerNameSnapshot: 'قديم',
            customerPhoneSnapshot: '01077777777',
            status: OrderStatus.processing,
            expectedPickupDate: OrderDate(2026, 9, 20),
            subtotal: const Money.fromPiastres(1000),
            total: const Money.fromPiastres(1000),
            createdAt: now,
            updatedAt: now,
          ),
        ]);
        await firstLoadFuture;

        // Stale result should NOT overwrite newer state (order-stale-2 must still be present)
        expect(testCubit.state.orders.any((vm) => vm.order.id == 'ord-stale-2'), isTrue);
      });

      test('5. Critical race: signal while loading triggers pending refresh after load', () async {
        final delayedRepo = DelayedOrderRepository(orderRepository)
          ..useCustomUpdates = true;
        final testCubit = OrdersListCubit(
          orderRepository: delayedRepo,
          customerRepository: customerRepository,
          paymentRepository: paymentRepository,
        );
        addTearDown(() {
          delayedRepo.dispose();
          return testCubit.close();
        });

        // Seed order into DB so enrichment queries succeed
        await seedOrder(
          orderId: 'ord-race-new',
          orderNumber: '26-999',
          customerId: 'cust-race',
          customerName: 'عميل جديد',
          phone: '01012345678',
          status: OrderStatus.processing,
          totalPiastres: 3000,
        );

        // 1. Start OrdersListCubit (testCubit started above)
        expect(testCubit.state.isLoading, isFalse);
        expect(testCubit.hasPendingReload, isFalse);

        // 2 & 3. Call loadOrders() and keep getOrders() pending
        final completer1 = Completer<List<Order>>();
        delayedRepo.getOrdersCompleter = completer1;
        final loadFuture = testCubit.loadOrders();

        expect(testCubit.state.isLoading, isTrue);
        expect(delayedRepo.getOrdersCallCount, 1);

        // 4. While it is pending, emit the repository DB update signal
        delayedRepo.emitDbSignal();
        await pumpEventQueue();

        // 5. Verify the signal sets pending invalidation instead of being lost
        expect(testCubit.hasPendingReload, isTrue);
        expect(delayedRepo.getOrdersCallCount, 1);

        // 6. Complete the first request with stale/empty data
        final completer2 = Completer<List<Order>>();
        delayedRepo.getOrdersCompleter = completer2;
        completer1.complete(<Order>[]);
        await pumpEventQueue();

        // 7. Verify exactly one fresh reload occurs automatically
        expect(delayedRepo.getOrdersCallCount, 2);
        expect(testCubit.hasPendingReload, isFalse);
        expect(testCubit.state.isLoading, isTrue);

        // 8. Complete the fresh reload with the new order
        final freshOrders = await orderRepository.getOrders();
        completer2.complete(freshOrders);
        await loadFuture;
        await pumpEventQueue();

        // 9. Verify final state contains the new order
        expect(testCubit.state.orders.length, 1);
        expect(testCubit.state.orders.first.order.id, 'ord-race-new');
        expect(testCubit.state.isLoading, isFalse);
      });

      test('6. Multiple signals while loading coalesce into exactly one fresh reload', () async {
        final delayedRepo = DelayedOrderRepository(orderRepository)
          ..useCustomUpdates = true;
        final testCubit = OrdersListCubit(
          orderRepository: delayedRepo,
          customerRepository: customerRepository,
          paymentRepository: paymentRepository,
        );
        addTearDown(() {
          delayedRepo.dispose();
          return testCubit.close();
        });

        await seedOrder(
          orderId: 'ord-multi-signal',
          orderNumber: '26-888',
          customerId: 'cust-multi',
          customerName: 'عميل إشارات متعددة',
          phone: '01012345678',
          status: OrderStatus.processing,
          totalPiastres: 2500,
        );

        final completer1 = Completer<List<Order>>();
        delayedRepo.getOrdersCompleter = completer1;
        final loadFuture = testCubit.loadOrders();

        expect(testCubit.state.isLoading, isTrue);
        expect(delayedRepo.getOrdersCallCount, 1);

        // Emit multiple signals while load is in-flight
        delayedRepo.emitDbSignal();
        delayedRepo.emitDbSignal();
        delayedRepo.emitDbSignal();
        await pumpEventQueue();

        expect(testCubit.hasPendingReload, isTrue);
        expect(delayedRepo.getOrdersCallCount, 1);

        // Prepare completer2 for the single coalesced reload
        final completer2 = Completer<List<Order>>();
        delayedRepo.getOrdersCompleter = completer2;
        completer1.complete(<Order>[]);
        await pumpEventQueue();

        // Exactly one reload triggered
        expect(delayedRepo.getOrdersCallCount, 2);
        expect(testCubit.hasPendingReload, isFalse);

        final freshOrders = await orderRepository.getOrders();
        completer2.complete(freshOrders);
        await loadFuture;
        await pumpEventQueue();

        // Ensure no third reload occurred
        expect(delayedRepo.getOrdersCallCount, 2);
        expect(testCubit.state.orders.length, 1);
        expect(testCubit.state.orders.first.order.id, 'ord-multi-signal');
        expect(testCubit.state.isLoading, isFalse);
      });

      test('7. Subscription is cancelled on close', () async {
        await cubit.close();

        // Seed order after cubit is closed
        await seedOrder(
          orderId: 'ord-closed',
          orderNumber: '26-999',
          customerId: 'cust-999',
          customerName: 'عميل بعد الإغلاق',
          phone: '01099999999',
          status: OrderStatus.processing,
          totalPiastres: 5000,
        );

        await pumpEventQueue();

        // Cubit state remains default empty and closed without throwing
        expect(cubit.isClosed, isTrue);
        expect(cubit.state.orders, isEmpty);
      });
    });
  });
}

class DelayedOrderRepository implements OrderRepository {
  final OrderRepository _delegate;
  Completer<List<Order>>? getOrdersCompleter;
  int getOrdersCallCount = 0;
  final StreamController<void> _dbUpdateController =
      StreamController<void>.broadcast();
  bool useCustomUpdates = false;

  DelayedOrderRepository(this._delegate);

  void emitDbSignal() {
    _dbUpdateController.add(null);
  }

  void dispose() {
    _dbUpdateController.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream<void> watchOrderTableUpdates() {
    if (useCustomUpdates) {
      return _dbUpdateController.stream;
    }
    return _delegate.watchOrderTableUpdates();
  }

  @override
  Future<List<Order>> getOrders({
    OrderStatus? status,
    List<OrderStatus>? excludedStatuses,
    OrderDate? expectedPickupDate,
    bool? isOverdue,
    DateTime? referenceDate,
    DateTime? createdFrom,
    DateTime? createdTo,
    String? customerId,
    bool? hasRemaining,
    String? query,
    int limit = 20,
    int offset = 0,
  }) {
    getOrdersCallCount++;
    if (getOrdersCompleter != null) {
      return getOrdersCompleter!.future;
    }
    return _delegate.getOrders(
      status: status,
      excludedStatuses: excludedStatuses,
      expectedPickupDate: expectedPickupDate,
      isOverdue: isOverdue,
      referenceDate: referenceDate,
      createdFrom: createdFrom,
      createdTo: createdTo,
      customerId: customerId,
      hasRemaining: hasRemaining,
      query: query,
      limit: limit,
      offset: offset,
    );
  }
}
