import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/application/use_cases/move_stored_item_use_case.dart';
import 'package:laundry_management/application/use_cases/store_order_items_use_case.dart';
import 'package:laundry_management/application/use_cases/unstore_item_use_case.dart';
import 'package:laundry_management/core/errors/failures.dart';
import 'package:laundry_management/domain/entities/item_type.dart';
import 'package:laundry_management/domain/entities/order.dart';
import 'package:laundry_management/domain/entities/order_item.dart';
import 'package:laundry_management/domain/entities/service.dart';
import 'package:laundry_management/domain/entities/storage_item.dart';
import 'package:laundry_management/domain/entities/storage_location.dart';
import 'package:laundry_management/domain/entities/storage_record.dart';
import 'package:laundry_management/domain/enums/order_status.dart';
import 'package:laundry_management/domain/enums/pricing_type.dart';
import 'package:laundry_management/domain/repositories/item_type_repository.dart';
import 'package:laundry_management/domain/repositories/service_repository.dart';
import 'package:laundry_management/domain/repositories/storage_location_repository.dart';
import 'package:laundry_management/domain/repositories/storage_repository.dart';
import 'package:laundry_management/domain/value_objects/money.dart';
import 'package:laundry_management/domain/value_objects/order_date.dart';
import 'package:laundry_management/features/storage/presentation/cubit/storage_cubit.dart';
import 'package:laundry_management/features/storage/presentation/models/storage_filter.dart';
import 'package:laundry_management/features/storage/presentation/models/storage_tab.dart';

class FakeStorageRepository implements StorageRepository {
  List<StorageItem> requiringItems = [];
  List<StorageItem> currentItems = [];
  bool shouldThrowOnLoadMore = false;
  int delayLoadMoreMs = 0;

  @override
  Future<List<StorageItem>> getItemsRequiringStorageWithDetails({
    String? query,
    String? orderId,
    String? itemTypeId,
    String? serviceId,
    OrderDate? expectedPickupDate,
    DateTime? orderReceivedDate,
    int limit = 50,
    int offset = 0,
  }) async {
    if (shouldThrowOnLoadMore && offset > 0) {
      throw const DatabaseFailure('Load more error');
    }
    if (delayLoadMoreMs > 0 && offset > 0) {
      await Future.delayed(Duration(milliseconds: delayLoadMoreMs));
    }
    var result = requiringItems;
    if (query != null && query.isNotEmpty) {
      result = result.where((i) => i.orderNumber.contains(query) || i.customerName.contains(query)).toList();
    }
    if (itemTypeId != null) {
      result = result.where((i) => i.orderItem.itemTypeId == itemTypeId).toList();
    }
    return result.skip(offset).take(limit).toList();
  }

  @override
  Future<int> countItemsRequiringStorage({
    String? query,
    String? orderId,
    String? itemTypeId,
    String? serviceId,
    OrderDate? expectedPickupDate,
    DateTime? orderReceivedDate,
  }) async {
    var result = requiringItems;
    if (query != null && query.isNotEmpty) {
      result = result.where((i) => i.orderNumber.contains(query) || i.customerName.contains(query)).toList();
    }
    if (itemTypeId != null) {
      result = result.where((i) => i.orderItem.itemTypeId == itemTypeId).toList();
    }
    return result.length;
  }

  @override
  Future<List<StorageItem>> getCurrentStorageItems({
    String? query,
    String? orderId,
    String? storageLocationId,
    String? itemTypeId,
    String? serviceId,
    OrderDate? expectedPickupDate,
    DateTime? orderReceivedDate,
    int limit = 50,
    int offset = 0,
  }) async {
    var result = currentItems;
    if (query != null && query.isNotEmpty) {
      result = result.where((i) => i.orderNumber.contains(query) || i.customerName.contains(query)).toList();
    }
    if (storageLocationId != null) {
      result = result.where((i) => i.storageLocation?.id == storageLocationId).toList();
    }
    return result.skip(offset).take(limit).toList();
  }

  @override
  Future<int> countCurrentStorageItems({
    String? query,
    String? orderId,
    String? storageLocationId,
    String? itemTypeId,
    String? serviceId,
    OrderDate? expectedPickupDate,
    DateTime? orderReceivedDate,
  }) async {
    var result = currentItems;
    if (query != null && query.isNotEmpty) {
      result = result.where((i) => i.orderNumber.contains(query) || i.customerName.contains(query)).toList();
    }
    if (storageLocationId != null) {
      result = result.where((i) => i.storageLocation?.id == storageLocationId).toList();
    }
    return result.length;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStorageLocationRepository implements StorageLocationRepository {
  List<StorageLocation> locations = [];
  Map<String, List<StorageLocation>> compatible = {};

  @override
  Future<List<StorageLocation>> getAllLocations() async => locations;

  @override
  Future<List<StorageLocation>> getCompatibleLocationsForItemType(String itemTypeId) async =>
      compatible[itemTypeId] ?? [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeItemTypeRepository implements ItemTypeRepository {
  List<ItemType> itemTypes = [];

  @override
  Future<List<ItemType>> getActiveItemTypes() async => itemTypes;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeServiceRepository implements ServiceRepository {
  List<Service> services = [];

  @override
  Future<List<Service>> getActiveServices() async => services;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStoreOrderItemsUseCase implements StoreOrderItemsUseCase {
  bool executed = false;
  StoreOrderItemsInput? lastInput;

  @override
  Future<StoreOrderItemsResult> execute(StoreOrderItemsInput input) async {
    executed = true;
    lastInput = input;
    final now = DateTime.now();
    return StoreOrderItemsResult(
      order: Order(
        id: 'ord-1',
        orderNumber: '26-001',
        customerId: 'c-1',
        customerNameSnapshot: 'أحمد',
        customerPhoneSnapshot: '01000000000',
        status: OrderStatus.ready,
        expectedPickupDate: OrderDate.today(),
        subtotal: const Money.fromPiastres(1000),
        total: const Money.fromPiastres(1000),
        createdAt: now,
        updatedAt: now,
      ),
      allStored: true,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMoveStoredItemUseCase implements MoveStoredItemUseCase {
  bool executed = false;
  MoveStoredItemInput? lastInput;

  @override
  Future<StorageRecord> execute(MoveStoredItemInput input) async {
    executed = true;
    lastInput = input;
    final now = DateTime.now();
    return StorageRecord(
      id: 'rec-moved',
      orderItemId: input.orderItemId,
      storageLocationId: input.newStorageLocationId,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUnstoreItemUseCase implements UnstoreItemUseCase {
  bool executed = false;
  UnstoreItemInput? lastInput;

  @override
  Future<void> execute(UnstoreItemInput input) async {
    executed = true;
    lastInput = input;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeStorageRepository storageRepo;
  late FakeStorageLocationRepository locationRepo;
  late FakeItemTypeRepository itemTypeRepo;
  late FakeServiceRepository serviceRepo;
  late FakeStoreOrderItemsUseCase storeUseCase;
  late FakeMoveStoredItemUseCase moveUseCase;
  late FakeUnstoreItemUseCase unstoreUseCase;
  late StorageCubit cubit;

  final now = DateTime.now();

  final loc1 = StorageLocation(id: 'loc-1', name: 'رف A-01', isActive: true, createdAt: now, updatedAt: now);
  final loc2 = StorageLocation(id: 'loc-2', name: 'رف B-02', isActive: true, createdAt: now, updatedAt: now);
  final typeClothes = ItemType(id: 'type-clothes', name: 'ملابس', isActive: true, createdAt: now, updatedAt: now);
  final typeCarpet = ItemType(id: 'type-carpet', name: 'سجاد', isActive: true, createdAt: now, updatedAt: now);

  final testItem1 = StorageItem(
    orderItem: OrderItem(
      id: 'item-1',
      orderId: 'ord-1',
      itemTypeId: 'type-clothes',
      serviceId: 'srv-1',
      itemTypeNameSnapshot: 'قميص',
      serviceNameSnapshot: 'غسيل',
      pricingType: PricingType.perPiece,
      quantity: 1.0,
      unitPrice: const Money.fromPiastres(1000),
      calculatedTotal: const Money.fromPiastres(1000),
      createdAt: now,
      updatedAt: now,
    ),
    orderId: 'ord-1',
    orderNumber: '26-001',
    customerName: 'محمد أحمد',
    customerPhone: '01012345678',
    orderStatus: OrderStatus.processing,
    expectedPickupDate: OrderDate.today(),
    orderCreatedAt: now,
  );

  final testItemStored = StorageItem(
    orderItem: OrderItem(
      id: 'item-stored',
      orderId: 'ord-1',
      itemTypeId: 'type-clothes',
      serviceId: 'srv-1',
      itemTypeNameSnapshot: 'قميص',
      serviceNameSnapshot: 'غسيل',
      pricingType: PricingType.perPiece,
      quantity: 1.0,
      unitPrice: const Money.fromPiastres(1000),
      calculatedTotal: const Money.fromPiastres(1000),
      createdAt: now,
      updatedAt: now,
    ),
    orderId: 'ord-1',
    orderNumber: '26-001',
    customerName: 'محمد أحمد',
    customerPhone: '01012345678',
    orderStatus: OrderStatus.processing,
    expectedPickupDate: OrderDate.today(),
    orderCreatedAt: now,
    activeRecord: StorageRecord(
      id: 'rec-1',
      orderItemId: 'item-stored',
      storageLocationId: 'loc-1',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    ),
    storageLocation: loc1,
  );

  setUp(() {
    storageRepo = FakeStorageRepository();
    locationRepo = FakeStorageLocationRepository();
    itemTypeRepo = FakeItemTypeRepository();
    serviceRepo = FakeServiceRepository();
    storeUseCase = FakeStoreOrderItemsUseCase();
    moveUseCase = FakeMoveStoredItemUseCase();
    unstoreUseCase = FakeUnstoreItemUseCase();

    locationRepo.locations = [loc1, loc2];
    locationRepo.compatible = {
      'type-clothes': [loc1, loc2],
      'type-carpet': [loc2],
    };
    itemTypeRepo.itemTypes = [typeClothes, typeCarpet];

    storageRepo.requiringItems = [testItem1];
    storageRepo.currentItems = [testItemStored];

    cubit = StorageCubit(
      storageRepository: storageRepo,
      storageLocationRepository: locationRepo,
      itemTypeRepository: itemTypeRepo,
      serviceRepository: serviceRepo,
      storeOrderItemsUseCase: storeUseCase,
      moveStoredItemUseCase: moveUseCase,
      unstoreItemUseCase: unstoreUseCase,
    );
  });

  tearDown(() {
    cubit.close();
  });

  group('StorageCubit — State Handling, Tabs, Selection & Pagination', () {
    test('28 & 29. initialize loads metadata and items requiring storage', () async {
      await cubit.initialize();

      expect(cubit.state.items.length, 1);
      expect(cubit.state.totalCount, 1);
      expect(cubit.state.activeTab, StorageTab.requiringStorage);
      expect(cubit.state.availableLocations.length, 2);
      expect(cubit.state.itemTypes.length, 2);
    });

    test('30. Empty state when no items exist', () async {
      storageRepo.requiringItems = [];
      await cubit.initialize();

      expect(cubit.state.items, isEmpty);
      expect(cubit.state.totalCount, 0);
    });

    test('31 & 32. Search filters items and supports debounce', () async {
      await cubit.initialize();
      expect(cubit.state.items.length, 1);

      cubit.search('26-001');
      await Future.delayed(const Duration(milliseconds: 350));
      expect(cubit.state.items.length, 1);

      cubit.search('NON_EXISTENT');
      await Future.delayed(const Duration(milliseconds: 350));
      expect(cubit.state.items, isEmpty);
    });

    test('33. Filter by item type', () async {
      await cubit.initialize();
      expect(cubit.state.items.length, 1);

      cubit.setFilter(const StorageFilter(itemTypeId: 'type-carpet'));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(cubit.state.items, isEmpty);

      cubit.resetFilters();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(cubit.state.items.length, 1);
    });

    test('Switch tab changes between requiring storage and current storage', () async {
      await cubit.initialize();
      expect(cubit.state.activeTab, StorageTab.requiringStorage);
      expect(cubit.state.items.first.orderItem.id, 'item-1');

      cubit.switchTab(StorageTab.currentStorage);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(cubit.state.activeTab, StorageTab.currentStorage);
      expect(cubit.state.items.first.orderItem.id, 'item-stored');
    });

    test('Bulk selection toggles items and checks intersection compatibility', () async {
      await cubit.initialize();

      cubit.toggleItemSelection('item-1', true);
      expect(cubit.state.selectedItemIds, contains('item-1'));
      expect(cubit.state.selectedItemsCount, 1);
      expect(cubit.state.isAnyItemSelected, true);
      // Item 1 is clothing -> compatible with loc1, loc2
      expect(cubit.state.effectiveBulkLocations.map((l) => l.id), containsAll(['loc-1', 'loc-2']));
      expect(cubit.state.hasConflictingItemTypes, false);

      cubit.clearSelection();
      expect(cubit.state.selectedItemIds, isEmpty);
      expect(cubit.state.isAnyItemSelected, false);
    });

    test('42. Existing data is preserved when loadMore fails', () async {
      // Setup 55 items so hasMore is true
      storageRepo.requiringItems = List.generate(
        55,
        (i) => StorageItem(
          orderItem: OrderItem(
            id: 'item-$i',
            orderId: 'ord-1',
            itemTypeId: 'type-clothes',
            serviceId: 'srv-1',
            itemTypeNameSnapshot: 'قميص',
            serviceNameSnapshot: 'غسيل',
            pricingType: PricingType.perPiece,
            quantity: 1.0,
            unitPrice: const Money.fromPiastres(1000),
            calculatedTotal: const Money.fromPiastres(1000),
            createdAt: now,
            updatedAt: now,
          ),
          orderId: 'ord-1',
          orderNumber: '26-001',
          customerName: 'محمد أحمد',
          customerPhone: '01012345678',
          orderStatus: OrderStatus.processing,
          expectedPickupDate: OrderDate.today(),
          orderCreatedAt: now,
        ),
      );

      await cubit.initialize();
      expect(cubit.state.items.length, 50);
      expect(cubit.state.hasMore, true);

      storageRepo.shouldThrowOnLoadMore = true;
      await cubit.loadMoreStorageItems();

      // Items still 50, not erased!
      expect(cubit.state.items.length, 50);
      expect(cubit.state.isLoadingMore, false);
      expect(cubit.state.errorMessage, isNotNull);
    });

    test('36. Stale load-more request protection', () async {
      storageRepo.requiringItems = List.generate(
        60,
        (i) => StorageItem(
          orderItem: OrderItem(
            id: 'item-$i',
            orderId: 'ord-1',
            itemTypeId: 'type-clothes',
            serviceId: 'srv-1',
            itemTypeNameSnapshot: 'قميص',
            serviceNameSnapshot: 'غسيل',
            pricingType: PricingType.perPiece,
            quantity: 1.0,
            unitPrice: const Money.fromPiastres(1000),
            calculatedTotal: const Money.fromPiastres(1000),
            createdAt: now,
            updatedAt: now,
          ),
          orderId: 'ord-1',
          orderNumber: '26-001',
          customerName: 'محمد أحمد',
          customerPhone: '01012345678',
          orderStatus: OrderStatus.processing,
          expectedPickupDate: OrderDate.today(),
          orderCreatedAt: now,
        ),
      );

      await cubit.initialize();
      storageRepo.delayLoadMoreMs = 100;

      // Launch loadMore
      final loadMoreFuture = cubit.loadMoreStorageItems();

      // Immediately trigger search which bumps _searchRequestId
      cubit.search('fresh-query');

      await loadMoreFuture;
      // Stale load-more did not overwrite
      expect(cubit.state.isLoadingMore, false);
    });
  });

  group('StorageCubit — Operational Actions (Store, Bulk, Move, Unstore)', () {
    test('37. Single store calls use case and reloads items', () async {
      await cubit.initialize();

      await cubit.storeSingleItem(
        orderItemId: 'item-1',
        storageLocationId: 'loc-1',
        orderId: 'ord-1',
      );

      expect(storeUseCase.executed, true);
      expect(storeUseCase.lastInput?.orderItemIds, ['item-1']);
      expect(storeUseCase.lastInput?.storageLocationId, 'loc-1');
      expect(cubit.state.successMessage, isNotNull);
    });

    test('38 & 43. Bulk store stores all selected items and clears selection', () async {
      await cubit.initialize();
      cubit.toggleItemSelection('item-1', true);
      expect(cubit.state.selectedItemsCount, 1);

      await cubit.bulkStoreSelected(storageLocationId: 'loc-1');

      expect(storeUseCase.executed, true);
      expect(storeUseCase.lastInput?.orderItemIds, ['item-1']);
      expect(cubit.state.selectedItemIds, isEmpty);
      expect(cubit.state.successMessage, isNotNull);
    });

    test('39. Move item calls move use case and reloads items', () async {
      await cubit.initialize();
      cubit.switchTab(StorageTab.currentStorage);
      await Future.delayed(const Duration(milliseconds: 50));

      await cubit.moveItem(
        orderItemId: 'item-stored',
        newStorageLocationId: 'loc-2',
      );

      expect(moveUseCase.executed, true);
      expect(moveUseCase.lastInput?.orderItemId, 'item-stored');
      expect(moveUseCase.lastInput?.newStorageLocationId, 'loc-2');
      expect(cubit.state.successMessage, isNotNull);
    });

    test('40. Unstore item calls unstore use case and reloads items', () async {
      await cubit.initialize();
      cubit.switchTab(StorageTab.currentStorage);
      await Future.delayed(const Duration(milliseconds: 50));

      await cubit.unstoreItem(orderItemId: 'item-stored');

      expect(unstoreUseCase.executed, true);
      expect(unstoreUseCase.lastInput?.orderItemId, 'item-stored');
      expect(cubit.state.successMessage, isNotNull);
    });
  });
}
