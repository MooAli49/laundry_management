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
import '../../../../domain/entities/item_definition.dart';
import '../cubit/item_types_management_cubit.dart';
import '../cubit/item_types_management_state.dart';
import 'active_status_badge.dart';
import 'deactivation_confirm_dialog.dart';
import 'item_definition_form_dialog.dart';

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

        final filteredDefs = state.filteredDefinitions;

        // Find type name map for fast display
        final typeNameMap = {for (var t in state.itemTypes) t.id: t.name};

        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with filter and Add button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppStrings.tabItemDefinitions, style: AppTextStyles.titleLarge),
                        AppSpacing.gapXs,
                        Text(
                          'إدارة القطع والتعريفات التابعة لكل نوع (مثل قميص، بنطلون، بطانية)',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapHorizontalMd,
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Filter dropdown
                      Text(
                        AppStrings.filterDefinitionsByItemType,
                        style: AppTextStyles.labelLarge,
                      ),
                      AppSpacing.gapHorizontalSm,
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: state.selectedFilterItemTypeId,
                            hint: Text(AppStrings.allItemDefinitions, style: AppTextStyles.bodyMedium),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(AppStrings.allItemDefinitions, style: AppTextStyles.bodyMedium),
                              ),
                              ...state.itemTypes.map((type) {
                                return DropdownMenuItem<String?>(
                                  value: type.id,
                                  child: Text(type.name, style: AppTextStyles.bodyMedium),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              context.read<ItemTypesManagementCubit>().selectFilterItemType(val);
                            },
                          ),
                        ),
                      ),
                      AppSpacing.gapHorizontalLg,
                      AppButton(
                        label: AppStrings.addItemDefinition,
                        icon: Icons.add,
                        onPressed: () => _handleAdd(context, state),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: AppSpacing.xxl, color: AppColors.divider),
              if (filteredDefs.isEmpty)
                EmptyState(
                  icon: Icons.style_outlined,
                  message: AppStrings.noItemDefinitions,
                )
              else
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(4),
                    1: FlexColumnWidth(3),
                    2: FlexColumnWidth(2),
                    3: FlexColumnWidth(3),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusSm)),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Text(AppStrings.tableHeaderName, style: AppTextStyles.labelLarge),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Text(AppStrings.tableHeaderItemType, style: AppTextStyles.labelLarge),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Text(AppStrings.tableHeaderStatus, style: AppTextStyles.labelLarge),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Text(AppStrings.tableHeaderActions, style: AppTextStyles.labelLarge),
                        ),
                      ],
                    ),
                    ...filteredDefs.map((def) {
                      final typeName = typeNameMap[def.itemTypeId] ?? '';

                      return TableRow(
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: AppColors.divider)),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Text(def.name, style: AppTextStyles.titleMedium),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Text(typeName, style: AppTextStyles.bodyMedium),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: ActiveStatusBadge(isActive: def.isActive),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  color: AppColors.primary,
                                  tooltip: AppStrings.edit,
                                  onPressed: () => _handleEdit(context, def, state),
                                ),
                                AppSpacing.gapHorizontalSm,
                                TextButton(
                                  onPressed: () => _handleToggleStatus(context, def),
                                  style: TextButton.styleFrom(
                                    foregroundColor: def.isActive ? AppColors.error : AppColors.success,
                                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                                  ),
                                  child: Text(
                                    def.isActive ? AppStrings.actionDeactivate : AppStrings.actionActivate,
                                    style: AppTextStyles.labelMedium.copyWith(
                                      color: def.isActive ? AppColors.error : AppColors.success,
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
