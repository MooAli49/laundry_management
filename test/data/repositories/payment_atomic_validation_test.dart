import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/errors/failures.dart';
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
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/entities/payment.dart';
import 'package:laundry_management/domain/enums/payment_method.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';

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
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> setupOrder({
    required String orderId,
    required int totalPiastres,
  }) async {
    final now = DateTime.now();
    await customerRepository.createCustomer(
      Customer(
        id: 'cust-1',
        name: 'عميل تجريبي',
        phone: '01012345678',
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
        price: totalPiastres,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final order = Order(
      id: orderId,
      orderNumber: '26-001',
      customerId: 'cust-1',
      customerNameSnapshot: 'عميل الدفع',
      customerPhoneSnapshot: '01012345678',
      expectedPickupDate: OrderDate(2026, 9, 12),
      subtotal: Money.fromPiastres(totalPiastres),
      total: Money.fromPiastres(totalPiastres),
      createdAt: now,
      updatedAt: now,
    );

    final item = OrderItem(
      id: 'item-1',
      orderId: orderId,
      itemTypeId: itemTypes.first.id,
      serviceId: 'srv-1',
      itemTypeNameSnapshot: 'قميص',
      serviceNameSnapshot: 'غسيل',
      pricingType: PricingType.perPiece,
      quantity: 1.0,
      unitPrice: Money.fromPiastres(totalPiastres),
      calculatedTotal: Money.fromPiastres(totalPiastres),
      createdAt: now,
      updatedAt: now,
    );

    await orderRepository.createOrder(order: order, items: [item]);
  }

  group('PaymentRepositoryImpl Atomic Transaction & Invariant Validation', () {
    test(
      'rejects payment for non-existent order with ValidationFailure',
      () async {
        final now = DateTime.now();
        final payment = Payment(
          id: 'pay-1',
          orderId: 'non-existent-order',
          amount: const Money.fromPiastres(1000),
          paymentMethod: PaymentMethod.cash,
          paidAt: now,
          createdAt: now,
          updatedAt: now,
        );

        expect(
          () => paymentRepository.recordPayment(payment),
          throwsA(isA<ValidationFailure>()),
        );
      },
    );

    test(
      'Payment entity rejects zero or negative amount at domain construction',
      () {
        final now = DateTime.now();
        expect(
          () => Payment(
            id: 'pay-2',
            orderId: 'ord-100',
            amount: Money.zero,
            paymentMethod: PaymentMethod.cash,
            paidAt: now,
            createdAt: now,
            updatedAt: now,
          ),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => Payment(
            id: 'pay-3',
            orderId: 'ord-101',
            amount: const Money.fromPiastres(-1000),
            paymentMethod: PaymentMethod.cash,
            paidAt: now,
            createdAt: now,
            updatedAt: now,
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test(
      'rejects payment when amount exceeds remaining balance with BusinessRuleFailure',
      () async {
        await setupOrder(orderId: 'ord-102', totalPiastres: 5000); // 50 EGP
        final now = DateTime.now();

        // Attempt payment of 60 EGP (6000 piastres)
        final overpayment = Payment(
          id: 'pay-4',
          orderId: 'ord-102',
          amount: const Money.fromPiastres(6000),
          paymentMethod: PaymentMethod.cash,
          paidAt: now,
          createdAt: now,
          updatedAt: now,
        );

        expect(
          () => paymentRepository.recordPayment(overpayment),
          throwsA(isA<BusinessRuleFailure>()),
        );

        // Verify no payment was recorded
        final totalPaid = await paymentRepository.getTotalPaidForOrder(
          'ord-102',
        );
        expect(totalPaid, Money.zero);
      },
    );

    test(
      'allows exact remaining balance payment and reduces remaining to zero',
      () async {
        await setupOrder(orderId: 'ord-103', totalPiastres: 5000); // 50 EGP
        final now = DateTime.now();

        final fullPayment = Payment(
          id: 'pay-5',
          orderId: 'ord-103',
          amount: const Money.fromPiastres(5000),
          paymentMethod: PaymentMethod.instapay,
          paidAt: now,
          createdAt: now,
          updatedAt: now,
        );

        await paymentRepository.recordPayment(fullPayment);

        final totalPaid = await paymentRepository.getTotalPaidForOrder(
          'ord-103',
        );
        expect(totalPaid, const Money.fromPiastres(5000));

        final remaining = await paymentRepository.getRemainingAmountForOrder(
          'ord-103',
        );
        expect(remaining, Money.zero);

        // Attempting any further payment now fails
        final extraPayment = Payment(
          id: 'pay-6',
          orderId: 'ord-103',
          amount: const Money.fromPiastres(100),
          paymentMethod: PaymentMethod.cash,
          paidAt: now,
          createdAt: now,
          updatedAt: now,
        );

        expect(
          () => paymentRepository.recordPayment(extraPayment),
          throwsA(isA<BusinessRuleFailure>()),
        );
      },
    );

    test(
      'supports multiple partial payments up to remaining balance',
      () async {
        await setupOrder(orderId: 'ord-104', totalPiastres: 10000); // 100 EGP
        final now = DateTime.now();

        // First partial: 40 EGP
        await paymentRepository.recordPayment(
          Payment(
            id: 'pay-p1',
            orderId: 'ord-104',
            amount: const Money.fromPiastres(4000),
            paymentMethod: PaymentMethod.cash,
            paidAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );

        var remaining = await paymentRepository.getRemainingAmountForOrder(
          'ord-104',
        );
        expect(remaining, const Money.fromPiastres(6000));

        // Attempt 70 EGP (exceeds 60 EGP remaining) -> must fail
        expect(
          () => paymentRepository.recordPayment(
            Payment(
              id: 'pay-p2-fail',
              orderId: 'ord-104',
              amount: const Money.fromPiastres(7000),
              paymentMethod: PaymentMethod.cash,
              paidAt: now,
              createdAt: now,
              updatedAt: now,
            ),
          ),
          throwsA(isA<BusinessRuleFailure>()),
        );

        // Second partial: 30 EGP -> succeeds
        await paymentRepository.recordPayment(
          Payment(
            id: 'pay-p2',
            orderId: 'ord-104',
            amount: const Money.fromPiastres(3000),
            paymentMethod: PaymentMethod.ewallet,
            paidAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );

        remaining = await paymentRepository.getRemainingAmountForOrder(
          'ord-104',
        );
        expect(remaining, const Money.fromPiastres(3000));

        // Third partial: 30 EGP (exact remaining) -> succeeds
        await paymentRepository.recordPayment(
          Payment(
            id: 'pay-p3',
            orderId: 'ord-104',
            amount: const Money.fromPiastres(3000),
            paymentMethod: PaymentMethod.instapay,
            paidAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );

        remaining = await paymentRepository.getRemainingAmountForOrder(
          'ord-104',
        );
        expect(remaining, Money.zero);
      },
    );

    group('Order Creation with Advance Payment (Atomic & Outbox)', () {
      test('creates order and initial payment atomically with strict outbox ordering (order -> payment)', () async {
        final now = DateTime.now();
        await customerRepository.createCustomer(
          Customer(
            id: 'cust-ap-1',
            name: 'عميل الدفع المقدم',
            phone: '01099887766',
            createdAt: now,
            updatedAt: now,
          ),
        );
        final itemTypes = await db.select(db.itemTypes).get();
        await servicesDao.insertService(
          db_pkg.ServicesCompanion.insert(
            id: 'srv-ap-1',
            name: 'غسيل',
            pricingType: 'perPiece',
            price: 8000,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await (db.delete(db.syncOperations)).go();

        final order = Order(
          id: 'ord-ap-1',
          customerId: 'cust-ap-1',
          customerNameSnapshot: 'عميل الدفع المقدم',
          customerPhoneSnapshot: '01099887766',
          orderNumber: '26-101',
          subtotal: const Money.fromPiastres(8000), // 80 EGP
          total: const Money.fromPiastres(8000),
          expectedPickupDate: OrderDate(2026, 9, 25),
          createdAt: now,
          updatedAt: now,
        );

        final item = OrderItem(
          id: 'item-ap-1',
          orderId: 'ord-ap-1',
          itemTypeId: itemTypes.first.id,
          serviceId: 'srv-ap-1',
          itemTypeNameSnapshot: 'قميص',
          serviceNameSnapshot: 'غسيل',
          pricingType: PricingType.perPiece,
          unitPrice: const Money.fromPiastres(8000),
          quantity: 1.0,
          calculatedTotal: const Money.fromPiastres(8000),
          createdAt: now,
          updatedAt: now,
        );

        final initialPayment = Payment(
          id: 'pay-ap-1',
          orderId: 'ord-ap-1',
          amount: const Money.fromPiastres(3000), // 30 EGP advance
          paymentMethod: PaymentMethod.instapay,
          paidAt: now,
          createdAt: now,
          updatedAt: now,
        );

        final createdOrder = await orderRepository.createOrder(
          order: order,
          items: [item],
          initialPayment: initialPayment,
        );

        expect(createdOrder.id, 'ord-ap-1');

        // Verify payment exists in paymentsDao / paymentRepository
        final payments = await paymentRepository.getPaymentsForOrder('ord-ap-1');
        expect(payments.length, 1);
        expect(payments.first.id, 'pay-ap-1');
        expect(payments.first.amount, const Money.fromPiastres(3000));
        expect(payments.first.paymentMethod, PaymentMethod.instapay);

        // Verify remaining balance
        final remaining = await paymentRepository.getRemainingAmountForOrder('ord-ap-1');
        expect(remaining, const Money.fromPiastres(5000));

        // Verify outbox ordering: order CREATE then payment CREATE
        final pendingOps = await syncOperationsDao.getPendingOperations();
        expect(pendingOps.length, 2);

        expect(pendingOps[0].entityType, 'order');
        expect(pendingOps[0].operationType, 'create');
        expect(pendingOps[0].entityId, 'ord-ap-1');

        expect(pendingOps[1].entityType, 'payment');
        expect(pendingOps[1].operationType, 'create');
        expect(pendingOps[1].entityId, 'pay-ap-1');
      });

      test('rolls back entire transaction if payment validation fails (neither order nor payment saved)', () async {
        final now = DateTime.now();
        await customerRepository.createCustomer(
          Customer(
            id: 'cust-ap-2',
            name: 'عميل التراجع',
            phone: '01011223399',
            createdAt: now,
            updatedAt: now,
          ),
        );
        final itemTypes = await db.select(db.itemTypes).get();
        await servicesDao.insertService(
          db_pkg.ServicesCompanion.insert(
            id: 'srv-ap-2',
            name: 'غسيل',
            pricingType: 'perPiece',
            price: 5000,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await (db.delete(db.syncOperations)).go();

        final order = Order(
          id: 'ord-ap-fail',
          customerId: 'cust-ap-2',
          customerNameSnapshot: 'عميل التراجع',
          customerPhoneSnapshot: '01011223399',
          orderNumber: '26-102',
          subtotal: const Money.fromPiastres(5000),
          total: const Money.fromPiastres(5000),
          expectedPickupDate: OrderDate(2026, 9, 25),
          createdAt: now,
          updatedAt: now,
        );

        final item = OrderItem(
          id: 'item-ap-fail',
          orderId: 'ord-ap-fail',
          itemTypeId: itemTypes.first.id,
          serviceId: 'srv-ap-2',
          itemTypeNameSnapshot: 'قميص',
          serviceNameSnapshot: 'غسيل',
          pricingType: PricingType.perPiece,
          unitPrice: const Money.fromPiastres(5000),
          quantity: 1.0,
          calculatedTotal: const Money.fromPiastres(5000),
          createdAt: now,
          updatedAt: now,
        );

        // Payment orderId mismatch triggers ValidationFailure in repository
        final invalidPayment = Payment(
          id: 'pay-ap-fail',
          orderId: 'wrong-order-id',
          amount: const Money.fromPiastres(2000),
          paymentMethod: PaymentMethod.cash,
          paidAt: now,
          createdAt: now,
          updatedAt: now,
        );

        await expectLater(
          () => orderRepository.createOrder(
            order: order,
            items: [item],
            initialPayment: invalidPayment,
          ),
          throwsA(isA<ValidationFailure>()),
        );

        // Verify order was NOT inserted
        final savedOrder = await orderRepository.getOrderById('ord-ap-fail');
        expect(savedOrder, isNull);

        // Verify payment was NOT inserted
        final payments = await paymentRepository.getPaymentsForOrder('ord-ap-fail');
        expect(payments, isEmpty);

        // Verify outbox has 0 pending operations
        final pendingOps = await syncOperationsDao.getPendingOperations();
        expect(pendingOps, isEmpty);
      });
    });
  });
}
