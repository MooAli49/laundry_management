import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/local/daos/customers_dao.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart' as db_pkg;
import 'package:laundry_management/data/local/database/dev_test_data.dart';
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
import 'package:laundry_management/features/customers/presentation/cubit/customer_detail_cubit.dart';

void main() {
  late db_pkg.AppDatabase db;
  late CustomersDao customersDao;
  late OrdersDao ordersDao;
  late PaymentsDao paymentsDao;
  late StorageRecordsDao storageRecordsDao;
  late SyncOperationsDao syncOperationsDao;

  late CustomerRepositoryImpl customerRepository;
  late OrderRepositoryImpl orderRepository;
  late PaymentRepositoryImpl paymentRepository;
  late CustomerDetailCubit cubit;

  setUp(() async {
    db = db_pkg.AppDatabase(NativeDatabase.memory());
    await DevTestData.seedDevData(db);

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

    cubit = CustomerDetailCubit(
      customerRepository: customerRepository,
      orderRepository: orderRepository,
      paymentRepository: paymentRepository,
    );
  });

  tearDown(() async {
    await cubit.close();
    await db.close();
  });

  group('CustomerDetailCubit', () {
    test('loadCustomerDetail populates customer data, orders, and balances', () async {
      final now = DateTime.now();
      final customer = await customerRepository.createCustomer(
        Customer(
          id: 'cust-detail-1',
          name: 'طارق علي',
          phone: '01099991111',
          notes: 'ملاحظات خاصة',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await cubit.loadCustomerDetail(customer.id);

      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.data, isNotNull);
      expect(cubit.state.data!.customer.name, equals('طارق علي'));
      expect(cubit.state.data!.totalOrdersCount, equals(0));
      expect(cubit.state.data!.activeOrdersCount, equals(0));
      expect(cubit.state.data!.completedOrdersCount, equals(0));
    });

    test('activeOrdersCount strictly counts processing and ready; completed and cancelled are not active', () async {
      final now = DateTime.now();
      final customer = await customerRepository.createCustomer(
        Customer(
          id: 'cust-stats-1',
          name: 'سمير محمود',
          phone: '01088882222',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final itemTypes = await db.select(db.itemTypes).get();
      final services = await db.select(db.services).get();

      // Create 4 orders with each of the 4 valid statuses:
      // 1. processing (active)
      // 2. ready (active)
      // 3. completed (not active)
      // 4. cancelled (not active)
      final statuses = [
        OrderStatus.processing,
        OrderStatus.ready,
        OrderStatus.completed,
        OrderStatus.cancelled,
      ];

      for (var i = 0; i < statuses.length; i++) {
        final status = statuses[i];
        final order = Order(
          id: 'ord-stat-$i',
          orderNumber: '26-10$i',
          customerId: customer.id,
          customerNameSnapshot: customer.name,
          customerPhoneSnapshot: customer.phone,
          status: status,
          expectedPickupDate: OrderDate.fromDate(now.add(const Duration(days: 2))),
          subtotal: const Money.fromPiastres(3000),
          discount: Money.zero,
          tax: Money.zero,
          total: const Money.fromPiastres(3000),
          completedAt: status == OrderStatus.completed ? now : null,
          cancelledAt: status == OrderStatus.cancelled ? now : null,
          cancellationReason: status == OrderStatus.cancelled ? 'إلغاء بناء على طلب العميل' : null,
          createdAt: now,
          updatedAt: now,
        );
        final item = OrderItem(
          id: 'itm-stat-$i',
          orderId: order.id,
          itemTypeId: itemTypes.first.id,
          serviceId: services.first.id,
          itemTypeNameSnapshot: itemTypes.first.name,
          serviceNameSnapshot: services.first.name,
          pricingType: PricingType.fixedPrice,
          quantity: 1,
          unitPrice: const Money.fromPiastres(3000),
          calculatedTotal: const Money.fromPiastres(3000),
          createdAt: now,
          updatedAt: now,
        );
        await orderRepository.createOrder(order: order, items: [item]);
      }

      await cubit.loadCustomerDetail(customer.id);

      final data = cubit.state.data!;
      expect(data.totalOrdersCount, equals(4));
      // INVARIANT: Active orders count strictly comprises processing and ready!
      expect(data.activeOrdersCount, equals(2));
      // Completed orders count strictly comprises completed!
      expect(data.completedOrdersCount, equals(1));
    });

    test('loadCustomerDetail accurately calculates totalPaid, totalRemaining, and latestOrder', () async {
      final now = DateTime.now();
      final customer = await customerRepository.createCustomer(
        Customer(
          id: 'cust-fin-1',
          name: 'عميل الحسابات',
          phone: '01011223344',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final itemTypes = await db.select(db.itemTypes).get();
      final services = await db.select(db.services).get();

      // Order 1: Total 100 EGP (10000 piastres), Paid 60 EGP (6000 piastres), Remaining 40 EGP
      final order1 = Order(
        id: 'ord-fin-1',
        orderNumber: '26-201',
        customerId: customer.id,
        customerNameSnapshot: customer.name,
        customerPhoneSnapshot: customer.phone,
        status: OrderStatus.processing,
        expectedPickupDate: OrderDate.fromDate(now.add(const Duration(days: 2))),
        subtotal: const Money.fromPiastres(10000),
        discount: Money.zero,
        tax: Money.zero,
        total: const Money.fromPiastres(10000),
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now,
      );
      final item1 = OrderItem(
        id: 'itm-fin-1',
        orderId: order1.id,
        itemTypeId: itemTypes.first.id,
        serviceId: services.first.id,
        itemTypeNameSnapshot: itemTypes.first.name,
        serviceNameSnapshot: services.first.name,
        pricingType: PricingType.fixedPrice,
        quantity: 1,
        unitPrice: const Money.fromPiastres(10000),
        calculatedTotal: const Money.fromPiastres(10000),
        createdAt: now,
        updatedAt: now,
      );
      await orderRepository.createOrder(order: order1, items: [item1]);
      await paymentRepository.recordPayment(Payment(
        id: 'pay-fin-1',
        orderId: order1.id,
        amount: const Money.fromPiastres(6000),
        paymentMethod: PaymentMethod.cash,
        paidAt: now,
        createdAt: now,
        updatedAt: now,
      ));

      // Order 2: Total 50 EGP (5000 piastres), Paid 50 EGP (5000 piastres), Remaining 0
      final order2 = Order(
        id: 'ord-fin-2',
        orderNumber: '26-202',
        customerId: customer.id,
        customerNameSnapshot: customer.name,
        customerPhoneSnapshot: customer.phone,
        status: OrderStatus.ready,
        expectedPickupDate: OrderDate.fromDate(now.add(const Duration(days: 2))),
        subtotal: const Money.fromPiastres(5000),
        discount: Money.zero,
        tax: Money.zero,
        total: const Money.fromPiastres(5000),
        createdAt: now, // latest
        updatedAt: now,
      );
      final item2 = OrderItem(
        id: 'itm-fin-2',
        orderId: order2.id,
        itemTypeId: itemTypes.first.id,
        serviceId: services.first.id,
        itemTypeNameSnapshot: itemTypes.first.name,
        serviceNameSnapshot: services.first.name,
        pricingType: PricingType.fixedPrice,
        quantity: 1,
        unitPrice: const Money.fromPiastres(5000),
        calculatedTotal: const Money.fromPiastres(5000),
        createdAt: now,
        updatedAt: now,
      );
      await orderRepository.createOrder(order: order2, items: [item2]);
      await paymentRepository.recordPayment(Payment(
        id: 'pay-fin-2',
        orderId: order2.id,
        amount: const Money.fromPiastres(5000),
        paymentMethod: PaymentMethod.cash,
        paidAt: now,
        createdAt: now,
        updatedAt: now,
      ));

      await cubit.loadCustomerDetail(customer.id);

      final data = cubit.state.data!;
      expect(data.totalOrdersCount, equals(2));
      // latestOrder should be order2 (created at `now`)
      expect(data.latestOrder?.id, equals('ord-fin-2'));
      // totalPaid = 60 + 50 = 110 EGP (11000 piastres)
      expect(data.totalPaid, equals(const Money.fromPiastres(11000)));
      // totalRemaining = 40 + 0 = 40 EGP (4000 piastres)
      expect(data.totalRemaining, equals(const Money.fromPiastres(4000)));
    });

    test('updateCustomerInfo updates customer details successfully', () async {
      final now = DateTime.now();
      final customer = await customerRepository.createCustomer(
        Customer(
          id: 'cust-update-1',
          name: 'سعيد عبد الله',
          phone: '01044445555',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await cubit.loadCustomerDetail(customer.id);

      final success = await cubit.updateCustomerInfo(
        name: 'سعيد عبد الله بعد التعديل',
        phone: '01044445555',
        notes: 'ملاحظة محدثة',
      );

      expect(success, isTrue);
      expect(cubit.state.data!.customer.name, equals('سعيد عبد الله بعد التعديل'));
      expect(cubit.state.data!.customer.notes, equals('ملاحظة محدثة'));
      expect(cubit.state.actionSuccessMessage, isNotNull);
    });

    test('updateCustomerInfo with duplicate phone emits error and does not update', () async {
      final now = DateTime.now();
      final custA = await customerRepository.createCustomer(
        Customer(
          id: 'cust-dup-a',
          name: 'عميل أ',
          phone: '01012340000',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await customerRepository.createCustomer(
        Customer(
          id: 'cust-dup-b',
          name: 'عميل ب',
          phone: '01012349999',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await cubit.loadCustomerDetail(custA.id);

      // Attempt to change custA phone to custB's phone
      final success = await cubit.updateCustomerInfo(
        name: 'عميل أ المعدل',
        phone: '01012349999',
      );

      expect(success, isFalse);
      expect(cubit.state.errorMessage, isNotNull);
      expect(cubit.state.errorMessage, contains('مسجل بهذا الرقم'));
    });

    test('customer with >20 orders has authoritative full aggregate counts, paginated history, and working loadMore', () async {
      final now = DateTime.now();
      final customer = await customerRepository.createCustomer(
        Customer(
          id: 'cust-many-orders',
          name: 'عميل الطلبات الكثيرة',
          phone: '01033334444',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final itemTypes = await db.select(db.itemTypes).get();
      final services = await db.select(db.services).get();

      // Create 25 orders:
      // - 10 processing
      // - 5 ready
      // - 7 completed
      // - 3 cancelled
      // Total = 25
      // Active = 15 (10 processing + 5 ready)
      // Completed = 7
      // Cancelled = 3

      for (var i = 0; i < 25; i++) {
        OrderStatus targetStatus;
        if (i < 10) {
          targetStatus = OrderStatus.processing;
        } else if (i < 15) {
          targetStatus = OrderStatus.ready;
        } else if (i < 22) {
          targetStatus = OrderStatus.completed;
        } else {
          targetStatus = OrderStatus.cancelled;
        }

        final order = Order(
          id: 'ord-many-$i',
          orderNumber: '26-${(300 + i).toString()}',
          customerId: customer.id,
          customerNameSnapshot: customer.name,
          customerPhoneSnapshot: customer.phone,
          status: OrderStatus.processing,
          expectedPickupDate: OrderDate.fromDate(now.add(const Duration(days: 2))),
          subtotal: const Money.fromPiastres(2000),
          discount: Money.zero,
          tax: Money.zero,
          total: const Money.fromPiastres(2000),
          createdAt: now.subtract(Duration(minutes: 25 - i)),
          updatedAt: now,
        );

        final item = OrderItem(
          id: 'itm-many-$i',
          orderId: order.id,
          itemTypeId: itemTypes.first.id,
          serviceId: services.first.id,
          itemTypeNameSnapshot: itemTypes.first.name,
          serviceNameSnapshot: services.first.name,
          pricingType: PricingType.fixedPrice,
          quantity: 1,
          unitPrice: const Money.fromPiastres(2000),
          calculatedTotal: const Money.fromPiastres(2000),
          createdAt: now,
          updatedAt: now,
        );
        await orderRepository.createOrder(order: order, items: [item]);

        int payAmount = 0;
        if (i < 10) {
          payAmount = 1000;
        } else if (i < 22) {
          payAmount = 2000;
        } else if (i == 22) {
          payAmount = 500; // cancelled order with historical payment
        }

        if (payAmount > 0) {
          await paymentRepository.recordPayment(Payment(
            id: 'pay-many-$i',
            orderId: order.id,
            amount: Money.fromPiastres(payAmount),
            paymentMethod: PaymentMethod.cash,
            paidAt: now,
            createdAt: now,
            updatedAt: now,
          ));
        }

        if (targetStatus != OrderStatus.processing) {
          await ordersDao.updateOrderStatus(
            orderId: order.id,
            status: targetStatus.name,
            completedAt: targetStatus == OrderStatus.completed ? now : null,
            cancelledAt: targetStatus == OrderStatus.cancelled ? now : null,
            cancellationReason: targetStatus == OrderStatus.cancelled ? 'سبب الإلغاء' : null,
            updatedAt: now,
          );
        }
      }

      await cubit.loadCustomerDetail(customer.id);

      final data = cubit.state.data!;
      // 1. Authoritative total order count is the full count (25), NOT 20!
      expect(data.totalOrdersCount, equals(25));
      expect(data.aggregate.totalOrders, equals(25));

      // 2. Status counts are full counts across all 25 orders:
      expect(data.activeOrdersCount, equals(15)); // 10 processing + 5 ready
      expect(data.completedOrdersCount, equals(7));
      expect(data.cancelledOrdersCount, equals(3));

      // 3. Financial totals across all orders including cancelled order with payment:
      expect(data.totalPaid, equals(const Money.fromPiastres(34500)));
      expect(data.totalRemaining, equals(const Money.fromPiastres(15500)));

      // 4. First history page remains limited to 20 orders:
      expect(data.orders.length, equals(20));
      expect(cubit.state.hasMoreOrders, isTrue);

      // 5. Load additional history:
      await cubit.loadMoreOrders();
      expect(cubit.state.data!.orders.length, equals(25));
      expect(cubit.state.hasMoreOrders, isFalse);

      // 6. Verify newest order is first:
      expect(cubit.state.data!.orders.first.id, equals('ord-many-24'));
    });

    test('loadCustomerDetail clears actionSuccessMessage on reload', () async {
      final now = DateTime.now();
      final customer = await customerRepository.createCustomer(
        Customer(
          id: 'cust-msg-1',
          name: 'عميل الرسائل',
          phone: '01011110000',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await cubit.loadCustomerDetail(customer.id);
      await cubit.updateCustomerInfo(name: 'اسم جديد', phone: '01011110000');
      expect(cubit.state.actionSuccessMessage, equals('تم تحديث بيانات العميل بنجاح'));

      // Reloading should clear the actionSuccessMessage (one-shot signal)
      await cubit.loadCustomerDetail(customer.id);
      expect(cubit.state.actionSuccessMessage, isNull);
    });

    test('unexpected exceptions emit localized generic Arabic error message', () async {
      await cubit.loadCustomerDetail('non-existent-id');
      expect(cubit.state.errorMessage, equals('العميل غير موجود'));
      expect(cubit.state.errorMessage, isNot(contains('Exception')));
      expect(cubit.state.errorMessage, isNot(contains('Error')));
    });
  });
}
