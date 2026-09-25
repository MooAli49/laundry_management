import 'dart:async';

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
      expectedPickupDate: expectedPickupDate ?? OrderDate(2026, 9, 20),
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
