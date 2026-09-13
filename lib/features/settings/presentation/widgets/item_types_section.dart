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
import '../../../../domain/entities/item_type.dart';
import '../cubit/item_types_management_cubit.dart';
import '../cubit/item_types_management_state.dart';
import 'active_status_badge.dart';
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

  Future<void> _handleToggleStatus(BuildContext context, ItemType itemType) async {
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

        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SettingsSectionHeader(
                title: AppStrings.tabItemTypes,
                subtitle: 'إدارة أنواع وتصنيفات الملابس والمفروشات الأساسية',
                actions: [
                  AppButton(
                    label: AppStrings.addItemType,
                    icon: Icons.add,
                    onPressed: () => _handleAdd(context),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.xxl, color: AppColors.divider),
              if (state.itemTypes.isEmpty)
                EmptyState(
                  icon: Icons.category_outlined,
                  message: AppStrings.noItemTypes,
                )
              else
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(4.5),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(3),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    SettingsTableHelper.buildHeaderRow([
                      AppStrings.tableHeaderName,
                      AppStrings.tableHeaderStatus,
                      AppStrings.tableHeaderActions,
                    ]),
                    ...state.itemTypes.map((type) {
                      return TableRow(
                        decoration: SettingsTableHelper.rowDecoration,
                        children: [
                          Padding(
                            padding: SettingsTableHelper.cellPadding,
                            child: Text(
                              type.name,
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Padding(
                            padding: SettingsTableHelper.cellPadding,
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: ActiveStatusBadge(isActive: type.isActive),
                            ),
                          ),
                          Padding(
                            padding: SettingsTableHelper.cellPadding,
                            child: SettingsRowActions(
                              onEdit: () => _handleEdit(context, type),
                              onToggleStatus: () => _handleToggleStatus(context, type),
                              isActive: type.isActive,
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
