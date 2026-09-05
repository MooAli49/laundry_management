import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/application/use_cases/store_order_items_use_case.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/entities/storage_location.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/repositories/order_repository.dart';
import 'package:laundry_management/domain/repositories/storage_location_repository.dart';
import 'package:laundry_management/domain/repositories/storage_repository.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';

class FakeOrderRepository implements OrderRepository {
  final Map<String, Order> orders = {};
  final Map<String, List<OrderItem>> orderItems = {};
  bool markReadyCalled = false;

  @override
  Future<Order?> getOrderById(String id) async => orders[id];

  @override
  Future<List<OrderItem>> getOrderItems(String orderId) async => orderItems[orderId] ?? [];

  @override
  Future<Order> markOrderReady(String orderId) async {
    markReadyCalled = true;
    final existing = orders[orderId]!;
    final updated = existing.copyWith(status: OrderStatus.ready);
    orders[orderId] = updated;
    return updated;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStorageRepository implements StorageRepository {
  final List<String> storedItemIds = [];
  bool allStored = false;

  @override
  Future<void> bulkStoreItems({
    required List<String> orderItemIds,
    required String storageLocationId,
  }) async {
    storedItemIds.addAll(orderItemIds);
  }

  @override
  Future<bool> areAllOrderItemsStored(String orderId) async => allStored;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStorageLocationRepository implements StorageLocationRepository {
  final Map<String, StorageLocation> locations = {};
  final Map<String, List<StorageLocation>> compatibleByItemType = {};

  @override
  Future<StorageLocation?> getStorageLocationById(String id) async => locations[id];

  @override
  Future<List<StorageLocation>> getCompatibleLocationsForItemType(String itemTypeId) async =>
      compatibleByItemType[itemTypeId] ?? [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeOrderRepository orderRepo;
  late FakeStorageRepository storageRepo;
  late FakeStorageLocationRepository locationRepo;
  late StoreOrderItemsUseCase useCase;

  final now = DateTime.now();

  setUp(() {
    orderRepo = FakeOrderRepository();
    storageRepo = FakeStorageRepository();
    locationRepo = FakeStorageLocationRepository();

    useCase = StoreOrderItemsUseCase(
      orderRepository: orderRepo,
      storageRepository: storageRepo,
      storageLocationRepository: locationRepo,
    );

    orderRepo.orders['ord-1'] = Order(
      id: 'ord-1',
      orderNumber: '26-001',
      customerId: 'cust-1',
      status: OrderStatus.processing,
      expectedPickupDate: OrderDate.today(),
      subtotal: const Money.fromPiastres(3000),
      total: const Money.fromPiastres(3000),
      createdAt: now,
      updatedAt: now,
    );

    orderRepo.orderItems['ord-1'] = [
      OrderItem(
        id: 'item-1',
        orderId: 'ord-1',
        itemTypeId: 'type-clothes',
        serviceId: 'srv-1',
        itemTypeNameSnapshot: 'ملابس',
        serviceNameSnapshot: 'غسيل',
        pricingType: PricingType.perPiece,
        quantity: 1.0,
        unitPrice: const Money.fromPiastres(1500),
        calculatedTotal: const Money.fromPiastres(1500),
        createdAt: now,
        updatedAt: now,
      ),
      OrderItem(
        id: 'item-2',
        orderId: 'ord-1',
        itemTypeId: 'type-clothes',
        serviceId: 'srv-1',
        itemTypeNameSnapshot: 'ملابس',
        serviceNameSnapshot: 'غسيل',
        pricingType: PricingType.perPiece,
        quantity: 1.0,
        unitPrice: const Money.fromPiastres(1500),
        calculatedTotal: const Money.fromPiastres(1500),
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final activeLocation = StorageLocation(
      id: 'loc-active',
      name: 'رف أ1',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    locationRepo.locations['loc-active'] = activeLocation;
    locationRepo.compatibleByItemType['type-clothes'] = [activeLocation];

    final inactiveLocation = StorageLocation(
      id: 'loc-inactive',
      name: 'رف معطل',
      isActive: false,
      createdAt: now,
      updatedAt: now,
    );
    locationRepo.locations['loc-inactive'] = inactiveLocation;
    locationRepo.compatibleByItemType['type-clothes']?.add(inactiveLocation);

    final incompatibleLocation = StorageLocation(
      id: 'loc-carpet-only',
      name: 'مخزن سجاد فقط',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    locationRepo.locations['loc-carpet-only'] = incompatibleLocation;
    locationRepo.compatibleByItemType['type-carpet'] = [incompatibleLocation];
  });

  group('StoreOrderItemsUseCase', () {
    test('rejects empty item list', () async {
      expect(
        () => useCase.execute(
          const StoreOrderItemsInput(
            orderId: 'ord-1',
            orderItemIds: [],
            storageLocationId: 'loc-active',
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects duplicate order item IDs', () async {
      expect(
        () => useCase.execute(
          const StoreOrderItemsInput(
            orderId: 'ord-1',
            orderItemIds: ['item-1', 'item-1'],
            storageLocationId: 'loc-active',
          ),
        ),
        throwsA(
          isA<ValidationFailure>().having(
            (e) => e.message,
            'message',
            contains('Duplicate item IDs'),
          ),
        ),
      );
      expect(storageRepo.storedItemIds, isEmpty);
    });

    test('rejects non-existent order', () async {
      expect(
        () => useCase.execute(
          const StoreOrderItemsInput(
            orderId: 'non-existent',
            orderItemIds: ['item-1'],
            storageLocationId: 'loc-active',
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects order not in Processing status', () async {
      orderRepo.orders['ord-ready'] = Order(
        id: 'ord-ready',
        orderNumber: '26-002',
        customerId: 'cust-1',
        status: OrderStatus.ready,
        expectedPickupDate: OrderDate.today(),
        subtotal: const Money.fromPiastres(1000),
        total: const Money.fromPiastres(1000),
        createdAt: now,
        updatedAt: now,
      );

      expect(
        () => useCase.execute(
          const StoreOrderItemsInput(
            orderId: 'ord-ready',
            orderItemIds: ['item-1'],
            storageLocationId: 'loc-active',
          ),
        ),
        throwsA(isA<BusinessRuleFailure>()),
      );
    });

    test('rejects inactive storage location', () async {
      expect(
        () => useCase.execute(
          const StoreOrderItemsInput(
            orderId: 'ord-1',
            orderItemIds: ['item-1'],
            storageLocationId: 'loc-inactive',
          ),
        ),
        throwsA(isA<BusinessRuleFailure>()),
      );
    });

    test('rejects items not belonging to the order', () async {
      expect(
        () => useCase.execute(
          const StoreOrderItemsInput(
            orderId: 'ord-1',
            orderItemIds: ['item-stranger'],
            storageLocationId: 'loc-active',
          ),
        ),
        throwsA(isA<BusinessRuleFailure>()),
      );
    });

    test('rejects storage location incompatible with item type', () async {
      expect(
        () => useCase.execute(
          const StoreOrderItemsInput(
            orderId: 'ord-1',
            orderItemIds: ['item-1'],
            storageLocationId: 'loc-carpet-only',
          ),
        ),
        throwsA(isA<IncompatibleStorageLocationFailure>()),
      );
    });

    test('LOCKED RULE: partial storage leaves order in Processing', () async {
      storageRepo.allStored = false; // Only 1 of 2 stored

      final result = await useCase.execute(
        const StoreOrderItemsInput(
          orderId: 'ord-1',
          orderItemIds: ['item-1'],
          storageLocationId: 'loc-active',
        ),
      );

      expect(result.allStored, false);
      expect(result.order.status, OrderStatus.processing);
      expect(orderRepo.markReadyCalled, false);
      expect(storageRepo.storedItemIds, contains('item-1'));
    });

    test('LOCKED RULE: all items stored automatically transitions order to Ready', () async {
      storageRepo.allStored = true; // All 2 items stored

      final result = await useCase.execute(
        const StoreOrderItemsInput(
          orderId: 'ord-1',
          orderItemIds: ['item-1', 'item-2'],
          storageLocationId: 'loc-active',
        ),
      );

      expect(result.allStored, true);
      expect(result.order.status, OrderStatus.ready);
      expect(orderRepo.markReadyCalled, true);
      expect(storageRepo.storedItemIds, containsAll(['item-1', 'item-2']));
    });
  });
}
