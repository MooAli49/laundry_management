import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:laundry_management/application/use_cases/edit_processing_order_use_case.dart';
import 'package:laundry_management/data/local/daos/payments_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart' as app_db;
import 'package:laundry_management/domain/entities/business_settings.dart';
import 'package:laundry_management/domain/entities/carpet_size.dart';
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/domain/entities/item_definition.dart';
import 'package:laundry_management/domain/entities/item_type.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/entities/service.dart';
import 'package:laundry_management/domain/entities/storage_location.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/repositories/carpet_size_repository.dart';
import 'package:laundry_management/domain/repositories/customer_repository.dart';
import 'package:laundry_management/domain/repositories/item_definition_repository.dart';
import 'package:laundry_management/domain/repositories/item_type_repository.dart';
import 'package:laundry_management/domain/repositories/order_repository.dart';
import 'package:laundry_management/domain/repositories/service_repository.dart';
import 'package:laundry_management/domain/repositories/settings_repository.dart';
import 'package:laundry_management/domain/repositories/storage_location_repository.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';
import 'package:laundry_management/features/orders/presentation/cubit/edit_processing_order_cubit.dart';
import 'package:laundry_management/features/orders/presentation/screens/edit_order_screen.dart';

class MockOrderRepo implements OrderRepository {
  Order? order;
  List<OrderItem> items = [];
  EditProcessingOrderInput? lastInput;

  @override
  Future<Order?> getOrderById(String id) async => order;

  @override
  Future<List<OrderItem>> getOrderItems(String orderId) async => items;

  @override
  Future<Order> editProcessingOrder(EditProcessingOrderInput input) async {
    lastInput = input;
    return order!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockCustomerRepo implements CustomerRepository {
  List<Customer> customers = [];

  @override
  Future<List<Customer>> searchCustomers({
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    if (query == null || query.isEmpty) return customers;
    return customers
        .where((c) => c.name.contains(query) || c.phone.contains(query))
        .toList();
  }

  @override
  Future<Customer?> getCustomerById(String id) async =>
      customers.firstWhere((c) => c.id == id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockServiceRepo implements ServiceRepository {
  List<Service> services = [];

  @override
  Future<List<Service>> getServicesForItemType(String itemTypeId) async =>
      services;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockItemTypeRepo implements ItemTypeRepository {
  List<ItemType> types = [];

  @override
  Future<List<ItemType>> getAllItemTypes({bool activeOnly = false}) async => types;

  @override
  Future<List<ItemType>> getActiveItemTypes() async => types;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockItemDefRepo implements ItemDefinitionRepository {
  List<ItemDefinition> defs = [];

  @override
  Future<List<ItemDefinition>> getDefinitionsForItemType(
    String itemTypeId, {
    bool activeOnly = false,
  }) async =>
      defs;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockCarpetSizeRepo implements CarpetSizeRepository {
  List<CarpetSize> sizes = [];

  @override
  Future<List<CarpetSize>> getActiveCarpetSizes() async => sizes;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockStorageLocRepo implements StorageLocationRepository {
  @override
  Future<StorageLocation?> getStorageLocationById(String id) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSettingsRepo implements SettingsRepository {
  @override
  Future<BusinessSettings> getSettings() async => BusinessSettings(
        id: 'settings-1',
        businessName: 'مغسلة النقاء',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockPaymentsDao implements PaymentsDao {
  int totalPaidPiastres = 0;

  @override
  Future<int> getTotalPaidForOrder(String orderId) async => totalPaidPiastres;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockStorageRecordsDao implements StorageRecordsDao {
  Map<String, int> counts = {};

  @override
  Future<int> countAllRecordsForOrderItem(String orderItemId) async =>
      counts[orderItemId] ?? 0;

  @override
  Future<app_db.StorageRecord?> getActiveRecordForOrderItem(
    String orderItemId,
  ) async =>
      null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime.now();

  final initialCustomer = Customer(
    id: 'cust-1',
    name: 'عميل أولي',
    phone: '01011112222',
    createdAt: now,
    updatedAt: now,
  );

  final secondCustomer = Customer(
    id: 'cust-2',
    name: 'عميل ثانٍ معدل',
    phone: '01099998888',
    createdAt: now,
    updatedAt: now,
  );

  final testOrder = Order(
    id: 'order-1',
    orderNumber: '26-001',
    customerId: initialCustomer.id,
    customerNameSnapshot: initialCustomer.name,
    customerPhoneSnapshot: initialCustomer.phone,
    status: OrderStatus.processing,
    expectedPickupDate: OrderDate.fromDate(now.add(const Duration(days: 3))),
    subtotal: Money.fromPiastres(2500),
    total: Money.fromPiastres(2500),
    createdAt: now,
    updatedAt: now,
  );

  final testItem = OrderItem(
    id: 'item-1',
    orderId: testOrder.id,
    itemTypeId: 'type-1',
    itemTypeNameSnapshot: 'ملابس',
    serviceId: 'srv-1',
    serviceNameSnapshot: 'غسيل',
    pricingType: PricingType.perPiece,
    quantity: 1,
    unitPrice: Money.fromPiastres(2500),
    calculatedTotal: Money.fromPiastres(2500),
    createdAt: now,
    updatedAt: now,
  );

  late MockOrderRepo orderRepo;
  late MockCustomerRepo customerRepo;
  late MockItemTypeRepo itemTypeRepo;
  late MockItemDefRepo itemDefRepo;
  late MockServiceRepo serviceRepo;
  late MockCarpetSizeRepo carpetSizeRepo;
  late MockPaymentsDao paymentsDao;
  late MockStorageRecordsDao storageDao;
  late MockStorageLocRepo storageLocRepo;
  late MockSettingsRepo settingsRepo;
  late EditProcessingOrderUseCase useCase;
  late EditProcessingOrderCubit cubit;

  setUp(() {
    orderRepo = MockOrderRepo()
      ..order = testOrder
      ..items = [testItem];
    customerRepo = MockCustomerRepo()..customers = [initialCustomer, secondCustomer];
    itemTypeRepo = MockItemTypeRepo()..types = [];
    itemDefRepo = MockItemDefRepo()..defs = [];
    serviceRepo = MockServiceRepo()..services = [];
    carpetSizeRepo = MockCarpetSizeRepo()..sizes = [];
    paymentsDao = MockPaymentsDao()..totalPaidPiastres = 0;
    storageDao = MockStorageRecordsDao();
    storageLocRepo = MockStorageLocRepo();
    settingsRepo = MockSettingsRepo();
    useCase = EditProcessingOrderUseCase(orderRepository: orderRepo);

    cubit = EditProcessingOrderCubit(
      orderRepository: orderRepo,
      customerRepository: customerRepo,
      itemTypeRepository: itemTypeRepo,
      itemDefinitionRepository: itemDefRepo,
      serviceRepository: serviceRepo,
      carpetSizeRepository: carpetSizeRepo,
      paymentsDao: paymentsDao,
      storageRecordsDao: storageDao,
      storageLocationRepository: storageLocRepo,
      settingsRepository: settingsRepo,
      editProcessingOrderUseCase: useCase,
    );
  });

  tearDown(() {
    cubit.close();
  });

  Widget buildTestWidget() {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: BlocProvider<EditProcessingOrderCubit>.value(
                value: cubit,
                child: const EditOrderView(orderId: 'order-1'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/orders/:id',
          builder: (context, state) => const Scaffold(body: Text('Order Detail')),
        ),
      ],
    );

    return MaterialApp.router(
      routerConfig: router,
    );
  }

  group('EditOrderScreen — Customer Change UAT Tests', () {
    testWidgets(
      'A. Processing order with totalPaid = 0: tapping تغيير opens customer picker, selecting new customer updates UI, and save persists new customer',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        paymentsDao.totalPaidPiastres = 0;
        await cubit.loadOrder('order-1');

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // 1. Initial state displays initial customer and "تغيير" button
        expect(find.text('عميل أولي'), findsOneWidget);
        expect(find.text('01011112222'), findsOneWidget);
        expect(find.text('تغيير'), findsOneWidget);
        expect(find.text('ابحث بالاسم أو رقم الهاتف...'), findsNothing);

        // 2. Tap "تغيير" -> customer picker opens!
        await tester.tap(find.text('تغيير'));
        await tester.pumpAndSettle();

        // Initial customer card is gone, search field and "+ عميل جديد" are now visible
        expect(find.text('عميل أولي'), findsNothing);
        expect(find.text('ابحث بالاسم أو رقم الهاتف...'), findsOneWidget);
        expect(find.text('+ عميل جديد'), findsOneWidget);

        // 3. Search and select another customer
        await tester.enterText(
          find.byType(TextField).first,
          'ثانٍ',
        );
        await tester.pumpAndSettle();

        // Search results show 'عميل ثانٍ معدل'
        expect(find.text('عميل ثانٍ معدل'), findsOneWidget);
        expect(find.text('01099998888'), findsOneWidget);

        // Tap the search result to select it
        await tester.tap(find.text('عميل ثانٍ معدل'));
        await tester.pumpAndSettle();

        // 4. UI updates to display the new selected customer
        expect(find.text('عميل ثانٍ معدل'), findsOneWidget);
        expect(find.text('01099998888'), findsOneWidget);
        expect(find.text('تغيير'), findsOneWidget);
        expect(find.text('ابحث بالاسم أو رقم الهاتف...'), findsNothing);

        // 5. Tap "حفظ التعديلات" -> save persists new customer
        await tester.tap(find.text('حفظ التعديلات'));
        await tester.pumpAndSettle();

        expect(orderRepo.lastInput, isNotNull);
        expect(orderRepo.lastInput!.customerId, 'cust-2');
      },
    );

    testWidgets(
      'B. Processing order with totalPaid > 0: customer change is blocked and lock notice is shown',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        paymentsDao.totalPaidPiastres = 1000; // 10 EGP paid
        await cubit.loadOrder('order-1');

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // 1. Initial state displays initial customer and lock notice
        expect(find.text('عميل أولي'), findsOneWidget);
        expect(find.textContaining('العميل مقفل لوجود دفعات'), findsOneWidget);

        // 2. Attempting to tap "تغيير" when canChangeCustomer is false does not clear customer
        // Note: CustomerSelector passes dummy callback when canChangeCustomer is false
        await tester.tap(find.text('تغيير'));
        await tester.pumpAndSettle();

        // Customer remains unchanged, search field is NOT shown
        expect(find.text('عميل أولي'), findsOneWidget);
        expect(find.text('ابحث بالاسم أو رقم الهاتف...'), findsNothing);
      },
    );
  });
}
