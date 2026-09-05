import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/application/use_cases/move_stored_item_use_case.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/entities/storage_location.dart';
import 'package:laundry_management/domain/entities/storage_record.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/repositories/order_repository.dart';
import 'package:laundry_management/domain/repositories/storage_location_repository.dart';
import 'package:laundry_management/domain/repositories/storage_repository.dart';
import 'package:laundry_management/domain/value_objects/money.dart';

class FakeOrderRepository implements OrderRepository {
  final Map<String, OrderItem> orderItems = {};

  @override
  Future<OrderItem?> getOrderItemById(String id) async => orderItems[id];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStorageRepository implements StorageRepository {
  final Map<String, StorageRecord> activeRecords = {};
  bool moveItemCalled = false;

  @override
  Future<StorageRecord?> getActiveRecordForOrderItem(String orderItemId) async =>
      activeRecords[orderItemId];

  @override
  Future<StorageRecord> moveItem({
    required String orderItemId,
    required String newStorageLocationId,
  }) async {
    moveItemCalled = true;
    final now = DateTime.now();
    final newRecord = StorageRecord(
      id: 'rec-new',
      orderItemId: orderItemId,
      storageLocationId: newStorageLocationId,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    activeRecords[orderItemId] = newRecord;
    return newRecord;
  }

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
  late MoveStoredItemUseCase useCase;

  final now = DateTime.now();

  setUp(() {
    orderRepo = FakeOrderRepository();
    storageRepo = FakeStorageRepository();
    locationRepo = FakeStorageLocationRepository();

    useCase = MoveStoredItemUseCase(
      orderRepository: orderRepo,
      storageRepository: storageRepo,
      storageLocationRepository: locationRepo,
    );

    // Existing stored item
    orderRepo.orderItems['item-1'] = OrderItem(
      id: 'item-1',
      orderId: 'ord-1',
      itemTypeId: 'type-clothes',
      serviceId: 'srv-1',
      itemTypeNameSnapshot: 'ملابس',
      serviceNameSnapshot: 'غسيل',
      pricingType: PricingType.perPiece,
      quantity: 1.0,
      unitPrice: const Money.fromPiastres(1000),
      calculatedTotal: const Money.fromPiastres(1000),
      createdAt: now,
      updatedAt: now,
    );

    // Existing unstored item
    orderRepo.orderItems['item-unstored'] = OrderItem(
      id: 'item-unstored',
      orderId: 'ord-1',
      itemTypeId: 'type-clothes',
      serviceId: 'srv-1',
      itemTypeNameSnapshot: 'ملابس',
      serviceNameSnapshot: 'غسيل',
      pricingType: PricingType.perPiece,
      quantity: 1.0,
      unitPrice: const Money.fromPiastres(1000),
      calculatedTotal: const Money.fromPiastres(1000),
      createdAt: now,
      updatedAt: now,
    );

    final loc1 = StorageLocation(
      id: 'loc-1',
      name: 'رف 1',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    locationRepo.locations['loc-1'] = loc1;

    final loc2 = StorageLocation(
      id: 'loc-2',
      name: 'رف 2',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    locationRepo.locations['loc-2'] = loc2;

    locationRepo.compatibleByItemType['type-clothes'] = [loc1, loc2];

    final locInactive = StorageLocation(
      id: 'loc-inactive',
      name: 'رف معطل',
      isActive: false,
      createdAt: now,
      updatedAt: now,
    );
    locationRepo.locations['loc-inactive'] = locInactive;
    locationRepo.compatibleByItemType['type-clothes']!.add(locInactive);

    final locCarpetOnly = StorageLocation(
      id: 'loc-carpet-only',
      name: 'مخزن سجاد فقط',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    locationRepo.locations['loc-carpet-only'] = locCarpetOnly;
    locationRepo.compatibleByItemType['type-carpet'] = [locCarpetOnly];

    storageRepo.activeRecords['item-1'] = StorageRecord(
      id: 'rec-1',
      orderItemId: 'item-1',
      storageLocationId: 'loc-1',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
  });

  group('MoveStoredItemUseCase', () {
    test('rejects empty inputs', () async {
      expect(
        () => useCase.execute(
          const MoveStoredItemInput(orderItemId: '', newStorageLocationId: 'loc-2'),
        ),
        throwsA(isA<ValidationFailure>()),
      );

      expect(
        () => useCase.execute(
          const MoveStoredItemInput(orderItemId: 'item-1', newStorageLocationId: ''),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('Case A: rejects non-existent OrderItem with Order item not found', () async {
      expect(
        () => useCase.execute(
          const MoveStoredItemInput(orderItemId: 'non-existent-item', newStorageLocationId: 'loc-2'),
        ),
        throwsA(
          isA<ValidationFailure>().having((e) => e.message, 'message', contains('Order item not found')),
        ),
      );
    });

    test('rejects non-existent target location', () async {
      expect(
        () => useCase.execute(
          const MoveStoredItemInput(orderItemId: 'item-1', newStorageLocationId: 'non-existent-loc'),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects inactive target location', () async {
      expect(
        () => useCase.execute(
          const MoveStoredItemInput(orderItemId: 'item-1', newStorageLocationId: 'loc-inactive'),
        ),
        throwsA(isA<BusinessRuleFailure>()),
      );
    });

    test('Test A: rejects target location incompatible with item ItemType', () async {
      expect(
        () => useCase.execute(
          const MoveStoredItemInput(orderItemId: 'item-1', newStorageLocationId: 'loc-carpet-only'),
        ),
        throwsA(isA<IncompatibleStorageLocationFailure>()),
      );
      expect(storageRepo.moveItemCalled, false);
    });

    test('Case B: rejects existing item without active storage record', () async {
      expect(
        () => useCase.execute(
          const MoveStoredItemInput(orderItemId: 'item-unstored', newStorageLocationId: 'loc-2'),
        ),
        throwsA(
          isA<BusinessRuleFailure>().having(
            (e) => e.message,
            'message',
            contains('Item has no active storage location to move from'),
          ),
        ),
      );
      expect(storageRepo.moveItemCalled, false);
    });

    test('Test E: returns existing record when moving to same location (no-op)', () async {
      final result = await useCase.execute(
        const MoveStoredItemInput(orderItemId: 'item-1', newStorageLocationId: 'loc-1'),
      );

      expect(result.id, 'rec-1');
      expect(storageRepo.moveItemCalled, false);
    });

    test('Test D: successfully moves item to compatible active location', () async {
      final result = await useCase.execute(
        const MoveStoredItemInput(orderItemId: 'item-1', newStorageLocationId: 'loc-2'),
      );

      expect(result.storageLocationId, 'loc-2');
      expect(storageRepo.moveItemCalled, true);
    });
  });
}
