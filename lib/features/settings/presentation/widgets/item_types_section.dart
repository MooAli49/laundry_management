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
                        Text(AppStrings.tabItemTypes, style: AppTextStyles.titleLarge),
                        AppSpacing.gapXs,
                        Text(
                          'إدارة أنواع وتصنيفات الملابس والمفروشات الأساسية',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapHorizontalMd,
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
                    0: FlexColumnWidth(4),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(3),
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
                          child: Text(AppStrings.tableHeaderStatus, style: AppTextStyles.labelLarge),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Text(AppStrings.tableHeaderActions, style: AppTextStyles.labelLarge),
                        ),
                      ],
                    ),
                    ...state.itemTypes.map((type) {
                      return TableRow(
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: AppColors.divider)),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Text(type.name, style: AppTextStyles.titleMedium),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: ActiveStatusBadge(isActive: type.isActive),
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
                                  onPressed: () => _handleEdit(context, type),
                                ),
                                AppSpacing.gapHorizontalSm,
                                TextButton(
                                  onPressed: () => _handleToggleStatus(context, type),
                                  style: TextButton.styleFrom(
                                    foregroundColor: type.isActive ? AppColors.error : AppColors.success,
                                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                                  ),
                                  child: Text(
                                    type.isActive ? AppStrings.actionDeactivate : AppStrings.actionActivate,
                                    style: AppTextStyles.labelMedium.copyWith(
                                      color: type.isActive ? AppColors.error : AppColors.success,
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
