import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../domain/enums/report_period.dart';

class ReportPeriodSelector extends StatelessWidget {
  final ReportPeriod selectedPeriod;
  final DateTime startDate;
  final DateTime endDate;
  final void Function(ReportPeriod period, {DateTime? customStart, DateTime? customEnd})
      onPeriodChanged;

  const ReportPeriodSelector({
    super.key,
    required this.selectedPeriod,
    required this.startDate,
    required this.endDate,
    required this.onPeriodChanged,
  });

  Future<void> _pickCustomStart(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: DateTime(2020),
      lastDate: endDate,
      locale: const Locale('ar'),
    );
    if (picked != null) {
      onPeriodChanged(
        ReportPeriod.custom,
        customStart: picked,
        customEnd: endDate,
      );
    }
  }

  Future<void> _pickCustomEnd(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: endDate,
      firstDate: startDate,
      lastDate: DateTime(2035),
      locale: const Locale('ar'),
    );
    if (picked != null) {
      onPeriodChanged(
        ReportPeriod.custom,
        customStart: startDate,
        customEnd: picked,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period Chips
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: ReportPeriod.values.map((period) {
              final isSelected = period == selectedPeriod;
              return ChoiceChip(
                key: ValueKey('period_chip_${period.name}'),
                label: Text(
                  period.label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isSelected ? AppColors.textOnPrimary : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: isSelected,
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.backgroundSecondary,
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                ),
                onSelected: (selected) {
                  if (selected) {
                    onPeriodChanged(period);
                  }
                },
              );
            }).toList(),
          ),
          AppSpacing.gapMd,

          // Custom Date Range Pickers (Visible when custom period selected)
          if (selectedPeriod == ReportPeriod.custom) ...[
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    key: const ValueKey('custom_start_date_button'),
                    onTap: () => _pickCustomStart(context),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 16, color: AppColors.textSecondary),
                          AppSpacing.gapHorizontalSm,
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('من', style: AppTextStyles.labelSmall),
                              Text(
                                DateFormatter.formatArabicDate(startDate),
                                style: AppTextStyles.bodyMedium,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                AppSpacing.gapHorizontalMd,
                Expanded(
                  child: InkWell(
                    key: const ValueKey('custom_end_date_button'),
                    onTap: () => _pickCustomEnd(context),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 16, color: AppColors.textSecondary),
                          AppSpacing.gapHorizontalSm,
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('إلى', style: AppTextStyles.labelSmall),
                              Text(
                                DateFormatter.formatArabicDate(endDate),
                                style: AppTextStyles.bodyMedium,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            AppSpacing.gapSm,
          ],

          // Active Date Range Label
          Row(
            children: [
              const Icon(Icons.date_range, size: 16, color: AppColors.textTertiary),
              AppSpacing.gapHorizontalXs,
              Expanded(
                child: Text(
                  'الفترة المحددة: ${DateFormatter.formatArabicDate(startDate)} — ${DateFormatter.formatArabicDate(endDate)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
