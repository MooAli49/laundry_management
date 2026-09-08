import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/page_header.dart';
import '../cubit/orders_list_cubit.dart';
import '../cubit/orders_list_state.dart';
import '../models/order_list_filter.dart';
import '../widgets/order_card.dart';
import '../widgets/orders_filter_bar.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<OrdersListCubit>()..loadOrders(),
      child: const _OrdersView(),
    );
  }
}

class _OrdersView extends StatelessWidget {
  const _OrdersView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OrdersListCubit>();

    return Scaffold(
      body: Padding(
        padding: AppSpacing.paddingPage,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with "+ إضافة طلب" Action
            BlocBuilder<OrdersListCubit, OrdersListState>(
              buildWhen: (prev, curr) => prev.orders.length != curr.orders.length,
              builder: (context, state) {
                return PageHeader(
                  title: AppStrings.orders,
                  subtitle: 'إجمالي ${state.orders.length} طلب',
                  actions: [
                    AppButton(
                      label: 'إضافة طلب',
                      icon: Icons.add,
                      onPressed: () => context.go(AppRoutes.ordersNew),
                    ),
                  ],
                );
              },
            ),
            AppSpacing.gapMd,

            // Search Bar
            AppTextField(
              hintText: 'بحث برقم الطلب، اسم العميل، أو رقم الهاتف...',
              prefixIcon: const Icon(Icons.search),
              onChanged: cubit.search,
            ),
            AppSpacing.gapMd,

            // Filter Bar
            BlocBuilder<OrdersListCubit, OrdersListState>(
              buildWhen: (prev, curr) => prev.activeFilter != curr.activeFilter,
              builder: (context, state) {
                return OrdersFilterBar(
                  selectedFilter: state.activeFilter,
                  onFilterSelected: cubit.setFilter,
                );
              },
            ),
            AppSpacing.gapLg,

            // Orders List Body
            Expanded(
              child: BlocBuilder<OrdersListCubit, OrdersListState>(
                builder: (context, state) {
                  if (state.isLoading && state.orders.isEmpty) {
                    return const Center(child: LoadingIndicator());
                  }

                  if (state.errorMessage != null && state.orders.isEmpty) {
                    return AppErrorState(
                      title: 'تعذر تحميل الطلبات',
                      message: state.errorMessage!,
                      onRetry: () => cubit.loadOrders(refresh: true),
                    );
                  }

                  if (state.orders.isEmpty) {
                    return EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'لا توجد طلبات مطابقة للبحث',
                      message: 'لم يتم العثور على أي طلبات وفقاً لمعايير البحث أو الفلتر المحددة.',
                      actionButton: AppButton(
                        label: 'إعادة ضبط الفلاتر',
                        variant: AppButtonVariant.secondary,
                        onPressed: () {
                          cubit.setFilter(OrderListFilter.all);
                          cubit.search('');
                        },
                      ),
                    );
                  }

                  return NotificationListener<ScrollNotification>(
                    onNotification: (scrollInfo) {
                      if (scrollInfo.metrics.pixels >=
                          scrollInfo.metrics.maxScrollExtent - 200) {
                        cubit.loadMore();
                      }
                      return false;
                    },
                    child: RefreshIndicator(
                      onRefresh: () => cubit.loadOrders(refresh: true),
                      child: ListView.builder(
                        itemCount: state.orders.length + (state.isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == state.orders.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                              child: Center(child: LoadingIndicator()),
                            );
                          }

                          final item = state.orders[index];
                          return OrderCard(
                            item: item,
                            onTap: () => context.go(AppRoutes.orderDetailPath(item.order.id)),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
