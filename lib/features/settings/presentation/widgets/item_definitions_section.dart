import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../domain/entities/item_definition.dart';
import '../cubit/item_types_management_cubit.dart';
import '../cubit/item_types_management_state.dart';
import 'deactivation_confirm_dialog.dart';
import 'item_definition_form_dialog.dart';
import 'settings_table_components.dart';

class ItemDefinitionsSection extends StatelessWidget {
  const ItemDefinitionsSection({super.key});

  Future<void> _handleAdd(BuildContext context, ItemTypesManagementState state) async {
    final activeTypes = state.itemTypes.where((t) => t.isActive).toList();
    if (activeTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب إضافة وتفعيل نوع قطعة أولاً قبل إضافة تعريفات'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    await ItemDefinitionFormDialog.show(
      context,
      availableItemTypes: activeTypes,
      preselectedItemTypeId: state.selectedFilterItemTypeId,
    );
  }

  Future<void> _handleEdit(
    BuildContext context,
    ItemDefinition definition,
    ItemTypesManagementState state,
  ) async {
    await ItemDefinitionFormDialog.show(
      context,
      definition: definition,
      availableItemTypes: state.itemTypes,
    );
  }

  Future<void> _handleToggleStatus(BuildContext context, ItemDefinition definition) async {
    final cubit = context.read<ItemTypesManagementCubit>();
    if (definition.isActive) {
      final confirmed = await DeactivationConfirmDialog.show(
        context,
        message: AppStrings.deactivateItemDefinitionConfirmMessage,
      );
      if (confirmed == true) {
        await cubit.deactivateItemDefinition(definition.id);
      }
    } else {
      await cubit.activateItemDefinition(definition.id);
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

        final typeNameMap = {for (var t in state.itemTypes) t.id: t.name};
        final groupedDefs = <String, List<ItemDefinition>>{};
        for (final def in state.definitions) {
          groupedDefs.putIfAbsent(def.itemTypeId, () => []).add(def);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsTopHeader(
              title: AppStrings.tabItemDefinitions,
              count: state.definitions.length,
              countLabel: 'عنصر',
              actionLabel: AppStrings.addItemDefinition,
              onAction: () => _handleAdd(context, state),
            ),
            const SettingsInfoBanner(
              message:
                  'تعريف القطعة نوع فرعي يتبع نوع قطعة (مثل: عجمي، صوف، حرير للسجاد). يظهر في الطلب الجديد فقط عندما يمتلك نوع القطعة تعريفات.',
            ),
            if (state.definitions.isEmpty)
              AppCard(
                child: EmptyState(
                  icon: Icons.list_alt_outlined,
                  message: AppStrings.noItemDefinitions,
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in groupedDefs.entries) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            typeNameMap[entry.key] ?? 'نوع غير معروف',
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${entry.value.length})',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SettingsCardGrid(
                      children: [
                        for (final def in entry.value)
                          SettingsCard(
                            icon: Icons.category_outlined,
                            title: def.name,
                            subtitle: '0 طلب',
                            isActive: def.isActive,
                            onEdit: () => _handleEdit(context, def, state),
                            onToggleActive: (_) => _handleToggleStatus(context, def),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
          ],
        );
      },
    );
  }
}
