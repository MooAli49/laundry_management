import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/local/daos/customers_dao.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/services_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart' as db_pkg;
import 'package:laundry_management/data/repositories/customer_repository_impl.dart';
import 'package:laundry_management/data/repositories/order_repository_impl.dart';
import 'package:laundry_management/data/repositories/payment_repository_impl.dart';
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
  }) async {
    final now = DateTime.now();
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
      expectedPickupDate: OrderDate(2026, 9, 20),
      subtotal: Money.fromPiastres(totalPiastres),
      total: Money.fromPiastres(totalPiastres),
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

    test('loadOrders enriches items with customer details and remaining balances', () async {
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
    });

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
  });
}
