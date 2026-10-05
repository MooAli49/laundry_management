import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/core/localization/app_strings.dart';
import 'package:laundry_management/domain/entities/item_type.dart';
import 'package:laundry_management/domain/entities/service.dart';
import 'package:laundry_management/domain/entities/service_item_type.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/models/service_with_pricing.dart';
import 'package:laundry_management/domain/repositories/item_type_repository.dart';
import 'package:laundry_management/domain/repositories/service_repository.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/features/settings/presentation/cubit/services_management_cubit.dart';

class FakeServiceRepository implements ServiceRepository {
  bool shouldThrow = false;
  final List<Service> services = [];
  final Map<String, List<ServiceItemType>> serviceItemTypesMap = {};

  @override
  Future<Service> createService(
    Service service, {
    required List<ServiceItemType> serviceItemTypes,
  }) async {
    if (shouldThrow) throw const DatabaseFailure('DB error');
    services.add(service);
    serviceItemTypesMap[service.id] = serviceItemTypes;
    return service;
  }

  @override
  Future<Service> updateService(
    Service service, {
    List<ServiceItemType>? serviceItemTypes,
  }) async {
    if (shouldThrow) throw const DatabaseFailure('DB error');
    final idx = services.indexWhere((s) => s.id == service.id);
    if (idx != -1) {
      services[idx] = service;
    }
    if (serviceItemTypes != null) {
      serviceItemTypesMap[service.id] = serviceItemTypes;
    }
    return service;
  }

  @override
  Future<List<Service>> getAllServices() async {
    if (shouldThrow) throw const DatabaseFailure('DB error');
    return List.from(services);
  }

  @override
  Future<List<Service>> getActiveServices() async {
    if (shouldThrow) throw const DatabaseFailure('DB error');
    return services.where((s) => s.isActive).toList();
  }

  @override
  Future<Service?> getServiceById(String id) async {
    final matches = services.where((s) => s.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<List<ServiceWithPricing>> getServicesForItemType(String itemTypeId) async {
    final list = <ServiceWithPricing>[];
    for (final s in services) {
      final sits = serviceItemTypesMap[s.id] ?? [];
      for (final sit in sits) {
        if (sit.itemTypeId == itemTypeId) {
          list.add(ServiceWithPricing(service: s, serviceItemType: sit));
        }
      }
    }
    return list;
  }

  @override
  Future<List<ServiceItemType>> getServiceItemTypes(String serviceId) async {
    return serviceItemTypesMap[serviceId] ?? [];
  }

  @override
  Future<ServiceItemType?> getServiceItemType(
    String serviceId,
    String itemTypeId,
  ) async {
    final list = serviceItemTypesMap[serviceId] ?? [];
    for (final sit in list) {
      if (sit.itemTypeId == itemTypeId) return sit;
    }
    return null;
  }

  @override
  Future<void> activateService(String id) async {
    if (shouldThrow) throw const DatabaseFailure('DB error');
    final idx = services.indexWhere((s) => s.id == id);
    if (idx != -1) {
      services[idx] = services[idx].copyWith(isActive: true);
    }
  }

  @override
  Future<void> deactivateService(String id) async {
    if (shouldThrow) throw const DatabaseFailure('DB error');
    final idx = services.indexWhere((s) => s.id == id);
    if (idx != -1) {
      services[idx] = services[idx].copyWith(isActive: false);
    }
  }

  @override
  Future<List<String>> getSupportedItemTypeIds(String serviceId) async {
    return (serviceItemTypesMap[serviceId] ?? []).map((e) => e.itemTypeId).toList();
  }
}

class FakeItemTypeRepository implements ItemTypeRepository {
  final List<ItemType> itemTypes = [
    ItemType(
      id: 't-1',
      name: 'ملابس',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  @override
  Future<List<ItemType>> getActiveItemTypes() async =>
      itemTypes.where((t) => t.isActive).toList();

  @override
  Future<List<ItemType>> getAllItemTypes() async => itemTypes;

  @override
  Future<ItemType> createItemType(ItemType itemType) async {
    itemTypes.add(itemType);
    return itemType;
  }

  @override
  Future<ItemType?> getItemTypeById(String id) async {
    final matches = itemTypes.where((t) => t.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<ItemType> updateItemType(ItemType itemType) async {
    final idx = itemTypes.indexWhere((t) => t.id == itemType.id);
    if (idx != -1) itemTypes[idx] = itemType;
    return itemType;
  }

  @override
  Future<void> activateItemType(String id) async {
    final idx = itemTypes.indexWhere((t) => t.id == id);
    if (idx != -1) itemTypes[idx] = itemTypes[idx].copyWith(isActive: true);
  }

  @override
  Future<void> deactivateItemType(String id) async {
    final idx = itemTypes.indexWhere((t) => t.id == id);
    if (idx != -1) itemTypes[idx] = itemTypes[idx].copyWith(isActive: false);
  }
}

void main() {
  late FakeServiceRepository serviceRepository;
  late FakeItemTypeRepository itemTypeRepository;
  late ServicesManagementCubit cubit;

  setUp(() {
    serviceRepository = FakeServiceRepository();
    itemTypeRepository = FakeItemTypeRepository();
    cubit = ServicesManagementCubit(
      serviceRepository: serviceRepository,
      itemTypeRepository: itemTypeRepository,
    );
  });

  tearDown(() {
    cubit.close();
  });

  group('ServicesManagementCubit Tests', () {
    test('loadServices loads services and item types', () async {
      await cubit.loadServices();
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.itemTypes.length, 1);
      expect(cubit.state.services.isEmpty, isTrue);
    });

    test('createService validates name, price > 0, and item types', () async {
      // Empty name
      var res = await cubit.createService(
        name: '',
        itemTypeConfigs: [
          const ServiceItemTypeConfig(
            itemTypeId: 't-1',
            pricingType: PricingType.perPiece,
            price: Money.fromPiastres(1000),
          ),
        ],
      );
      expect(res, isFalse);
      expect(cubit.state.errorMessage, AppStrings.serviceNameRequired);

      // Price zero
      res = await cubit.createService(
        name: 'غسيل',
        itemTypeConfigs: [
          const ServiceItemTypeConfig(
            itemTypeId: 't-1',
            pricingType: PricingType.perPiece,
            price: Money.zero,
          ),
        ],
      );
      expect(res, isFalse);
      expect(cubit.state.errorMessage, AppStrings.servicePriceMustBePositive);

      // Empty configs
      res = await cubit.createService(
        name: 'غسيل',
        itemTypeConfigs: [],
      );
      expect(res, isFalse);
      expect(cubit.state.errorMessage, AppStrings.selectAtLeastOneItemType);

      // Valid create
      res = await cubit.createService(
        name: 'غسيل ومكواة',
        itemTypeConfigs: [
          const ServiceItemTypeConfig(
            itemTypeId: 't-1',
            pricingType: PricingType.perPiece,
            price: Money.fromPiastres(2500),
          ),
        ],
      );
      expect(res, isTrue);
      expect(cubit.state.services.length, 1);
      expect(cubit.state.services.first.name, 'غسيل ومكواة');
    });

    test('updateService updates existing service', () async {
      await cubit.createService(
        name: 'غسيل',
        itemTypeConfigs: [
          const ServiceItemTypeConfig(
            itemTypeId: 't-1',
            pricingType: PricingType.perPiece,
            price: Money.fromPiastres(2000),
          ),
        ],
      );

      final svc = cubit.state.services.first;
      final res = await cubit.updateService(
        service: svc.copyWith(name: 'غسيل مستعجل'),
        itemTypeConfigs: [
          const ServiceItemTypeConfig(
            itemTypeId: 't-1',
            pricingType: PricingType.perPiece,
            price: Money.fromPiastres(2500),
          ),
        ],
      );

      expect(res, isTrue);
      expect(cubit.state.services.first.name, 'غسيل مستعجل');
    });

    test(
      'deactivateService and activateService change active status',
      () async {
        await cubit.createService(
          name: 'سرفيس',
          itemTypeConfigs: [
            const ServiceItemTypeConfig(
              itemTypeId: 't-1',
              pricingType: PricingType.perPiece,
              price: Money.fromPiastres(1500),
            ),
          ],
        );

        final id = cubit.state.services.first.id;

        await cubit.deactivateService(id);
        expect(cubit.state.services.first.isActive, isFalse);

        await cubit.activateService(id);
        expect(cubit.state.services.first.isActive, isTrue);
      },
    );

    test(
      'MED-01 & LOW-01: preserve inactive item-type pricing mappings and existing ServiceItemType IDs',
      () async {
        // 1. Service has pricing for item types t-1 (active) and t-2 (active)
        final now = DateTime.now();
        itemTypeRepository.itemTypes.add(
          ItemType(
            id: 't-2',
            name: 'سجاد',
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await cubit.createService(
          name: 'غسيل متعدد',
          itemTypeConfigs: [
            const ServiceItemTypeConfig(
              itemTypeId: 't-1',
              pricingType: PricingType.perPiece,
              price: Money.fromPiastres(2000),
            ),
            const ServiceItemTypeConfig(
              itemTypeId: 't-2',
              pricingType: PricingType.perSquareMeter,
              price: Money.fromPiastres(3500),
            ),
          ],
        );

        final initialService = cubit.state.services.first;
        final initialSits = await serviceRepository.getServiceItemTypes(
          initialService.id,
        );
        expect(initialSits.length, 2);
        final sitT1Initial = initialSits.firstWhere((s) => s.itemTypeId == 't-1');
        final sitT2Initial = initialSits.firstWhere((s) => s.itemTypeId == 't-2');

        // 2. Item type t-2 becomes inactive
        await itemTypeRepository.deactivateItemType('t-2');
        final activeItemTypes = await itemTypeRepository.getActiveItemTypes();
        expect(activeItemTypes.map((t) => t.id), contains('t-1'));
        expect(activeItemTypes.map((t) => t.id), isNot(contains('t-2')));

        // 3. Service name / rate for active item type t-1 is edited
        // Notice: The UI form only presents active item types (t-1), so itemTypeConfigs only contains t-1
        final updateRes = await cubit.updateService(
          service: initialService.copyWith(name: 'غسيل متعدد ممتاز'),
          itemTypeConfigs: [
            const ServiceItemTypeConfig(
              itemTypeId: 't-1',
              pricingType: PricingType.perPiece,
              price: Money.fromPiastres(2500), // rate updated from 2000 to 2500
            ),
          ],
        );
        expect(updateRes, isTrue);

        // 4. Verify existing inactive mapping t-2 remains preserved in repository/DB with its original configuration
        final updatedSits = await serviceRepository.getServiceItemTypes(
          initialService.id,
        );
        expect(updatedSits.length, 2);

        final sitT1Updated = updatedSits.firstWhere((s) => s.itemTypeId == 't-1');
        final sitT2Preserved = updatedSits.firstWhere((s) => s.itemTypeId == 't-2');

        // LOW-01: verify t-1 preserved its original ID instead of generating a new UUID
        expect(sitT1Updated.id, equals(sitT1Initial.id));
        expect(sitT1Updated.price.piastres, equals(2500));

        // MED-01: verify t-2 inactive mapping was not silently deleted
        expect(sitT2Preserved.id, equals(sitT2Initial.id));
        expect(sitT2Preserved.price.piastres, equals(3500));
        expect(sitT2Preserved.pricingType, equals(PricingType.perSquareMeter));

        // 5. Reactivating item type t-2 restores its previous configuration
        await itemTypeRepository.activateItemType('t-2');
        final servicesForT2 = await serviceRepository.getServicesForItemType('t-2');
        expect(servicesForT2.length, 1);
        expect(servicesForT2.first.service.id, equals(initialService.id));
        expect(servicesForT2.first.serviceItemType.price.piastres, equals(3500));
        expect(
          servicesForT2.first.serviceItemType.pricingType,
          equals(PricingType.perSquareMeter),
        );
      },
    );
  });
}
