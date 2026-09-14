import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../application/use_cases/move_stored_item_use_case.dart';
import '../../../../application/use_cases/store_order_items_use_case.dart';
import '../../../../application/use_cases/unstore_item_use_case.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../domain/entities/storage_location.dart';
import '../../../../domain/repositories/item_type_repository.dart';
import '../../../../domain/repositories/service_repository.dart';
import '../../../../domain/repositories/storage_location_repository.dart';
import '../../../../domain/repositories/storage_repository.dart';
import '../models/storage_filter.dart';
import '../models/storage_tab.dart';
import 'storage_state.dart';

class StorageCubit extends Cubit<StorageState> {
  static const int _pageSize = 50;

  final StorageRepository _storageRepository;
  final StorageLocationRepository _storageLocationRepository;
  final ItemTypeRepository _itemTypeRepository;
  final ServiceRepository _serviceRepository;
  final StoreOrderItemsUseCase _storeOrderItemsUseCase;
  final MoveStoredItemUseCase _moveStoredItemUseCase;
  final UnstoreItemUseCase _unstoreItemUseCase;

  Timer? _debounceTimer;
  int _searchRequestId = 0;
  int _latestLoadMoreRequestId = 0;

  StorageCubit({
    required StorageRepository storageRepository,
    required StorageLocationRepository storageLocationRepository,
    required ItemTypeRepository itemTypeRepository,
    required ServiceRepository serviceRepository,
    required StoreOrderItemsUseCase storeOrderItemsUseCase,
    required MoveStoredItemUseCase moveStoredItemUseCase,
    required UnstoreItemUseCase unstoreItemUseCase,
  })  : _storageRepository = storageRepository,
        _storageLocationRepository = storageLocationRepository,
        _itemTypeRepository = itemTypeRepository,
        _serviceRepository = serviceRepository,
        _storeOrderItemsUseCase = storeOrderItemsUseCase,
        _moveStoredItemUseCase = moveStoredItemUseCase,
        _unstoreItemUseCase = unstoreItemUseCase,
        super(const StorageState());

  bool _isStaleLoadMore(int requestId) {
    if (requestId != _searchRequestId) {
      if (requestId == _latestLoadMoreRequestId && state.isLoadingMore) {
        emit(state.copyWith(isLoadingMore: false));
      }
      return true;
    }
    return false;
  }

  Future<void> initialize({
    String? initialOrderId,
    String? initialOrderNumber,
  }) async {
    try {
      final locations = await _storageLocationRepository.getAllLocations();
      final itemTypes = await _itemTypeRepository.getActiveItemTypes();
      final services = await _serviceRepository.getActiveServices();

      final Map<String, List<StorageLocation>> compatibleByItemType = {};
      for (final type in itemTypes) {
        final compatible =
            await _storageLocationRepository.getCompatibleLocationsForItemType(type.id);
        compatibleByItemType[type.id] = compatible;
      }

      emit(state.copyWith(
        availableLocations: locations,
        compatibleLocationsByItemType: compatibleByItemType,
        itemTypes: itemTypes,
        services: services,
        orderFilterId: initialOrderId,
        searchQuery: initialOrderNumber ?? state.searchQuery,
      ));

      await loadStorageItems();
    } catch (_) {
      emit(state.copyWith(
        errorMessage: AppStrings.failedToLoadStorage,
      ));
    }
  }

  Future<void> loadStorageItems({bool refresh = false}) async {
    final requestId = ++_searchRequestId;
    emit(state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    ));

    try {
      final rawQuery = state.searchQuery.trim();
      final query = rawQuery.isNotEmpty ? rawQuery : null;
      final f = state.filter;

      if (state.activeTab == StorageTab.requiringStorage) {
        final items = await _storageRepository.getItemsRequiringStorageWithDetails(
          query: query,
          orderId: state.orderFilterId,
          itemTypeId: f.itemTypeId,
          serviceId: f.serviceId,
          expectedPickupDate: f.expectedPickupDate,
          orderReceivedDate: f.orderReceivedDate,
          limit: _pageSize,
          offset: 0,
        );

        final totalCount = await _storageRepository.countItemsRequiringStorage(
          query: query,
          orderId: state.orderFilterId,
          itemTypeId: f.itemTypeId,
          serviceId: f.serviceId,
          expectedPickupDate: f.expectedPickupDate,
          orderReceivedDate: f.orderReceivedDate,
        );

        if (isClosed || requestId != _searchRequestId) return;

        final hasMore = items.length == _pageSize && items.length < totalCount;
        emit(state.copyWith(
          items: items,
          totalCount: totalCount,
          hasMore: hasMore,
          isLoading: false,
          isLoadingMore: false,
        ));
      } else {
        final items = await _storageRepository.getCurrentStorageItems(
          query: query,
          orderId: state.orderFilterId,
          storageLocationId: f.storageLocationId,
          itemTypeId: f.itemTypeId,
          serviceId: f.serviceId,
          expectedPickupDate: f.expectedPickupDate,
          orderReceivedDate: f.orderReceivedDate,
          limit: _pageSize,
          offset: 0,
        );

        final totalCount = await _storageRepository.countCurrentStorageItems(
          query: query,
          orderId: state.orderFilterId,
          storageLocationId: f.storageLocationId,
          itemTypeId: f.itemTypeId,
          serviceId: f.serviceId,
          expectedPickupDate: f.expectedPickupDate,
          orderReceivedDate: f.orderReceivedDate,
        );

        if (isClosed || requestId != _searchRequestId) return;

        final hasMore = items.length == _pageSize && items.length < totalCount;
        emit(state.copyWith(
          items: items,
          totalCount: totalCount,
          hasMore: hasMore,
          isLoading: false,
          isLoadingMore: false,
        ));
      }
    } on Failure catch (e) {
      if (isClosed || requestId != _searchRequestId) return;
      emit(state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        errorMessage: e.message,
      ));
    } catch (_) {
      if (isClosed || requestId != _searchRequestId) return;
      emit(state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        errorMessage: AppStrings.unexpectedError,
      ));
    }
  }

  Future<void> loadMoreStorageItems() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore || isClosed) {
      return;
    }

    final requestId = ++_searchRequestId;
    _latestLoadMoreRequestId = requestId;
    emit(state.copyWith(isLoadingMore: true, clearErrorMessage: true));

    try {
      final rawQuery = state.searchQuery.trim();
      final query = rawQuery.isNotEmpty ? rawQuery : null;
      final currentCount = state.items.length;
      final f = state.filter;

      if (state.activeTab == StorageTab.requiringStorage) {
        final nextItems = await _storageRepository.getItemsRequiringStorageWithDetails(
          query: query,
          orderId: state.orderFilterId,
          itemTypeId: f.itemTypeId,
          serviceId: f.serviceId,
          expectedPickupDate: f.expectedPickupDate,
          orderReceivedDate: f.orderReceivedDate,
          limit: _pageSize,
          offset: currentCount,
        );

        if (isClosed) return;
        if (_isStaleLoadMore(requestId)) return;

        final totalLoaded = currentCount + nextItems.length;
        final hasMore = nextItems.length == _pageSize && totalLoaded < state.totalCount;

        emit(state.copyWith(
          items: [...state.items, ...nextItems],
          isLoadingMore: false,
          hasMore: hasMore,
        ));
      } else {
        final nextItems = await _storageRepository.getCurrentStorageItems(
          query: query,
          orderId: state.orderFilterId,
          storageLocationId: f.storageLocationId,
          itemTypeId: f.itemTypeId,
          serviceId: f.serviceId,
          expectedPickupDate: f.expectedPickupDate,
          orderReceivedDate: f.orderReceivedDate,
          limit: _pageSize,
          offset: currentCount,
        );

        if (isClosed) return;
        if (_isStaleLoadMore(requestId)) return;

        final totalLoaded = currentCount + nextItems.length;
        final hasMore = nextItems.length == _pageSize && totalLoaded < state.totalCount;

        emit(state.copyWith(
          items: [...state.items, ...nextItems],
          isLoadingMore: false,
          hasMore: hasMore,
        ));
      }
    } on Failure catch (e) {
      if (isClosed) return;
      if (_isStaleLoadMore(requestId)) return;
      emit(state.copyWith(
        isLoadingMore: false,
        errorMessage: e.message,
      ));
    } catch (_) {
      if (isClosed) return;
      if (_isStaleLoadMore(requestId)) return;
      emit(state.copyWith(
        isLoadingMore: false,
        errorMessage: AppStrings.unexpectedError,
      ));
    }
  }

  void search(String query) {
    final trimmed = query.trim();
    if (trimmed == state.searchQuery) return;
    _debounceTimer?.cancel();
    _searchRequestId++;
    emit(state.copyWith(searchQuery: trimmed));
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      loadStorageItems();
    });
  }

  void switchTab(StorageTab tab) {
    if (tab == state.activeTab) return;
    _debounceTimer?.cancel();
    _searchRequestId++;
    emit(state.copyWith(
      activeTab: tab,
      selectedItemIds: {},
      filter: StorageFilter.empty,
      items: [],
      totalCount: 0,
      hasMore: false,
    ));
    loadStorageItems();
  }

  void setFilter(StorageFilter filter) {
    _debounceTimer?.cancel();
    _searchRequestId++;
    emit(state.copyWith(filter: filter));
    loadStorageItems();
  }

  void resetFilters() {
    _debounceTimer?.cancel();
    _searchRequestId++;
    emit(state.copyWith(
      filter: StorageFilter.empty,
      searchQuery: '',
      clearOrderFilterId: true,
    ));
    loadStorageItems();
  }

  void toggleItemSelection(String itemId, bool selected) {
    final updated = Set<String>.from(state.selectedItemIds);
    if (selected) {
      updated.add(itemId);
    } else {
      updated.remove(itemId);
    }
    emit(state.copyWith(selectedItemIds: updated));
  }

  void toggleSelectAll(bool selectAll) {
    if (selectAll) {
      final allIds = state.items.map((i) => i.orderItem.id).toSet();
      emit(state.copyWith(selectedItemIds: allIds));
    } else {
      emit(state.copyWith(selectedItemIds: {}));
    }
  }

  void clearSelection() {
    emit(state.copyWith(selectedItemIds: {}));
  }

  Future<void> storeSingleItem({
    required String orderItemId,
    required String storageLocationId,
    String? orderId,
  }) async {
    emit(state.copyWith(isActionInProgress: true, clearErrorMessage: true, clearSuccessMessage: true));
    try {
      await _storeOrderItemsUseCase.execute(StoreOrderItemsInput(
        orderId: orderId,
        orderItemIds: [orderItemId],
        storageLocationId: storageLocationId,
      ));

      await loadStorageItems(refresh: true);
      emit(state.copyWith(
        isActionInProgress: false,
        successMessage: AppStrings.storeItemSuccess,
      ));
    } on Failure catch (e) {
      emit(state.copyWith(isActionInProgress: false, errorMessage: e.message));
      rethrow;
    } catch (_) {
      emit(state.copyWith(isActionInProgress: false, errorMessage: AppStrings.unexpectedError));
      rethrow;
    }
  }

  Future<void> bulkStoreSelected({
    required String storageLocationId,
  }) async {
    if (state.selectedItemIds.isEmpty) {
      throw const ValidationFailure(AppStrings.selectAtLeastOneItem);
    }

    emit(state.copyWith(isActionInProgress: true, clearErrorMessage: true, clearSuccessMessage: true));
    try {
      await _storeOrderItemsUseCase.execute(StoreOrderItemsInput(
        orderItemIds: state.selectedItemIds.toList(),
        storageLocationId: storageLocationId,
      ));

      await loadStorageItems(refresh: true);
      emit(state.copyWith(
        isActionInProgress: false,
        selectedItemIds: {},
        successMessage: AppStrings.storeItemsSuccess,
      ));
    } on Failure catch (e) {
      emit(state.copyWith(isActionInProgress: false, errorMessage: e.message));
      rethrow;
    } catch (_) {
      emit(state.copyWith(isActionInProgress: false, errorMessage: AppStrings.unexpectedError));
      rethrow;
    }
  }

  Future<void> moveItem({
    required String orderItemId,
    required String newStorageLocationId,
  }) async {
    emit(state.copyWith(isActionInProgress: true, clearErrorMessage: true, clearSuccessMessage: true));
    try {
      await _moveStoredItemUseCase.execute(MoveStoredItemInput(
        orderItemId: orderItemId,
        newStorageLocationId: newStorageLocationId,
      ));

      await loadStorageItems(refresh: true);
      emit(state.copyWith(
        isActionInProgress: false,
        successMessage: AppStrings.moveItemSuccess,
      ));
    } on Failure catch (e) {
      emit(state.copyWith(isActionInProgress: false, errorMessage: e.message));
      rethrow;
    } catch (_) {
      emit(state.copyWith(isActionInProgress: false, errorMessage: AppStrings.unexpectedError));
      rethrow;
    }
  }

  Future<void> unstoreItem({
    required String orderItemId,
  }) async {
    emit(state.copyWith(isActionInProgress: true, clearErrorMessage: true, clearSuccessMessage: true));
    try {
      await _unstoreItemUseCase.execute(UnstoreItemInput(
        orderItemId: orderItemId,
      ));

      await loadStorageItems(refresh: true);
      emit(state.copyWith(
        isActionInProgress: false,
        successMessage: AppStrings.unstoreItemSuccess,
      ));
    } on Failure catch (e) {
      emit(state.copyWith(isActionInProgress: false, errorMessage: e.message));
      rethrow;
    } catch (_) {
      emit(state.copyWith(isActionInProgress: false, errorMessage: AppStrings.unexpectedError));
      rethrow;
    }
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }
}
