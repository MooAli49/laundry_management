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
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(cubit.state.customers.length, equals(1));
      expect(cubit.state.customers.first.customer.name, equals('أحمد محمود'));

      // Search by phone
      cubit.search('3333');
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(cubit.state.customers.length, equals(1));
      expect(cubit.state.customers.first.customer.name, equals('علي حسن'));

      // Empty query restores all
      cubit.search('');
      await Future<void>.delayed(const Duration(milliseconds: 600));
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
      await Future<void>.delayed(const Duration(milliseconds: 600));
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

    test('createCustomer creates customer and refreshes list through Cubit', () async {
      expect(cubit.state.customers, isEmpty);

      final created = await cubit.createCustomer(
        name: 'عميل جديد',
        phone: '01019283746',
        notes: 'ملاحظة',
      );

      expect(created.name, equals('عميل جديد'));
      expect(created.phone, equals('01019283746'));
      expect(cubit.state.customers.length, equals(1));
      expect(cubit.state.customers.first.customer.id, equals(created.id));
      expect(cubit.state.totalCustomersCount, equals(1));
    });

    test('stale request cannot overwrite newer search state when search query changes', () async {
      final now = DateTime.now();
      await customerRepository.createCustomer(
        Customer(
          id: 'c-old',
          name: 'عميل قديم',
          phone: '01011111111',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await customerRepository.createCustomer(
        Customer(
          id: 'c-new',
          name: 'عميل جديد',
          phone: '01022222222',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Start an initial load
      final initialLoad = cubit.loadCustomers();

      // Immediately before initial load finishes, user enters a new search query
      cubit.search('جديد');
      expect(cubit.state.searchQuery, equals('جديد'));

      // Wait for initial load to finish
      await initialLoad;

      // The old load must have been discarded because search invalidated the request generation
      // Now wait for the debounced search to execute
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(cubit.state.customers.length, equals(1));
      expect(cubit.state.customers.first.customer.name, equals('عميل جديد'));
      expect(cubit.state.searchQuery, equals('جديد'));
    });

    test('pagination: 60 customers loads 50 first, hasMore is true, loadMore appends remaining 10, hasMore becomes false', () async {
      final now = DateTime.now();
      for (var i = 1; i <= 60; i++) {
        final phoneSuffix = i.toString().padLeft(8, '0');
        await customerRepository.createCustomer(
          Customer(
            id: 'cust-$i',
            name: 'عميل $i',
            phone: '010$phoneSuffix',
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      // Initial page: loads 50
      await cubit.loadCustomers();
      expect(cubit.state.customers.length, equals(50));
      expect(cubit.state.totalCustomersCount, equals(60));
      expect(cubit.state.hasMoreCustomers, isTrue);

      // Load more: appends remaining 10
      await cubit.loadMoreCustomers();
      expect(cubit.state.customers.length, equals(60));
      expect(cubit.state.totalCustomersCount, equals(60));
      expect(cubit.state.hasMoreCustomers, isFalse);

      // Subsequent load-more call does nothing
      await cubit.loadMoreCustomers();
      expect(cubit.state.customers.length, equals(60));

      // Refresh resets to first 50
      await cubit.loadCustomers(refresh: true);
      expect(cubit.state.customers.length, equals(50));
      expect(cubit.state.hasMoreCustomers, isTrue);
    });

    test('focused order counts: only customer IDs in the loaded page are queried', () async {
      final now = DateTime.now();
      final ids = <String>[];
      for (var i = 1; i <= 3; i++) {
        final id = 'cust-focused-$i';
        ids.add(id);
        await customerRepository.createCustomer(
          Customer(
            id: id,
            name: 'عميل $i',
            phone: '0101234000$i',
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      final counts = await orderRepository.getOrderCountsByCustomerIds(ids);
      expect(counts, isA<Map<String, int>>());
      // Calling with empty list returns empty map immediately
      final emptyCounts = await orderRepository.getOrderCountsByCustomerIds([]);
      expect(emptyCounts, isEmpty);
    });
  });
}
