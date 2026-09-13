import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/page_header.dart';
import '../cubit/carpet_sizes_management_cubit.dart';
import '../cubit/expense_categories_management_cubit.dart';
import '../cubit/item_types_management_cubit.dart';
import '../cubit/services_management_cubit.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_state.dart';
import '../cubit/storage_locations_management_cubit.dart';
import '../widgets/business_info_section.dart';
import '../widgets/carpet_sizes_section.dart';
import '../widgets/expense_categories_section.dart';
import '../widgets/invoice_settings_section.dart';
import '../widgets/item_definitions_section.dart';
import '../widgets/item_types_section.dart';
import '../widgets/services_section.dart';
import '../widgets/settings_tab_bar.dart';
import '../widgets/storage_locations_section.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SettingsCubit>(
          create: (_) => getIt<SettingsCubit>()..loadSettings(),
        ),
        BlocProvider<ServicesManagementCubit>(
          create: (_) => getIt<ServicesManagementCubit>()..loadServices(),
        ),
        BlocProvider<ItemTypesManagementCubit>(
          create: (_) => getIt<ItemTypesManagementCubit>()..loadData(),
        ),
        BlocProvider<CarpetSizesManagementCubit>(
          create: (_) => getIt<CarpetSizesManagementCubit>()..loadCarpetSizes(),
        ),
        BlocProvider<StorageLocationsManagementCubit>(
          create: (_) => getIt<StorageLocationsManagementCubit>()..loadLocations(),
        ),
        BlocProvider<ExpenseCategoriesManagementCubit>(
          create: (_) => getIt<ExpenseCategoriesManagementCubit>()..loadCategories(),
        ),
      ],
      child: const _SettingsScreenContent(),
    );
  }
}

class _SettingsScreenContent extends StatelessWidget {
  const _SettingsScreenContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.page,
            AppSpacing.page,
            AppSpacing.page,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                title: AppStrings.settings,
                subtitle: AppStrings.settingsSubtitle,
              ),
              BlocBuilder<SettingsCubit, SettingsState>(
                buildWhen: (prev, curr) => prev.selectedTabIndex != curr.selectedTabIndex,
                builder: (context, state) {
                  return SettingsTabBar(
                    selectedIndex: state.selectedTabIndex,
                    onTabSelected: (index) {
                      context.read<SettingsCubit>().selectTab(index);
                    },
                  );
                },
              ),
              AppSpacing.gapLg,
              Expanded(
                child: BlocBuilder<SettingsCubit, SettingsState>(
                  buildWhen: (prev, curr) => prev.selectedTabIndex != curr.selectedTabIndex,
                  builder: (context, state) {
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: _buildTabSection(state.selectedTabIndex),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabSection(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return const BusinessInfoSection();
      case 1:
        return const InvoiceSettingsSection();
      case 2:
        return const ServicesSection();
      case 3:
        return const ItemTypesSection();
      case 4:
        return const ItemDefinitionsSection();
      case 5:
        return const CarpetSizesSection();
      case 6:
        return const StorageLocationsSection();
      case 7:
        return const ExpenseCategoriesSection();
      default:
        return const BusinessInfoSection();
    }
  }
}
