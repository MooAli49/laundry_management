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
  }) async =>
      customers;

  @override
  Future<Customer?> getCustomerById(String id) async =>
      customers.firstWhere((c) => c.id == id, orElse: () => customers.first);

  @override
  Future<Customer> createCustomer(Customer customer) async => customer;

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

class MockServiceRepo implements ServiceRepository {
  List<Service> services = [];

  @override
  Future<List<Service>> getServicesForItemType(String itemTypeId) async =>
      services;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockCarpetSizeRepo implements CarpetSizeRepository {
  List<CarpetSize> sizes = [];

  @override
  Future<List<CarpetSize>> getAllCarpetSizes({bool activeOnly = false}) async =>
      sizes;

  @override
  Future<List<CarpetSize>> getActiveCarpetSizes() async => sizes;

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
  @override
  Future<int> countAllRecordsForOrderItem(String orderItemId) async => 0;

  @override
  Future<app_db.StorageRecord?> getActiveRecordForOrderItem(
    String orderItemId,
  ) async =>
      null;

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
        businessName: 'مغسلة تجريبية',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime.now();

  final initialCustomer = Customer(
    id: 'cust-1',
    name: 'أحمد علي',
    phone: '01011112222',
    createdAt: now,
    updatedAt: now,
  );

  final testType = ItemType(
    id: 'type-1',
    name: 'سجاد',
    createdAt: now,
    updatedAt: now,
  );

  final testPieceService = Service(
    id: 'srv-piece',
    name: 'غسيل قطعة',
    price: Money.fromEgp(25),
    pricingType: PricingType.perPiece,
    createdAt: now,
    updatedAt: now,
  );

  final testCarpetService = Service(
    id: 'srv-carpet',
    name: 'غسيل بالمتر',
    price: Money.fromEgp(40),
    pricingType: PricingType.perSquareMeter,
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

  final existingItem = OrderItem(
    id: 'item-1',
    orderId: testOrder.id,
    itemTypeId: testType.id,
    itemTypeNameSnapshot: testType.name,
    serviceId: testPieceService.id,
    serviceNameSnapshot: testPieceService.name,
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

  setUp(() async {
    orderRepo = MockOrderRepo()
      ..order = testOrder
      ..items = [existingItem];
    customerRepo = MockCustomerRepo()..customers = [initialCustomer];
    itemTypeRepo = MockItemTypeRepo()..types = [testType];
    itemDefRepo = MockItemDefRepo()..defs = [];
    serviceRepo = MockServiceRepo()..services = [testPieceService, testCarpetService];
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
    await cubit.loadOrder('order-1');
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
      ],
    );

    return MaterialApp.router(
      routerConfig: router,
    );
  }

  group('UAT-D — Edit Order Quantity UI & Physical Piece Expansion Tests', () {
    testWidgets('A. New non-carpet item: quantity = 2 expands into two separate pieces with physicalQuantity = 1', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Ensure form is in new item mode
      expect(find.text('إضافة بند جديد'), findsOneWidget);
      expect(find.text('الكمية (عدد القطع) *'), findsOneWidget);

      // Select item type and service via cubit for reliable state setup
      await cubit.selectItemType(testType);
      cubit.selectService(testPieceService);
      await tester.pumpAndSettle();

      // Enter quantity = 2
      final quantityField = find.byKey(const ValueKey('draft_item_quantity_field'));
      expect(quantityField, findsOneWidget);
      await tester.enterText(quantityField, '2');
      await tester.pumpAndSettle();

      expect(cubit.state.draftQuantity, 2);

      // Tap add item
      await tester.tap(find.text('إضافة البند للطلب'));
      await tester.pumpAndSettle();

      // Total items should now be 3 (1 existing + 2 newly added)
      expect(cubit.state.items.length, 3);
      expect(cubit.state.items[1].physicalQuantity, 1);
      expect(cubit.state.items[2].physicalQuantity, 1);

      // Quantity input should reset back to 1
      expect(cubit.state.draftQuantity, 1);
    });

    testWidgets('B. New carpet item: quantity control and carpet dimensions are both visible, creating two physical pieces with carpet data', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await cubit.selectItemType(testType);
      cubit.selectService(testCarpetService);
      await tester.pumpAndSettle();

      // Both Quantity AND Carpet Dimensions must be visible simultaneously
      expect(find.text('الكمية (عدد القطع) *'), findsOneWidget);
      expect(find.text('الطول (متر) *'), findsOneWidget);
      expect(find.text('العرض (متر) *'), findsOneWidget);

      // Set quantity = 2 and dimensions
      cubit.updateDraftQuantity(2);
      cubit.updateDraftCarpetDimensions(3.0, 2.0);
      await tester.pumpAndSettle();

      // Add item
      await tester.tap(find.text('إضافة البند للطلب'));
      await tester.pumpAndSettle();

      // Verify two carpet items created each with physicalQuantity = 1 and correct dimensions
      expect(cubit.state.items.length, 3);
      final c1 = cubit.state.items[1];
      final c2 = cubit.state.items[2];

      expect(c1.physicalQuantity, 1);
      expect(c2.physicalQuantity, 1);
      expect(c1.length, 3.0);
      expect(c1.width, 2.0);
      expect(c1.carpetArea, 6.0);
      expect(c2.length, 3.0);
      expect(c2.width, 2.0);
      expect(c2.carpetArea, 6.0);
    });

    testWidgets('C. Existing item edit: quantity is not editable, read-only label shown, and piece remains physicalQuantity = 1', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Click edit on the existing item (index 0)
      await cubit.startEditItem(0);
      await tester.pumpAndSettle();

      expect(find.text('تعديل بند من الطلب'), findsOneWidget);

      // Editable quantity field is NOT rendered
      expect(find.text('الكمية (عدد القطع) *'), findsNothing);

      // Read-only informational label is rendered
      expect(find.text('العدد: 1 قطعة'), findsOneWidget);

      // Existing item still has physicalQuantity = 1
      expect(cubit.state.items[0].physicalQuantity, 1);
    });

    testWidgets('D. Quantity = 1: creates exactly one draft item with physicalQuantity = 1', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await cubit.selectItemType(testType);
      cubit.selectService(testPieceService);
      cubit.updateDraftQuantity(1);
      await tester.pumpAndSettle();

      await tester.tap(find.text('إضافة البند للطلب'));
      await tester.pumpAndSettle();

      // 1 existing + 1 newly added = 2 items
      expect(cubit.state.items.length, 2);
      expect(cubit.state.items[1].physicalQuantity, 1);
    });
  });
}
