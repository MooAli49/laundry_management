import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/core/localization/app_strings.dart';
import 'package:laundry_management/domain/entities/item_type.dart';
import 'package:laundry_management/domain/entities/service.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/repositories/item_type_repository.dart';
import 'package:laundry_management/domain/repositories/service_repository.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/features/settings/presentation/cubit/services_management_cubit.dart';

class FakeServiceRepository implements ServiceRepository {
  bool shouldThrow = false;
  final List<Service> services = [];
  final Map<String, List<String>> supportedTypes = {};

  @override
  Future<Service> createService(
    Service service, {
    required List<String> supportedItemTypeIds,
  }) async {
    if (shouldThrow) throw const DatabaseFailure('DB error');
    services.add(service);
    supportedTypes[service.id] = supportedItemTypeIds;
    return service;
  }

  @override
  Future<Service> updateService(
    Service service, {
    List<String>? supportedItemTypeIds,
  }) async {
    if (shouldThrow) throw const DatabaseFailure('DB error');
    final idx = services.indexWhere((s) => s.id == service.id);
    if (idx != -1) {
      services[idx] = service;
    }
    if (supportedItemTypeIds != null) {
      supportedTypes[service.id] = supportedItemTypeIds;
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
  Future<List<Service>> getServicesForItemType(String itemTypeId) async {
    return List.from(services);
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
    return supportedTypes[serviceId] ?? [];
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
  Future<List<ItemType>> getActiveItemTypes() async => itemTypes;

  @override
  Future<List<ItemType>> getAllItemTypes() async => itemTypes;

  @override
  Future<ItemType> createItemType(ItemType itemType) async => itemType;

  @override
  Future<ItemType?> getItemTypeById(String id) async => null;

  @override
  Future<ItemType> updateItemType(ItemType itemType) async => itemType;

  @override
  Future<void> activateItemType(String id) async {}

  @override
  Future<void> deactivateItemType(String id) async {}
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
        pricingType: PricingType.perPiece,
        price: const Money.fromPiastres(1000),
        supportedItemTypeIds: ['t-1'],
      );
      expect(res, isFalse);
      expect(cubit.state.errorMessage, AppStrings.serviceNameRequired);

      // Price zero
      res = await cubit.createService(
        name: 'غسيل',
        pricingType: PricingType.perPiece,
        price: Money.zero,
        supportedItemTypeIds: ['t-1'],
      );
      expect(res, isFalse);
      expect(cubit.state.errorMessage, AppStrings.servicePriceMustBePositive);

      // Empty supported item types
      res = await cubit.createService(
        name: 'غسيل',
        pricingType: PricingType.perPiece,
        price: const Money.fromPiastres(1000),
        supportedItemTypeIds: [],
      );
      expect(res, isFalse);
      expect(cubit.state.errorMessage, AppStrings.selectAtLeastOneItemType);

      // Valid create
      res = await cubit.createService(
        name: 'غسيل ومكواة',
        pricingType: PricingType.perPiece,
        price: const Money.fromPiastres(2500),
        supportedItemTypeIds: ['t-1'],
      );
      expect(res, isTrue);
      expect(cubit.state.services.length, 1);
      expect(cubit.state.services.first.name, 'غسيل ومكواة');
    });

    test('updateService updates existing service', () async {
      await cubit.createService(
        name: 'غسيل',
        pricingType: PricingType.perPiece,
        price: const Money.fromPiastres(2000),
        supportedItemTypeIds: ['t-1'],
      );

      final svc = cubit.state.services.first;
      final res = await cubit.updateService(
        service: svc.copyWith(name: 'غسيل مستعجل'),
        supportedItemTypeIds: ['t-1'],
      );

      expect(res, isTrue);
      expect(cubit.state.services.first.name, 'غسيل مستعجل');
    });

    test(
      'deactivateService and activateService change active status',
      () async {
        await cubit.createService(
          name: 'سرفيس',
          pricingType: PricingType.perPiece,
          price: const Money.fromPiastres(1500),
          supportedItemTypeIds: ['t-1'],
        );

        final id = cubit.state.services.first.id;

        await cubit.deactivateService(id);
        expect(cubit.state.services.first.isActive, isFalse);

        await cubit.activateService(id);
        expect(cubit.state.services.first.isActive, isTrue);
      },
    );
  });
}
