import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/application/use_cases/create_order_use_case.dart';
import 'package:laundry_management/core/theme/app_theme.dart';
import 'package:laundry_management/core/widgets/app_text_field.dart';
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
import 'package:laundry_management/domain/entities/service.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/features/orders/presentation/cubit/create_order_cubit.dart';
import 'package:laundry_management/features/orders/presentation/widgets/order_item_form.dart';

Widget testBoilerplate(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    ),
  );
}

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

  testWidgets('OrderItemForm initializes notes field from state and clears after adding item', (tester) async {
    await cubit.initialize();
    final itemType = cubit.state.itemTypes.first;
    final service = Service(
      id: 'srv-form-test',
      name: 'غسيل وكي',
      pricingType: PricingType.perPiece,
      price: const Money.fromPiastres(2500),
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await serviceRepository.createService(service, supportedItemTypeIds: [itemType.id]);

    await cubit.selectItemType(itemType);
    cubit.selectService(cubit.state.compatibleServices.first);

    // Pump widget with initial cubit state
    await tester.pumpWidget(testBoilerplate(
      OrderItemForm(state: cubit.state, cubit: cubit),
    ));
    await tester.pumpAndSettle();

    final notesFieldContainer = find.widgetWithText(AppTextField, 'ملاحظات القطعة');
    expect(notesFieldContainer, findsOneWidget);

    final notesTextFormField = find.descendant(
      of: notesFieldContainer,
      matching: find.byType(TextFormField),
    );
    expect(notesTextFormField, findsOneWidget);

    // Enter notes in text field
    await tester.enterText(notesTextFormField, 'بقعة شاي على الصدر');
    await tester.pumpAndSettle();

    expect(cubit.state.draftNotes, 'بقعة شاي على الصدر');

    // Tap Add Item button
    final addButtonFinder = find.text('إضافة القطعة');
    expect(addButtonFinder, findsOneWidget);
    await tester.tap(addButtonFinder);
    await tester.pumpAndSettle();

    // Verify item draft has notes intact
    expect(cubit.state.items.length, 1);
    expect(cubit.state.items.first.notes, 'بقعة شاي على الصدر');

    // Verify cubit state draftNotes is reset
    expect(cubit.state.draftNotes, isNull);

    // Pump with updated state
    await tester.pumpWidget(testBoilerplate(
      OrderItemForm(state: cubit.state, cubit: cubit),
    ));
    await tester.pumpAndSettle();

    // Verify TextFormField controller text is empty
    final textFormFieldWidget = tester.widget<TextFormField>(notesTextFormField);
    expect(textFormFieldWidget.controller?.text, '');
  });

  testWidgets('OrderItemForm prevents note leakage to second item in UI flow', (tester) async {
    await cubit.initialize();
    final itemType = cubit.state.itemTypes.first;
    final service = Service(
      id: 'srv-form-leak-test',
      name: 'غسيل سريع',
      pricingType: PricingType.perPiece,
      price: const Money.fromPiastres(3500),
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await serviceRepository.createService(service, supportedItemTypeIds: [itemType.id]);

    // Item 1
    await cubit.selectItemType(itemType);
    cubit.selectService(cubit.state.compatibleServices.first);

    await tester.pumpWidget(testBoilerplate(
      OrderItemForm(state: cubit.state, cubit: cubit),
    ));
    await tester.pumpAndSettle();

    final notesFieldContainer = find.widgetWithText(AppTextField, 'ملاحظات القطعة');
    final notesTextFormField = find.descendant(
      of: notesFieldContainer,
      matching: find.byType(TextFormField),
    );

    // Enter notes for item 1
    await tester.enterText(notesTextFormField, 'ملاحظة خاصة بالقطعة 1');
    await tester.pumpAndSettle();

    // Add item 1
    await tester.tap(find.text('إضافة القطعة'));
    await tester.pumpAndSettle();

    expect(cubit.state.items.length, 1);
    expect(cubit.state.items.first.notes, 'ملاحظة خاصة بالقطعة 1');
    expect(cubit.state.draftNotes, isNull);

    // Item 2: select item type & service
    await cubit.selectItemType(itemType);
    cubit.selectService(cubit.state.compatibleServices.first);

    await tester.pumpWidget(testBoilerplate(
      OrderItemForm(state: cubit.state, cubit: cubit),
    ));
    await tester.pumpAndSettle();

    // Verify text field is blank for Item 2
    final textWidgetAfterReset = tester.widget<TextFormField>(notesTextFormField);
    expect(textWidgetAfterReset.controller?.text, '');

    // Add item 2 without entering notes
    await tester.tap(find.text('إضافة القطعة'));
    await tester.pumpAndSettle();

    expect(cubit.state.items.length, 2);
    // Item 1 notes intact
    expect(cubit.state.items[0].notes, 'ملاحظة خاصة بالقطعة 1');
    // Item 2 notes null (no leakage)
    expect(cubit.state.items[1].notes, isNull);
    // Draft notes remains null
    expect(cubit.state.draftNotes, isNull);
  });
}
