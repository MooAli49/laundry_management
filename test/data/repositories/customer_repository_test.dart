import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/data/local/daos/customers_dao.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart'
    as app_db;
import 'package:laundry_management/data/local/database/dev_test_data.dart';
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
  late app_db.AppDatabase db;
  late CustomersDao customersDao;
  late OrdersDao ordersDao;
  late SyncOperationsDao syncOperationsDao;
  late StorageRecordsDao storageRecordsDao;
  late CustomerRepositoryImpl customerRepository;
  late OrderRepositoryImpl orderRepository;

  setUp(() async {
    db = app_db.AppDatabase(NativeDatabase.memory());
    await DevTestData.seedDevData(db);

    customersDao = CustomersDao(db);
    ordersDao = OrdersDao(db);
    syncOperationsDao = SyncOperationsDao(db);
    storageRecordsDao = StorageRecordsDao(db);

    customerRepository = CustomerRepositoryImpl(
      customersDao: customersDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    orderRepository = OrderRepositoryImpl(
      ordersDao: ordersDao,
      paymentsDao: PaymentsDao(db),
      storageRecordsDao: storageRecordsDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('CustomerRepositoryImpl', () {
    test('creates customer with normalized phone', () async {
      final now = DateTime.now();
      final customer = await customerRepository.createCustomer(
        Customer(
          id: 'cust-101',
          name: 'محمد أحمد',
          phone: '  ٠١٠١٢٣٤٥٦٧٨  ',
          notes: 'عميل مميز',
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(customer.id, 'cust-101');
      expect(customer.phone, '01012345678');

      final fetched = await customerRepository.getCustomerById('cust-101');
      expect(fetched != null, isTrue);
      expect(fetched!.phone, '01012345678');
      expect(fetched.name, 'محمد أحمد');
      expect(fetched.notes, 'عميل مميز');
    });

    test(
      'rejects duplicate customer phone on creation with DuplicateCustomerPhoneFailure',
      () async {
        final now = DateTime.now();
        await customerRepository.createCustomer(
          Customer(
            id: 'cust-1',
            name: 'عميل أول',
            phone: '01012345678',
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(
          () => customerRepository.createCustomer(
            Customer(
              id: 'cust-2',
              name: 'عميل ثان',
              phone: '٠١٠١٢٣٤٥٦٧٨', // Same normalized phone
              createdAt: now,
              updatedAt: now,
            ),
          ),
          throwsA(isA<DuplicateCustomerPhoneFailure>()),
        );
      },
    );

    test(
      'rejects empty or invalid Egyptian mobile phone on creation',
      () async {
        final now = DateTime.now();
        // Empty phone rejected at entity boundary
        expect(
          () => Customer(
            id: 'cust-empty',
            name: 'عميل',
            phone: '   ',
            createdAt: now,
            updatedAt: now,
          ),
          throwsA(isA<ArgumentError>()),
        );

        // Invalid Egyptian prefix (013)
        expect(
          () => customerRepository.createCustomer(
            Customer(
              id: 'cust-inv-1',
              name: 'عميل',
              phone: '01312345678',
              createdAt: now,
              updatedAt: now,
            ),
          ),
          throwsA(
            isA<ValidationFailure>().having(
              (e) => e.message,
              'message',
              'رقم الهاتف غير صحيح',
            ),
          ),
        );

        // Invalid length (10 digits)
        expect(
          () => customerRepository.createCustomer(
            Customer(
              id: 'cust-inv-2',
              name: 'عميل',
              phone: '0101234567',
              createdAt: now,
              updatedAt: now,
            ),
          ),
          throwsA(
            isA<ValidationFailure>().having(
              (e) => e.message,
              'message',
              'رقم الهاتف غير صحيح',
            ),
          ),
        );

        // Non-digit
        expect(
          () => customerRepository.createCustomer(
            Customer(
              id: 'cust-inv-3',
              name: 'عميل',
              phone: '0101234567a',
              createdAt: now,
              updatedAt: now,
            ),
          ),
          throwsA(
            isA<ValidationFailure>().having(
              (e) => e.message,
              'message',
              'رقم الهاتف غير صحيح',
            ),
          ),
        );
      },
    );

    test('updates customer and validates duplicate phone on update', () async {
      final now = DateTime.now();
      await customerRepository.createCustomer(
        Customer(
          id: 'cust-1',
          name: 'أحمد',
          phone: '01011111111',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await customerRepository.createCustomer(
        Customer(
          id: 'cust-2',
          name: 'محمود',
          phone: '01022222222',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Updating cust-1 name and notes with same phone should succeed
      final updated = await customerRepository.updateCustomer(
        Customer(
          id: 'cust-1',
          name: 'أحمد المعدل',
          phone: '01011111111',
          notes: 'ملاحظة جديدة',
          createdAt: now,
          updatedAt: now,
        ),
      );
      expect(updated.name, 'أحمد المعدل');
      expect(updated.notes, 'ملاحظة جديدة');

      // Updating cust-1 phone to cust-2 phone should fail
      expect(
        () => customerRepository.updateCustomer(
          Customer(
            id: 'cust-1',
            name: 'أحمد المعدل',
            phone: '01022222222',
            createdAt: now,
            updatedAt: now,
          ),
        ),
        throwsA(isA<DuplicateCustomerPhoneFailure>()),
      );
    });

    test(
      'updating customer details does not alter historical order snapshots',
      () async {
        final now = DateTime.now();
        final customer = await customerRepository.createCustomer(
          Customer(
            id: 'cust-snapshot-test',
            name: 'الاسم الأصلي',
            phone: '01055555555',
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Create an order for this customer
        final itemTypes = await db.select(db.itemTypes).get();
        final services = await db.select(db.services).get();
        final itemType = itemTypes.first;
        final service = services.first;

        final order = Order(
          id: 'ord-snapshot-test',
          orderNumber: '26-999',
          customerId: customer.id,
          customerNameSnapshot: 'الاسم الأصلي',
          customerPhoneSnapshot: '01055555555',
          status: OrderStatus.processing,
          expectedPickupDate: OrderDate.fromDate(
            now.add(const Duration(days: 3)),
          ),
          subtotal: const Money.fromPiastres(10000),
          discount: Money.zero,
          tax: Money.zero,
          total: const Money.fromPiastres(10000),
          createdAt: now,
          updatedAt: now,
        );

        final item = OrderItem(
          id: 'item-snap-1',
          orderId: order.id,
          itemTypeId: itemType.id,
          serviceId: service.id,
          itemTypeNameSnapshot: itemType.name,
          serviceNameSnapshot: service.name,
          pricingType: PricingType.fixedPrice,
          quantity: 1,
          unitPrice: const Money.fromPiastres(10000),
          calculatedTotal: const Money.fromPiastres(10000),
          createdAt: now,
          updatedAt: now,
        );

        await orderRepository.createOrder(order: order, items: [item]);

        // Now update the customer to a new name and phone
        await customerRepository.updateCustomer(
          customer.copyWith(
            name: 'الاسم الجديد بعد التعديل',
            phone: '01099999999',
          ),
        );

        // Verify the order still has the original snapshot
        final reloadedOrder = await orderRepository.getOrderById(
          'ord-snapshot-test',
        );
        expect(reloadedOrder != null, isTrue);
        expect(reloadedOrder!.customerNameSnapshot, equals('الاسم الأصلي'));
        expect(reloadedOrder.customerPhoneSnapshot, equals('01055555555'));
      },
    );

    test('counts customer orders accurately in OrderRepository', () async {
      final now = DateTime.now();
      final custA = await customerRepository.createCustomer(
        Customer(
          id: 'cust-count-a',
          name: 'عميل أ',
          phone: '01077771111',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final custB = await customerRepository.createCustomer(
        Customer(
          id: 'cust-count-b',
          name: 'عميل ب',
          phone: '01077772222',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final itemTypes = await db.select(db.itemTypes).get();
      final services = await db.select(db.services).get();

      // Create 2 orders for custA and 1 order for custB
      for (var i = 1; i <= 2; i++) {
        final ord = Order(
          id: 'ord-a-$i',
          orderNumber: '26-07$i',
          customerId: custA.id,
          customerNameSnapshot: custA.name,
          customerPhoneSnapshot: custA.phone,
          status: OrderStatus.processing,
          expectedPickupDate: OrderDate.fromDate(
            now.add(const Duration(days: 3)),
          ),
          subtotal: const Money.fromPiastres(5000),
          discount: Money.zero,
          tax: Money.zero,
          total: const Money.fromPiastres(5000),
          createdAt: now,
          updatedAt: now,
        );
        final itm = OrderItem(
          id: 'itm-a-$i',
          orderId: ord.id,
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
        await orderRepository.createOrder(order: ord, items: [itm]);
      }

      final ordB = Order(
        id: 'ord-b-1',
        orderNumber: '26-081',
        customerId: custB.id,
        customerNameSnapshot: custB.name,
        customerPhoneSnapshot: custB.phone,
        status: OrderStatus.processing,
        expectedPickupDate: OrderDate.fromDate(
          now.add(const Duration(days: 3)),
        ),
        subtotal: const Money.fromPiastres(5000),
        discount: Money.zero,
        tax: Money.zero,
        total: const Money.fromPiastres(5000),
        createdAt: now,
        updatedAt: now,
      );
      final itmB = OrderItem(
        id: 'itm-b-1',
        orderId: ordB.id,
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
      await orderRepository.createOrder(order: ordB, items: [itmB]);

      // Verify single customer count
      final countA = await orderRepository.getOrderCountByCustomerId(custA.id);
      expect(countA, equals(2));

      final countB = await orderRepository.getOrderCountByCustomerId(custB.id);
      expect(countB, equals(1));

      // Verify grouped counts
      final grouped = await orderRepository.getOrderCountsByCustomer();
      expect(grouped[custA.id], equals(2));
      expect(grouped[custB.id], equals(1));
    });

    group('Customer Address', () {
      test('1. Create customer with address persists and normalizes address', () async {
        final now = DateTime.now();
        final customer = Customer(
          id: 'cust-addr-1',
          name: 'عميل العنوان',
          phone: '01099887766',
          address: '  شارع التحرير، الدقي  ',
          createdAt: now,
          updatedAt: now,
        );

        final created = await customerRepository.createCustomer(customer);
        expect(created.address, equals('شارع التحرير، الدقي'));

        final fetched = await customerRepository.getCustomerById('cust-addr-1');
        expect(fetched?.address, equals('شارع التحرير، الدقي'));
      });

      test('2. Create customer without address persists null', () async {
        final now = DateTime.now();
        final customer = Customer(
          id: 'cust-addr-2',
          name: 'عميل بدون عنوان',
          phone: '01099887767',
          createdAt: now,
          updatedAt: now,
        );

        final created = await customerRepository.createCustomer(customer);
        expect(created.address, isNull);

        final fetched = await customerRepository.getCustomerById('cust-addr-2');
        expect(fetched?.address, isNull);
      });

      test('3 & 4. Edit and replace existing address', () async {
        final now = DateTime.now();
        final customer = Customer(
          id: 'cust-addr-3',
          name: 'عميل تعديل العنوان',
          phone: '01099887768',
          address: 'شارع التحرير',
          createdAt: now,
          updatedAt: now,
        );
        await customerRepository.createCustomer(customer);

        final updated = await customerRepository.updateCustomer(
          customer.copyWith(address: 'شارع النيل'),
        );
        expect(updated.address, equals('شارع النيل'));

        final fetched = await customerRepository.getCustomerById('cust-addr-3');
        expect(fetched?.address, equals('شارع النيل'));
      });

      test('5. Clear address to NULL via copyWith', () async {
        final now = DateTime.now();
        final customer = Customer(
          id: 'cust-addr-5',
          name: 'عميل حذف العنوان',
          phone: '01099887769',
          address: 'شارع التحرير',
          createdAt: now,
          updatedAt: now,
        );
        await customerRepository.createCustomer(customer);

        // Clear using address: null
        final cleared = await customerRepository.updateCustomer(
          customer.copyWith(address: null),
        );
        expect(cleared.address, isNull);

        final fetched = await customerRepository.getCustomerById('cust-addr-5');
        expect(fetched?.address, isNull);
      });

      test('6. Whitespace-only address becomes NULL on create and update', () async {
        final now = DateTime.now();
        final customer = Customer(
          id: 'cust-addr-6',
          name: 'عميل مسافات',
          phone: '01099887770',
          address: '     ',
          createdAt: now,
          updatedAt: now,
        );
        final created = await customerRepository.createCustomer(customer);
        expect(created.address, isNull);

        final updated = await customerRepository.updateCustomer(
          created.copyWith(address: '\t \n '),
        );
        expect(updated.address, isNull);
      });

      test('7. Address persists after local database reload', () async {
        final now = DateTime.now();
        final customer = Customer(
          id: 'cust-addr-7',
          name: 'عميل استمرار قاعدة البيانات',
          phone: '01099887771',
          address: '15 شارع طلعت حرب',
          createdAt: now,
          updatedAt: now,
        );
        await customerRepository.createCustomer(customer);

        // Fetch again through fresh accessor
        final freshDao = CustomersDao(db);
        final freshRepo = CustomerRepositoryImpl(
          customersDao: freshDao,
          syncOperationsDao: syncOperationsDao,
          db: db,
        );

        final fetched = await freshRepo.getCustomerById('cust-addr-7');
        expect(fetched?.address, equals('15 شارع طلعت حرب'));
      });

      test('8 & 9. Address appears in create and update outbox payloads', () async {
        final now = DateTime.now();
        final customer = Customer(
          id: 'cust-addr-8',
          name: 'عميل المزامنة',
          phone: '01099887772',
          address: 'شارع العروبة',
          createdAt: now,
          updatedAt: now,
        );
        await customerRepository.createCustomer(customer);

        final ops = await syncOperationsDao.getPendingOperations();
        final createOp = ops.firstWhere((o) => o.entityId == 'cust-addr-8' && o.operationType == 'create');
        expect(createOp.payload, contains('"address":"شارع العروبة"'));

        await customerRepository.updateCustomer(
          customer.copyWith(address: 'شارع مصدق'),
        );
        final updatedOps = await syncOperationsDao.getPendingOperations();
        final updateOp = updatedOps.firstWhere((o) => o.entityId == 'cust-addr-8' && o.operationType == 'update');
        expect(updateOp.payload, contains('"address":"شارع مصدق"'));
      });

      test('12. Existing customer with NULL address remains valid', () async {
        final now = DateTime.now();
        // Insert directly into Drift DB with NULL address (simulating row created before schema v6)
        await db.into(db.customers).insert(
          app_db.CustomersCompanion.insert(
            id: 'legacy-cust-1',
            name: 'عميل قديم',
            phone: '01011119999',
            createdAt: now,
            updatedAt: now,
          ),
        );

        final existing = await customerRepository.getCustomerById('legacy-cust-1');
        expect(existing, isNotNull);
        expect(existing?.address, isNull);

        // Update name of existing customer without setting address
        final updated = await customerRepository.updateCustomer(
          existing!.copyWith(name: 'عميل قديم محدث'),
        );
        expect(updated.name, equals('عميل قديم محدث'));
        expect(updated.address, isNull);
      });
    });
  });
}
