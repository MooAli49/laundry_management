import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/errors/failures.dart';
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

  Future<void> setupOrder({required String orderId, required int totalPiastres}) async {
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
    test('rejects payment for non-existent order with ValidationFailure', () async {
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
    });

    test('Payment entity rejects zero or negative amount at domain construction', () {
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
    });

    test('rejects payment when amount exceeds remaining balance with BusinessRuleFailure', () async {
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
      final totalPaid = await paymentRepository.getTotalPaidForOrder('ord-102');
      expect(totalPaid, Money.zero);
    });

    test('allows exact remaining balance payment and reduces remaining to zero', () async {
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

      final totalPaid = await paymentRepository.getTotalPaidForOrder('ord-103');
      expect(totalPaid, const Money.fromPiastres(5000));

      final remaining = await paymentRepository.getRemainingAmountForOrder('ord-103');
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
    });

    test('supports multiple partial payments up to remaining balance', () async {
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

      var remaining = await paymentRepository.getRemainingAmountForOrder('ord-104');
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

      remaining = await paymentRepository.getRemainingAmountForOrder('ord-104');
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

      remaining = await paymentRepository.getRemainingAmountForOrder('ord-104');
      expect(remaining, Money.zero);
    });
  });
}
