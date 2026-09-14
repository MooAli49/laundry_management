import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_error_state.dart';
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
      child: _StorageView(
        initialOrderId: initialOrderId,
        initialOrderNumber: initialOrderNumber,
      ),
    );
  }
}

class _StorageView extends StatefulWidget {
  final String? initialOrderId;
  final String? initialOrderNumber;

  const _StorageView({
    this.initialOrderId,
    this.initialOrderNumber,
  });

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

    return BlocConsumer<StorageCubit, StorageState>(
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
        final hasOrderContext = widget.initialOrderId != null;

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () => cubit.loadStorageItems(refresh: true),
            child: NotificationListener<ScrollNotification>(
              onNotification: (scrollInfo) {
                if (scrollInfo.metrics.pixels >=
                    scrollInfo.metrics.maxScrollExtent - 200) {
                  cubit.loadMoreStorageItems();
                }
                return false;
              },
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      AppSpacing.lg,
                      AppSpacing.page,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. Order Context Banner (ONLY when orderContextId / initialOrderId is present)
                          if (hasOrderContext) ...[
                            AppCard(
                              backgroundColor: AppColors.primaryLighter,
                              borderColor: Colors.transparent,
                              borderRadius: AppSpacing.radiusLg,
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 20,
                                    color: AppColors.primary,
                                  ),
                                  AppSpacing.gapHorizontalMd,
                                  Text.rich(
                                    TextSpan(
                                      text: 'تخزين الطلب ',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontSize: 14,
                                        color: AppColors.textPrimary,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: '#${widget.initialOrderNumber ?? widget.initialOrderId}',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AppSpacing.gapLg,
                          ],

                          // 2. Header Area (PageHeader)
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

                          // 3. Segmented Tab Switcher (Figma: natural width inline-flex)
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.secondary,
                                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                                border: Border.all(color: AppColors.border),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _FigmaSegmentedTab(
                                    label: AppStrings.itemsRequiringStorage,
                                    isSelected: isRequiring,
                                    onTap: () =>
                                        cubit.switchTab(StorageTab.requiringStorage),
                                  ),
                                  _FigmaSegmentedTab(
                                    label: AppStrings.currentStorage,
                                    isSelected: !isRequiring,
                                    onTap: () =>
                                        cubit.switchTab(StorageTab.currentStorage),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          AppSpacing.gapLg,

                          // 4. Search Field (Figma: h-11 rounded-xl bg-surface border-border)
                          Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) {
                                cubit.search(val);
                                setState(() {});
                              },
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: 'ابحث برقم الطلب أو اسم العميل',
                                hintStyle: AppTextStyles.bodyMedium.copyWith(
                                  fontSize: 14,
                                  color: AppColors.textTertiary,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search,
                                  size: 18,
                                  color: AppColors.textTertiary,
                                ),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          size: 16,
                                          color: AppColors.textTertiary,
                                        ),
                                        onPressed: () {
                                          _searchController.clear();
                                          cubit.search('');
                                          setState(() {});
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          AppSpacing.gapMd,

                          // 5. Storage Filter Bar (Figma: structured responsive grid)
                          StorageFilterBar(
                            activeTab: state.activeTab,
                            filter: state.filter,
                            itemTypes: state.itemTypes,
                            services: state.services,
                            locations: state.availableLocations,
                            isSearchActive: _searchController.text.trim().isNotEmpty,
                            onFilterChanged: cubit.setFilter,
                            onResetFilters: () {
                              _searchController.clear();
                              cubit.resetFilters();
                              setState(() {});
                            },
                          ),

                          // 6. Bulk Selection Floating Bar (Figma: sticky top-2 rounded-xl bg-surface-selected)
                          if (isRequiring && state.isAnyItemSelected) ...[
                            AppSpacing.gapLg,
                            BulkStorageBottomBar(
                              selectedCount: state.selectedItemsCount,
                              hasConflictingTypes: state.hasConflictingItemTypes,
                              onClearSelection: cubit.clearSelection,
                              onBulkStore: () => _openBulkStoreDialog(context),
                            ),
                          ] else ...[
                            AppSpacing.gapLg,
                          ],
                        ],
                      ),
                    ),
                  ),

                  // 7. Storage Items List Body or States
                  if (state.isLoading && state.items.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: LoadingIndicator()),
                    )
                  else if (state.errorMessage != null && state.items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: AppErrorState(
                        title: AppStrings.failedToLoadStorage,
                        message: state.errorMessage!,
                        onRetry: () => cubit.loadStorageItems(refresh: true),
                      ),
                    )
                  else if (state.items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.page,
                          0,
                          AppSpacing.page,
                          AppSpacing.lg,
                        ),
                        child: (state.searchQuery.isNotEmpty || state.filter.isActive)
                            ? _StorageEmptyContainer(
                                icon: Icons.search_off_outlined,
                                iconColor: AppColors.textSecondary,
                                iconBgColor: AppColors.secondary,
                                title: 'لا توجد نتائج مطابقة',
                                description: 'جرّب تعديل البحث أو مسح الفلاتر.',
                                action: TextButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    cubit.resetFilters();
                                    setState(() {});
                                  },
                                  child: Text(
                                    'مسح البحث والفلاتر',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              )
                            : _StorageEmptyContainer(
                                icon: Icons.inventory_2_outlined,
                                iconColor: AppColors.primary,
                                iconBgColor: AppColors.primaryLighter,
                                title: isRequiring
                                    ? 'لا توجد عناصر تحتاج إلى تخزين'
                                    : 'لا توجد عناصر مخزنة',
                                description: isRequiring
                                    ? 'جميع العناصر الحالية تمت معالجتها. يمكنك العودة إلى الطلبات.'
                                    : 'لم يتم تخزين أي عنصر بعد.',
                              ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page,
                        0,
                        AppSpacing.page,
                        AppSpacing.lg,
                      ),
                      sliver: SliverList.builder(
                        itemCount: state.items.length +
                            (state.isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == state.items.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: AppSpacing.md,
                              ),
                              child: Center(child: LoadingIndicator()),
                            );
                          }

                          final item = state.items[index];
                          final isSelected = state.selectedItemIds
                              .contains(item.orderItem.id);

                          return StorageItemCard(
                            item: item,
                            isSelected: isSelected,
                            onSelectionChanged: isRequiring
                                ? (selected) =>
                                    cubit.toggleItemSelection(
                                      item.orderItem.id,
                                      selected,
                                    )
                                : null,
                            onStore: () =>
                                _openStoreSingleDialog(context, item),
                            onMove: () =>
                                _openMoveDialog(context, item),
                            onUnstore: () =>
                                _openUnstoreDialog(context, item),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Natural-width Segmented Tab Item matching Figma SegmentedControl.
class _FigmaSegmentedTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FigmaSegmentedTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0x1417212E),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

/// Dashed bordered empty state container matching Figma `EmptyState` / `NoResultsState`.
class _StorageEmptyContainer extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String description;
  final Widget? action;

  const _StorageEmptyContainer({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            border: Border.all(
              color: AppColors.border,
              width: 1,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 56x56 icon box
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 28, color: iconColor),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: AppTextStyles.headlineMedium.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Text(
                  description,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: 16),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
