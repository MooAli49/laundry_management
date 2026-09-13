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

        final filteredDefs = state.filteredDefinitions;
        final typeNameMap = {for (var t in state.itemTypes) t.id: t.name};

        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SettingsSectionHeader(
                title: AppStrings.tabItemDefinitions,
                subtitle: 'إدارة القطع والتعريفات التابعة لكل نوع (مثل قميص، بنطلون، بطانية)',
                actions: [
                  // Filter dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 2.0,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.filter_list_outlined,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        AppSpacing.gapHorizontalSm,
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: state.selectedFilterItemTypeId,
                            hint: Text(
                              AppStrings.allItemDefinitions,
                              style: AppTextStyles.bodyMedium,
                            ),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                  AppStrings.allItemDefinitions,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              ...state.itemTypes.map((type) {
                                return DropdownMenuItem<String?>(
                                  value: type.id,
                                  child: Text(
                                    type.name,
                                    style: AppTextStyles.bodyMedium,
                                  ),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              context
                                  .read<ItemTypesManagementCubit>()
                                  .selectFilterItemType(val);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppButton(
                    label: AppStrings.addItemDefinition,
                    icon: Icons.add,
                    onPressed: () => _handleAdd(context, state),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.xxl, color: AppColors.divider),
              if (filteredDefs.isEmpty)
                EmptyState(
                  icon: Icons.list_alt_outlined,
                  message: AppStrings.noItemDefinitions,
                )
              else
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(4),
                    1: FlexColumnWidth(3),
                    2: FlexColumnWidth(2),
                    3: FlexColumnWidth(2.8),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    SettingsTableHelper.buildHeaderRow([
                      AppStrings.tableHeaderName,
                      AppStrings.tableHeaderItemType,
                      AppStrings.tableHeaderStatus,
                      AppStrings.tableHeaderActions,
                    ]),
                    ...filteredDefs.map((def) {
                      final typeName = typeNameMap[def.itemTypeId] ?? '-';
                      return TableRow(
                        decoration: SettingsTableHelper.rowDecoration,
                        children: [
                          Padding(
                            padding: SettingsTableHelper.cellPadding,
                            child: Text(
                              def.name,
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Padding(
                            padding: SettingsTableHelper.cellPadding,
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusSm,
                                  ),
                                ),
                                child: Text(
                                  typeName,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: SettingsTableHelper.cellPadding,
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: ActiveStatusBadge(isActive: def.isActive),
                            ),
                          ),
                          Padding(
                            padding: SettingsTableHelper.cellPadding,
                            child: SettingsRowActions(
                              onEdit: () => _handleEdit(context, def, state),
                              onToggleStatus: () => _handleToggleStatus(context, def),
                              isActive: def.isActive,
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
