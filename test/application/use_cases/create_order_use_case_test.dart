import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/application/use_cases/create_order_use_case.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/domain/entities/item_definition.dart';
import 'package:laundry_management/domain/entities/item_type.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/entities/service.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/repositories/customer_repository.dart';
import 'package:laundry_management/domain/repositories/item_definition_repository.dart';
import 'package:laundry_management/domain/repositories/item_type_repository.dart';
import 'package:laundry_management/domain/repositories/order_repository.dart';
import 'package:laundry_management/domain/repositories/service_repository.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';

class FakeOrderRepository implements OrderRepository {
  Order? lastCreatedOrder;
  List<OrderItem>? lastCreatedItems;

  @override
  Future<Order> createOrder({required Order order, required List<OrderItem> items}) async {
    lastCreatedOrder = order.copyWith(orderNumber: '26-001');
    lastCreatedItems = items;
    return lastCreatedOrder!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCustomerRepository implements CustomerRepository {
  final Map<String, Customer> customers = {};

  @override
  Future<Customer?> getCustomerById(String id) async => customers[id];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeServiceRepository implements ServiceRepository {
  final Map<String, Service> services = {};
  final Map<String, List<Service>> servicesByItemType = {};

  @override
  Future<Service?> getServiceById(String id) async => services[id];

  @override
  Future<List<Service>> getServicesForItemType(String itemTypeId) async =>
      servicesByItemType[itemTypeId] ?? [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeItemTypeRepository implements ItemTypeRepository {
  final Map<String, ItemType> itemTypes = {};

  @override
  Future<ItemType?> getItemTypeById(String id) async => itemTypes[id];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeItemDefinitionRepository implements ItemDefinitionRepository {
  final Map<String, ItemDefinition> itemDefinitions = {};

  @override
  Future<ItemDefinition?> getItemDefinitionById(String id) async => itemDefinitions[id];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeOrderRepository orderRepo;
  late FakeCustomerRepository customerRepo;
  late FakeServiceRepository serviceRepo;
  late FakeItemTypeRepository itemTypeRepo;
  late FakeItemDefinitionRepository itemDefRepo;
  late CreateOrderUseCase useCase;

  final now = DateTime.now();

  setUp(() {
    orderRepo = FakeOrderRepository();
    customerRepo = FakeCustomerRepository();
    serviceRepo = FakeServiceRepository();
    itemTypeRepo = FakeItemTypeRepository();
    itemDefRepo = FakeItemDefinitionRepository();

    useCase = CreateOrderUseCase(
      orderRepository: orderRepo,
      customerRepository: customerRepo,
      serviceRepository: serviceRepo,
      itemTypeRepository: itemTypeRepo,
      itemDefinitionRepository: itemDefRepo,
    );

    customerRepo.customers['cust-1'] = Customer(
      id: 'cust-1',
      name: 'أحمد علي',
      phone: '01012345678',
      createdAt: now,
      updatedAt: now,
    );

    itemTypeRepo.itemTypes['type-clothes'] = ItemType(
      id: 'type-clothes',
      name: 'ملابس',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    itemTypeRepo.itemTypes['type-carpet'] = ItemType(
      id: 'type-carpet',
      name: 'سجاد',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    itemTypeRepo.itemTypes['type-inactive'] = ItemType(
      id: 'type-inactive',
      name: 'نوع ملغي',
      isActive: false,
      createdAt: now,
      updatedAt: now,
    );

    itemDefRepo.itemDefinitions['def-shirt'] = ItemDefinition(
      id: 'def-shirt',
      itemTypeId: 'type-clothes',
      name: 'قميص رجالي',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    itemDefRepo.itemDefinitions['def-inactive'] = ItemDefinition(
      id: 'def-inactive',
      itemTypeId: 'type-clothes',
      name: 'قميص ملغي',
      isActive: false,
      createdAt: now,
      updatedAt: now,
    );

    final washIronService = Service(
      id: 'srv-wash-iron',
      name: 'غسيل ومكواة',
      pricingType: PricingType.perPiece,
      price: const Money.fromPiastres(1500), // 15 EGP
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    serviceRepo.services['srv-wash-iron'] = washIronService;

    final fixedService = Service(
      id: 'srv-fixed',
      name: 'خدمة بسعر ثابت',
      pricingType: PricingType.fixedPrice,
      price: const Money.fromPiastres(2500),
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    serviceRepo.services['srv-fixed'] = fixedService;
    serviceRepo.servicesByItemType['type-clothes'] = [washIronService, fixedService];

    final carpetService = Service(
      id: 'srv-carpet',
      name: 'غسيل سجاد',
      pricingType: PricingType.perSquareMeter,
      price: const Money.fromPiastres(3000), // 30 EGP / m2
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    serviceRepo.services['srv-carpet'] = carpetService;
    serviceRepo.servicesByItemType['type-carpet'] = [carpetService];

    final inactiveService = Service(
      id: 'srv-inactive',
      name: 'خدمة ملغاة',
      pricingType: PricingType.perPiece,
      price: const Money.fromPiastres(1000),
      isActive: false,
      createdAt: now,
      updatedAt: now,
    );
    serviceRepo.services['srv-inactive'] = inactiveService;

    final perKgService = Service(
      id: 'srv-kg',
      name: 'خدمة بالكيلو',
      pricingType: PricingType.perKilogram,
      price: const Money.fromPiastres(2000),
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    serviceRepo.services['srv-kg'] = perKgService;
    serviceRepo.servicesByItemType['type-clothes']?.add(perKgService);
  });

  group('CreateOrderUseCase', () {
    test('rejects empty items list', () async {
      expect(
        () => useCase.execute(
          CreateOrderInput(
            customerId: 'cust-1',
            expectedPickupDate: OrderDate.today(),
            items: [],
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects expected pickup date in the past', () async {
      expect(
        () => useCase.execute(
          CreateOrderInput(
            customerId: 'cust-1',
            expectedPickupDate: OrderDate(2020, 1, 1),
            items: [
              const CreateOrderItemInput(
                itemTypeId: 'type-clothes',
                serviceId: 'srv-wash-iron',
                physicalQuantity: 1,
              ),
            ],
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects missing customer', () async {
      expect(
        () => useCase.execute(
          CreateOrderInput(
            customerId: 'non-existent',
            expectedPickupDate: OrderDate.today(),
            items: [
              const CreateOrderItemInput(
                itemTypeId: 'type-clothes',
                serviceId: 'srv-wash-iron',
                physicalQuantity: 1,
              ),
            ],
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects negative delivery or pickup fees', () async {
      expect(
        () => useCase.execute(
          CreateOrderInput(
            customerId: 'cust-1',
            expectedPickupDate: OrderDate.today(),
            customerPickupRequested: true,
            customerPickupFee: const Money.fromPiastres(-100),
            items: [
              const CreateOrderItemInput(
                itemTypeId: 'type-clothes',
                serviceId: 'srv-wash-iron',
                physicalQuantity: 1,
              ),
            ],
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects pickup fee > 0 when pickup requested is false', () async {
      expect(
        () => useCase.execute(
          CreateOrderInput(
            customerId: 'cust-1',
            expectedPickupDate: OrderDate.today(),
            customerPickupRequested: false,
            customerPickupFee: const Money.fromPiastres(500),
            items: [
              const CreateOrderItemInput(
                itemTypeId: 'type-clothes',
                serviceId: 'srv-wash-iron',
                physicalQuantity: 1,
              ),
            ],
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects delivery fee > 0 when delivery requested is false', () async {
      expect(
        () => useCase.execute(
          CreateOrderInput(
            customerId: 'cust-1',
            expectedPickupDate: OrderDate.today(),
            customerDeliveryRequested: false,
            customerDeliveryFee: const Money.fromPiastres(500),
            items: [
              const CreateOrderItemInput(
                itemTypeId: 'type-clothes',
                serviceId: 'srv-wash-iron',
                physicalQuantity: 1,
              ),
            ],
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects inactive ItemType', () async {
      expect(
        () => useCase.execute(
          CreateOrderInput(
            customerId: 'cust-1',
            expectedPickupDate: OrderDate.today(),
            items: [
              const CreateOrderItemInput(
                itemTypeId: 'type-inactive',
                serviceId: 'srv-wash-iron',
                physicalQuantity: 1,
              ),
            ],
          ),
        ),
        throwsA(isA<BusinessRuleFailure>()),
      );
    });

    test('rejects inactive ItemDefinition', () async {
      expect(
        () => useCase.execute(
          CreateOrderInput(
            customerId: 'cust-1',
            expectedPickupDate: OrderDate.today(),
            items: [
              const CreateOrderItemInput(
                itemTypeId: 'type-clothes',
                itemDefinitionId: 'def-inactive',
                serviceId: 'srv-wash-iron',
                physicalQuantity: 1,
              ),
            ],
          ),
        ),
        throwsA(isA<BusinessRuleFailure>()),
      );
    });

    test('rejects inactive Service', () async {
      expect(
        () => useCase.execute(
          CreateOrderInput(
            customerId: 'cust-1',
            expectedPickupDate: OrderDate.today(),
            items: [
              const CreateOrderItemInput(
                itemTypeId: 'type-clothes',
                serviceId: 'srv-inactive',
                physicalQuantity: 1,
              ),
            ],
          ),
        ),
        throwsA(isA<BusinessRuleFailure>()),
      );
    });

    test('rejects incompatible Service for ItemType', () async {
      expect(
        () => useCase.execute(
          CreateOrderInput(
            customerId: 'cust-1',
            expectedPickupDate: OrderDate.today(),
            items: [
              const CreateOrderItemInput(
                itemTypeId: 'type-clothes',
                serviceId: 'srv-carpet', // Carpet service for clothes
                physicalQuantity: 1,
              ),
            ],
          ),
        ),
        throwsA(isA<IncompatibleServiceFailure>()),
      );
    });

    test('LOCKED RULE: rejects PerKilogram pricing in V1', () async {
      expect(
        () => useCase.execute(
          CreateOrderInput(
            customerId: 'cust-1',
            expectedPickupDate: OrderDate.today(),
            items: [
              const CreateOrderItemInput(
                itemTypeId: 'type-clothes',
                serviceId: 'srv-kg',
                physicalQuantity: 1,
              ),
            ],
          ),
        ),
        throwsA(isA<BusinessRuleFailure>()),
      );
    });

    test('LOCKED RULE: strictly rejects zero price and negative price', () async {
      // Zero custom price
      expect(
        () => useCase.execute(
          CreateOrderInput(
            customerId: 'cust-1',
            expectedPickupDate: OrderDate.today(),
            items: [
              const CreateOrderItemInput(
                itemTypeId: 'type-clothes',
                serviceId: 'srv-wash-iron',
                customUnitPrice: Money.zero,
                physicalQuantity: 1,
              ),
            ],
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );

      // Negative custom price
      expect(
        () => useCase.execute(
          CreateOrderInput(
            customerId: 'cust-1',
            expectedPickupDate: OrderDate.today(),
            items: [
              const CreateOrderItemInput(
                itemTypeId: 'type-clothes',
                serviceId: 'srv-wash-iron',
                customUnitPrice: Money.fromPiastres(-500),
                physicalQuantity: 1,
              ),
            ],
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('expands physical quantity N into N distinct OrderItems with unique IDs', () async {
      final result = await useCase.execute(
        CreateOrderInput(
          customerId: 'cust-1',
          expectedPickupDate: OrderDate.today(),
          items: [
            const CreateOrderItemInput(
              itemTypeId: 'type-clothes',
              itemDefinitionId: 'def-shirt',
              serviceId: 'srv-wash-iron',
              physicalQuantity: 3,
            ),
          ],
        ),
      );

      expect(result.status, OrderStatus.processing);
      expect(orderRepo.lastCreatedItems, isNotNull);
      expect(orderRepo.lastCreatedItems!.length, 3);

      final itemIds = orderRepo.lastCreatedItems!.map((i) => i.id).toSet();
      expect(itemIds.length, 3, reason: 'Every physical item must have a unique UUID');

      for (final item in orderRepo.lastCreatedItems!) {
        expect(item.quantity, 1.0);
        expect(item.unitPrice, const Money.fromPiastres(1500));
        expect(item.calculatedTotal, const Money.fromPiastres(1500));
        expect(item.itemTypeNameSnapshot, 'ملابس');
        expect(item.itemDefinitionNameSnapshot, 'قميص رجالي');
        expect(item.serviceNameSnapshot, 'غسيل ومكواة');
      }

      // 3 items * 1500 = 4500 piastres (45 EGP)
      expect(result.subtotal, const Money.fromPiastres(4500));
      expect(result.total, const Money.fromPiastres(4500));
    });

    test('supports custom price override', () async {
      final result = await useCase.execute(
        CreateOrderInput(
          customerId: 'cust-1',
          expectedPickupDate: OrderDate.today(),
          items: [
            const CreateOrderItemInput(
              itemTypeId: 'type-clothes',
              serviceId: 'srv-wash-iron',
              customUnitPrice: Money.fromPiastres(2000), // Override 15 EGP -> 20 EGP
              physicalQuantity: 1,
            ),
          ],
        ),
      );

      expect(result.subtotal, const Money.fromPiastres(2000));
      expect(orderRepo.lastCreatedItems!.first.unitPrice, const Money.fromPiastres(2000));
      expect(orderRepo.lastCreatedItems!.first.calculatedTotal, const Money.fromPiastres(2000));
    });

    test('calculates carpet per-square-meter area and total accurately', () async {
      final result = await useCase.execute(
        CreateOrderInput(
          customerId: 'cust-1',
          expectedPickupDate: OrderDate.today(),
          items: [
            const CreateOrderItemInput(
              itemTypeId: 'type-carpet',
              serviceId: 'srv-carpet',
              physicalQuantity: 1,
              carpetData: CarpetItemInput(
                length: 3.0,
                width: 2.0,
              ),
            ),
          ],
        ),
      );

      expect(orderRepo.lastCreatedItems!.length, 1);
      final carpetItem = orderRepo.lastCreatedItems!.first;
      expect(carpetItem.carpetData, isNotNull);
      expect(carpetItem.carpetData!.area, 6.0); // 3 * 2 = 6 m2
      // 3000 piastres/m2 * 6 m2 = 18000 piastres (180 EGP)
      expect(carpetItem.calculatedTotal, const Money.fromPiastres(18000));
      expect(result.subtotal, const Money.fromPiastres(18000));
      expect(result.total, const Money.fromPiastres(18000));
    });

    test('rejects carpetData for perPiece pricing', () async {
      expect(
        () => useCase.execute(
          CreateOrderInput(
            customerId: 'cust-1',
            expectedPickupDate: OrderDate.today(),
            items: [
              const CreateOrderItemInput(
                itemTypeId: 'type-clothes',
                serviceId: 'srv-wash-iron',
                physicalQuantity: 1,
                carpetData: CarpetItemInput(
                  length: 2.0,
                  width: 3.0,
                ),
              ),
            ],
          ),
        ),
        throwsA(
          isA<ValidationFailure>().having(
            (e) => e.message,
            'message',
            contains('Carpet data is not allowed'),
          ),
        ),
      );
    });

    test('rejects carpetData for fixedPrice pricing', () async {
      expect(
        () => useCase.execute(
          CreateOrderInput(
            customerId: 'cust-1',
            expectedPickupDate: OrderDate.today(),
            items: [
              const CreateOrderItemInput(
                itemTypeId: 'type-clothes',
                serviceId: 'srv-fixed',
                physicalQuantity: 1,
                carpetData: CarpetItemInput(
                  length: 2.0,
                  width: 3.0,
                ),
              ),
            ],
          ),
        ),
        throwsA(
          isA<ValidationFailure>().having(
            (e) => e.message,
            'message',
            contains('Carpet data is not allowed'),
          ),
        ),
      );
    });

    test('rejects perSquareMeter pricing without carpetData', () async {
      expect(
        () => useCase.execute(
          CreateOrderInput(
            customerId: 'cust-1',
            expectedPickupDate: OrderDate.today(),
            items: [
              const CreateOrderItemInput(
                itemTypeId: 'type-carpet',
                serviceId: 'srv-carpet',
                physicalQuantity: 1,
                carpetData: null,
              ),
            ],
          ),
        ),
        throwsA(
          isA<ValidationFailure>().having(
            (e) => e.message,
            'message',
            contains('Carpet data is required'),
          ),
        ),
      );
    });

    test('enforces complete order total formula with discount and delivery fees', () async {
      final result = await useCase.execute(
        CreateOrderInput(
          customerId: 'cust-1',
          expectedPickupDate: OrderDate.today(),
          customerPickupRequested: true,
          customerPickupFee: const Money.fromPiastres(2000), // 20 EGP
          customerDeliveryRequested: true,
          customerDeliveryFee: const Money.fromPiastres(2500), // 25 EGP
          discount: const Money.fromPiastres(1000), // 10 EGP discount
          items: [
            const CreateOrderItemInput(
              itemTypeId: 'type-clothes',
              serviceId: 'srv-wash-iron',
              physicalQuantity: 2, // 2 * 1500 = 3000 piastres
            ),
          ],
        ),
      );

      // Subtotal = 3000
      // Discount = 1000
      // PickupFee = 2000
      // DeliveryFee = 2500
      // Tax = 0
      // Total = 3000 - 1000 + 2000 + 2500 = 6500 piastres (65 EGP)
      expect(result.subtotal, const Money.fromPiastres(3000));
      expect(result.discount, const Money.fromPiastres(1000));
      expect(result.customerPickupFee, const Money.fromPiastres(2000));
      expect(result.customerDeliveryFee, const Money.fromPiastres(2500));
      expect(result.tax, Money.zero);
      expect(result.total, const Money.fromPiastres(6500));
    });

    test('rejects discount exceeding subtotal', () async {
      expect(
        () => useCase.execute(
          CreateOrderInput(
            customerId: 'cust-1',
            expectedPickupDate: OrderDate.today(),
            discount: const Money.fromPiastres(5000), // Exceeds 1500
            items: [
              const CreateOrderItemInput(
                itemTypeId: 'type-clothes',
                serviceId: 'srv-wash-iron',
                physicalQuantity: 1, // 1500
              ),
            ],
          ),
        ),
        throwsA(isA<BusinessRuleFailure>()),
      );
    });
  });
}
