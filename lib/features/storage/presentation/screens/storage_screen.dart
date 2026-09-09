import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../domain/entities/storage_item.dart';
import '../cubit/storage_cubit.dart';
import '../cubit/storage_state.dart';
import '../models/storage_tab.dart';
import '../widgets/bulk_storage_bottom_bar.dart';
import '../widgets/move_storage_dialog.dart';
import '../widgets/storage_filter_bar.dart';
import '../widgets/storage_item_card.dart';
import '../widgets/store_storage_dialog.dart';
import '../widgets/unstore_confirm_dialog.dart';

class StorageScreen extends StatelessWidget {
  final String? initialOrderId;
  final String? initialOrderNumber;

  const StorageScreen({
    super.key,
    this.initialOrderId,
    this.initialOrderNumber,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<StorageCubit>()
        ..initialize(
          initialOrderId: initialOrderId,
          initialOrderNumber: initialOrderNumber,
        ),
      child: const _StorageView(),
    );
  }
}

class _StorageView extends StatefulWidget {
  const _StorageView();

  @override
  State<_StorageView> createState() => _StorageViewState();
}

class _StorageViewState extends State<_StorageView> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<StorageCubit>();
    _searchController = TextEditingController(text: cubit.state.searchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openStoreSingleDialog(BuildContext context, StorageItem item) {
    final cubit = context.read<StorageCubit>();
    final locations = cubit.state.compatibleLocationsForItem(item);

    showDialog(
      context: context,
      builder: (_) => StoreStorageDialog(
        itemsToStore: [item],
        availableLocations: locations,
        onConfirm: (storageLocationId) => cubit.storeSingleItem(
          orderItemId: item.orderItem.id,
          storageLocationId: storageLocationId,
          orderId: item.orderId,
        ),
      ),
    );
  }

  void _openBulkStoreDialog(BuildContext context) {
    final cubit = context.read<StorageCubit>();
    final selectedItems = cubit.state.selectedItems;
    final locations = cubit.state.effectiveBulkLocations;

    showDialog(
      context: context,
      builder: (_) => StoreStorageDialog(
        itemsToStore: selectedItems,
        availableLocations: locations,
        onConfirm: (storageLocationId) => cubit.bulkStoreSelected(
          storageLocationId: storageLocationId,
        ),
      ),
    );
  }

  void _openMoveDialog(BuildContext context, StorageItem item) {
    final cubit = context.read<StorageCubit>();
    final destinationLocations = cubit.state.moveDestinationLocations(item);

    showDialog(
      context: context,
      builder: (_) => MoveStorageDialog(
        item: item,
        destinationLocations: destinationLocations,
        onConfirm: (newStorageLocationId) => cubit.moveItem(
          orderItemId: item.orderItem.id,
          newStorageLocationId: newStorageLocationId,
        ),
      ),
    );
  }

  void _openUnstoreDialog(BuildContext context, StorageItem item) {
    final cubit = context.read<StorageCubit>();

    showDialog(
      context: context,
      builder: (_) => UnstoreConfirmDialog(
        item: item,
        onConfirm: () => cubit.unstoreItem(
          orderItemId: item.orderItem.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StorageCubit>();

    return Scaffold(
      body: BlocConsumer<StorageCubit, StorageState>(
        listenWhen: (prev, curr) =>
            prev.successMessage != curr.successMessage ||
            (prev.errorMessage != curr.errorMessage && curr.items.isNotEmpty),
        listener: (context, state) {
          if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.successMessage!),
                backgroundColor: AppColors.success,
              ),
            );
          } else if (state.errorMessage != null && state.items.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          final isRequiring = state.activeTab == StorageTab.requiringStorage;

          return Stack(
            children: [
              Padding(
                padding: AppSpacing.paddingPage,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    PageHeader(
                      title: AppStrings.storage,
                      subtitle: isRequiring
                          ? '${AppStrings.itemsRequiringStorage} (${state.totalCount})'
                          : '${AppStrings.currentStorage} (${state.totalCount})',
                      actions: [
                        if (isRequiring && state.items.isNotEmpty) ...[
                          TextButton.icon(
                            onPressed: () {
                              final allSelected =
                                  state.selectedItemIds.length == state.items.length;
                              cubit.toggleSelectAll(!allSelected);
                            },
                            icon: Icon(
                              state.selectedItemIds.length == state.items.length
                                  ? Icons.deselect_outlined
                                  : Icons.select_all_outlined,
                              size: 18,
                            ),
                            label: Text(
                              state.selectedItemIds.length == state.items.length
                                  ? 'إلغاء تحديد الكل'
                                  : 'تحديد كل الصفحة',
                            ),
                          ),
                        ],
                      ],
                    ),
                    AppSpacing.gapMd,

                    // Operational Tab Switcher
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: _TabButton(
                              label: AppStrings.itemsRequiringStorage,
                              isSelected: isRequiring,
                              onTap: () => cubit.switchTab(StorageTab.requiringStorage),
                            ),
                          ),
                          Expanded(
                            child: _TabButton(
                              label: AppStrings.currentStorage,
                              isSelected: !isRequiring,
                              onTap: () => cubit.switchTab(StorageTab.currentStorage),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.gapMd,

                    // Search Bar
                    AppTextField(
                      controller: _searchController,
                      hintText: AppStrings.searchStoragePlaceholder,
                      prefixIcon: const Icon(Icons.search),
                      onChanged: cubit.search,
                    ),
                    AppSpacing.gapMd,

                    // Filters Bar
                    StorageFilterBar(
                      activeTab: state.activeTab,
                      filter: state.filter,
                      itemTypes: state.itemTypes,
                      services: state.services,
                      locations: state.availableLocations,
                      onFilterChanged: cubit.setFilter,
                      onResetFilters: () {
                        _searchController.clear();
                        cubit.resetFilters();
                      },
                    ),
                    AppSpacing.gapMd,

                    // List Body
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          if (state.isLoading && state.items.isEmpty) {
                            return const Center(child: LoadingIndicator());
                          }

                          if (state.errorMessage != null && state.items.isEmpty) {
                            return AppErrorState(
                              title: AppStrings.failedToLoadStorage,
                              message: state.errorMessage!,
                              onRetry: () => cubit.loadStorageItems(refresh: true),
                            );
                          }

                          if (state.items.isEmpty) {
                            final hasSearchOrFilter =
                                state.searchQuery.isNotEmpty || state.filter.isActive;
                            if (hasSearchOrFilter) {
                              return EmptyState(
                                icon: Icons.search_off_outlined,
                                title: AppStrings.noStorageResults,
                                message: AppStrings.noStorageResultsMessage,
                                actionButton: AppButton(
                                  label: AppStrings.resetFilters,
                                  variant: AppButtonVariant.secondary,
                                  onPressed: () {
                                    _searchController.clear();
                                    cubit.resetFilters();
                                  },
                                ),
                              );
                            }

                            return EmptyState(
                              icon: Icons.inventory_2_outlined,
                              title: isRequiring
                                  ? AppStrings.noItemsRequiringStorage
                                  : AppStrings.noCurrentStorageItems,
                              message: isRequiring
                                  ? 'جميع عناصر الطلبات الجارية مخزنة بالفعل.'
                                  : 'لا توجد عناصر مخزنة حالياً في المستودع.',
                            );
                          }

                          return NotificationListener<ScrollNotification>(
                            onNotification: (scrollInfo) {
                              if (scrollInfo.metrics.pixels >=
                                  scrollInfo.metrics.maxScrollExtent - 200) {
                                cubit.loadMoreStorageItems();
                              }
                              return false;
                            },
                            child: RefreshIndicator(
                              onRefresh: () => cubit.loadStorageItems(refresh: true),
                              child: ListView.builder(
                                padding: EdgeInsets.only(
                                  bottom: state.isAnyItemSelected && isRequiring ? 90 : AppSpacing.md,
                                ),
                                itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == state.items.length) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                                      child: Center(child: LoadingIndicator()),
                                    );
                                  }

                                  final item = state.items[index];
                                  final isSelected = state.selectedItemIds.contains(item.orderItem.id);

                                  return StorageItemCard(
                                    item: item,
                                    isSelected: isSelected,
                                    onSelectionChanged: isRequiring
                                        ? (selected) => cubit.toggleItemSelection(
                                              item.orderItem.id,
                                              selected,
                                            )
                                        : null,
                                    onStore: () => _openStoreSingleDialog(context, item),
                                    onMove: () => _openMoveDialog(context, item),
                                    onUnstore: () => _openUnstoreDialog(context, item),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Bulk Selection Bottom Bar
              if (isRequiring && state.isAnyItemSelected)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: BulkStorageBottomBar(
                    selectedCount: state.selectedItemsCount,
                    hasConflictingTypes: state.hasConflictingItemTypes,
                    onClearSelection: cubit.clearSelection,
                    onBulkStore: () => _openBulkStoreDialog(context),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.labelLarge.copyWith(
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
