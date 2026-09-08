import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../domain/entities/customer.dart';
import '../../../../domain/repositories/customer_repository.dart';
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
          onSave: ({required name, required phone, notes}) async {
            final now = DateTime.now();
            final newCustomer = Customer(
              id: const Uuid().v4(),
              name: name,
              phone: phone,
              notes: notes,
              createdAt: now,
              updatedAt: now,
            );
            await getIt<CustomerRepository>().createCustomer(newCustomer);
            cubit.loadCustomers();
          },
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
            // Header with "+ إضافة عميل"
            BlocBuilder<CustomersListCubit, CustomersListState>(
              buildWhen: (prev, curr) =>
                  prev.totalCustomersCount != curr.totalCustomersCount ||
                  prev.customers.length != curr.customers.length,
              builder: (context, state) {
                return PageHeader(
                  title: 'العملاء',
                  subtitle: 'إجمالي ${state.totalCustomersCount} عميل',
                  actions: [
                    AppButton(
                      label: 'إضافة عميل',
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
              hintText: 'بحث باسم العميل أو رقم الهاتف...',
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
                      title: 'تعذر تحميل العملاء',
                      message: state.errorMessage!,
                      onRetry: () => cubit.loadCustomers(refresh: true),
                    );
                  }

                  if (state.customers.isEmpty) {
                    final isSearching = state.searchQuery.isNotEmpty;
                    return EmptyState(
                      icon: isSearching ? Icons.search_off : Icons.people_outline,
                      title: isSearching
                          ? 'لا توجد نتائج مطابقة'
                          : 'لا يوجد عملاء حتى الآن',
                      message: isSearching
                          ? 'لم يتم العثور على عملاء مطابقين لنص البحث.'
                          : 'قم بإضافة عميلك الأول لبدء إدارة الطلبات.',
                      actionButton: isSearching
                          ? AppButton(
                              label: 'مسح البحث',
                              variant: AppButtonVariant.secondary,
                              onPressed: () {
                                _searchController.clear();
                                cubit.search('');
                                setState(() {});
                              },
                            )
                          : AppButton(
                              label: 'إضافة عميل',
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
                        child: GridView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: state.customers.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: AppSpacing.md,
                            mainAxisSpacing: AppSpacing.sm,
                            mainAxisExtent: 88,
                          ),
                          itemBuilder: (context, index) {
                            final item = state.customers[index];
                            return CustomerCard(
                              item: item,
                              onTap: () {
                                context
                                    .push(AppRoutes.customerDetailPath(item.customer.id))
                                    .then((_) {
                                  if (mounted) cubit.loadCustomers();
                                });
                              },
                            );
                          },
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
