import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/local/daos/customers_dao.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/storage_locations_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart'
    hide Customer, Order, OrderItem, Payment;
import 'package:laundry_management/data/repositories/dashboard_repository_impl.dart';
import 'package:laundry_management/data/repositories/order_repository_impl.dart';
import 'package:laundry_management/data/repositories/payment_repository_impl.dart';
import 'package:laundry_management/data/repositories/storage_repository_impl.dart';
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/domain/entities/dashboard_data.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/enums/payment_method.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';

void main() {
  late AppDatabase db;
  late OrdersDao ordersDao;
  late PaymentsDao paymentsDao;
  late StorageRecordsDao storageRecordsDao;
  late StorageLocationsDao storageLocationsDao;
  late SyncOperationsDao syncOperationsDao;
  late CustomersDao customersDao;

  late OrderRepositoryImpl orderRepository;
  late PaymentRepositoryImpl paymentRepository;
  late StorageRepositoryImpl storageRepository;
  late DashboardRepositoryImpl dashboardRepository;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ordersDao = OrdersDao(db);
    paymentsDao = PaymentsDao(db);
    storageRecordsDao = StorageRecordsDao(db);
    storageLocationsDao = StorageLocationsDao(db);
    syncOperationsDao = SyncOperationsDao(db);
    customersDao = CustomersDao(db);

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
      ordersDao: ordersDao,
      db: db,
    );

    dashboardRepository = DashboardRepositoryImpl(
      ordersDao: ordersDao,
      orderRepository: orderRepository,
      paymentRepository: paymentRepository,
      storageRepository: storageRepository,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('returns empty operational stats when no orders exist', () async {
    final data = await dashboardRepository.getDashboardData();

    expect(data.todayOrdersCount, 0);
    expect(data.processingOrdersCount, 0);
    expect(data.readyOrdersCount, 0);
    expect(data.totalRemainingAmount, Money.zero);
    expect(data.unpaidOrdersCount, 0);
    expect(data.storageAttentionCount, 0);
    expect(data.overdueOrdersCount, 0);
    expect(data.todayPickupOrdersCount, 0);
    expect(data.todayPickupOrders, isEmpty);
    expect(data.recentOrders, isEmpty);
  });

  test(
    'calculates operational summary and attention metrics correctly from orders and payments',
    () async {
      final now = DateTime.now();
      final today = OrderDate.today();
      final yesterday = OrderDate.fromDate(
        now.subtract(const Duration(days: 1)),
      );

      // Create a customer
      final customer = Customer(
        id: 'cust-1',
        name: 'أحمد محمود',
        phone: '01012345678',
        createdAt: now,
        updatedAt: now,
      );
      await customersDao.insertCustomer(
        CustomersCompanion.insert(
          id: customer.id,
          name: customer.name,
          phone: customer.phone,
          createdAt: customer.createdAt,
          updatedAt: customer.updatedAt,
        ),
      );

      // Order 1: Created today, processing, pickup today, partially paid
      await ordersDao.insertOrder(
        OrdersCompanion.insert(
          id: 'order-1',
          orderNumber: '26-001',
          customerId: customer.id,
          customerNameSnapshot: const Value('أحمد محمود'),
          customerPhoneSnapshot: const Value('01012345678'),
          status: const Value('processing'),
          expectedPickupDate: today.toDateTime(),
          subtotal: 10000,
          total: 10000,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Order 2: Created today, ready, pickup yesterday (overdue!), unpaid
      await ordersDao.insertOrder(
        OrdersCompanion.insert(
          id: 'order-2',
          orderNumber: '26-002',
          customerId: customer.id,
          customerNameSnapshot: const Value('أحمد محمود'),
          customerPhoneSnapshot: const Value('01012345678'),
          status: const Value('ready'),
          expectedPickupDate: yesterday.toDateTime(),
          subtotal: 15000,
          total: 15000,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Insert service
      await db
          .into(db.services)
          .insert(
            ServicesCompanion.insert(
              id: 'serv-1',
              name: 'غسيل ومكواة',
              pricingType: 'per_piece',
              price: 5000,
              createdAt: now,
              updatedAt: now,
            ),
          );

      const clothingTypeId = '00000000-0000-0000-0001-000000000001';

      // Insert order items requiring storage
      await db
          .into(db.orderItems)
          .insert(
            OrderItemsCompanion.insert(
              id: 'item-1',
              orderId: 'order-1',
              itemTypeId: clothingTypeId,
              serviceId: 'serv-1',
              itemTypeNameSnapshot: 'قميص',
              serviceNameSnapshot: 'غسيل ومكواة',
              pricingType: 'per_piece',
              quantity: 2,
              unitPrice: 5000,
              calculatedTotal: 10000,
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db
          .into(db.orderItems)
          .insert(
            OrderItemsCompanion.insert(
              id: 'item-2',
              orderId: 'order-2',
              itemTypeId: clothingTypeId,
              serviceId: 'serv-1',
              itemTypeNameSnapshot: 'بدلة',
              serviceNameSnapshot: 'غسيل ومكواة',
              pricingType: 'per_piece',
              quantity: 1,
              unitPrice: 15000,
              calculatedTotal: 15000,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Pay 4000 piastres for order 1 (leaving 6000 piastres remaining)
      await paymentsDao.insertPayment(
        PaymentsCompanion.insert(
          id: 'pay-1',
          orderId: 'order-1',
          amount: 4000,
          paymentMethod: PaymentMethod.cash.name,
          paidAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final data = await dashboardRepository.getDashboardData();

      // 4 Primary Operational Summary Metrics
      expect(data.todayOrdersCount, 2);
      expect(data.processingOrdersCount, 1);
      expect(data.readyOrdersCount, 1);
      expect(
        data.totalRemainingAmount,
        const Money.fromPiastres(21000),
      ); // 6000 + 15000

      // Attention Required Metrics
      expect(data.unpaidOrdersCount, 2);
      expect(
        data.overdueOrdersCount,
        1,
      ); // order 2 has expectedPickupDate yesterday
      expect(
        data.todayPickupOrdersCount,
        1,
      ); // order 1 has expectedPickupDate today
      expect(data.storageAttentionCount, 2); // 2 unstored items

      // Today's Pickups Section
      expect(data.todayPickupOrders.length, 1);
      expect(data.todayPickupOrders.first.order.id, 'order-1');
      expect(
        data.todayPickupOrders.first.remainingAmount,
        const Money.fromPiastres(6000),
      );

      // Recent Orders Section
      expect(data.recentOrders.length, 2);
    },
  );

  test(
    'todayPickupOrdersCount reflects true database count while todayPickupOrders is capped at 5',
    () async {
      final now = DateTime.now();
      final today = OrderDate.today();

      final customer = Customer(
        id: 'cust-pickups',
        name: 'عميل الاستلام',
        phone: '01099999999',
        createdAt: now,
        updatedAt: now,
      );
      await customersDao.insertCustomer(
        CustomersCompanion.insert(
          id: customer.id,
          name: customer.name,
          phone: customer.phone,
          createdAt: customer.createdAt,
          updatedAt: customer.updatedAt,
        ),
      );

      // Seed 7 active orders due today
      for (var i = 1; i <= 7; i++) {
        await ordersDao.insertOrder(
          OrdersCompanion.insert(
            id: 'order-pickup-$i',
            orderNumber: '26-10$i',
            customerId: customer.id,
            customerNameSnapshot: const Value('عميل الاستلام'),
            customerPhoneSnapshot: const Value('01099999999'),
            status: const Value('processing'),
            expectedPickupDate: today.toDateTime(),
            subtotal: 5000,
            total: 5000,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      // Seed 1 completed order due today (should NOT be counted or listed)
      await ordersDao.insertOrder(
        OrdersCompanion.insert(
          id: 'order-pickup-completed',
          orderNumber: '26-200',
          customerId: customer.id,
          customerNameSnapshot: const Value('عميل الاستلام'),
          customerPhoneSnapshot: const Value('01099999999'),
          status: const Value('completed'),
          expectedPickupDate: today.toDateTime(),
          completedAt: Value(now),
          subtotal: 5000,
          total: 5000,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Seed 1 cancelled order due today (should NOT be counted or listed)
      await ordersDao.insertOrder(
        OrdersCompanion.insert(
          id: 'order-pickup-cancelled',
          orderNumber: '26-201',
          customerId: customer.id,
          customerNameSnapshot: const Value('عميل الاستلام'),
          customerPhoneSnapshot: const Value('01099999999'),
          status: const Value('cancelled'),
          expectedPickupDate: today.toDateTime(),
          cancelledAt: Value(now),
          cancellationReason: const Value('ملغي'),
          subtotal: 5000,
          total: 5000,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final data = await dashboardRepository.getDashboardData();

      expect(
        data.todayPickupOrdersCount,
        7,
        reason: 'True database count of active orders due today',
      );
      expect(
        data.todayPickupOrders.length,
        5,
        reason: 'Displayed list is capped at 5',
      );
      // None of the displayed items should be completed or cancelled
      for (final item in data.todayPickupOrders) {
        expect(
          item.order.status,
          isNot(anyOf(OrderStatus.completed, OrderStatus.cancelled)),
        );
      }
    },
  );

  test('date-boundary test: todayOrdersCount accurately respects today start and end of day', () async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final yesterdayEnd = todayStart.subtract(const Duration(milliseconds: 1));
    final tomorrowStart = todayEnd.add(const Duration(milliseconds: 1));

    final customer = Customer(
      id: 'cust-bounds',
      name: 'عميل الحدود',
      phone: '01011112222',
      createdAt: now,
      updatedAt: now,
    );
    await customersDao.insertCustomer(
      CustomersCompanion.insert(
        id: customer.id,
        name: customer.name,
        phone: customer.phone,
        createdAt: customer.createdAt,
        updatedAt: customer.updatedAt,
      ),
    );

    // 1. Order created yesterday at 23:59:59.999 (NOT today)
    await ordersDao.insertOrder(
      OrdersCompanion.insert(
        id: 'ord-yesterday',
        orderNumber: '26-901',
        customerId: customer.id,
        customerNameSnapshot: const Value('عميل الحدود'),
        customerPhoneSnapshot: const Value('01011112222'),
        status: const Value('processing'),
        expectedPickupDate: OrderDate.today().toDateTime(),
        subtotal: 1000,
        total: 1000,
        createdAt: yesterdayEnd,
        updatedAt: yesterdayEnd,
      ),
    );

    // 2. Order created today at 00:00:00 (IS today)
    await ordersDao.insertOrder(
      OrdersCompanion.insert(
        id: 'ord-today-start',
        orderNumber: '26-902',
        customerId: customer.id,
        customerNameSnapshot: const Value('عميل الحدود'),
        customerPhoneSnapshot: const Value('01011112222'),
        status: const Value('processing'),
        expectedPickupDate: OrderDate.today().toDateTime(),
        subtotal: 1000,
        total: 1000,
        createdAt: todayStart,
        updatedAt: todayStart,
      ),
    );

    // 3. Order created today at 23:59:59.999 (IS today)
    await ordersDao.insertOrder(
      OrdersCompanion.insert(
        id: 'ord-today-end',
        orderNumber: '26-903',
        customerId: customer.id,
        customerNameSnapshot: const Value('عميل الحدود'),
        customerPhoneSnapshot: const Value('01011112222'),
        status: const Value('processing'),
        expectedPickupDate: OrderDate.today().toDateTime(),
        subtotal: 1000,
        total: 1000,
        createdAt: todayEnd,
        updatedAt: todayEnd,
      ),
    );

    // 4. Order created tomorrow at 00:00:00.001 (NOT today)
    await ordersDao.insertOrder(
      OrdersCompanion.insert(
        id: 'ord-tomorrow',
        orderNumber: '26-904',
        customerId: customer.id,
        customerNameSnapshot: const Value('عميل الحدود'),
        customerPhoneSnapshot: const Value('01011112222'),
        status: const Value('processing'),
        expectedPickupDate: OrderDate.today().toDateTime(),
        subtotal: 1000,
        total: 1000,
        createdAt: tomorrowStart,
        updatedAt: tomorrowStart,
      ),
    );

    final data = await dashboardRepository.getDashboardData();
    expect(data.todayOrdersCount, 2, reason: 'Only ord-today-start and ord-today-end were created today');
  });

  test('overdue and pickup status exclusions: completed and cancelled orders are excluded from attention', () async {
    final now = DateTime.now();
    final today = OrderDate.today();
    final pastDate = OrderDate.fromDate(now.subtract(const Duration(days: 3)));

    final customer = Customer(
      id: 'cust-exclusions',
      name: 'عميل الاستثناءات',
      phone: '01033334444',
      createdAt: now,
      updatedAt: now,
    );
    await customersDao.insertCustomer(
      CustomersCompanion.insert(
        id: customer.id,
        name: customer.name,
        phone: customer.phone,
        createdAt: customer.createdAt,
        updatedAt: customer.updatedAt,
      ),
    );

    // 1. Completed order with past pickup date -> NOT overdue
    await ordersDao.insertOrder(
      OrdersCompanion.insert(
        id: 'ord-overdue-completed',
        orderNumber: '26-801',
        customerId: customer.id,
        customerNameSnapshot: const Value('عميل الاستثناءات'),
        customerPhoneSnapshot: const Value('01033334444'),
        status: const Value('completed'),
        expectedPickupDate: pastDate.toDateTime(),
        completedAt: Value(now),
        subtotal: 2000,
        total: 2000,
        createdAt: now,
        updatedAt: now,
      ),
    );

    // 2. Cancelled order with past pickup date -> NOT overdue
    await ordersDao.insertOrder(
      OrdersCompanion.insert(
        id: 'ord-overdue-cancelled',
        orderNumber: '26-802',
        customerId: customer.id,
        customerNameSnapshot: const Value('عميل الاستثناءات'),
        customerPhoneSnapshot: const Value('01033334444'),
        status: const Value('cancelled'),
        expectedPickupDate: pastDate.toDateTime(),
        cancelledAt: Value(now),
        cancellationReason: const Value('ملغي'),
        subtotal: 2000,
        total: 2000,
        createdAt: now,
        updatedAt: now,
      ),
    );

    // 3. Active processing order with past pickup date -> IS overdue
    await ordersDao.insertOrder(
      OrdersCompanion.insert(
        id: 'ord-overdue-active',
        orderNumber: '26-803',
        customerId: customer.id,
        customerNameSnapshot: const Value('عميل الاستثناءات'),
        customerPhoneSnapshot: const Value('01033334444'),
        status: const Value('processing'),
        expectedPickupDate: pastDate.toDateTime(),
        subtotal: 2000,
        total: 2000,
        createdAt: now,
        updatedAt: now,
      ),
    );

    // 4. Active ready order with today pickup date -> IS today pickup
    await ordersDao.insertOrder(
      OrdersCompanion.insert(
        id: 'ord-today-pickup-active',
        orderNumber: '26-804',
        customerId: customer.id,
        customerNameSnapshot: const Value('عميل الاستثناءات'),
        customerPhoneSnapshot: const Value('01033334444'),
        status: const Value('ready'),
        expectedPickupDate: today.toDateTime(),
        subtotal: 2000,
        total: 2000,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final data = await dashboardRepository.getDashboardData();
    expect(data.overdueOrdersCount, 1, reason: 'Only ord-overdue-active is overdue');
    expect(data.todayPickupOrdersCount, 1, reason: 'Only ord-today-pickup-active is due today');
  });

  test('payment remaining consistency: cancelled orders excluded, fully paid orders excluded', () async {
    final now = DateTime.now();

    final customer = Customer(
      id: 'cust-payments',
      name: 'عميل الدفع',
      phone: '01055556666',
      createdAt: now,
      updatedAt: now,
    );
    await customersDao.insertCustomer(
      CustomersCompanion.insert(
        id: customer.id,
        name: customer.name,
        phone: customer.phone,
        createdAt: customer.createdAt,
        updatedAt: customer.updatedAt,
      ),
    );

    // 1. Cancelled order with 0 payments -> NOT counted in unpaidOrdersCount or remaining
    await ordersDao.insertOrder(
      OrdersCompanion.insert(
        id: 'ord-pay-cancelled',
        orderNumber: '26-701',
        customerId: customer.id,
        customerNameSnapshot: const Value('عميل الدفع'),
        customerPhoneSnapshot: const Value('01055556666'),
        status: const Value('cancelled'),
        expectedPickupDate: OrderDate.today().toDateTime(),
        cancelledAt: Value(now),
        cancellationReason: const Value('ملغي'),
        subtotal: 8000,
        total: 8000,
        createdAt: now,
        updatedAt: now,
      ),
    );

    // 2. Active order fully paid -> NOT counted in unpaidOrdersCount or remaining
    await ordersDao.insertOrder(
      OrdersCompanion.insert(
        id: 'ord-pay-full',
        orderNumber: '26-702',
        customerId: customer.id,
        customerNameSnapshot: const Value('عميل الدفع'),
        customerPhoneSnapshot: const Value('01055556666'),
        status: const Value('processing'),
        expectedPickupDate: OrderDate.today().toDateTime(),
        subtotal: 5000,
        total: 5000,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await paymentsDao.insertPayment(
      PaymentsCompanion.insert(
        id: 'pay-full',
        orderId: 'ord-pay-full',
        amount: 5000,
        paymentMethod: PaymentMethod.cash.name,
        paidAt: now,
        createdAt: now,
        updatedAt: now,
      ),
    );

    // 3. Active order partially paid -> counted (remaining 2000)
    await ordersDao.insertOrder(
      OrdersCompanion.insert(
        id: 'ord-pay-partial',
        orderNumber: '26-703',
        customerId: customer.id,
        customerNameSnapshot: const Value('عميل الدفع'),
        customerPhoneSnapshot: const Value('01055556666'),
        status: const Value('ready'),
        expectedPickupDate: OrderDate.today().toDateTime(),
        subtotal: 6000,
        total: 6000,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await paymentsDao.insertPayment(
      PaymentsCompanion.insert(
        id: 'pay-partial',
        orderId: 'ord-pay-partial',
        amount: 4000,
        paymentMethod: PaymentMethod.instapay.name,
        paidAt: now,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final data = await dashboardRepository.getDashboardData();
    expect(data.unpaidOrdersCount, 1);
    expect(data.totalRemainingAmount, const Money.fromPiastres(2000));
  });

  test('reactive watchDashboardData emits initial state and updates when database mutates', () async {
    final now = DateTime.now();

    final customer = Customer(
      id: 'cust-watch',
      name: 'عميل البث',
      phone: '01077778888',
      createdAt: now,
      updatedAt: now,
    );
    await customersDao.insertCustomer(
      CustomersCompanion.insert(
        id: customer.id,
        name: customer.name,
        phone: customer.phone,
        createdAt: customer.createdAt,
        updatedAt: customer.updatedAt,
      ),
    );

    final emissions = <DashboardData>[];
    final sub = dashboardRepository.watchDashboardData().listen(emissions.add);

    // Wait for initial emission
    await Future.delayed(const Duration(milliseconds: 50));
    expect(emissions.isNotEmpty, isTrue);
    final initialCount = emissions.last.todayOrdersCount;

    // Mutate database: insert new order
    await ordersDao.insertOrder(
      OrdersCompanion.insert(
        id: 'ord-watch-new',
        orderNumber: '26-601',
        customerId: customer.id,
        customerNameSnapshot: const Value('عميل البث'),
        customerPhoneSnapshot: const Value('01077778888'),
        status: const Value('processing'),
        expectedPickupDate: OrderDate.today().toDateTime(),
        subtotal: 3000,
        total: 3000,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await Future.delayed(const Duration(milliseconds: 100));
    expect(emissions.last.todayOrdersCount, initialCount + 1, reason: 'Stream automatically re-emitted with new order');

    await sub.cancel();
  });

  test('BUG-002: getDashboardData includes orders with non-midnight expectedPickupDate in todayPickupOrdersCount', () async {
    final now = DateTime.now();
    final customer = Customer(
      id: 'cust-time-test',
      name: 'عميل وقت الاستلام',
      phone: '01011223344',
      createdAt: now,
      updatedAt: now,
    );
    await customersDao.insertCustomer(
      CustomersCompanion.insert(
        id: customer.id,
        name: customer.name,
        phone: customer.phone,
        createdAt: customer.createdAt,
        updatedAt: customer.updatedAt,
      ),
    );

    // Order with afternoon expected pickup time today (14:30)
    final afternoonPickup = DateTime(now.year, now.month, now.day, 14, 30);
    await ordersDao.insertOrder(
      OrdersCompanion.insert(
        id: 'ord-afternoon',
        orderNumber: '26-701',
        customerId: customer.id,
        customerNameSnapshot: const Value('عميل وقت الاستلام'),
        customerPhoneSnapshot: const Value('01011223344'),
        status: const Value('processing'),
        expectedPickupDate: afternoonPickup,
        subtotal: 5000,
        total: 5000,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final data = await dashboardRepository.getDashboardData();
    expect(data.todayPickupOrdersCount, equals(1));
  });
}
