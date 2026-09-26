import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../domain/entities/service.dart';
import '../../../../domain/enums/pricing_type.dart';
import '../cubit/services_management_cubit.dart';
import '../cubit/services_management_state.dart';
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

  Future<void> _handleToggleStatus(
    BuildContext context,
    Service service,
  ) async {
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

  String _getUnitLabel(PricingType type) {
    switch (type) {
      case PricingType.perPiece:
        return 'قطعة';
      case PricingType.perSquareMeter:
        return 'م²';
      case PricingType.fixedPrice:
        return 'الخدمة';
    }
  }

  IconData _getServiceIcon(String name) {
    if (name.contains('كي')) return Icons.iron_outlined;
    if (name.contains('سجاد')) return Icons.straighten_outlined;
    if (name.contains('تنظيف')) return Icons.dry_cleaning_outlined;
    return Icons.local_laundry_service_outlined;
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsTopHeader(
              title: AppStrings.tabServices,
              count: state.services.length,
              countLabel: 'خدمات',
              actionLabel: AppStrings.addService,
              onAction: () => _handleAdd(context),
            ),
            if (state.services.isEmpty)
              AppCard(
                child: EmptyState(
                  icon: Icons.local_laundry_service_outlined,
                  message: AppStrings.noServices,
                ),
              )
            else
              Column(
                children: [
                  for (final svc in state.services) ...[
                    SettingsCard(
                      icon: _getServiceIcon(svc.name),
                      title: svc.name,
                      subtitle:
                          '${_getPricingTypeLabel(svc.pricingType)} • ${svc.price.toEgp.toStringAsFixed(2)} ج.م / ${_getUnitLabel(svc.pricingType)}',
                      isActive: svc.isActive,
                      onEdit: () => _handleEdit(context, svc),
                      onToggleActive: (_) => _handleToggleStatus(context, svc),
                      useOutlinedEditButton: true,
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
          ],
        );
      },
    );
  }
}
