import 'package:flutter_test/flutter_test.dart';
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
  Future<List<CarpetSize>> getAllCarpetSizes({bool activeOnly = false}) async =>
      sizes;

  @override
  Future<List<CarpetSize>> getActiveCarpetSizes() async => sizes;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePaymentsDao extends Fake implements PaymentsDao {
  int totalPaidPiastres = 0;

  @override
  Future<int> getTotalPaidForOrder(String orderId) async => totalPaidPiastres;
}

class FakeStorageDao extends Fake implements StorageRecordsDao {
  final Map<String, int> counts = {};

  @override
  Future<int> countAllRecordsForOrderItem(String orderItemId) async =>
      counts[orderItemId] ?? 0;

  @override
  Future<app_db.StorageRecord?> getActiveRecordForOrderItem(String orderItemId) async => null;
}

class FakeStorageLocRepo extends Fake implements StorageLocationRepository {
  @override
  Future<StorageLocation?> getStorageLocationById(String id) async => null;
}

class FakeSettingsRepo extends Fake implements SettingsRepository {
  @override
  Future<BusinessSettings> getSettings() async => BusinessSettings(
        id: 'settings-1',
        businessName: 'مغسلة تجريبية',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
}

void main() {
  late MockOrderRepo orderRepo;
  late MockCustomerRepo customerRepo;
  late MockServiceRepo serviceRepo;
  late MockItemTypeRepo itemTypeRepo;
  late MockItemDefRepo itemDefRepo;
  late MockCarpetSizeRepo carpetSizeRepo;
  late FakePaymentsDao paymentsDao;
  late FakeStorageDao storageDao;
  late FakeStorageLocRepo storageLocRepo;
  late FakeSettingsRepo settingsRepo;
  late EditProcessingOrderUseCase useCase;
  late EditProcessingOrderCubit cubit;

  final now = DateTime.now();

  final testCustomer = Customer(
    id: 'cust-1',
    name: 'عميل تجريبي',
    phone: '0555555555',
    createdAt: now,
    updatedAt: now,
  );

  final testType = ItemType(
    id: 'type-1',
    name: 'ملابس',
    createdAt: now,
    updatedAt: now,
  );

  final testService = Service(
    id: 'srv-1',
    name: 'غسيل',
    price: Money.fromEgp(20),
    pricingType: PricingType.perPiece,
    createdAt: now,
    updatedAt: now,
  );

  final testCarpetService = Service(
    id: 'srv-carpet',
    name: 'غسيل سجاد',
    price: Money.fromEgp(30),
    pricingType: PricingType.perSquareMeter,
    createdAt: now,
    updatedAt: now,
  );

  final testItem = OrderItem(
    id: 'item-1',
    orderId: 'order-1',
    itemTypeId: 'type-1',
    itemTypeNameSnapshot: 'ملابس',
    serviceId: 'srv-1',
    serviceNameSnapshot: 'غسيل',
    pricingType: PricingType.perPiece,
    quantity: 2,
    unitPrice: Money.fromEgp(20),
    calculatedTotal: Money.fromEgp(40),
    createdAt: now,
    updatedAt: now,
  );

  final testOrder = Order(
    id: 'order-1',
    orderNumber: '26-001',
    customerId: 'cust-1',
    customerNameSnapshot: 'عميل تجريبي',
    customerPhoneSnapshot: '0555555555',
    status: OrderStatus.processing,
    subtotal: Money.fromEgp(20),
    total: Money.fromEgp(20),
    expectedPickupDate: OrderDate.fromDate(now.add(const Duration(days: 2))),
    createdAt: now,
    updatedAt: now,
  );

  setUp(() {
    orderRepo = MockOrderRepo();
    customerRepo = MockCustomerRepo();
    serviceRepo = MockServiceRepo();
    itemTypeRepo = MockItemTypeRepo();
    itemDefRepo = MockItemDefRepo();
    carpetSizeRepo = MockCarpetSizeRepo();
    paymentsDao = FakePaymentsDao();
    storageDao = FakeStorageDao();
    storageLocRepo = FakeStorageLocRepo();
    settingsRepo = FakeSettingsRepo();

    orderRepo.order = testOrder;
    orderRepo.items = [testItem];
    customerRepo.customers = [testCustomer];
    itemTypeRepo.types = [testType];
    serviceRepo.services = [testService, testCarpetService];

    useCase = EditProcessingOrderUseCase(orderRepository: orderRepo);

    cubit = EditProcessingOrderCubit(
      orderRepository: orderRepo,
      customerRepository: customerRepo,
      serviceRepository: serviceRepo,
      itemTypeRepository: itemTypeRepo,
      itemDefinitionRepository: itemDefRepo,
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

  group('EditProcessingOrderCubit', () {
    test('loadOrder() sets canChangeCustomer true when totalPaid == 0', () async {
      paymentsDao.totalPaidPiastres = 0;
      await cubit.loadOrder('order-1');

      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.canChangeCustomer, isTrue);
      expect(cubit.state.items.length, 1);
      expect(cubit.state.total, Money.fromEgp(20));
    });

    test('loadOrder() locks customer when totalPaid > 0', () async {
      paymentsDao.totalPaidPiastres = 2000; // 20 EGP
      await cubit.loadOrder('order-1');

      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.canChangeCustomer, isFalse);
      expect(cubit.state.totalPaid, Money.fromEgp(20));
    });

    test('selectCustomer does nothing when canChangeCustomer is false', () async {
      paymentsDao.totalPaidPiastres = 2000;
      await cubit.loadOrder('order-1');

      final newCustomer = Customer(
        id: 'cust-2',
        name: 'عميل آخر',
        phone: '0544444444',
        createdAt: now,
        updatedAt: now,
      );

      cubit.selectCustomer(newCustomer);
      expect(cubit.state.selectedCustomer?.id, 'cust-1');
      expect(cubit.state.errorMessage, contains('لا يمكن تغيير العميل لوجود مدفوعات'));
    });

    test('selectCustomer(null) clears selectedCustomer when canChangeCustomer is true (totalPaid == 0)', () async {
      paymentsDao.totalPaidPiastres = 0;
      await cubit.loadOrder('order-1');
      expect(cubit.state.selectedCustomer?.id, 'cust-1');

      // Operator taps "تغيير" -> sets selectedCustomer to null so picker opens
      cubit.selectCustomer(null);
      expect(cubit.state.selectedCustomer, isNull);

      // Operator selects another customer
      final newCustomer = Customer(
        id: 'cust-2',
        name: 'عميل جديد',
        phone: '0544444444',
        createdAt: now,
        updatedAt: now,
      );
      cubit.selectCustomer(newCustomer);
      expect(cubit.state.selectedCustomer?.id, 'cust-2');

      // Operator saves
      await cubit.submitEdit();
      expect(cubit.state.savedOrder, isNotNull);
      expect(orderRepo.lastInput?.customerId, 'cust-2');
    });

    test('blocks deletion of item that has storage records', () async {
      storageDao.counts['item-1'] = 1;
      await cubit.loadOrder('order-1');

      cubit.deleteItem(0);
      expect(cubit.state.errorMessage, contains('تخزين'));
      expect(cubit.state.items.length, 1);
    });

    test('allows deletion of item without storage records', () async {
      storageDao.counts['item-1'] = 0;
      await cubit.loadOrder('order-1');

      // Add a second item first
      await cubit.selectItemType(testType);
      cubit.selectService(testService);
      cubit.saveDraftItem();
      expect(cubit.state.items.length, 2);

      cubit.deleteItem(0);
      expect(cubit.state.items.length, 1);
      expect(cubit.state.deletedItemIds, contains('item-1'));
    });

    test('recalculates totals when discount and delivery fees are updated', () async {
      await cubit.loadOrder('order-1');
      expect(cubit.state.total, Money.fromEgp(20));

      cubit.updateDiscount(Money.fromEgp(5));
      expect(cubit.state.total, Money.fromEgp(15));

      cubit.toggleCustomerDelivery(true);
      cubit.updateCustomerDeliveryFee(Money.fromEgp(10));
      expect(cubit.state.total, Money.fromEgp(25));
    });

    test('submitEdit blocks when total < totalPaid', () async {
      paymentsDao.totalPaidPiastres = 2000; // 20 EGP paid
      await cubit.loadOrder('order-1');

      cubit.updateDiscount(Money.fromEgp(10)); // Subtotal 20 - 10 = 10 < paid 20
      await cubit.submitEdit();

      expect(cubit.state.savedOrder, isNull);
      expect(cubit.state.errorMessage, contains('أقل من المبلغ المدفوع'));
    });

    group('UAT-D — In-flight draft quantity presentation', () {
      test('adding draft with quantity = 2 creates 2 separate items with physicalQuantity = 1 each', () async {
        paymentsDao.totalPaidPiastres = 0;
        await cubit.loadOrder('order-1');
        expect(cubit.state.items.length, 1);

        await cubit.selectItemType(testType);
        cubit.selectService(testService);
        cubit.updateDraftQuantity(2);
        cubit.saveDraftItem();

        // 1 original + 2 newly added
        expect(cubit.state.items.length, 3);
        final piece1 = cubit.state.items[1];
        final piece2 = cubit.state.items[2];

        expect(piece1.physicalQuantity, 1);
        expect(piece2.physicalQuantity, 1);
        expect(piece1.unitPrice, Money.fromEgp(20));
        expect(piece2.unitPrice, Money.fromEgp(20));
        expect(piece1.calculatedTotal, Money.fromEgp(20));
        expect(piece2.calculatedTotal, Money.fromEgp(20));

        // Subtotal = 20 (original) + 20 + 20 = 60
        expect(cubit.state.subtotal, Money.fromEgp(60));
      });

      test('deleting one newly-added draft piece does not affect the other and recalculates total', () async {
        paymentsDao.totalPaidPiastres = 0;
        await cubit.loadOrder('order-1');

        await cubit.selectItemType(testType);
        cubit.selectService(testService);
        cubit.updateDraftQuantity(2);
        cubit.saveDraftItem();
        expect(cubit.state.items.length, 3);
        expect(cubit.state.subtotal, Money.fromEgp(60));

        // Delete the first newly-added item (index 1)
        cubit.deleteItem(1);

        expect(cubit.state.items.length, 2);
        expect(cubit.state.items[1].physicalQuantity, 1);
        expect(cubit.state.items[1].serviceName, 'غسيل');
        // Subtotal should now be 20 (original) + 20 (remaining piece) = 40
        expect(cubit.state.subtotal, Money.fromEgp(40));
      });

      test('saving order persists N individual CreateOrderItemInput rows with physicalQuantity = 1', () async {
        paymentsDao.totalPaidPiastres = 0;
        await cubit.loadOrder('order-1');

        await cubit.selectItemType(testType);
        cubit.selectService(testService);
        cubit.updateDraftQuantity(2);
        cubit.saveDraftItem();

        await cubit.submitEdit();

        expect(cubit.state.savedOrder, isNotNull);
        final newItems = orderRepo.lastInput?.newItems;
        expect(newItems, isNotNull);
        expect(newItems!.length, 2);
        expect(newItems[0].physicalQuantity, 1);
        expect(newItems[1].physicalQuantity, 1);
      });

      test('adding draft with quantity = 1 creates exactly 1 item with physicalQuantity = 1', () async {
        paymentsDao.totalPaidPiastres = 0;
        await cubit.loadOrder('order-1');
        expect(cubit.state.items.length, 1);

        await cubit.selectItemType(testType);
        cubit.selectService(testService);
        cubit.updateDraftQuantity(1);
        cubit.saveDraftItem();

        expect(cubit.state.items.length, 2);
        expect(cubit.state.items[1].physicalQuantity, 1);
        expect(cubit.state.subtotal, Money.fromEgp(40));
      });

      test('adding carpet draft with quantity = 2 and dimensions creates 2 separate items with physicalQuantity = 1 each and correct carpet data', () async {
        paymentsDao.totalPaidPiastres = 0;
        await cubit.loadOrder('order-1');
        expect(cubit.state.items.length, 1);

        await cubit.selectItemType(testType);
        cubit.selectService(testCarpetService);
        cubit.updateDraftQuantity(2);
        cubit.updateDraftCarpetDimensions(3.0, 2.0);
        cubit.saveDraftItem();

        // 1 original + 2 newly added carpet items
        expect(cubit.state.items.length, 3);
        final piece1 = cubit.state.items[1];
        final piece2 = cubit.state.items[2];

        expect(piece1.physicalQuantity, 1);
        expect(piece2.physicalQuantity, 1);
        expect(piece1.pricingType, PricingType.perSquareMeter);
        expect(piece2.pricingType, PricingType.perSquareMeter);
        expect(piece1.length, 3.0);
        expect(piece1.width, 2.0);
        expect(piece1.carpetArea, 6.0);
        expect(piece2.length, 3.0);
        expect(piece2.width, 2.0);
        expect(piece2.carpetArea, 6.0);
        // unit price 30 EGP / m^2 * 6 m^2 = 180 EGP each
        expect(piece1.calculatedTotal, Money.fromEgp(180));
        expect(piece2.calculatedTotal, Money.fromEgp(180));

        // Subtotal = 20 (original) + 180 + 180 = 380
        expect(cubit.state.subtotal, Money.fromEgp(380));
      });

      test('existing persisted items loaded from database have physicalQuantity = 1', () async {
        await cubit.loadOrder('order-1');
        expect(cubit.state.items.length, 1);
        expect(cubit.state.items[0].isExisting, isTrue);
        expect(cubit.state.items[0].physicalQuantity, 1);
      });
    });
  });
}
