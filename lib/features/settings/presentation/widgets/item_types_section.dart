import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../domain/entities/item_type.dart';
import '../cubit/item_types_management_cubit.dart';
import '../cubit/item_types_management_state.dart';
import 'deactivation_confirm_dialog.dart';
import 'item_type_form_dialog.dart';
import 'settings_table_components.dart';

class ItemTypesSection extends StatelessWidget {
  const ItemTypesSection({super.key});

  Future<void> _handleAdd(BuildContext context) async {
    await ItemTypeFormDialog.show(context);
  }

  Future<void> _handleEdit(BuildContext context, ItemType itemType) async {
    await ItemTypeFormDialog.show(context, itemType: itemType);
  }

  Future<void> _handleToggleStatus(
    BuildContext context,
    ItemType itemType,
  ) async {
    final cubit = context.read<ItemTypesManagementCubit>();
    if (itemType.isActive) {
      final confirmed = await DeactivationConfirmDialog.show(
        context,
        message: AppStrings.deactivateItemTypeConfirmMessage,
      );
      if (confirmed == true) {
        await cubit.deactivateItemType(itemType.id);
      }
    } else {
      await cubit.activateItemType(itemType.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ItemTypesManagementCubit, ItemTypesManagementState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.error,
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
              title: AppStrings.tabItemTypes,
              count: state.itemTypes.length,
              countLabel: 'أنواع',
              actionLabel: AppStrings.addItemType,
              onAction: () => _handleAdd(context),
            ),
            if (state.itemTypes.isEmpty)
              AppCard(
                child: EmptyState(
                  icon: Icons.category_outlined,
                  message: AppStrings.noItemTypes,
                ),
              )
            else
              SettingsCardGrid(
                children: [
                  for (final type in state.itemTypes)
                    SettingsCard(
                      icon: Icons.inventory_2_outlined,
                      title: type.name,
                      subtitle:
                          '${state.getDefinitionCountForType(type.id)} تعريفات متاحة',
                      isActive: type.isActive,
                      onEdit: () => _handleEdit(context, type),
                      onToggleActive: (_) => _handleToggleStatus(context, type),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}
