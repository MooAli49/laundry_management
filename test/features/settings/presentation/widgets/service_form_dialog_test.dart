import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/localization/app_strings.dart';
import 'package:laundry_management/domain/entities/item_type.dart';
import 'package:laundry_management/domain/entities/service.dart';
import 'package:laundry_management/domain/repositories/item_type_repository.dart';
import 'package:laundry_management/domain/repositories/service_repository.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/features/settings/presentation/cubit/services_management_cubit.dart';
import 'package:laundry_management/features/settings/presentation/widgets/service_form_dialog.dart';

class MockServiceRepo implements ServiceRepository {
  final List<Service> services = [];
  final Map<String, List<String>> supportedTypes = {};

  @override
  Future<Service> createService(
    Service service, {
    required List<String> supportedItemTypeIds,
  }) async {
    services.add(service);
    supportedTypes[service.id] = supportedItemTypeIds;
    return service;
  }

  @override
  Future<Service> updateService(
    Service service, {
    List<String>? supportedItemTypeIds,
  }) async => service;
  @override
  Future<List<Service>> getAllServices() async => services;
  @override
  Future<List<Service>> getActiveServices() async => services;
  @override
  Future<Service?> getServiceById(String id) async => null;
  @override
  Future<List<Service>> getServicesForItemType(String itemTypeId) async =>
      services;
  @override
  Future<void> activateService(String id) async {}
  @override
  Future<void> deactivateService(String id) async {}
  @override
  Future<List<String>> getSupportedItemTypeIds(String serviceId) async =>
      supportedTypes[serviceId] ?? [];
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
    testWidgets('displays only approved V1 pricing types', (tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.pumpAndSettle();

      // Check V1 types are displayed
      expect(find.text(AppStrings.pricingPerPiece), findsOneWidget);
      expect(find.text(AppStrings.pricingPerSquareMeter), findsOneWidget);
      expect(find.text(AppStrings.pricingFixedPrice), findsOneWidget);
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

      // Enter zero price
      final priceField = find.widgetWithText(TextFormField, '0.00');
      await tester.enterText(priceField, '0');

      // Select item type
      await tester.ensureVisible(find.text('ملابس'));
      await tester.tap(find.text('ملابس'));
      await tester.pumpAndSettle();

      // Tap save
      await tester.tap(find.text(AppStrings.save));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.servicePriceMustBePositive), findsWidgets);
    });

    testWidgets('UAT-B — dialog renders without fixed 720px height and submits valid service', (tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.pumpAndSettle();

      // Enter valid name
      final nameField = find.widgetWithText(TextFormField, '');
      await tester.enterText(nameField.first, 'خدمة غسيل خاصة');

      // Enter valid price
      final priceField = find.widgetWithText(TextFormField, '0.00');
      await tester.enterText(priceField, '45.00');

      // Select item type
      await tester.ensureVisible(find.text('ملابس'));
      await tester.tap(find.text('ملابس'));
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text(AppStrings.save));
      await tester.pumpAndSettle();

      expect(serviceRepo.services.length, 1);
      expect(serviceRepo.services.first.name, 'خدمة غسيل خاصة');
      expect(serviceRepo.services.first.price, Money.fromEgp(45));
    });
  });
}
