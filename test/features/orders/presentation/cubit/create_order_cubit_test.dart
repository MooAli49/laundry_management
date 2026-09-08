import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/application/use_cases/create_order_use_case.dart';
import 'package:laundry_management/data/local/daos/business_settings_dao.dart';
import 'package:laundry_management/data/local/daos/carpet_sizes_dao.dart';
import 'package:laundry_management/data/local/daos/customers_dao.dart';
import 'package:laundry_management/data/local/daos/item_definitions_dao.dart';
import 'package:laundry_management/data/local/daos/item_types_dao.dart';
import 'package:laundry_management/data/local/daos/orders_dao.dart';
import 'package:laundry_management/data/local/daos/services_dao.dart';
import 'package:laundry_management/data/local/daos/storage_records_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart' as db_pkg;
import 'package:laundry_management/data/repositories/carpet_size_repository_impl.dart';
import 'package:laundry_management/data/repositories/customer_repository_impl.dart';
import 'package:laundry_management/data/repositories/item_definition_repository_impl.dart';
import 'package:laundry_management/data/repositories/item_type_repository_impl.dart';
import 'package:laundry_management/data/repositories/order_repository_impl.dart';
import 'package:laundry_management/data/repositories/service_repository_impl.dart';
import 'package:laundry_management/data/repositories/settings_repository_impl.dart';
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/domain/entities/service.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/features/orders/presentation/cubit/create_order_cubit.dart';

void main() {
  late db_pkg.AppDatabase db;
  late CustomersDao customersDao;
  late OrdersDao ordersDao;
  late StorageRecordsDao storageRecordsDao;
  late ServicesDao servicesDao;
  late ItemTypesDao itemTypesDao;
  late ItemDefinitionsDao itemDefinitionsDao;
  late CarpetSizesDao carpetSizesDao;
  late BusinessSettingsDao businessSettingsDao;
  late SyncOperationsDao syncOperationsDao;

  late CustomerRepositoryImpl customerRepository;
  late OrderRepositoryImpl orderRepository;
  late ServiceRepositoryImpl serviceRepository;
  late ItemTypeRepositoryImpl itemTypeRepository;
  late ItemDefinitionRepositoryImpl itemDefinitionRepository;
  late CarpetSizeRepositoryImpl carpetSizeRepository;
  late SettingsRepositoryImpl settingsRepository;
  late CreateOrderUseCase createOrderUseCase;
  late CreateOrderCubit cubit;

  setUp(() async {
    db = db_pkg.AppDatabase(NativeDatabase.memory());
    customersDao = CustomersDao(db);
    ordersDao = OrdersDao(db);
    storageRecordsDao = StorageRecordsDao(db);
    servicesDao = ServicesDao(db);
    itemTypesDao = ItemTypesDao(db);
    itemDefinitionsDao = ItemDefinitionsDao(db);
    carpetSizesDao = CarpetSizesDao(db);
    businessSettingsDao = BusinessSettingsDao(db);
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

    serviceRepository = ServiceRepositoryImpl(
      servicesDao: servicesDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    itemTypeRepository = ItemTypeRepositoryImpl(
      itemTypesDao: itemTypesDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    itemDefinitionRepository = ItemDefinitionRepositoryImpl(
      itemDefinitionsDao: itemDefinitionsDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    carpetSizeRepository = CarpetSizeRepositoryImpl(
      carpetSizesDao: carpetSizesDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    settingsRepository = SettingsRepositoryImpl(
      settingsDao: businessSettingsDao,
      syncOperationsDao: syncOperationsDao,
      db: db,
    );

    createOrderUseCase = CreateOrderUseCase(
      orderRepository: orderRepository,
      customerRepository: customerRepository,
      serviceRepository: serviceRepository,
      itemTypeRepository: itemTypeRepository,
      itemDefinitionRepository: itemDefinitionRepository,
    );

    cubit = CreateOrderCubit(
      customerRepository: customerRepository,
      itemTypeRepository: itemTypeRepository,
      itemDefinitionRepository: itemDefinitionRepository,
      serviceRepository: serviceRepository,
      carpetSizeRepository: carpetSizeRepository,
      settingsRepository: settingsRepository,
      createOrderUseCase: createOrderUseCase,
    );
  });

  tearDown(() async {
    await cubit.close();
    await db.close();
  });

  group('CreateOrderCubit', () {
    test('initial state loads master data and defaults', () async {
      await cubit.initialize();
      expect(cubit.state.itemTypes, isNotEmpty);
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.subtotal, Money.zero);
    });

    test('selectCustomer updates state', () {
      final now = DateTime.now();
      final customer = Customer(
        id: 'cust-1',
        name: 'عميل تجريبي',
        phone: '01011112222',
        createdAt: now,
        updatedAt: now,
      );

      cubit.selectCustomer(customer);
      expect(cubit.state.selectedCustomer, customer);
    });

    test('Fixed Price quantity expansion produces subtotal = unitPrice * quantity', () async {
      await cubit.initialize();

      // Seed a service with fixed price
      final now = DateTime.now();
      final itemType = cubit.state.itemTypes.first;
      final service = Service(
        id: 'srv-fixed',
        name: 'تنظيف خاص',
        pricingType: PricingType.perPiece,
        price: const Money.fromPiastres(50000), // 500 EGP
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );
      await serviceRepository.createService(service, supportedItemTypeIds: [itemType.id]);

      // Select item type & service
      await cubit.selectItemType(itemType);
      cubit.selectService(service);
      cubit.updateQuantity(5); // 5 pieces

      expect(cubit.state.draftQuantity, 5);
      expect(cubit.state.draftUnitPrice, const Money.fromPiastres(50000));

      // Add to order
      cubit.addItemDraftToOrder();

      expect(cubit.state.items.length, 1);
      final draft = cubit.state.items.first;
      expect(draft.physicalQuantity, 5);
      expect(draft.unitPrice, const Money.fromPiastres(50000));
      expect(draft.calculatedTotal, const Money.fromPiastres(250000)); // 2500 EGP (500 * 5)
      expect(cubit.state.subtotal, const Money.fromPiastres(250000));
    });

    test('updates delivery options, discount, and calculates final total', () async {
      await cubit.initialize();

      final now = DateTime.now();
      final itemType = cubit.state.itemTypes.first;
      final service = Service(
        id: 'srv-1',
        name: 'غسيل عادي',
        pricingType: PricingType.perPiece,
        price: const Money.fromPiastres(10000), // 100 EGP
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );
      await serviceRepository.createService(service, supportedItemTypeIds: [itemType.id]);

      await cubit.selectItemType(itemType);
      cubit.selectService(service);
      cubit.updateQuantity(2); // 2 * 100 = 200 EGP (20000 piastres)
      cubit.addItemDraftToOrder();

      expect(cubit.state.subtotal, const Money.fromPiastres(20000));

      // Enable delivery with 30 EGP fee
      cubit.updateDelivery(
        deliveryRequested: true,
        deliveryFee: const Money.fromPiastres(3000),
      );

      // Apply 20 EGP discount
      cubit.updateDiscount(const Money.fromPiastres(2000));

      // Total = subtotal (200) + delivery (30) - discount (20) = 210 EGP (21000 piastres)
      expect(cubit.state.total, const Money.fromPiastres(21000));
    });

    test('submitOrder creates discrete physical OrderItems via usecase', () async {
      await cubit.initialize();

      final now = DateTime.now();
      final customer = Customer(
        id: 'cust-real',
        name: 'طارق حسام',
        phone: '01099998888',
        createdAt: now,
        updatedAt: now,
      );
      await customerRepository.createCustomer(customer);
      cubit.selectCustomer(customer);

      final itemType = cubit.state.itemTypes.first;
      final service = Service(
        id: 'srv-suite',
        name: 'تنظيف بدلة',
        pricingType: PricingType.perPiece,
        price: const Money.fromPiastres(5000), // 50 EGP
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );
      await serviceRepository.createService(service, supportedItemTypeIds: [itemType.id]);

      await cubit.selectItemType(itemType);
      cubit.selectService(service);
      cubit.updateQuantity(3); // 3 physical items!
      cubit.addItemDraftToOrder();

      // Submit
      await cubit.submitOrder();

      final createdOrder = cubit.state.createdOrder;
      expect(createdOrder, isNotNull);
      expect(createdOrder!.orderNumber, startsWith('26-'));
      expect(createdOrder.total, const Money.fromPiastres(15000)); // 150 EGP

      // Verify discrete physical items in database
      final physicalItems = await orderRepository.getOrderItems(createdOrder.id);
      expect(physicalItems.length, 3);
      for (final item in physicalItems) {
        expect(item.quantity, 1.0);
        expect(item.unitPrice, const Money.fromPiastres(5000));
        expect(item.calculatedTotal, const Money.fromPiastres(5000));
      }
    });

    test('CreateOrderState.copyWith clearDraftNotes explicitly resets draftNotes to null', () {
      final stateWithNotes = cubit.state.copyWith(draftNotes: 'بقعة حبر قديمة');
      expect(stateWithNotes.draftNotes, 'بقعة حبر قديمة');

      // Without clearDraftNotes flag, passing draftNotes: null retains previous value
      final untouched = stateWithNotes.copyWith(draftNotes: null);
      expect(untouched.draftNotes, 'بقعة حبر قديمة');

      // With clearDraftNotes: true, draftNotes is explicitly reset to null
      final cleared = stateWithNotes.copyWith(clearDraftNotes: true);
      expect(cleared.draftNotes, isNull);
    });

    test('updateDraftNotes with null explicitly resets draftNotes via clearDraftNotes', () {
      cubit.updateDraftNotes('ملاحظة أولية');
      expect(cubit.state.draftNotes, 'ملاحظة أولية');

      cubit.updateDraftNotes(null);
      expect(cubit.state.draftNotes, isNull);
    });

    test('addItemDraftToOrder persists notes on added item and resets draftNotes in state', () async {
      await cubit.initialize();
      final itemType = cubit.state.itemTypes.first;
      final service = Service(
        id: 'srv-notes-1',
        name: 'كي بالبخار',
        pricingType: PricingType.perPiece,
        price: const Money.fromPiastres(3000),
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await serviceRepository.createService(service, supportedItemTypeIds: [itemType.id]);

      await cubit.selectItemType(itemType);
      cubit.selectService(service);
      cubit.updateDraftNotes('بقعة زيت على الكم الأيمن');

      expect(cubit.state.draftNotes, 'بقعة زيت على الكم الأيمن');

      cubit.addItemDraftToOrder();

      expect(cubit.state.items.length, 1);
      final addedItem = cubit.state.items.first;
      // Notes on the saved draft item remain intact
      expect(addedItem.notes, 'بقعة زيت على الكم الأيمن');
      // Draft notes in cubit state are cleared for the next item
      expect(cubit.state.draftNotes, isNull);
    });

    test('addItemDraftToOrder prevents note leakage to subsequent items', () async {
      await cubit.initialize();
      final itemType = cubit.state.itemTypes.first;
      final service1 = Service(
        id: 'srv-leak-1',
        name: 'غسيل خاص',
        pricingType: PricingType.perPiece,
        price: const Money.fromPiastres(4000),
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final service2 = Service(
        id: 'srv-leak-2',
        name: 'تنظيف جاف',
        pricingType: PricingType.perPiece,
        price: const Money.fromPiastres(6000),
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await serviceRepository.createService(service1, supportedItemTypeIds: [itemType.id]);
      await serviceRepository.createService(service2, supportedItemTypeIds: [itemType.id]);

      // Add First Item with a specific note
      await cubit.selectItemType(itemType);
      cubit.selectService(service1);
      cubit.updateDraftNotes('ملاحظة خاصة بالقطعة الأولى فقط');
      cubit.addItemDraftToOrder();

      expect(cubit.state.items.length, 1);
      expect(cubit.state.items[0].notes, 'ملاحظة خاصة بالقطعة الأولى فقط');
      expect(cubit.state.draftNotes, isNull);

      // Add Second Item WITHOUT providing notes
      await cubit.selectItemType(itemType);
      cubit.selectService(service2);
      // Ensure we do not set any draft notes for the second item
      expect(cubit.state.draftNotes, isNull);
      cubit.addItemDraftToOrder();

      expect(cubit.state.items.length, 2);
      // First item notes must stay intact
      expect(cubit.state.items[0].notes, 'ملاحظة خاصة بالقطعة الأولى فقط');
      // Second item must NOT inherit any notes from the first item
      expect(cubit.state.items[1].notes, isNull);
      // State draft notes remains null
      expect(cubit.state.draftNotes, isNull);
    });
  });
}
