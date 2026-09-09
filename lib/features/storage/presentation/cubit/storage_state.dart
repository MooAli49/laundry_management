import '../../../../domain/entities/item_type.dart';
import '../../../../domain/entities/service.dart';
import '../../../../domain/entities/storage_item.dart';
import '../../../../domain/entities/storage_location.dart';
import '../models/storage_filter.dart';
import '../models/storage_tab.dart';

class StorageState {
  final StorageTab activeTab;
  final List<StorageItem> items;
  final int totalCount;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isActionInProgress;
  final String? errorMessage;
  final String? successMessage;
  final String searchQuery;
  final StorageFilter filter;
  final Set<String> selectedItemIds;
  final List<StorageLocation> availableLocations;
  final Map<String, List<StorageLocation>> compatibleLocationsByItemType;
  final List<ItemType> itemTypes;
  final List<Service> services;
  final String? orderFilterId;

  const StorageState({
    this.activeTab = StorageTab.requiringStorage,
    this.items = const [],
    this.totalCount = 0,
    this.hasMore = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isActionInProgress = false,
    this.errorMessage,
    this.successMessage,
    this.searchQuery = '',
    this.filter = StorageFilter.empty,
    this.selectedItemIds = const {},
    this.availableLocations = const [],
    this.compatibleLocationsByItemType = const {},
    this.itemTypes = const [],
    this.services = const [],
    this.orderFilterId,
  });

  List<StorageItem> get selectedItems =>
      items.where((i) => selectedItemIds.contains(i.orderItem.id)).toList();

  int get selectedItemsCount => selectedItemIds.length;

  bool get isAnyItemSelected => selectedItemIds.isNotEmpty;

  List<StorageLocation> get effectiveBulkLocations {
    if (selectedItemIds.isEmpty) {
      return availableLocations.where((l) => l.isActive).toList();
    }

    final selected = selectedItems;
    if (selected.isEmpty) return [];

    List<StorageLocation>? intersection;
    for (final item in selected) {
      final compatible =
          compatibleLocationsByItemType[item.orderItem.itemTypeId] ?? [];
      final activeCompatible = compatible.where((l) => l.isActive).toList();
      if (intersection == null) {
        intersection = List.of(activeCompatible);
      } else {
        intersection = intersection
            .where((loc) => activeCompatible.any((c) => c.id == loc.id))
            .toList();
      }
    }
    return intersection ?? [];
  }

  bool get hasConflictingItemTypes =>
      selectedItemIds.isNotEmpty && effectiveBulkLocations.isEmpty;

  List<StorageLocation> compatibleLocationsForItem(StorageItem item) {
    final compatible =
        compatibleLocationsByItemType[item.orderItem.itemTypeId] ?? [];
    return compatible.where((l) => l.isActive).toList();
  }

  List<StorageLocation> moveDestinationLocations(StorageItem item) {
    final compatible = compatibleLocationsForItem(item);
    final currentLocationId = item.activeRecord?.storageLocationId;
    if (currentLocationId == null) return compatible;
    return compatible.where((loc) => loc.id != currentLocationId).toList();
  }

  StorageState copyWith({
    StorageTab? activeTab,
    List<StorageItem>? items,
    int? totalCount,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isActionInProgress,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? successMessage,
    bool clearSuccessMessage = false,
    String? searchQuery,
    StorageFilter? filter,
    Set<String>? selectedItemIds,
    List<StorageLocation>? availableLocations,
    Map<String, List<StorageLocation>>? compatibleLocationsByItemType,
    List<ItemType>? itemTypes,
    List<Service>? services,
    String? orderFilterId,
    bool clearOrderFilterId = false,
  }) {
    return StorageState(
      activeTab: activeTab ?? this.activeTab,
      items: items ?? this.items,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isActionInProgress: isActionInProgress ?? this.isActionInProgress,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccessMessage ? null : (successMessage ?? this.successMessage),
      searchQuery: searchQuery ?? this.searchQuery,
      filter: filter ?? this.filter,
      selectedItemIds: selectedItemIds ?? this.selectedItemIds,
      availableLocations: availableLocations ?? this.availableLocations,
      compatibleLocationsByItemType:
          compatibleLocationsByItemType ?? this.compatibleLocationsByItemType,
      itemTypes: itemTypes ?? this.itemTypes,
      services: services ?? this.services,
      orderFilterId: clearOrderFilterId ? null : (orderFilterId ?? this.orderFilterId),
    );
  }
}
