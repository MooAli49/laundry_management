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
import '../../../../domain/entities/carpet_size.dart';
import '../cubit/carpet_sizes_management_cubit.dart';
import '../cubit/carpet_sizes_management_state.dart';
import 'active_status_badge.dart';
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

  Future<void> _handleToggleStatus(BuildContext context, CarpetSize carpetSize) async {
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

        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SettingsSectionHeader(
                title: AppStrings.tabCarpetSizes,
                subtitle: 'إدارة مقاسات السجاد القياسية وحساب المساحات بالمتر المربع',
                actions: [
                  AppButton(
                    label: AppStrings.addCarpetSize,
                    icon: Icons.add,
                    onPressed: () => _handleAdd(context),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.xxl, color: AppColors.divider),
              if (state.carpetSizes.isEmpty)
                EmptyState(
                  icon: Icons.straighten_outlined,
                  message: AppStrings.noCarpetSizes,
                )
              else
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(4),
                    1: FlexColumnWidth(2.5),
                    2: FlexColumnWidth(2),
                    3: FlexColumnWidth(2.8),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    SettingsTableHelper.buildHeaderRow([
                      AppStrings.tableHeaderDimensions,
                      AppStrings.tableHeaderArea,
                      AppStrings.tableHeaderStatus,
                      AppStrings.tableHeaderActions,
                    ]),
                    ...state.carpetSizes.map((cs) {
                      return TableRow(
                        decoration: SettingsTableHelper.rowDecoration,
                        children: [
                          Padding(
                            padding: SettingsTableHelper.cellPadding,
                            child: Text(
                              '${_formatNum(cs.length)} م × ${_formatNum(cs.width)} م',
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Padding(
                            padding: SettingsTableHelper.cellPadding,
                            child: Text(
                              '${_formatNum(cs.area)} م²',
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
                              child: ActiveStatusBadge(isActive: cs.isActive),
                            ),
                          ),
                          Padding(
                            padding: SettingsTableHelper.cellPadding,
                            child: SettingsRowActions(
                              onEdit: () => _handleEdit(context, cs),
                              onToggleStatus: () => _handleToggleStatus(context, cs),
                              isActive: cs.isActive,
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
