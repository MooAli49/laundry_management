import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/application/use_cases/create_order_use_case.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/data/local/daos/services_dao.dart';
import 'package:laundry_management/data/local/daos/sync_operations_dao.dart';
import 'package:laundry_management/data/local/daos/sync_state_dao.dart';
import 'package:laundry_management/data/local/database/app_database.dart' as app_db;
import 'package:laundry_management/data/repositories/service_repository_impl.dart';
import 'package:laundry_management/data/sync/remote_change_applier.dart';
import 'package:laundry_management/data/sync/sync_payload_builder.dart';
import 'package:laundry_management/domain/entities/carpet_item_data.dart';
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/domain/entities/item_type.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/entities/payment.dart';
import 'package:laundry_management/domain/entities/service.dart';
import 'package:laundry_management/domain/entities/service_item_type.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/repositories/customer_repository.dart';
import 'package:laundry_management/domain/repositories/item_definition_repository.dart';
import 'package:laundry_management/domain/repositories/item_type_repository.dart';
import 'package:laundry_management/domain/repositories/order_repository.dart';
import 'package:laundry_management/domain/repositories/service_repository.dart';
import 'package:laundry_management/data/remote/dto/sync_change_dto.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';
import 'package:laundry_management/features/settings/presentation/cubit/services_management_cubit.dart';

void main() {
  group('Section 12: Service + Item Type Pricing Model Specification Tests', () {
    late app_db.AppDatabase db;
    late ServicesDao servicesDao;
    late SyncOperationsDao syncOperationsDao;
    late SyncStateDao syncStateDao;
    late ServiceRepository serviceRepository;
    late ItemTypeRepository itemTypeRepository;

    setUp(() async {
      db = app_db.AppDatabase(NativeDatabase.memory());
      servicesDao = ServicesDao(db);
      syncOperationsDao = SyncOperationsDao(db);
      syncStateDao = SyncStateDao(db);
      serviceRepository = ServiceRepositoryImpl(
        db: db,
        servicesDao: servicesDao,
        syncOperationsDao: syncOperationsDao,
      );

      // Seed item types in DB (clear default seed first to avoid unique name conflicts)
      await db.customStatement('DELETE FROM item_types;');
      final now = DateTime.now();
      await db.customStatement(
        'INSERT INTO item_types (id, name, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
        [
          'it-clothes',
          'ملابس',
          1,
          now.millisecondsSinceEpoch ~/ 1000,
          now.millisecondsSinceEpoch ~/ 1000,
        ],
      );
      await db.customStatement(
        'INSERT INTO item_types (id, name, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
        [
          'it-blanket',
          'بطانية',
          1,
          now.millisecondsSinceEpoch ~/ 1000,
          now.millisecondsSinceEpoch ~/ 1000,
        ],
      );
      await db.customStatement(
        'INSERT INTO item_types (id, name, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
        [
          'it-carpet',
          'سجاد',
          1,
          now.millisecondsSinceEpoch ~/ 1000,
          now.millisecondsSinceEpoch ~/ 1000,
        ],
      );

      itemTypeRepository = _FakeItemTypeRepository([
        ItemType(id: 'it-clothes', name: 'ملابس', isActive: true, createdAt: now, updatedAt: now),
        ItemType(id: 'it-blanket', name: 'بطانية', isActive: true, createdAt: now, updatedAt: now),
        ItemType(id: 'it-carpet', name: 'سجاد', isActive: true, createdAt: now, updatedAt: now),
      ]);
    });

    tearDown(() async {
      await db.close();
    });

    // -------------------------------------------------------------------------
    // 1. Service without pricing fields
    // -------------------------------------------------------------------------
    test('1. Service entity and database table contain NO price or pricing_type', () {
      final now = DateTime.now();
      final service = Service(
        id: 'srv-1',
        name: 'غسيل عادي',
        description: 'وصف تجريبي',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      expect(service.id, equals('srv-1'));
      expect(service.name, equals('غسيل عادي'));
      expect(service.description, equals('وصف تجريبي'));
      expect(service.isActive, isTrue);

      // ServicesCompanion.insert must compile without price or pricingType
      final companion = app_db.ServicesCompanion.insert(
        id: 'srv-1',
        name: 'غسيل عادي',
        createdAt: now,
        updatedAt: now,
      );
      expect(companion.name.value, equals('غسيل عادي'));
    });

    // -------------------------------------------------------------------------
    // 2. ServiceItemType with pricing fields
    // -------------------------------------------------------------------------
    test('2. ServiceItemType contains pricing fields and enforces price > 0', () {
      final now = DateTime.now();
      final sit = ServiceItemType(
        id: 'sit-1',
        serviceId: 'srv-1',
        itemTypeId: 'it-clothes',
        pricingType: PricingType.perPiece,
        price: const Money.fromPiastres(2500),
        createdAt: now,
        updatedAt: now,
      );

      expect(sit.id, equals('sit-1'));
      expect(sit.serviceId, equals('srv-1'));
      expect(sit.itemTypeId, equals('it-clothes'));
      expect(sit.pricingType, equals(PricingType.perPiece));
      expect(sit.price, equals(const Money.fromPiastres(2500)));

      // Non-positive price must throw ArgumentError
      expect(
        () => ServiceItemType(
          id: 'sit-err',
          serviceId: 'srv-1',
          itemTypeId: 'it-clothes',
          pricingType: PricingType.perPiece,
          price: Money.zero,
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );
      expect(
        () => ServiceItemType(
          id: 'sit-err',
          serviceId: 'srv-1',
          itemTypeId: 'it-clothes',
          pricingType: PricingType.perPiece,
          price: const Money.fromPiastres(-500),
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );
    });

    // -------------------------------------------------------------------------
    // 3. Multiple ItemTypes for the same Service
    // -------------------------------------------------------------------------
    test('3. A single Service can support multiple distinct ItemTypes', () async {
      final now = DateTime.now();
      final service = Service(
        id: 'srv-wash',
        name: 'غسيل شامل',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final configs = <ServiceItemType>[
        ServiceItemType(
          id: 'sit-w-clothes',
          serviceId: 'srv-wash',
          itemTypeId: 'it-clothes',
          pricingType: PricingType.perPiece,
          price: const Money.fromPiastres(2500),
          createdAt: now,
          updatedAt: now,
        ),
        ServiceItemType(
          id: 'sit-w-blanket',
          serviceId: 'srv-wash',
          itemTypeId: 'it-blanket',
          pricingType: PricingType.perPiece,
          price: const Money.fromPiastres(8000),
          createdAt: now,
          updatedAt: now,
        ),
        ServiceItemType(
          id: 'sit-w-carpet',
          serviceId: 'srv-wash',
          itemTypeId: 'it-carpet',
          pricingType: PricingType.perSquareMeter,
          price: const Money.fromPiastres(6000),
          createdAt: now,
          updatedAt: now,
        ),
      ];

      await serviceRepository.createService(service, serviceItemTypes: configs);

      final persisted = await serviceRepository.getServiceItemTypes('srv-wash');
      expect(persisted.length, equals(3));
      final itemTypeIds = persisted.map((e) => e.itemTypeId).toSet();
      expect(itemTypeIds, containsAll(['it-clothes', 'it-blanket', 'it-carpet']));
    });

    // -------------------------------------------------------------------------
    // 4. Different pricing configurations for different ItemTypes
    // -------------------------------------------------------------------------
    test('4. Each ItemType has its own distinct pricing type and price', () async {
      final now = DateTime.now();
      final service = Service(
        id: 'srv-multi-pricing',
        name: 'خدمة متعددة الأسعار',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final configs = <ServiceItemType>[
        ServiceItemType(
          id: 'sit-mp-1',
          serviceId: 'srv-multi-pricing',
          itemTypeId: 'it-clothes',
          pricingType: PricingType.perPiece,
          price: const Money.fromPiastres(2500),
          createdAt: now,
          updatedAt: now,
        ),
        ServiceItemType(
          id: 'sit-mp-2',
          serviceId: 'srv-multi-pricing',
          itemTypeId: 'it-carpet',
          pricingType: PricingType.perSquareMeter,
          price: const Money.fromPiastres(6000),
          createdAt: now,
          updatedAt: now,
        ),
      ];

      await serviceRepository.createService(service, serviceItemTypes: configs);

      final clothesCfg = await serviceRepository.getServiceItemType(
        'srv-multi-pricing',
        'it-clothes',
      );
      expect(clothesCfg, isNotNull);
      expect(clothesCfg!.pricingType, equals(PricingType.perPiece));
      expect(clothesCfg.price.piastres, equals(2500));

      final carpetCfg = await serviceRepository.getServiceItemType(
        'srv-multi-pricing',
        'it-carpet',
      );
      expect(carpetCfg, isNotNull);
      expect(carpetCfg!.pricingType, equals(PricingType.perSquareMeter));
      expect(carpetCfg.price.piastres, equals(6000));
    });

    // -------------------------------------------------------------------------
    // 5. Service + ItemType lookup
    // -------------------------------------------------------------------------
    test('5. Service + ItemType lookup returns accurate configuration and ServiceWithPricing', () async {
      final now = DateTime.now();
      final service = Service(
        id: 'srv-lookup',
        name: 'خدمة بحث',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );
      await serviceRepository.createService(
        service,
        serviceItemTypes: [
          ServiceItemType(
            id: 'sit-lookup-1',
            serviceId: 'srv-lookup',
            itemTypeId: 'it-clothes',
            pricingType: PricingType.perPiece,
            price: const Money.fromPiastres(3500),
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      final match = await serviceRepository.getServiceItemType(
        'srv-lookup',
        'it-clothes',
      );
      expect(match, isNotNull);
      expect(match!.serviceId, equals('srv-lookup'));
      expect(match.itemTypeId, equals('it-clothes'));
      expect(match.price.piastres, equals(3500));

      final servicesWithPricing =
          await serviceRepository.getServicesForItemType('it-clothes');
      expect(servicesWithPricing.length, equals(1));
      expect(servicesWithPricing.first.service.name, equals('خدمة بحث'));
      expect(servicesWithPricing.first.price.piastres, equals(3500));
      expect(servicesWithPricing.first.pricingType, equals(PricingType.perPiece));
    });

    // -------------------------------------------------------------------------
    // 6. Missing ServiceItemType -> incompatible service failure
    // -------------------------------------------------------------------------
    test('6. Missing ServiceItemType results in IncompatibleServiceFailure in CreateOrderUseCase', () async {
      final now = DateTime.now();
      final service = Service(
        id: 'srv-clothes-only',
        name: 'خدمة ملابس فقط',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );
      // Configured only for clothing, NOT carpet
      await serviceRepository.createService(
        service,
        serviceItemTypes: [
          ServiceItemType(
            id: 'sit-co-1',
            serviceId: 'srv-clothes-only',
            itemTypeId: 'it-clothes',
            pricingType: PricingType.perPiece,
            price: const Money.fromPiastres(2000),
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      // Verify direct repository lookup returns null for carpet
      final unlinked = await serviceRepository.getServiceItemType(
        'srv-clothes-only',
        'it-carpet',
      );
      expect(unlinked, isNull);

      final customer = Customer(
        id: 'c-test',
        name: 'Customer Test',
        phone: '01011112222',
        createdAt: now,
        updatedAt: now,
      );

      final mockCustomerRepo = _MockCustomerRepo(customer);
      final mockOrderRepo = _MockOrderRepo();
      final mockItemDefRepo = _MockItemDefRepo();

      final useCase = CreateOrderUseCase(
        orderRepository: mockOrderRepo,
        customerRepository: mockCustomerRepo,
        serviceRepository: serviceRepository,
        itemTypeRepository: itemTypeRepository,
        itemDefinitionRepository: mockItemDefRepo,
      );

      final input = CreateOrderInput(
        customerId: 'c-test',
        expectedPickupDate: OrderDate.fromDate(now.add(const Duration(days: 2))),
        items: [
          const CreateOrderItemInput(
            itemTypeId: 'it-carpet', // carpet item with clothes-only service!
            serviceId: 'srv-clothes-only',
            physicalQuantity: 1,
          ),
        ],
      );

      expect(
        () async => await useCase.execute(input),
        throwsA(isA<IncompatibleServiceFailure>()),
      );
    });

    // -------------------------------------------------------------------------
    // 7. per_piece pricing
    // -------------------------------------------------------------------------
    test('7. per_piece pricing calculates correctly (unitPrice * quantity)', () {
      final now = DateTime.now();
      const unitPrice = Money.fromPiastres(2500); // 25.00 EGP
      const quantity = 3.0;

      final item = OrderItem(
        id: 'oi-1',
        orderId: 'ord-1',
        itemTypeId: 'it-clothes',
        serviceId: 'srv-1',
        itemTypeNameSnapshot: 'ملابس',
        serviceNameSnapshot: 'غسيل',
        pricingType: PricingType.perPiece,
        quantity: quantity,
        unitPrice: unitPrice,
        calculatedTotal: unitPrice * quantity,
        createdAt: now,
        updatedAt: now,
      );

      expect(item.pricingType, equals(PricingType.perPiece));
      expect(item.quantity, equals(3.0));
      expect(item.unitPrice.piastres, equals(2500));
      expect(item.calculatedTotal.piastres, equals(7500));
    });

    // -------------------------------------------------------------------------
    // 8. per_square_meter pricing
    // -------------------------------------------------------------------------
    test('8. per_square_meter pricing calculates correctly from carpet dimensions', () {
      final now = DateTime.now();
      const unitPrice = Money.fromPiastres(6000); // 60.00 EGP per m²
      const carpetLength = 2.0;
      const carpetWidth = 3.0;
      const area = carpetLength * carpetWidth; // 6.0 m²

      final item = OrderItem(
        id: 'oi-carpet',
        orderId: 'ord-1',
        itemTypeId: 'it-carpet',
        serviceId: 'srv-wash',
        itemTypeNameSnapshot: 'سجاد',
        serviceNameSnapshot: 'غسيل سجاد',
        pricingType: PricingType.perSquareMeter,
        quantity: area,
        unitPrice: unitPrice,
        calculatedTotal: unitPrice * area,
        carpetData: CarpetItemData(
          id: 'cd-1',
          orderItemId: 'oi-carpet',
          length: carpetLength,
          width: carpetWidth,
          area: area,
          createdAt: now,
          updatedAt: now,
        ),
        createdAt: now,
        updatedAt: now,
      );

      expect(item.pricingType, equals(PricingType.perSquareMeter));
      expect(item.quantity, equals(6.0));
      expect(item.unitPrice.piastres, equals(6000));
      expect(item.calculatedTotal.piastres, equals(36000));
    });

    // -------------------------------------------------------------------------
    // 9. Historical OrderItem pricing snapshot
    // -------------------------------------------------------------------------
    test('9. OrderItem snapshots pricing_type and unit_price immutably at creation', () {
      final now = DateTime.now();
      final item = OrderItem(
        id: 'oi-snap',
        orderId: 'ord-snap',
        itemTypeId: 'it-clothes',
        serviceId: 'srv-wash',
        itemTypeNameSnapshot: 'ملابس',
        serviceNameSnapshot: 'غسيل',
        pricingType: PricingType.perPiece,
        quantity: 2.0,
        unitPrice: const Money.fromPiastres(3000),
        calculatedTotal: const Money.fromPiastres(6000),
        createdAt: now,
        updatedAt: now,
      );

      expect(item.pricingType, equals(PricingType.perPiece));
      expect(item.unitPrice.piastres, equals(3000));
      expect(item.calculatedTotal.piastres, equals(6000));
    });

    // -------------------------------------------------------------------------
    // 10. Changing master price does not alter existing OrderItems
    // -------------------------------------------------------------------------
    test('10. Updating ServiceItemType price does not mutate existing OrderItem snapshot', () async {
      final now = DateTime.now();
      final service = Service(
        id: 'srv-master-change',
        name: 'خدمة تتغير',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      await serviceRepository.createService(
        service,
        serviceItemTypes: [
          ServiceItemType(
            id: 'sit-mc-1',
            serviceId: 'srv-master-change',
            itemTypeId: 'it-clothes',
            pricingType: PricingType.perPiece,
            price: const Money.fromPiastres(2500),
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      // 1. Insert customer and an actual order into SQLite
      await db.into(db.customers).insert(
        app_db.CustomersCompanion.insert(
          id: 'cust-hist-1',
          name: 'عميل تاريخي',
          phone: '01011112222',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await db.into(db.orders).insert(
        app_db.OrdersCompanion.insert(
          id: 'ord-hist',
          orderNumber: '26-00010',
          customerId: 'cust-hist-1',
          expectedPickupDate: now.add(const Duration(days: 2)),
          subtotal: 10000,
          total: 10000,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 2. Insert an actual order_item snapshot into SQLite
      await db.into(db.orderItems).insert(
        app_db.OrderItemsCompanion.insert(
          id: 'oi-hist-1',
          orderId: 'ord-hist',
          itemTypeId: 'it-clothes',
          serviceId: 'srv-master-change',
          itemTypeNameSnapshot: 'ملابس',
          serviceNameSnapshot: 'خدمة تتغير',
          pricingType: 'per_piece',
          quantity: 4.0,
          unitPrice: 2500,
          calculatedTotal: 10000,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 3. Update master service pricing to 5000 piastres
      await serviceRepository.updateService(
        service,
        serviceItemTypes: [
          ServiceItemType(
            id: 'sit-mc-1',
            serviceId: 'srv-master-change',
            itemTypeId: 'it-clothes',
            pricingType: PricingType.perPiece,
            price: const Money.fromPiastres(5000),
            createdAt: now,
            updatedAt: now.add(const Duration(hours: 1)),
          ),
        ],
      );

      // Master data updated in database
      final updatedMaster = await serviceRepository.getServiceItemType(
        'srv-master-change',
        'it-clothes',
      );
      expect(updatedMaster!.price.piastres, equals(5000));

      // 4. Re-query the order_item from SQLite
      final queriedItem = await (db.select(db.orderItems)
            ..where((t) => t.id.equals('oi-hist-1')))
          .getSingle();

      // 5. Verify unit_price, calculated_total, and pricing_type remain unchanged
      expect(queriedItem.unitPrice, equals(2500));
      expect(queriedItem.calculatedTotal, equals(10000));
      expect(queriedItem.pricingType, equals('per_piece'));
    });

    // -------------------------------------------------------------------------
    // 11. fixed_price no longer exists
    // -------------------------------------------------------------------------
    test('11. fixed_price is completely removed and throws ArgumentError on resolution', () {
      expect(PricingType.values, [
        PricingType.perPiece,
        PricingType.perSquareMeter,
      ]);

      expect(() => PricingType.fromValue('fixed_price'), throwsArgumentError);
      expect(() => PricingType.fromValue('fixedPrice'), throwsArgumentError);
    });

    // -------------------------------------------------------------------------
    // 12. Service uniqueness by (service_id, item_type_id)
    // -------------------------------------------------------------------------
    test('12. Database enforces UNIQUE(service_id, item_type_id)', () async {
      final now = DateTime.now();
      await db.into(db.services).insert(
            app_db.ServicesCompanion.insert(
              id: 'srv-unique-test',
              name: 'خدمة فريدة',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await db.into(db.serviceItemTypes).insert(
            app_db.ServiceItemTypesCompanion.insert(
              id: 'sit-u-1',
              serviceId: 'srv-unique-test',
              itemTypeId: 'it-clothes',
              pricingType: 'per_piece',
              price: 2000,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Attempt duplicate pair insert
      expect(
        () async => await db.into(db.serviceItemTypes).insert(
              app_db.ServiceItemTypesCompanion.insert(
                id: 'sit-u-2',
                serviceId: 'srv-unique-test',
                itemTypeId: 'it-clothes', // Same pair!
                pricingType: 'per_piece',
                price: 2500,
                createdAt: now,
                updatedAt: now,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    // -------------------------------------------------------------------------
    // 13. Sync payload contains nested ServiceItemType pricing configurations
    // -------------------------------------------------------------------------
    test('13. SyncPayloadBuilder serializes nested service_item_types and omits root price', () {
      final now = DateTime.utc(2026, 10, 1, 10, 0);
      final service = Service(
        id: 'srv-sync-payload',
        name: 'خدمة تزامن',
        description: 'وصف',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final configs = <ServiceItemType>[
        ServiceItemType(
          id: 'sit-sp-1',
          serviceId: 'srv-sync-payload',
          itemTypeId: 'it-clothes',
          pricingType: PricingType.perPiece,
          price: const Money.fromPiastres(3000),
          createdAt: now,
          updatedAt: now,
        ),
        ServiceItemType(
          id: 'sit-sp-2',
          serviceId: 'srv-sync-payload',
          itemTypeId: 'it-carpet',
          pricingType: PricingType.perSquareMeter,
          price: const Money.fromPiastres(6500),
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final jsonStr = SyncPayloadBuilder.buildServicePayload(service, configs);
      final payload = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(payload['id'], equals('srv-sync-payload'));
      expect(payload['name'], equals('خدمة تزامن'));
      expect(payload.containsKey('price'), isFalse);
      expect(payload.containsKey('pricing_type'), isFalse);

      final sits = payload['service_item_types'] as List;
      expect(sits.length, equals(2));
      expect(sits[0]['pricing_type'], equals('per_piece'));
      expect(sits[0]['price'], equals(3000));
      expect(sits[1]['pricing_type'], equals('per_square_meter'));
      expect(sits[1]['price'], equals(6500));
    });

    // -------------------------------------------------------------------------
    // 14. Remote sync applies the pricing configurations correctly
    // -------------------------------------------------------------------------
    test('14. RemoteChangeApplier ingests nested service_item_types into local database', () async {
      final applier = RemoteChangeApplier(db: db, syncStateDao: syncStateDao);
      final change = SyncChangeDto(
        sequence: 101,
        operationId: 'op-remote-srv-1',
        entityType: 'service',
        entityId: 'srv-remote-1',
        operationType: 'create',
        payload: {
          'id': 'srv-remote-1',
          'name': 'خدمة عن بعد',
          'description': 'خدمة من السيرفر',
          'is_active': true,
          'service_item_types': [
            {
              'id': 'sit-rem-1',
              'item_type_id': 'it-clothes',
              'pricing_type': 'per_piece',
              'price': 4000,
            },
            {
              'id': 'sit-rem-2',
              'item_type_id': 'it-carpet',
              'pricing_type': 'per_square_meter',
              'price': 7500,
            },
          ],
          'created_at': '2026-10-01T10:00:00.000Z',
          'updated_at': '2026-10-01T10:00:00.000Z',
        },
        serverVersion: 1,
        createdAt: DateTime.parse('2026-10-01T10:00:00.000Z'),
      );

      await applier.applyBatch([change]);

      // Verify service row
      final svc = await (db.select(db.services)..where((t) => t.id.equals('srv-remote-1'))).getSingle();
      expect(svc.name, equals('خدمة عن بعد'));

      // Verify service_item_types rows
      final junctionRows = await (db.select(db.serviceItemTypes)..where((t) => t.serviceId.equals('srv-remote-1'))).get();
      expect(junctionRows.length, equals(2));

      final clothesRow = junctionRows.firstWhere((r) => r.itemTypeId == 'it-clothes');
      expect(clothesRow.pricingType, equals('per_piece'));
      expect(clothesRow.price, equals(4000));

      final carpetRow = junctionRows.firstWhere((r) => r.itemTypeId == 'it-carpet');
      expect(carpetRow.pricingType, equals('per_square_meter'));
      expect(carpetRow.price, equals(7500));
    });

    // -------------------------------------------------------------------------
    // 15. Settings UI can configure multiple ItemTypes with different prices
    // -------------------------------------------------------------------------
    test('15. ServicesManagementCubit can configure multiple ItemTypes with distinct prices', () async {
      final cubit = ServicesManagementCubit(
        serviceRepository: serviceRepository,
        itemTypeRepository: itemTypeRepository,
      );

      final configs = [
        ServiceItemTypeConfig(
          itemTypeId: 'it-clothes',
          pricingType: PricingType.perPiece,
          price: const Money.fromPiastres(2500),
        ),
        ServiceItemTypeConfig(
          itemTypeId: 'it-blanket',
          pricingType: PricingType.perPiece,
          price: const Money.fromPiastres(8000),
        ),
        ServiceItemTypeConfig(
          itemTypeId: 'it-carpet',
          pricingType: PricingType.perSquareMeter,
          price: const Money.fromPiastres(6000),
        ),
      ];

      final success = await cubit.createService(
        name: 'خدمة إعدادات متكاملة',
        description: 'تجربة الإعدادات',
        itemTypeConfigs: configs,
      );

      expect(success, isTrue);

      final allServices = await serviceRepository.getAllServices();
      final created = allServices.firstWhere((s) => s.name == 'خدمة إعدادات متكاملة');

      final persistedConfigs = await cubit.getServiceItemTypes(created.id);
      expect(persistedConfigs.length, equals(3));

      final clothesCfg = persistedConfigs.firstWhere((c) => c.itemTypeId == 'it-clothes');
      expect(clothesCfg.price.piastres, equals(2500));
      expect(clothesCfg.pricingType, equals(PricingType.perPiece));

      final carpetCfg = persistedConfigs.firstWhere((c) => c.itemTypeId == 'it-carpet');
      expect(carpetCfg.price.piastres, equals(6000));
      expect(carpetCfg.pricingType, equals(PricingType.perSquareMeter));

      await cubit.close();
    });
  });
}

// -----------------------------------------------------------------------------
// Test Mocks / Fakes
// -----------------------------------------------------------------------------
class _MockCustomerRepo implements CustomerRepository {
  final Customer _customer;
  _MockCustomerRepo(this._customer);

  @override
  Future<Customer?> getCustomerById(String id) async => _customer;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockOrderRepo implements OrderRepository {
  @override
  Future<Order> createOrder({
    required Order order,
    required List<OrderItem> items,
    Payment? initialPayment,
  }) async => order;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockItemDefRepo implements ItemDefinitionRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeItemTypeRepository implements ItemTypeRepository {
  final List<ItemType> _itemTypes;
  _FakeItemTypeRepository(this._itemTypes);

  @override
  Future<List<ItemType>> getActiveItemTypes() async => _itemTypes;

  @override
  Future<List<ItemType>> getAllItemTypes() async => _itemTypes;

  @override
  Future<ItemType?> getItemTypeById(String id) async {
    try {
      return _itemTypes.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
