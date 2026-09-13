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
import '../../../../domain/entities/service.dart';
import '../../../../domain/enums/pricing_type.dart';
import '../cubit/services_management_cubit.dart';
import '../cubit/services_management_state.dart';
import 'active_status_badge.dart';
import 'deactivation_confirm_dialog.dart';
import 'service_form_dialog.dart';

class ServicesSection extends StatelessWidget {
  const ServicesSection({super.key});

  String _getPricingTypeLabel(PricingType type) {
    switch (type) {
      case PricingType.perPiece:
        return AppStrings.pricingPerPiece;
      case PricingType.perSquareMeter:
        return AppStrings.pricingPerSquareMeter;
      case PricingType.fixedPrice:
        return AppStrings.pricingFixedPrice;
      case PricingType.perKilogram:
        return '';
    }
  }

  Future<void> _handleAdd(BuildContext context) async {
    final cubit = context.read<ServicesManagementCubit>();
    await ServiceFormDialog.show(
      context,
      availableItemTypes: cubit.state.itemTypes,
    );
  }

  Future<void> _handleEdit(BuildContext context, Service service) async {
    final cubit = context.read<ServicesManagementCubit>();
    final supportedIds = await cubit.getSupportedItemTypeIds(service.id);
    if (context.mounted) {
      await ServiceFormDialog.show(
        context,
        service: service,
        availableItemTypes: cubit.state.itemTypes,
        initialSupportedTypeIds: supportedIds,
      );
    }
  }

  Future<void> _handleToggleStatus(BuildContext context, Service service) async {
    final cubit = context.read<ServicesManagementCubit>();
    if (service.isActive) {
      final confirmed = await DeactivationConfirmDialog.show(
        context,
        message: AppStrings.deactivateServiceConfirmMessage,
      );
      if (confirmed == true) {
        await cubit.deactivateService(service.id);
      }
    } else {
      await cubit.activateService(service.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ServicesManagementCubit, ServicesManagementState>(
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
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppStrings.tabServices, style: AppTextStyles.titleLarge),
                        AppSpacing.gapXs,
                        Text(
                          'إدارة الخدمات المتاحة والأسعار المرتبطة بها',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapHorizontalMd,
                  AppButton(
                    label: AppStrings.addService,
                    icon: Icons.add,
                    onPressed: () => _handleAdd(context),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.xxl, color: AppColors.divider),
              if (state.services.isEmpty)
                EmptyState(
                  icon: Icons.local_laundry_service_outlined,
                  message: AppStrings.noServices,
                )
              else
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(2),
                    3: FlexColumnWidth(2),
                    4: FlexColumnWidth(3),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusSm)),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Text(AppStrings.tableHeaderName, style: AppTextStyles.labelLarge),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Text(AppStrings.tableHeaderPricingType, style: AppTextStyles.labelLarge),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Text(AppStrings.tableHeaderPrice, style: AppTextStyles.labelLarge),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Text(AppStrings.tableHeaderStatus, style: AppTextStyles.labelLarge),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Text(AppStrings.tableHeaderActions, style: AppTextStyles.labelLarge),
                        ),
                      ],
                    ),
                    ...state.services.map((svc) {
                      return TableRow(
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: AppColors.divider)),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(svc.name, style: AppTextStyles.titleMedium),
                                if (svc.description != null && svc.description!.isNotEmpty) ...[
                                  AppSpacing.gapXs,
                                  Text(
                                    svc.description!,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Text(
                              _getPricingTypeLabel(svc.pricingType),
                              style: AppTextStyles.bodyMedium,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Text(
                              '${svc.price.toEgp.toStringAsFixed(2)} ج.م',
                              style: AppTextStyles.titleSmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: ActiveStatusBadge(isActive: svc.isActive),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  color: AppColors.primary,
                                  tooltip: AppStrings.edit,
                                  onPressed: () => _handleEdit(context, svc),
                                ),
                                AppSpacing.gapHorizontalSm,
                                TextButton(
                                  onPressed: () => _handleToggleStatus(context, svc),
                                  style: TextButton.styleFrom(
                                    foregroundColor: svc.isActive ? AppColors.error : AppColors.success,
                                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                                  ),
                                  child: Text(
                                    svc.isActive ? AppStrings.actionDeactivate : AppStrings.actionActivate,
                                    style: AppTextStyles.labelMedium.copyWith(
                                      color: svc.isActive ? AppColors.error : AppColors.success,
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
