import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/local/daos/customers_dao.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart'
    as db_pkg;
import 'package:laundry_management/data/repositories/customer_repository_impl.dart';
import 'package:laundry_management/data/repositories/order_repository_impl.dart';
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/domain/repositories/customer_repository.dart';
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
      paymentsDao: PaymentsDao(db),
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

    test(
      'search with Arabic-Indic digits normalizes and finds customer by phone',
      () async {
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
        expect(
          cubit.state.customers.first.customer.phone,
          equals('01012345678'),
        );
      },
    );

    test(
      'totalCustomersCount reflects authoritative count from repository',
      () async {
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
      },
    );

    test(
      'createCustomer creates customer and refreshes list through Cubit',
      () async {
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
      },
    );

    test(
      'stale request cannot overwrite newer search state when search query changes',
      () async {
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
      },
    );

    test(
      'pagination: 60 customers loads 50 first, hasMore is true, loadMore appends remaining 10, hasMore becomes false',
      () async {
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
      },
    );

    test(
      'focused order counts: only customer IDs in the loaded page are queried',
      () async {
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
        final emptyCounts = await orderRepository.getOrderCountsByCustomerIds(
          [],
        );
        expect(emptyCounts, isEmpty);
      },
    );

    test(
      'regression: stale loadMore is discarded, clears isLoadingMore, and does not block subsequent pagination',
      () async {
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

        final controllableRepo = DelayedCustomerRepository(customerRepository);
        final testCubit = CustomersListCubit(
          customerRepository: controllableRepo,
          orderRepository: orderRepository,
        );
        addTearDown(testCubit.close);

        // 1. Initial page loads 50 customers
        await testCubit.loadCustomers();
        expect(testCubit.state.customers.length, equals(50));
        expect(testCubit.state.hasMoreCustomers, isTrue);
        expect(testCubit.state.isLoadingMore, isFalse);

        // 2. Start loadMore with a pending completer
        final completer = Completer<List<Customer>>();
        controllableRepo.searchCompleter = completer;

        final loadMoreFuture = testCubit.loadMoreCustomers();
        expect(testCubit.state.isLoadingMore, isTrue);

        // 3. User search invalidates the loadMore request immediately
        testCubit.search('عميل 1');
        expect(testCubit.state.searchQuery, equals('عميل 1'));

        // 4. Old loadMore request completes late
        controllableRepo.searchCompleter = null;
        completer.complete(
          List.generate(
            10,
            (i) => Customer(
              id: 'cust-${51 + i}',
              name: 'عميل ${51 + i}',
              phone: '010${(51 + i).toString().padLeft(8, '0')}',
              createdAt: now,
              updatedAt: now,
            ),
          ),
        );
        await loadMoreFuture;

        // 5. Stale response is discarded, and isLoadingMore is cleared (not stuck!)
        expect(testCubit.state.isLoadingMore, isFalse);
        expect(testCubit.state.customers.length, equals(50));

        // 6. Wait for search debounce to complete and load the new query
        await Future<void>.delayed(const Duration(milliseconds: 600));
        expect(testCubit.state.isLoading, isFalse);
        expect(testCubit.state.isLoadingMore, isFalse);

        // 7. Newer request can still paginate normally
        await testCubit.loadMoreCustomers();
        expect(testCubit.state.isLoadingMore, isFalse);
      },
    );

    test(
      'regression: stale loadMore does NOT clear isLoadingMore if a newer loadMore is already active',
      () async {
        final now = DateTime.now();
        for (var i = 1; i <= 120; i++) {
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

        final controllableRepo = DelayedCustomerRepository(customerRepository);
        final testCubit = CustomersListCubit(
          customerRepository: controllableRepo,
          orderRepository: orderRepository,
        );
        addTearDown(testCubit.close);

        // Load initial 50
        await testCubit.loadCustomers();
        expect(testCubit.state.customers.length, equals(50));

        // 1. loadMore #1 starts with completer1
        final completer1 = Completer<List<Customer>>();
        controllableRepo.searchCompleter = completer1;
        final loadMoreFuture1 = testCubit.loadMoreCustomers();
        expect(testCubit.state.isLoadingMore, isTrue);

        // 2. A refresh occurs and completes quickly
        controllableRepo.searchCompleter = null;
        await testCubit.loadCustomers(refresh: true);
        expect(testCubit.state.isLoadingMore, isFalse);
        expect(testCubit.state.customers.length, equals(50));

        // 3. loadMore #2 starts with completer2
        final completer2 = Completer<List<Customer>>();
        controllableRepo.searchCompleter = completer2;
        final loadMoreFuture2 = testCubit.loadMoreCustomers();
        expect(testCubit.state.isLoadingMore, isTrue);

        // 4. Now loadMore #1 completes late
        completer1.complete(
          List.generate(
            10,
            (i) => Customer(
              id: 'stale-$i',
              name: 'stale $i',
              phone: '0100000000$i',
              createdAt: now,
              updatedAt: now,
            ),
          ),
        );
        await loadMoreFuture1;

        // 5. loadMore #1 was stale, but because loadMore #2 is active, isLoadingMore MUST REMAIN TRUE!
        expect(testCubit.state.isLoadingMore, isTrue);

        // 6. Now loadMore #2 completes
        controllableRepo.searchCompleter = null;
        completer2.complete(
          List.generate(
            50,
            (i) => Customer(
              id: 'page2-$i',
              name: 'page2 $i',
              phone: '010000000$i',
              createdAt: now,
              updatedAt: now,
            ),
          ),
        );
        await loadMoreFuture2;

        // 7. loadMore #2 finished and cleared isLoadingMore
        expect(testCubit.state.isLoadingMore, isFalse);
        expect(testCubit.state.customers.length, equals(100));
      },
    );

    group('Reactive SQLite Signal & Concurrency', () {
      test('6. Existing watchCustomers emission triggers reload', () async {
        expect(cubit.state.customers, isEmpty);

        final now = DateTime.now();
        await customerRepository.createCustomer(
          Customer(
            id: 'cust-signal-1',
            name: 'عميل تلقائي',
            phone: '01077777771',
            createdAt: now,
            updatedAt: now,
          ),
        );

        await pumpEventQueue();

        expect(cubit.state.customers.length, equals(1));
        expect(cubit.state.customers.first.customer.id, equals('cust-signal-1'));
      });

      test('7. Pagination guard is respected on DB change', () async {
        final now = DateTime.now();
        for (var i = 1; i <= 60; i++) {
          final phoneSuffix = i.toString().padLeft(8, '0');
          await customerRepository.createCustomer(
            Customer(
              id: 'c-pag-$i',
              name: 'عميل $i',
              phone: '010$phoneSuffix',
              createdAt: now,
              updatedAt: now,
            ),
          );
        }

        await cubit.loadCustomers();
        expect(cubit.state.customers.length, equals(50));

        await cubit.loadMoreCustomers();
        expect(cubit.state.customers.length, equals(60));

        // Seed 61st customer to fire watchCustomers
        await customerRepository.createCustomer(
          Customer(
            id: 'c-pag-61',
            name: 'عميل 61',
            phone: '01099999961',
            createdAt: now,
            updatedAt: now,
          ),
        );

        await pumpEventQueue();

        // Length should still be 60 because first-page guard dropped the signal
        expect(cubit.state.customers.length, equals(60));
      });

      test('8. Subscription is cancelled on close', () async {
        await cubit.close();

        final now = DateTime.now();
        await customerRepository.createCustomer(
          Customer(
            id: 'c-closed',
            name: 'عميل بعد الإغلاق',
            phone: '01099999999',
            createdAt: now,
            updatedAt: now,
          ),
        );

        await pumpEventQueue();

        expect(cubit.isClosed, isTrue);
        expect(cubit.state.customers, isEmpty);
      });

      test('9. Critical race: signal while loading triggers pending refresh after load', () async {
        final controllableRepo = DelayedCustomerRepository(customerRepository)
          ..useCustomWatch = true;
        final testCubit = CustomersListCubit(
          customerRepository: controllableRepo,
          orderRepository: orderRepository,
        );
        addTearDown(() {
          controllableRepo.dispose();
          return testCubit.close();
        });

        // 1. Start CustomersListCubit
        expect(testCubit.state.isLoading, isFalse);
        expect(testCubit.hasPendingReload, isFalse);

        // 2 & 3. Call loadCustomers() and keep searchCustomers() pending
        final completer1 = Completer<List<Customer>>();
        controllableRepo.searchCompleter = completer1;
        final loadFuture = testCubit.loadCustomers();

        expect(testCubit.state.isLoading, isTrue);
        expect(controllableRepo.searchCallCount, 1);

        // 4. While it is pending, emit the repository DB update signal
        controllableRepo.emitDbSignal();
        await pumpEventQueue();

        // 5. Verify the signal sets pending invalidation instead of being lost
        expect(testCubit.hasPendingReload, isTrue);
        expect(controllableRepo.searchCallCount, 1);

        // 6. Complete the first request with stale/empty data
        final completer2 = Completer<List<Customer>>();
        controllableRepo.searchCompleter = completer2;
        completer1.complete(<Customer>[]);
        await pumpEventQueue();

        // 7. Verify exactly one fresh reload occurs automatically
        expect(controllableRepo.searchCallCount, 2);
        expect(testCubit.hasPendingReload, isFalse);
        expect(testCubit.state.isLoading, isTrue);

        // 8. Complete the fresh reload with the new customer
        final now = DateTime.now();
        final newCustomer = Customer(
          id: 'cust-race-new',
          name: 'عميل السباق الجديد',
          phone: '01099998888',
          createdAt: now,
          updatedAt: now,
        );
        completer2.complete([newCustomer]);
        await loadFuture;
        await pumpEventQueue();

        // 9. Verify final state contains the new customer
        expect(testCubit.state.customers.length, 1);
        expect(testCubit.state.customers.first.customer.id, 'cust-race-new');
        expect(testCubit.state.isLoading, isFalse);
      });

      test('10. Multiple signals while loading coalesce into exactly one fresh reload', () async {
        final controllableRepo = DelayedCustomerRepository(customerRepository)
          ..useCustomWatch = true;
        final testCubit = CustomersListCubit(
          customerRepository: controllableRepo,
          orderRepository: orderRepository,
        );
        addTearDown(() {
          controllableRepo.dispose();
          return testCubit.close();
        });

        final completer1 = Completer<List<Customer>>();
        controllableRepo.searchCompleter = completer1;
        final loadFuture = testCubit.loadCustomers();

        expect(testCubit.state.isLoading, isTrue);
        expect(controllableRepo.searchCallCount, 1);

        // Emit multiple signals while load is in-flight
        controllableRepo.emitDbSignal();
        controllableRepo.emitDbSignal();
        controllableRepo.emitDbSignal();
        await pumpEventQueue();

        expect(testCubit.hasPendingReload, isTrue);
        expect(controllableRepo.searchCallCount, 1);

        final completer2 = Completer<List<Customer>>();
        controllableRepo.searchCompleter = completer2;
        completer1.complete(<Customer>[]);
        await pumpEventQueue();

        // Exactly one reload triggered
        expect(controllableRepo.searchCallCount, 2);
        expect(testCubit.hasPendingReload, isFalse);

        final now = DateTime.now();
        final newCustomer = Customer(
          id: 'cust-multi-signal',
          name: 'عميل إشارات متعددة',
          phone: '01077776666',
          createdAt: now,
          updatedAt: now,
        );
        completer2.complete([newCustomer]);
        await loadFuture;
        await pumpEventQueue();

        // Ensure no third reload occurred
        expect(controllableRepo.searchCallCount, 2);
        expect(testCubit.state.customers.length, 1);
        expect(testCubit.state.customers.first.customer.id, 'cust-multi-signal');
        expect(testCubit.state.isLoading, isFalse);
      });
    });
  });
}

class DelayedCustomerRepository implements CustomerRepository {
  final CustomerRepository _delegate;
  Completer<List<Customer>>? searchCompleter;
  int searchCallCount = 0;
  final StreamController<List<Customer>> _customerStreamController =
      StreamController<List<Customer>>.broadcast();
  bool useCustomWatch = false;

  DelayedCustomerRepository(this._delegate);

  void emitDbSignal([List<Customer>? customers]) {
    _customerStreamController.add(customers ?? <Customer>[]);
  }

  void dispose() {
    _customerStreamController.close();
  }

  @override
  Future<Customer> createCustomer(Customer customer) =>
      _delegate.createCustomer(customer);

  @override
  Future<Customer?> getCustomerById(String id) => _delegate.getCustomerById(id);

  @override
  Future<Customer?> getCustomerByPhone(String phone) =>
      _delegate.getCustomerByPhone(phone);

  @override
  Future<int> getCustomersCount({String? query}) =>
      _delegate.getCustomersCount(query: query);

  @override
  Future<bool> hasOrderHistory(String customerId) =>
      _delegate.hasOrderHistory(customerId);

  @override
  Future<List<Customer>> searchCustomers({
    String? query,
    int limit = 50,
    int offset = 0,
  }) {
    searchCallCount++;
    if (searchCompleter != null) {
      return searchCompleter!.future;
    }
    return _delegate.searchCustomers(
      query: query,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<Customer> updateCustomer(Customer customer) =>
      _delegate.updateCustomer(customer);

  @override
  Stream<List<Customer>> watchCustomers() {
    if (useCustomWatch) {
      return _customerStreamController.stream;
    }
    return _delegate.watchCustomers();
  }
}
