import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../customers/presentation/cubit/customers_list_cubit.dart';
import '../../../customers/presentation/widgets/customer_form_dialog.dart';
import '../../../expenses/presentation/widgets/add_expense_dialog.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';
import '../widgets/dashboard_attention_section.dart';
import '../widgets/dashboard_metric_card.dart';
import '../widgets/dashboard_recent_orders_section.dart';
import '../widgets/dashboard_today_pickups_section.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<DashboardCubit>()..loadDashboard(),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  void _openAddCustomerDialog(BuildContext context) {
    final cubit = getIt<CustomersListCubit>();
    showDialog(
      context: context,
      builder: (ctx) => CustomerFormDialog(
        onSave: ({required name, required phone, notes}) async {
          await cubit.createCustomer(
            name: name,
            phone: phone,
            notes: notes,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تمت إضافة العميل بنجاح')),
            );
          }
        },
        onFindDuplicate: cubit.getCustomerByPhone,
      ),
    );
  }

  void _openAddExpenseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AddExpenseDialog(
        onExpenseCreated: (_) async {
          if (context.mounted) {
            context.read<DashboardCubit>().refresh();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: AppSpacing.paddingPage,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            PageHeader(
              title: AppStrings.dashboard,
              subtitle: 'نظرة عامة على العمليات التشغيلية والإجراءات اليومية',
              actions: [
                IconButton(
                  tooltip: 'تحديث',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => context.read<DashboardCubit>().refresh(),
                ),
              ],
            ),

            // Quick Actions Bar
            Text('الإجراءات السريعة', style: AppTextStyles.titleLarge),
            AppSpacing.gapMd,
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                AppButton(
                  key: const ValueKey('dashboard_add_order_button'),
                  label: 'إضافة طلب',
                  icon: Icons.add,
                  variant: AppButtonVariant.primary,
                  onPressed: () => context.push(AppRoutes.ordersNew),
                ),
                AppButton(
                  key: const ValueKey('dashboard_add_customer_button'),
                  label: 'إضافة عميل',
                  icon: Icons.person_add_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => _openAddCustomerDialog(context),
                ),
                AppButton(
                  key: const ValueKey('dashboard_record_payment_button'),
                  label: 'تسجيل دفعة',
                  icon: Icons.payment_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => context.push(AppRoutes.orders),
                ),
                AppButton(
                  key: const ValueKey('dashboard_add_expense_button'),
                  label: 'إضافة مصروف',
                  icon: Icons.shopping_bag_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => _openAddExpenseDialog(context),
                ),
              ],
            ),
            AppSpacing.gapXxl,

            BlocBuilder<DashboardCubit, DashboardState>(
              builder: (context, state) {
                if (state.isLoading && state.data.todayOrdersCount == 0 && state.data.recentOrders.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
                    child: Center(
                      child: LoadingIndicator(message: 'جاري تحميل بيانات الرئيسية...'),
                    ),
                  );
                }

                if (state.errorMessage != null && state.data.todayOrdersCount == 0 && state.data.recentOrders.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
                    child: AppErrorState(
                      title: 'تعذر تحميل بيانات الرئيسية',
                      message: state.errorMessage!,
                      onRetry: () => context.read<DashboardCubit>().loadDashboard(),
                    ),
                  );
                }

                final data = state.data;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Operational Summary Header
                    Text('ملخص اليوم', style: AppTextStyles.titleLarge),
                    AppSpacing.gapMd,

                    // Operational Summary — Exactly 4 cards
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isSmall = constraints.maxWidth < 650;
                        final isMedium = constraints.maxWidth < 1100;
                        final cardWidth = isSmall
                            ? constraints.maxWidth
                            : isMedium
                                ? (constraints.maxWidth - AppSpacing.md) / 2
                                : (constraints.maxWidth - (AppSpacing.md * 3)) / 4;

                        return Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.md,
                          children: [
                            SizedBox(
                              width: cardWidth,
                              child: DashboardMetricCard(
                                title: 'طلبات اليوم',
                                value: '${data.todayOrdersCount}',
                                icon: Icons.receipt_long_outlined,
                                subtitle: 'إجمالي الطلبات المستلمة اليوم',
                                onTap: () => context.push(AppRoutes.orders),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: DashboardMetricCard(
                                title: 'قيد التنفيذ',
                                value: '${data.processingOrdersCount}',
                                icon: Icons.sync,
                                iconColor: AppColors.info,
                                iconBackground: AppColors.infoLight,
                                subtitle: 'طلبات جاري العمل عليها',
                                onTap: () => context.push(AppRoutes.orders),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: DashboardMetricCard(
                                title: 'جاهزة للتسليم',
                                value: '${data.readyOrdersCount}',
                                icon: Icons.inventory_2_outlined,
                                iconColor: AppColors.warning,
                                iconBackground: AppColors.warningLight,
                                subtitle: 'طلبات جاهزة لتسليم العملاء',
                                onTap: () => context.push(AppRoutes.orders),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: DashboardMetricCard(
                                title: 'مبالغ متبقية',
                                value: '${data.totalRemainingAmount.toEgp.toStringAsFixed(2)} ج.م',
                                icon: Icons.payments_outlined,
                                iconColor: data.totalRemainingAmount.isPositive
                                    ? AppColors.warning
                                    : AppColors.textSecondary,
                                iconBackground: data.totalRemainingAmount.isPositive
                                    ? AppColors.warningLight
                                    : AppColors.backgroundSecondary,
                                valueColor: data.totalRemainingAmount.isPositive
                                    ? AppColors.warning
                                    : null,
                                subtitle: 'متبقي على طلبات العملاء',
                                onTap: () => context.push(AppRoutes.orders),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    AppSpacing.gapXxl,

                    // Main Operational Content — Responsive RTL Tablet Layout
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isTablet = constraints.maxWidth >= 850;

                        if (isTablet) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Right / Start in RTL: Attention Required
                              Expanded(
                                flex: 5,
                                child: DashboardAttentionSection(data: data),
                              ),
                              AppSpacing.gapHorizontalXl,
                              // Left / End in RTL: Today's Pickups & Recent Orders
                              Expanded(
                                flex: 6,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    DashboardTodayPickupsSection(
                                      orders: data.todayPickupOrders,
                                    ),
                                    AppSpacing.gapXxl,
                                    DashboardRecentOrdersSection(
                                      orders: data.recentOrders,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DashboardAttentionSection(data: data),
                              AppSpacing.gapXxl,
                              DashboardTodayPickupsSection(
                                orders: data.todayPickupOrders,
                              ),
                              AppSpacing.gapXxl,
                              DashboardRecentOrdersSection(
                                orders: data.recentOrders,
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
