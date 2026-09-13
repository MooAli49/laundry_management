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
                        Text(AppStrings.tabExpenseCategories,
                            style: AppTextStyles.titleLarge),
                        AppSpacing.gapXs,
                        Text(
                          'إدارة بنود وتصنيفات المصروفات التشغيلية للمغسلة',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapHorizontalMd,
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
                    ...state.categories.map((cat) {
                      return TableRow(
                        decoration: const BoxDecoration(
                          border:
                              Border(bottom: BorderSide(color: AppColors.divider)),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Text(cat.name,
                                style: AppTextStyles.titleMedium),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: ActiveStatusBadge(isActive: cat.isActive),
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
                                  onPressed: () => _handleEdit(context, cat),
                                ),
                                AppSpacing.gapHorizontalSm,
                                TextButton(
                                  onPressed: () =>
                                      _handleToggleStatus(context, cat),
                                  style: TextButton.styleFrom(
                                    foregroundColor: cat.isActive
                                        ? AppColors.error
                                        : AppColors.success,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.sm),
                                  ),
                                  child: Text(
                                    cat.isActive
                                        ? AppStrings.actionDeactivate
                                        : AppStrings.actionActivate,
                                    style: AppTextStyles.labelMedium.copyWith(
                                      color: cat.isActive
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
