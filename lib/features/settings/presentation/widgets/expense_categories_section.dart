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
import '../../../../domain/entities/expense_category.dart';
import '../cubit/expense_categories_management_cubit.dart';
import '../cubit/expense_categories_management_state.dart';
import 'active_status_badge.dart';
import 'deactivation_confirm_dialog.dart';
import 'expense_category_form_dialog.dart';
import 'settings_table_components.dart';

class ExpenseCategoriesSection extends StatelessWidget {
  const ExpenseCategoriesSection({super.key});

  Future<void> _handleAdd(BuildContext context) async {
    await ExpenseCategoryFormDialog.show(context);
  }

  Future<void> _handleEdit(
    BuildContext context,
    ExpenseCategory category,
  ) async {
    await ExpenseCategoryFormDialog.show(context, category: category);
  }

  Future<void> _handleToggleStatus(
    BuildContext context,
    ExpenseCategory category,
  ) async {
    final cubit = context.read<ExpenseCategoriesManagementCubit>();
    if (category.isActive) {
      final confirmed = await DeactivationConfirmDialog.show(
        context,
        message: AppStrings.deactivateExpenseCategoryConfirmMessage,
      );
      if (confirmed == true) {
        await cubit.deactivateCategory(category.id);
      }
    } else {
      await cubit.activateCategory(category.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExpenseCategoriesManagementCubit,
        ExpenseCategoriesManagementState>(
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
                title: AppStrings.tabExpenseCategories,
                subtitle: 'إدارة بنود وتصنيفات المصروفات التشغيلية للمغسلة',
                actions: [
                  AppButton(
                    label: AppStrings.addExpenseCategory,
                    icon: Icons.add,
                    onPressed: () => _handleAdd(context),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.xxl, color: AppColors.divider),
              if (state.categories.isEmpty)
                EmptyState(
                  icon: Icons.receipt_long_outlined,
                  message: AppStrings.noExpenseCategories,
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
                    ...state.categories.map((cat) {
                      return TableRow(
                        decoration: SettingsTableHelper.rowDecoration,
                        children: [
                          Padding(
                            padding: SettingsTableHelper.cellPadding,
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary,
                                    borderRadius:
                                        BorderRadius.circular(AppSpacing.radiusSm),
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet_outlined,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                ),
                                AppSpacing.gapHorizontalSm,
                                Expanded(
                                  child: Text(
                                    cat.name,
                                    style: AppTextStyles.titleMedium.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: SettingsTableHelper.cellPadding,
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: ActiveStatusBadge(isActive: cat.isActive),
                            ),
                          ),
                          Padding(
                            padding: SettingsTableHelper.cellPadding,
                            child: SettingsRowActions(
                              onEdit: () => _handleEdit(context, cat),
                              onToggleStatus: () => _handleToggleStatus(context, cat),
                              isActive: cat.isActive,
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
