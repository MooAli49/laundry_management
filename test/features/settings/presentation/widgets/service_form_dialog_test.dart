import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:laundry_management/features/settings/presentation/widgets/service_form_dialog.dart';

class MockServiceRepo implements ServiceRepository {
  final List<Service> services = [];
  final Map<String, List<ServiceItemType>> serviceItemTypesMap = {};

  @override
  Future<Service> createService(
    Service service, {
    required List<ServiceItemType> serviceItemTypes,
  }) async {
    services.add(service);
    serviceItemTypesMap[service.id] = serviceItemTypes;
    return service;
  }

  @override
  Future<Service> updateService(
    Service service, {
    List<ServiceItemType>? serviceItemTypes,
  }) async {
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
  Future<List<Service>> getAllServices() async => services;
  @override
  Future<List<Service>> getActiveServices() async => services;
  @override
  Future<Service?> getServiceById(String id) async => null;

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
  Future<void> activateService(String id) async {}
  @override
  Future<void> deactivateService(String id) async {}
  @override
  Future<List<String>> getSupportedItemTypeIds(String serviceId) async =>
      (serviceItemTypesMap[serviceId] ?? []).map((e) => e.itemTypeId).toList();
}

class MockItemTypeRepo implements ItemTypeRepository {
  final List<ItemType> types = [
    ItemType(
      id: 't-1',
      name: 'ملابس',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  @override
  Future<List<ItemType>> getActiveItemTypes() async => types;
  @override
  Future<List<ItemType>> getAllItemTypes() async => types;
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
  late MockServiceRepo serviceRepo;
  late MockItemTypeRepo itemTypeRepo;
  late ServicesManagementCubit cubit;

  setUp(() {
    serviceRepo = MockServiceRepo();
    itemTypeRepo = MockItemTypeRepo();
    cubit = ServicesManagementCubit(
      serviceRepository: serviceRepo,
      itemTypeRepository: itemTypeRepo,
    );
  });

  tearDown(() {
    cubit.close();
  });

  Widget buildDialog() {
    return MaterialApp(
      locale: const Locale('ar'),
      home: Scaffold(
        body: BlocProvider.value(
          value: cubit,
          child: ServiceFormDialog(availableItemTypes: itemTypeRepo.types),
        ),
      ),
    );
  }

  group('ServiceFormDialog Widget Tests', () {
    testWidgets('displays only approved V1 pricing types in item type configuration', (tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.pumpAndSettle();

      // Enable the item type
      await tester.tap(find.text('ملابس'));
      await tester.pumpAndSettle();

      // Check V1 types are displayed
      expect(find.text(AppStrings.pricingPerPiece), findsOneWidget);

      // Open pricing type dropdown
      await tester.tap(find.text(AppStrings.pricingPerPiece));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.pricingPerSquareMeter), findsWidgets);
    });

    testWidgets('rejects empty name on submit', (tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.pumpAndSettle();

      // Tap save without entering name
      await tester.tap(find.text(AppStrings.save));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.serviceNameRequired), findsOneWidget);
    });

    testWidgets('rejects zero or non-positive price on submit', (tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.pumpAndSettle();

      // Enter name
      final nameField = find.widgetWithText(TextFormField, '');
      await tester.enterText(nameField.first, 'خدمة تجريبية');

      // Select item type
      await tester.tap(find.text('ملابس'));
      await tester.pumpAndSettle();

      // Price defaults to 0.00 or empty, enter zero
      final priceField = find.widgetWithText(TextFormField, '0.00');
      if (priceField.evaluate().isNotEmpty) {
        await tester.enterText(priceField.first, '0');
      }

      // Tap save
      await tester.tap(find.text(AppStrings.save));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.servicePriceMustBePositive), findsWidgets);
    });

    testWidgets(
      'submits valid service with configured item type pricing',
      (tester) async {
        await tester.pumpWidget(buildDialog());
        await tester.pumpAndSettle();

        // Enter valid name
        final nameField = find.widgetWithText(TextFormField, '');
        await tester.enterText(nameField.first, 'خدمة غسيل خاصة');

        // Select item type
        await tester.tap(find.text('ملابس'));
        await tester.pumpAndSettle();

        // Enter valid price
        final priceField = find.widgetWithText(TextFormField, '0.00');
        await tester.enterText(priceField.first, '45.00');

        // Submit
        await tester.tap(find.text(AppStrings.save));
        await tester.pumpAndSettle();

        expect(serviceRepo.services.length, 1);
        expect(serviceRepo.services.first.name, 'خدمة غسيل خاصة');
        final sits = serviceRepo.serviceItemTypesMap[serviceRepo.services.first.id]!;
        expect(sits.length, 1);
        expect(sits.first.price, Money.fromEgp(45));
        expect(sits.first.pricingType, PricingType.perPiece);
      },
    );
  });
}
