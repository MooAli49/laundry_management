import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/order_status_badge.dart';
import '../../../../domain/enums/order_status.dart';
import '../../../../domain/value_objects/money.dart';
import '../cubit/customer_detail_cubit.dart';
import '../cubit/customer_detail_state.dart';
import '../widgets/customer_form_dialog.dart';

class CustomerDetailScreen extends StatelessWidget {
  final String customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<CustomerDetailCubit>()..loadCustomerDetail(customerId),
      child: _CustomerDetailView(customerId: customerId),
    );
  }
}

class _CustomerDetailView extends StatelessWidget {
  final String customerId;

  const _CustomerDetailView({required this.customerId});

  void _showEditCustomerDialog(
    BuildContext context,
    CustomerDetailState state,
  ) {
    if (state.data == null) return;
    final cubit = context.read<CustomerDetailCubit>();
    final customer = state.data!.customer;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return CustomerFormDialog(
          customer: customer,
          onSave: ({required name, required phone, address, notes}) async {
            await cubit.updateCustomerInfo(
              name: name,
              phone: phone,
              address: address,
              notes: notes,
            );
          },
          onFindDuplicate: cubit.getCustomerByPhone,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CustomerDetailCubit>();

    return Scaffold(
      body: BlocConsumer<CustomerDetailCubit, CustomerDetailState>(
        listener: (context, state) {
          if (state.actionSuccessMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.actionSuccessMessage!)),
            );
          }
        },
        builder: (context, state) {
          if (state.isLoading && state.data == null) {
            return const Center(child: LoadingIndicator());
          }

          if (state.errorMessage != null && state.data == null) {
            return Center(
              child: AppErrorState(
                title: AppStrings.failedToLoadCustomerDetails,
                message: state.errorMessage!,
                onRetry: () => cubit.loadCustomerDetail(customerId),
              ),
            );
          }

          if (state.data == null) {
            return const Center(
              child: EmptyState(
                title: AppStrings.customerNotFound,
                icon: Icons.person_off_outlined,
              ),
            );
          }

          final data = state.data!;
          final customer = data.customer;

          return RefreshIndicator(
            onRefresh: () => cubit.loadCustomerDetail(customerId),
            child: SingleChildScrollView(
              padding: AppSpacing.paddingPage,
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button and header
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        tooltip: AppStrings.back,
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go(AppRoutes.customers);
                          }
                        },
                      ),
                      AppSpacing.gapHorizontalSm,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer.name,
                              style: AppTextStyles.headlineMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            AppSpacing.gapXs,
                            Row(
                              children: [
                                const Icon(
                                  Icons.phone_outlined,
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                                AppSpacing.gapHorizontalXs,
                                Text(
                                  customer.phone,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                  textDirection: TextDirection.ltr,
                                ),
                              ],
                            ),
                            if (customer.address != null &&
                                customer.address!.trim().isNotEmpty) ...[
                              AppSpacing.gapXs,
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                  AppSpacing.gapHorizontalXs,
                                  Expanded(
                                    child: Text(
                                      customer.address!.trim(),
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      AppSpacing.gapHorizontalMd,
                      AppButton(
                        label: AppStrings.createOrder,
                        icon: Icons.add,
                        onPressed: () {
                          context
                              .push(
                                '${AppRoutes.ordersNew}?customerId=${customer.id}',
                              )
                              .then(
                                (_) => cubit.loadCustomerDetail(customerId),
                              );
                        },
                      ),
                      AppSpacing.gapHorizontalSm,
                      AppButton(
                        label: AppStrings.editCustomer,
                        variant: AppButtonVariant.secondary,
                        icon: Icons.edit_outlined,
                        onPressed: () =>
                            _showEditCustomerDialog(context, state),
                      ),
                    ],
                  ),

                  if (customer.notes != null &&
                      customer.notes!.trim().isNotEmpty) ...[
                    AppSpacing.gapMd,
                    Container(
                      width: double.infinity,
                      padding: AppSpacing.paddingMd,
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.notes_outlined,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          AppSpacing.gapHorizontalSm,
                          Expanded(
                            child: Text(
                              customer.notes!,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  AppSpacing.gapXl,

                  // Summary KPI Cards (2 Rows)
                  // Row 1: Order Counts
                  Row(
                    children: [
                      Expanded(
                        child: _KpiCard(
                          title: AppStrings.totalOrders,
                          value: '${data.totalOrdersCount}',
                          icon: Icons.receipt_long_outlined,
                          color: AppColors.primary,
                          backgroundColor: AppColors.primaryLighter,
                        ),
                      ),
                      AppSpacing.gapHorizontalMd,
                      Expanded(
                        child: _KpiCard(
                          title: AppStrings.activeOrders,
                          value: '${data.activeOrdersCount}',
                          icon: Icons.pending_actions_outlined,
                          color: AppColors.warning,
                          backgroundColor: AppColors.warningLight,
                        ),
                      ),
                      AppSpacing.gapHorizontalMd,
                      Expanded(
                        child: _KpiCard(
                          title: AppStrings.completedOrders,
                          value: '${data.completedOrdersCount}',
                          icon: Icons.check_circle_outline,
                          color: AppColors.success,
                          backgroundColor: AppColors.successLight,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapMd,
                  // Row 2: Financial Summary — Payments & Refunds
                  Row(
                    children: [
                      Expanded(
                        child: _KpiCard(
                          title: AppStrings.totalPayments,
                          subtitle: 'المدفوعات المسجلة للعميل',
                          value:
                              '${data.totalPaid.toEgp.toStringAsFixed(2)} ${AppStrings.currency}',
                          icon: Icons.payments_outlined,
                          color: AppColors.info,
                          backgroundColor: AppColors.infoLight,
                          isFinancial: true,
                        ),
                      ),
                      AppSpacing.gapHorizontalMd,
                      Expanded(
                        child: _KpiCard(
                          title: AppStrings.totalRefunds,
                          subtitle: 'المبالغ المستردة للعميل',
                          value:
                              '${data.totalRefunds.toEgp.toStringAsFixed(2)} ${AppStrings.currency}',
                          icon: Icons.assignment_return_outlined,
                          color: data.totalRefunds.isPositive
                              ? AppColors.warning
                              : AppColors.textSecondary,
                          backgroundColor: data.totalRefunds.isPositive
                              ? AppColors.warningLight
                              : AppColors.backgroundSecondary,
                          isFinancial: true,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapMd,
                  // Row 3: Financial Summary — Net Paid & Outstanding
                  Row(
                    children: [
                      Expanded(
                        child: _KpiCard(
                          title: AppStrings.netPaid,
                          subtitle: 'المدفوعات − الاستردادات',
                          value:
                              '${data.netPaid.toEgp.toStringAsFixed(2)} ${AppStrings.currency}',
                          icon: Icons.account_balance_outlined,
                          color: AppColors.success,
                          backgroundColor: AppColors.successLight,
                          isFinancial: true,
                        ),
                      ),
                      AppSpacing.gapHorizontalMd,
                      Expanded(
                        child: _KpiCard(
                          title: AppStrings.outstandingAmounts,
                          subtitle: 'على الطلبات غير الملغاة',
                          value:
                              '${data.totalRemaining.toEgp.toStringAsFixed(2)} ${AppStrings.currency}',
                          icon: Icons.hourglass_bottom,
                          color: data.totalRemaining.isZero
                              ? AppColors.textSecondary
                              : AppColors.warning,
                          backgroundColor: data.totalRemaining.isZero
                              ? AppColors.backgroundSecondary
                              : AppColors.warningLight,
                          isFinancial: true,
                        ),
                      ),
                    ],
                  ),

                  AppSpacing.gapXl,

                  // Order History Section Header
                  Text(
                    AppStrings.orderHistoryWithCount(data.totalOrdersCount),
                    style: AppTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AppSpacing.gapMd,

                  // Orders List or Empty State
                  if (data.orders.isEmpty)
                    EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: AppStrings.noOrdersForCustomer,
                      message: AppStrings.createFirstOrderForCustomerPrompt,
                      actionButton: AppButton(
                        label: AppStrings.createOrder,
                        icon: Icons.add,
                        onPressed: () {
                          context
                              .push(
                                '${AppRoutes.ordersNew}?customerId=${customer.id}',
                              )
                              .then(
                                (_) => cubit.loadCustomerDetail(customerId),
                              );
                        },
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: data.orders.length,
                      separatorBuilder: (_, __) => AppSpacing.gapSm,
                      itemBuilder: (context, index) {
                        final order = data.orders[index];
                        final summary = data.paymentSummaries[order.id];
                        final isCancelled =
                            order.status == OrderStatus.cancelled;
                        final paid =
                            summary?.totalPaid ??
                            data.paidAmounts[order.id] ??
                            Money.zero;
                        final refunded = summary?.totalRefunded ?? Money.zero;
                        final remaining =
                            isCancelled
                                ? Money.zero
                                : (summary?.remaining ??
                                    data.remainingAmounts[order.id] ??
                                    Money.zero);
                        final isFullyPaid = remaining.isZero;

                        return AppCard(
                          onTap: () {
                            context
                                .push(AppRoutes.orderDetailPath(order.id))
                                .then(
                                  (_) => cubit.loadCustomerDetail(customerId),
                                );
                          },
                          padding: AppSpacing.paddingMd,
                          child: Row(
                            children: [
                              // Order Icon
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isCancelled
                                      ? AppColors.backgroundSecondary
                                      : AppColors.primaryLighter,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusSm,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.receipt_outlined,
                                  color: isCancelled
                                      ? AppColors.textSecondary
                                      : AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              AppSpacing.gapHorizontalMd,

                              // Order Number & Date
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          order.orderNumber.startsWith('#')
                                              ? order.orderNumber
                                              : '#${order.orderNumber}',
                                          textDirection: TextDirection.ltr,
                                          style: AppTextStyles.titleMedium
                                              .copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        AppSpacing.gapHorizontalSm,
                                        OrderStatusBadge(status: order.status),
                                      ],
                                    ),
                                    AppSpacing.gapXs,
                                    Text(
                                      DateFormatter.formatDMY(order.createdAt),
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Amounts: Total, Paid & Remaining (and Refunded if cancelled or exists)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    AppStrings.totalAmount(
                                      order.total.toEgp.toStringAsFixed(2),
                                    ),
                                    style: AppTextStyles.titleSmall.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isCancelled
                                          ? AppColors.textSecondary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  AppSpacing.gapXs,
                                  Text(
                                    AppStrings.paidAmount(
                                      paid.toEgp.toStringAsFixed(2),
                                    ),
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  if (refunded.isPositive || isCancelled) ...[
                                    AppSpacing.gapXs,
                                    Text(
                                      AppStrings.refundedAmount(
                                        refunded.toEgp.toStringAsFixed(2),
                                      ),
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: refunded.isPositive
                                            ? AppColors.warning
                                            : AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                  AppSpacing.gapXs,
                                  Text(
                                    isCancelled
                                        ? AppStrings.remainingAmount('0.00')
                                        : isFullyPaid
                                            ? AppStrings.fullyPaid
                                            : AppStrings.remainingAmount(
                                                remaining.toEgp.toStringAsFixed(2),
                                              ),
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: isCancelled
                                          ? AppColors.textSecondary
                                          : isFullyPaid
                                              ? AppColors.success
                                              : AppColors.warning,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              AppSpacing.gapHorizontalSm,

                              // Forward Chevron
                              const Icon(
                                Icons.chevron_left,
                                color: AppColors.textTertiary,
                                size: 20,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  if (state.hasMoreOrders) ...[
                    AppSpacing.gapMd,
                    Center(
                      child: AppButton(
                        label: AppStrings.loadMoreOrders,
                        variant: AppButtonVariant.secondary,
                        icon: Icons.expand_more,
                        isLoading: state.isLoadingMore,
                        onPressed: () => cubit.loadMoreOrders(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String value;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final bool isFinancial;

  const _KpiCard({
    required this.title,
    this.subtitle,
    required this.value,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    this.isFinancial = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: AppSpacing.paddingMd,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 24),
          ),
          AppSpacing.gapHorizontalMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
                AppSpacing.gapXs,
                Text(
                  value,
                  style: isFinancial
                      ? AppTextStyles.headlineSmall.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        )
                      : AppTextStyles.headlineMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
