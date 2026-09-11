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

  test('calculates operational summary and attention metrics correctly from orders and payments', () async {
    final now = DateTime.now();
    final today = OrderDate.today();
    final yesterday = OrderDate.fromDate(now.subtract(const Duration(days: 1)));

    // Create a customer
    final customer = Customer(
      id: 'cust-1',
      name: 'أحمد محمود',
      phone: '01012345678',
      createdAt: now,
      updatedAt: now,
    );
    await customersDao.insertCustomer(CustomersCompanion.insert(
      id: customer.id,
      name: customer.name,
      phone: customer.phone,
      createdAt: customer.createdAt,
      updatedAt: customer.updatedAt,
    ));

    // Order 1: Created today, processing, pickup today, partially paid
    await ordersDao.insertOrder(OrdersCompanion.insert(
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
    ));

    // Order 2: Created today, ready, pickup yesterday (overdue!), unpaid
    await ordersDao.insertOrder(OrdersCompanion.insert(
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
    ));

    // Insert service
    await db.into(db.services).insert(
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
    await db.into(db.orderItems).insert(
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

    await db.into(db.orderItems).insert(
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
    await paymentsDao.insertPayment(PaymentsCompanion.insert(
      id: 'pay-1',
      orderId: 'order-1',
      amount: 4000,
      paymentMethod: PaymentMethod.cash.name,
      paidAt: now,
      createdAt: now,
      updatedAt: now,
    ));

    final data = await dashboardRepository.getDashboardData();

    // 4 Primary Operational Summary Metrics
    expect(data.todayOrdersCount, 2);
    expect(data.processingOrdersCount, 1);
    expect(data.readyOrdersCount, 1);
    expect(data.totalRemainingAmount, const Money.fromPiastres(21000)); // 6000 + 15000

    // Attention Required Metrics
    expect(data.unpaidOrdersCount, 2);
    expect(data.overdueOrdersCount, 1); // order 2 has expectedPickupDate yesterday
    expect(data.todayPickupOrdersCount, 1); // order 1 has expectedPickupDate today
    expect(data.storageAttentionCount, 2); // 2 unstored items

    // Today's Pickups Section
    expect(data.todayPickupOrders.length, 1);
    expect(data.todayPickupOrders.first.order.id, 'order-1');
    expect(data.todayPickupOrders.first.remainingAmount, const Money.fromPiastres(6000));

    // Recent Orders Section
    expect(data.recentOrders.length, 2);
  });
}
