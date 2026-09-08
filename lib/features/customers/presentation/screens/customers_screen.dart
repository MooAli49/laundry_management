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
import '../cubit/customers_list_cubit.dart';
import '../cubit/customers_list_state.dart';
import '../widgets/customer_card.dart';
import '../widgets/customer_form_dialog.dart';

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<CustomersListCubit>()..loadCustomers(),
      child: const _CustomersView(),
    );
  }
}

class _CustomersView extends StatefulWidget {
  const _CustomersView();

  @override
  State<_CustomersView> createState() => _CustomersViewState();
}

class _CustomersViewState extends State<_CustomersView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddCustomerDialog(BuildContext context) {
    final cubit = context.read<CustomersListCubit>();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return CustomerFormDialog(
          onSave: ({required name, required phone, notes}) => cubit.createCustomer(
            name: name,
            phone: phone,
            notes: notes,
          ),
          onFindDuplicate: cubit.getCustomerByPhone,
          onViewExisting: (existingCustomer) {
            context.push(AppRoutes.customerDetailPath(existingCustomer.id)).then((_) {
              if (mounted) cubit.loadCustomers();
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CustomersListCubit>();

    return Scaffold(
      body: Padding(
        padding: AppSpacing.paddingPage,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with "+ Add Customer"
            BlocBuilder<CustomersListCubit, CustomersListState>(
              buildWhen: (prev, curr) =>
                  prev.totalCustomersCount != curr.totalCustomersCount ||
                  prev.customers.length != curr.customers.length,
              builder: (context, state) {
                return PageHeader(
                  title: AppStrings.customers,
                  subtitle: AppStrings.totalCustomersCount(state.totalCustomersCount),
                  actions: [
                    AppButton(
                      label: AppStrings.addCustomer,
                      icon: Icons.add,
                      onPressed: () => _showAddCustomerDialog(context),
                    ),
                  ],
                );
              },
            ),
            AppSpacing.gapMd,

            // Search Bar
            AppTextField(
              controller: _searchController,
              hintText: AppStrings.searchCustomerPlaceholder,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        cubit.search('');
                        setState(() {});
                      },
                    )
                  : null,
              onChanged: (value) {
                cubit.search(value);
                setState(() {});
              },
            ),
            AppSpacing.gapLg,

            // Customers List Body
            Expanded(
              child: BlocBuilder<CustomersListCubit, CustomersListState>(
                builder: (context, state) {
                  if (state.isLoading && state.customers.isEmpty) {
                    return const Center(child: LoadingIndicator());
                  }

                  if (state.errorMessage != null && state.customers.isEmpty) {
                    return AppErrorState(
                      title: AppStrings.failedToLoadCustomers,
                      message: state.errorMessage!,
                      onRetry: () => cubit.loadCustomers(refresh: true),
                    );
                  }

                  if (state.customers.isEmpty) {
                    final isSearching = state.searchQuery.isNotEmpty;
                    return EmptyState(
                      icon: isSearching ? Icons.search_off : Icons.people_outline,
                      title: isSearching
                          ? AppStrings.noMatchingResults
                          : AppStrings.noCustomersYet,
                      message: isSearching
                          ? AppStrings.noMatchingCustomersMessage
                          : AppStrings.addFirstCustomerPrompt,
                      actionButton: isSearching
                          ? AppButton(
                              label: AppStrings.clearSearch,
                              variant: AppButtonVariant.secondary,
                              onPressed: () {
                                _searchController.clear();
                                cubit.search('');
                                setState(() {});
                              },
                            )
                          : AppButton(
                              label: AppStrings.addCustomer,
                              icon: Icons.add,
                              onPressed: () => _showAddCustomerDialog(context),
                            ),
                    );
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 600;
                      final crossAxisCount = isNarrow ? 1 : 2;

                      return RefreshIndicator(
                        onRefresh: () => cubit.loadCustomers(refresh: true),
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: AppSpacing.md,
                                mainAxisSpacing: AppSpacing.sm,
                                mainAxisExtent: 88,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final item = state.customers[index];
                                  return CustomerCard(
                                    item: item,
                                    onTap: () {
                                      context
                                          .push(AppRoutes.customerDetailPath(
                                              item.customer.id))
                                          .then((_) {
                                        if (mounted) cubit.loadCustomers();
                                      });
                                    },
                                  );
                                },
                                childCount: state.customers.length,
                              ),
                            ),
                            if (state.hasMoreCustomers)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: AppSpacing.lg),
                                  child: Center(
                                    child: AppButton(
                                      label: AppStrings.loadMoreCustomers,
                                      variant: AppButtonVariant.secondary,
                                      icon: Icons.expand_more,
                                      isLoading: state.isLoadingMore,
                                      onPressed: state.isLoadingMore
                                          ? null
                                          : () => cubit.loadMoreCustomers(),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
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
