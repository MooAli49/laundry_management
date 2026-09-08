import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/local/daos/customers_dao.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart' as db_pkg;
import 'package:laundry_management/data/repositories/customer_repository_impl.dart';
import 'package:laundry_management/data/repositories/order_repository_impl.dart';
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/features/customers/presentation/cubit/customers_list_cubit.dart';

void main() {
  late db_pkg.AppDatabase db;
  late CustomersDao customersDao;
  late OrdersDao ordersDao;
  late SyncOperationsDao syncOperationsDao;
  late StorageRecordsDao storageRecordsDao;

  late CustomerRepositoryImpl customerRepository;
  late OrderRepositoryImpl orderRepository;
  late CustomersListCubit cubit;

  setUp(() async {
    db = db_pkg.AppDatabase(NativeDatabase.memory());
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
      storageRecordsDao: storageRecordsDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    cubit = CustomersListCubit(
      customerRepository: customerRepository,
      orderRepository: orderRepository,
    );
  });

  tearDown(() async {
    await cubit.close();
    await db.close();
  });

  group('CustomersListCubit', () {
    test('initial state is empty and not loading', () {
      expect(cubit.state.customers, isEmpty);
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.searchQuery, isEmpty);
      expect(cubit.state.errorMessage, isNull);
    });

    test('loadCustomers loads customers and maps order counts', () async {
      final now = DateTime.now();
      await customerRepository.createCustomer(
        Customer(
          id: 'c1',
          name: 'عميل أ',
          phone: '01011111111',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await customerRepository.createCustomer(
        Customer(
          id: 'c2',
          name: 'عميل ب',
          phone: '01022222222',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await cubit.loadCustomers();

      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.customers.length, equals(2));
      expect(cubit.state.customers.any((c) => c.customer.id == 'c1'), isTrue);
      expect(cubit.state.customers.any((c) => c.customer.id == 'c2'), isTrue);
    });

    test('search filters customers by name and phone', () async {
      final now = DateTime.now();
      await customerRepository.createCustomer(
        Customer(
          id: 'c1',
          name: 'أحمد محمود',
          phone: '01011111111',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await customerRepository.createCustomer(
        Customer(
          id: 'c2',
          name: 'علي حسن',
          phone: '01022223333',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Search by name (wait for 300ms debounce)
      cubit.search('أحمد');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(cubit.state.customers.length, equals(1));
      expect(cubit.state.customers.first.customer.name, equals('أحمد محمود'));

      // Search by phone
      cubit.search('3333');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(cubit.state.customers.length, equals(1));
      expect(cubit.state.customers.first.customer.name, equals('علي حسن'));

      // Empty query restores all
      cubit.search('');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(cubit.state.customers.length, equals(2));
    });

    test('search debounces rapid input and avoids race conditions', () async {
      final now = DateTime.now();
      await customerRepository.createCustomer(
        Customer(
          id: 'c1',
          name: 'أحمد محمود',
          phone: '01011111111',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await customerRepository.createCustomer(
        Customer(
          id: 'c2',
          name: 'علي حسن',
          phone: '01022223333',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Rapid keystrokes: 'أ', 'أح', 'أحم'
      cubit.search('أ');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      cubit.search('أح');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      cubit.search('أحم');

      // State query is updated immediately, but loading is debounced
      expect(cubit.state.searchQuery, equals('أحم'));

      // Wait full debounce duration
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(cubit.state.customers.length, equals(1));
      expect(cubit.state.customers.first.customer.name, equals('أحمد محمود'));
    });

    test('search with Arabic-Indic digits normalizes and finds customer by phone', () async {
      final now = DateTime.now();
      await customerRepository.createCustomer(
        Customer(
          id: 'c-arabic-phone',
          name: 'محمود شاكر',
          phone: '01012345678',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Search with Eastern Arabic-Indic numerals: ٠١٠١٢٣٤٥٦٧٨
      cubit.search('٠١٠١٢٣٤٥٦٧٨');
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(cubit.state.customers.length, equals(1));
      expect(cubit.state.customers.first.customer.name, equals('محمود شاكر'));
      expect(cubit.state.customers.first.customer.phone, equals('01012345678'));
    });

    test('totalCustomersCount reflects authoritative count from repository', () async {
      final now = DateTime.now();
      for (var i = 0; i < 5; i++) {
        await customerRepository.createCustomer(
          Customer(
            id: 'c-count-$i',
            name: 'عميل رقم $i',
            phone: '0101111000$i',
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      await cubit.loadCustomers();

      expect(cubit.state.customers.length, equals(5));
      expect(cubit.state.totalCustomersCount, equals(5));
    });
  });
}
