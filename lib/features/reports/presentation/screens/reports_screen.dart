import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/page_header.dart';
import '../cubit/reports_cubit.dart';
import '../cubit/reports_state.dart';
import '../widgets/financial_report_view.dart';
import '../widgets/orders_report_view.dart';
import '../widgets/report_period_selector.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ReportsCubit>()..loadReports(),
      child: const _ReportsView(),
    );
  }
}

class _ReportsView extends StatelessWidget {
  const _ReportsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: AppSpacing.paddingPage,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and refresh button
            PageHeader(
              title: AppStrings.reports,
              subtitle: 'متابعة الأداء التشغيلي والمالي للمغسلة',
              actions: [
                IconButton(
                  tooltip: 'تحديث البيانات',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => context.read<ReportsCubit>().refresh(),
                ),
              ],
            ),

            BlocBuilder<ReportsCubit, ReportsState>(
              builder: (context, state) {
                if (state.isLoading && state.startDate == null) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
                    child: Center(
                      child: LoadingIndicator(message: 'جاري تحميل بيانات التقارير...'),
                    ),
                  );
                }

                if (state.errorMessage != null && state.startDate == null) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
                    child: AppErrorState(
                      title: 'تعذر تحميل التقرير',
                      message: state.errorMessage!,
                      onRetry: () => context.read<ReportsCubit>().refresh(),
                    ),
                  );
                }

                if (state.startDate != null) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tab Switcher
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _buildTabSwitcher(context, state.selectedTab),
                      ),
                      AppSpacing.gapLg,

                      // Period Selector
                      ReportPeriodSelector(
                        selectedPeriod: state.selectedPeriod,
                        startDate: state.startDate!,
                        endDate: state.endDate!,
                        onPeriodChanged: (period, {customStart, customEnd}) {
                          context.read<ReportsCubit>().selectPeriod(
                                period,
                                customStart: customStart,
                                customEnd: customEnd,
                              );
                        },
                      ),
                      AppSpacing.gapXxl,

                      // Active Tab View
                      if (state.selectedTab == ReportsTab.orders)
                        OrdersReportView(data: state.ordersReport)
                      else
                        FinancialReportView(
                          data: state.financialReport,
                          onRefresh: () => context.read<ReportsCubit>().refresh(),
                        ),
                    ],
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSwitcher(BuildContext context, ReportsTab activeTab) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabButton(
            context,
            label: 'تقرير الطلبات',
            icon: Icons.receipt_long_outlined,
            isSelected: activeTab == ReportsTab.orders,
            onTap: () => context.read<ReportsCubit>().selectTab(ReportsTab.orders),
          ),
          _buildTabButton(
            context,
            label: 'التقرير المالي',
            icon: Icons.monetization_on_outlined,
            isSelected: activeTab == ReportsTab.financial,
            onTap: () => context.read<ReportsCubit>().selectTab(ReportsTab.financial),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            AppSpacing.gapHorizontalSm,
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
