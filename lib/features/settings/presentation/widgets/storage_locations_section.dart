import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../domain/entities/storage_location.dart';
import '../cubit/storage_locations_management_cubit.dart';
import '../cubit/storage_locations_management_state.dart';
import 'active_status_badge.dart';
import 'deactivation_confirm_dialog.dart';
import 'storage_location_form_dialog.dart';

class StorageLocationsSection extends StatelessWidget {
  const StorageLocationsSection({super.key});

  Future<void> _handleAdd(BuildContext context) async {
    final cubit = context.read<StorageLocationsManagementCubit>();
    await StorageLocationFormDialog.show(
      context,
      availableItemTypes: cubit.state.itemTypes,
    );
  }

  Future<void> _handleEdit(BuildContext context, StorageLocation location) async {
    final cubit = context.read<StorageLocationsManagementCubit>();
    final supportedIds = await cubit.getSupportedItemTypeIds(location.id);
    if (context.mounted) {
      await StorageLocationFormDialog.show(
        context,
        location: location,
        availableItemTypes: cubit.state.itemTypes,
        initialSupportedTypeIds: supportedIds,
      );
    }
  }

  Future<void> _handleToggleStatus(
    BuildContext context,
    StorageLocation location,
  ) async {
    final cubit = context.read<StorageLocationsManagementCubit>();
    if (location.isActive) {
      final confirmed = await DeactivationConfirmDialog.show(
        context,
        message: AppStrings.deactivateStorageLocationConfirmMessage,
      );
      if (confirmed == true) {
        await cubit.deactivateStorageLocation(location.id);
      }
    } else {
      await cubit.activateStorageLocation(location.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<StorageLocationsManagementCubit,
        StorageLocationsManagementState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: LoadingIndicator());
        }

        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppStrings.tabStorageLocations,
                            style: AppTextStyles.titleLarge),
                        AppSpacing.gapXs,
                        Text(
                          'إدارة أرفف ومواقع تخزين القطع الجاهزة لتسليمها للعملاء',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapHorizontalMd,
                  AppButton(
                    label: AppStrings.addStorageLocation,
                    icon: Icons.add,
                    onPressed: () => _handleAdd(context),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.xxl, color: AppColors.divider),
              if (state.locations.isEmpty)
                EmptyState(
                  icon: Icons.inventory_2_outlined,
                  message: AppStrings.noStorageLocations,
                )
              else
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(4),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(3),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.all(
                            Radius.circular(AppSpacing.radiusSm)),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Text(AppStrings.tableHeaderName,
                              style: AppTextStyles.labelLarge),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Text(AppStrings.tableHeaderStatus,
                              style: AppTextStyles.labelLarge),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Text(AppStrings.tableHeaderActions,
                              style: AppTextStyles.labelLarge),
                        ),
                      ],
                    ),
                    ...state.locations.map((loc) {
                      return TableRow(
                        decoration: const BoxDecoration(
                          border:
                              Border(bottom: BorderSide(color: AppColors.divider)),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Text(loc.name,
                                style: AppTextStyles.titleMedium),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: ActiveStatusBadge(isActive: loc.isActive),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon:
                                      const Icon(Icons.edit_outlined, size: 20),
                                  color: AppColors.primary,
                                  tooltip: AppStrings.edit,
                                  onPressed: () => _handleEdit(context, loc),
                                ),
                                AppSpacing.gapHorizontalSm,
                                TextButton(
                                  onPressed: () =>
                                      _handleToggleStatus(context, loc),
                                  style: TextButton.styleFrom(
                                    foregroundColor: loc.isActive
                                        ? AppColors.error
                                        : AppColors.success,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.sm),
                                  ),
                                  child: Text(
                                    loc.isActive
                                        ? AppStrings.actionDeactivate
                                        : AppStrings.actionActivate,
                                    style: AppTextStyles.labelMedium.copyWith(
                                      color: loc.isActive
                                          ? AppColors.error
                                          : AppColors.success,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
