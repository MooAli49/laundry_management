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
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppStrings.tabCarpetSizes, style: AppTextStyles.titleLarge),
                        AppSpacing.gapXs,
                        Text(
                          'إدارة مقاسات السجاد القياسية وحساب المساحات بالمتر المربع',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapHorizontalMd,
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
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(3),
                    2: FlexColumnWidth(2),
                    3: FlexColumnWidth(3),
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
                          child: Text(AppStrings.tableHeaderDimensions, style: AppTextStyles.labelLarge),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Text(AppStrings.tableHeaderArea, style: AppTextStyles.labelLarge),
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
                    ...state.carpetSizes.map((cs) {
                      return TableRow(
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: AppColors.divider)),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Text(
                              '${_formatNum(cs.length)} م × ${_formatNum(cs.width)} م',
                              style: AppTextStyles.titleMedium,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Text(
                              '${_formatNum(cs.area)} م²',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: ActiveStatusBadge(isActive: cs.isActive),
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
                                  onPressed: () => _handleEdit(context, cs),
                                ),
                                AppSpacing.gapHorizontalSm,
                                TextButton(
                                  onPressed: () => _handleToggleStatus(context, cs),
                                  style: TextButton.styleFrom(
                                    foregroundColor: cs.isActive ? AppColors.error : AppColors.success,
                                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                                  ),
                                  child: Text(
                                    cs.isActive ? AppStrings.actionDeactivate : AppStrings.actionActivate,
                                    style: AppTextStyles.labelMedium.copyWith(
                                      color: cs.isActive ? AppColors.error : AppColors.success,
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
