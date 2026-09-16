import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../domain/entities/expense_category.dart';
import '../cubit/expense_categories_management_cubit.dart';
import '../cubit/expense_categories_management_state.dart';
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
    return BlocConsumer<
      ExpenseCategoriesManagementCubit,
      ExpenseCategoriesManagementState
    >(
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
              title: AppStrings.tabExpenseCategories,
              count: state.categories.length,
              countLabel: 'عنصر',
              actionLabel: AppStrings.addExpenseCategory,
              onAction: () => _handleAdd(context),
            ),
            const SettingsInfoBanner(
              message:
                  'المصروفات السابقة تبقى محفوظة بتصنيفها الأصلي حتى إذا تم تعطيل التصنيف أو تعديله.',
            ),
            if (state.categories.isEmpty)
              AppCard(
                child: EmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  message: AppStrings.noExpenseCategories,
                ),
              )
            else
              SettingsCardGrid(
                children: [
                  for (final cat in state.categories)
                    SettingsCard(
                      icon: Icons.account_balance_wallet_outlined,
                      title: cat.name,
                      subtitle: '0 مصروف مسجّل',
                      isActive: cat.isActive,
                      onEdit: () => _handleEdit(context, cat),
                      onToggleActive: (_) => _handleToggleStatus(context, cat),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}
