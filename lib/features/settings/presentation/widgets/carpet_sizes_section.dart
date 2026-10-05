import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../domain/entities/carpet_size.dart';
import '../cubit/carpet_sizes_management_cubit.dart';
import '../cubit/carpet_sizes_management_state.dart';
import 'carpet_size_form_dialog.dart';
import 'deactivation_confirm_dialog.dart';
import 'settings_table_components.dart';

class CarpetSizesSection extends StatelessWidget {
  const CarpetSizesSection({super.key});

  String _formatNum(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(2);
  }

  Future<void> _handleAdd(BuildContext context) async {
    await CarpetSizeFormDialog.show(context);
  }

  Future<void> _handleEdit(BuildContext context, CarpetSize carpetSize) async {
    await CarpetSizeFormDialog.show(context, carpetSize: carpetSize);
  }

  Future<void> _handleToggleStatus(
    BuildContext context,
    CarpetSize carpetSize,
  ) async {
    final cubit = context.read<CarpetSizesManagementCubit>();
    if (carpetSize.isActive) {
      final confirmed = await DeactivationConfirmDialog.show(
        context,
        message: AppStrings.deactivateCarpetSizeConfirmMessage,
      );
      if (confirmed == true) {
        await cubit.deactivateCarpetSize(carpetSize.id);
      }
    } else {
      await cubit.activateCarpetSize(carpetSize.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CarpetSizesManagementCubit, CarpetSizesManagementState>(
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
              title: AppStrings.tabCarpetSizes,
              count: state.carpetSizes.length,
              countLabel: 'مقاسات',
              actionLabel: AppStrings.addCarpetSize,
              onAction: () => _handleAdd(context),
            ),
            if (state.carpetSizes.isEmpty)
              AppCard(
                child: EmptyState(
                  icon: Icons.straighten_outlined,
                  message: AppStrings.noCarpetSizes,
                ),
              )
            else
              SettingsCardGrid(
                children: [
                  for (final cs in state.carpetSizes)
                    SettingsCard(
                      icon: Icons.straighten_outlined,
                      title:
                          '${_formatNum(cs.length)} × ${_formatNum(cs.width)} م',
                      subtitle: '${_formatNum(cs.area)} م²',
                      isActive: cs.isActive,
                      onEdit: () => _handleEdit(context, cs),
                      onToggleActive: (_) => _handleToggleStatus(context, cs),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}
