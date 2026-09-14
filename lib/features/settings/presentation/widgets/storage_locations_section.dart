import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../domain/entities/storage_location.dart';
import '../cubit/storage_locations_management_cubit.dart';
import '../cubit/storage_locations_management_state.dart';
import 'deactivation_confirm_dialog.dart';
import 'settings_table_components.dart';
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsTopHeader(
              title: AppStrings.tabStorageLocations,
              count: state.locations.length,
              countLabel: 'مواقع',
              actionLabel: AppStrings.addStorageLocation,
              onAction: () => _handleAdd(context),
            ),
            if (state.locations.isEmpty)
              AppCard(
                child: EmptyState(
                  icon: Icons.inventory_2_outlined,
                  message: AppStrings.noStorageLocations,
                ),
              )
            else
              SettingsCardGrid(
                children: [
                  for (final loc in state.locations)
                    SettingsCard(
                      icon: Icons.location_on_outlined,
                      title: loc.name,
                      subtitle: 'جاهز للتخزين',
                      secondarySubtitle: 'كل أنواع القطع',
                      isActive: loc.isActive,
                      onEdit: () => _handleEdit(context, loc),
                      onToggleActive: (_) => _handleToggleStatus(context, loc),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}
