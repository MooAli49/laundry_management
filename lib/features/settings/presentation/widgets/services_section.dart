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
import 'settings_table_components.dart';

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
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SettingsSectionHeader(
                title: AppStrings.tabServices,
                subtitle: 'إدارة الخدمات المتاحة والأسعار المرتبطة بها في نظام المغسلة',
                actions: [
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
                    0: FlexColumnWidth(3.5),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(2),
                    3: FlexColumnWidth(1.8),
                    4: FlexColumnWidth(2.7),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    SettingsTableHelper.buildHeaderRow([
                      AppStrings.tableHeaderName,
                      AppStrings.tableHeaderPricingType,
                      AppStrings.tableHeaderPrice,
                      AppStrings.tableHeaderStatus,
                      AppStrings.tableHeaderActions,
                    ]),
                    ...state.services.map((svc) {
                      return TableRow(
                        decoration: SettingsTableHelper.rowDecoration,
                        children: [
                          Padding(
                            padding: SettingsTableHelper.cellPadding,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  svc.name,
                                  style: AppTextStyles.titleMedium.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (svc.description != null &&
                                    svc.description!.isNotEmpty) ...[
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
                            padding: SettingsTableHelper.cellPadding,
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusSm,
                                  ),
                                ),
                                child: Text(
                                  _getPricingTypeLabel(svc.pricingType),
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: SettingsTableHelper.cellPadding,
                            child: Text(
                              '${svc.price.toEgp.toStringAsFixed(2)} ج.م',
                              style: AppTextStyles.titleMedium.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Padding(
                            padding: SettingsTableHelper.cellPadding,
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: ActiveStatusBadge(isActive: svc.isActive),
                            ),
                          ),
                          Padding(
                            padding: SettingsTableHelper.cellPadding,
                            child: SettingsRowActions(
                              onEdit: () => _handleEdit(context, svc),
                              onToggleStatus: () => _handleToggleStatus(context, svc),
                              isActive: svc.isActive,
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
