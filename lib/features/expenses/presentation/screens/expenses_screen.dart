import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../domain/enums/report_period.dart';
import '../cubit/expenses_list_cubit.dart';
import '../cubit/expenses_list_state.dart';
import '../widgets/add_expense_dialog.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ExpensesListCubit>()..loadExpenses(),
      child: const _ExpensesView(),
    );
  }
}

class _ExpensesView extends StatefulWidget {
  const _ExpensesView();

  @override
  State<_ExpensesView> createState() => _ExpensesViewState();
}

class _ExpensesViewState extends State<_ExpensesView> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddExpenseDialog(BuildContext context) {
    final cubit = context.read<ExpensesListCubit>();
    showDialog(
      context: context,
      builder: (ctx) => AddExpenseDialog(
        onExpenseCreated: (_) async {
          await cubit.refresh();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExpensesListCubit>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingPage,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Page Header
              PageHeader(
                title: AppStrings.expenses,
                subtitle: AppStrings.expensesSubtitle,
                actions: [
                  IconButton(
                    tooltip: 'تحديث البيانات',
                    icon: const Icon(Icons.refresh),
                    onPressed: () => cubit.refresh(),
                  ),
                  AppSpacing.gapHorizontalSm,
                  AppButton(
                    key: const ValueKey('add_expense_screen_button'),
                    label: AppStrings.addExpense,
                    icon: Icons.add,
                    onPressed: () => _openAddExpenseDialog(context),
                  ),
                ],
              ),
              AppSpacing.gapLg,

              // 2. Summary KPI Cards
              BlocBuilder<ExpensesListCubit, ExpensesListState>(
                builder: (context, state) {
                  return _buildSummaryCards(context, state);
                },
              ),
              AppSpacing.gapLg,

              // 3. Filters & Search Card
              BlocBuilder<ExpensesListCubit, ExpensesListState>(
                builder: (context, state) {
                  return _buildFilterBar(context, state, cubit);
                },
              ),
              AppSpacing.gapLg,

              // 4. Content Area (Loading / Error / Empty / Data Table)
              BlocBuilder<ExpensesListCubit, ExpensesListState>(
                builder: (context, state) {
                  if (state.isLoading && state.expenses.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
                      child: Center(
                        child: LoadingIndicator(
                          message: 'جاري تحميل المصروفات...',
                        ),
                      ),
                    );
                  }

                  if (state.errorMessage != null && state.expenses.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xxxl,
                      ),
                      child: AppErrorState(
                        title: AppStrings.failedToLoadExpenses,
                        message: state.errorMessage!,
                        onRetry: () => cubit.refresh(),
                      ),
                    );
                  }

                  final filtered = state.filteredExpenses;
                  if (filtered.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return _buildExpensesTable(context, state, filtered);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, ExpensesListState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 650
            ? 1
            : (constraints.maxWidth < 950 ? 2 : 3);
        final cardWidth =
            (constraints.maxWidth - (AppSpacing.md * (columns - 1))) / columns;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: AppStrings.totalExpensesAmount,
                value: '${state.totalAmount.toEgp.toStringAsFixed(2)} ج.م',
                icon: Icons.shopping_bag_outlined,
                iconColor: AppColors.error,
                iconBackground: AppColors.errorLight,
                valueColor: AppColors.error,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: AppStrings.expensesCount,
                value: '${state.totalCount} مصروف',
                icon: Icons.receipt_long_outlined,
                iconColor: AppColors.primary,
                iconBackground: AppColors.surfaceSelected,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: AppStrings.topCategory,
                value: state.topCategory?.name ?? '—',
                subtitle: state.topCategory != null
                    ? '${state.topCategory!.amount.toEgp.toStringAsFixed(2)} ج.م'
                    : 'لا توجد بيانات',
                icon: Icons.category_outlined,
                iconColor: AppColors.warning,
                iconBackground: AppColors.warningLight,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    Color? valueColor,
    String? subtitle,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ],
          ),
          AppSpacing.gapSm,
          Text(
            value,
            style: AppTextStyles.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            AppSpacing.gapXs,
            Text(
              subtitle,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterBar(
    BuildContext context,
    ExpensesListState state,
    ExpensesListCubit cubit,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ReportPeriod.values.map((period) {
                final isSelected = period == state.selectedPeriod;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text(
                      period.label,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isSelected
                            ? AppColors.textOnPrimary
                            : AppColors.textPrimary,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.backgroundSecondary,
                    showCheckmark: false,
                    onSelected: (selected) {
                      if (selected) {
                        cubit.selectPeriod(period);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          AppSpacing.gapMd,

          // Search Field & Category Dropdown
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 600;

              final searchField = TextField(
                controller: _searchController,
                onChanged: cubit.search,
                decoration: InputDecoration(
                  hintText: AppStrings.searchExpensesPlaceholder,
                  hintStyle: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            cubit.search('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.backgroundSecondary,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
              );

              final categoryDropdown = Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: state.selectedCategoryId,
                    isExpanded: true,
                    hint: const Text(AppStrings.allCategories),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text(AppStrings.allCategories),
                      ),
                      ...state.categories.map((cat) {
                        return DropdownMenuItem<String?>(
                          value: cat.id,
                          child: Text(cat.name),
                        );
                      }),
                    ],
                    onChanged: (catId) => cubit.selectCategory(catId),
                  ),
                ),
              );

              if (isSmall) {
                return Column(
                  children: [
                    searchField,
                    AppSpacing.gapSm,
                    categoryDropdown,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 3, child: searchField),
                  AppSpacing.gapHorizontalMd,
                  Expanded(flex: 2, child: categoryDropdown),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xxxl,
        horizontal: AppSpacing.xl,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                color: AppColors.backgroundSecondary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: AppColors.textTertiary,
              ),
            ),
            AppSpacing.gapLg,
            Text(
              AppStrings.noExpenses,
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            AppSpacing.gapSm,
            Text(
              AppStrings.noExpensesPrompt,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            AppSpacing.gapXl,
            AppButton(
              label: AppStrings.addExpense,
              icon: Icons.add,
              onPressed: () => _openAddExpenseDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesTable(
    BuildContext context,
    ExpensesListState state,
    List<dynamic> filtered,
  ) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    AppColors.backgroundSecondary,
                  ),
                  headingRowHeight: 48,
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 56,
                  horizontalMargin: AppSpacing.lg,
                  columnSpacing: AppSpacing.xl,
                  columns: [
                    DataColumn(
                      label: Text(
                        'التاريخ',
                        style: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'التصنيف',
                        style: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'اسم المصروف / الملاحظات',
                        style: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    DataColumn(
                      numeric: true,
                      label: Text(
                        'المبلغ',
                        style: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                  rows: filtered.map((exp) {
                    final hasNotes = exp.notes != null &&
                        exp.notes!.trim().isNotEmpty;
                    final hasName = exp.expenseName != null &&
                        exp.expenseName!.trim().isNotEmpty;

                    String details = '—';
                    if (hasName && hasNotes) {
                      details = '${exp.expenseName} (${exp.notes})';
                    } else if (hasName) {
                      details = exp.expenseName!;
                    } else if (hasNotes) {
                      details = exp.notes!;
                    }

                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            DateFormatter.formatDMY(
                              exp.expenseDate.toDateTime(),
                            ),
                            style: AppTextStyles.bodyMedium,
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSelected,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusSm,
                              ),
                            ),
                            child: Text(
                              exp.categoryNameSnapshot,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            details,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyMedium,
                          ),
                        ),
                        DataCell(
                          Text(
                            '${exp.amount.toEgp.toStringAsFixed(2)} ج.م',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
