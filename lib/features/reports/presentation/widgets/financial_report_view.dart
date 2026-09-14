import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../domain/entities/financial_report_data.dart';
import '../../../../domain/value_objects/money.dart';
import '../../../expenses/presentation/widgets/add_expense_dialog.dart';
import 'report_metric_card.dart';

class FinancialReportView extends StatelessWidget {
  final FinancialReportData data;
  final VoidCallback onRefresh;

  const FinancialReportView({
    super.key,
    required this.data,
    required this.onRefresh,
  });

  void _openAddExpenseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AddExpenseDialog(
        onExpenseCreated: (_) async {
          onRefresh();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Action Row with Section Title & Add Expense Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('الملخص المالي', style: AppTextStyles.titleLarge),
            AppButton(
              key: const ValueKey('add_expense_quick_action_button'),
              label: 'إضافة مصروف',
              icon: Icons.add,
              variant: AppButtonVariant.secondary,
              onPressed: () => _openAddExpenseDialog(context),
            ),
          ],
        ),
        AppSpacing.gapMd,

        // Primary Metric Cards Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 650
                ? 1
                : (constraints.maxWidth < 950 ? 2 : 3);
            final cardWidth = (constraints.maxWidth - (AppSpacing.md * (columns - 1))) / columns;

            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: ReportMetricCard(
                    title: 'إجمالي المبيعات',
                    value: '${data.totalSales.toEgp.toStringAsFixed(2)} ج.م',
                    icon: Icons.point_of_sale,
                    subtitle: 'إجمالي قيمة طلبات الفترة',
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: ReportMetricCard(
                    title: 'إجمالي المدفوعات',
                    value: '${data.totalPayments.toEgp.toStringAsFixed(2)} ج.م',
                    icon: Icons.payments_outlined,
                    iconColor: AppColors.info,
                    iconBackground: AppColors.infoLight,
                    subtitle: 'المبالغ المحصلة فعلياً',
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: ReportMetricCard(
                    title: 'إجمالي المصروفات',
                    value: '${data.totalOperatingExpenses.toEgp.toStringAsFixed(2)} ج.م',
                    icon: Icons.shopping_bag_outlined,
                    iconColor: AppColors.error,
                    iconBackground: AppColors.errorLight,
                    valueColor: AppColors.error,
                    subtitle: 'مصروفات التشغيل للفترة',
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: ReportMetricCard(
                    title: 'صافي الربح',
                    value: '${data.netProfit.toEgp.toStringAsFixed(2)} ج.م',
                    icon: Icons.account_balance_wallet_outlined,
                    isProminent: true,
                    subtitle: 'المبيعات — المصروفات',
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: ReportMetricCard(
                    title: 'المبالغ المتبقية',
                    value: '${data.outstandingAmount.toEgp.toStringAsFixed(2)} ج.م',
                    icon: Icons.hourglass_bottom,
                    iconColor: data.outstandingAmount > Money.zero ? AppColors.warning : AppColors.textSecondary,
                    iconBackground: data.outstandingAmount > Money.zero ? AppColors.warningLight : AppColors.backgroundSecondary,
                    valueColor: data.outstandingAmount > Money.zero ? AppColors.warning : null,
                    subtitle: 'مبالغ غير مسددة على طلبات الفترة',
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: ReportMetricCard(
                    title: 'إجمالي الخصومات',
                    value: '${data.totalDiscounts.toEgp.toStringAsFixed(2)} ج.م',
                    icon: Icons.local_offer_outlined,
                    iconColor: AppColors.textSecondary,
                    iconBackground: AppColors.backgroundSecondary,
                    subtitle: 'الخصومات الممنوحة على الطلبات',
                  ),
                ),
              ],
            );
          },
        ),
        AppSpacing.gapXxl,

        // Payment Methods Breakdown & Expenses by Category Breakdown (Two Column / Responsive)
        LayoutBuilder(
          builder: (context, constraints) {
            final isSmall = constraints.maxWidth < 800;
            if (isSmall) {
              return Column(
                children: [
                  _buildPaymentMethodsSection(),
                  AppSpacing.gapXl,
                  _buildExpensesByCategorySection(),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildPaymentMethodsSection()),
                AppSpacing.gapHorizontalLg,
                Expanded(child: _buildExpensesByCategorySection()),
              ],
            );
          },
        ),
        AppSpacing.gapXxl,

        // Outstanding Orders Section
        _buildOutstandingOrdersSection(),
        AppSpacing.gapXxl,

        // Expense Transactions Table
        _buildExpenseTransactionsSection(),
      ],
    );
  }

  Widget _buildPaymentMethodsSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payment, size: 20, color: AppColors.primary),
              AppSpacing.gapHorizontalSm,
              Text('طرق الدفع', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          AppSpacing.gapMd,
          if (data.totalPayments.isZero)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Text(
                  'لا توجد مدفوعات خلال هذه الفترة',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else ...[
            // Progress Bar representing method shares
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: data.paymentMethodsBreakdown.map((item) {
                    if (item.percentage <= 0) return const SizedBox.shrink();
                    Color barColor = AppColors.primary;
                    if (item.method.name == 'instapay') barColor = AppColors.info;
                    if (item.method.name == 'ewallet') barColor = AppColors.warning;

                    return Expanded(
                      flex: (item.percentage * 10).round().clamp(1, 1000),
                      child: Container(color: barColor),
                    );
                  }).toList(),
                ),
              ),
            ),
            AppSpacing.gapMd,

            // List of methods
            ...data.paymentMethodsBreakdown.map((item) {
              Color dotColor = AppColors.primary;
              if (item.method.name == 'instapay') dotColor = AppColors.info;
              if (item.method.name == 'ewallet') dotColor = AppColors.warning;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                    ),
                    AppSpacing.gapHorizontalSm,
                    Text(item.arabicName, style: AppTextStyles.bodyMedium),
                    const Spacer(),
                    Text(
                      '${item.count} معاملة',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                    AppSpacing.gapHorizontalMd,
                    Text(
                      '${item.totalAmount.toEgp.toStringAsFixed(2)} ج.م',
                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                    AppSpacing.gapHorizontalSm,
                    SizedBox(
                      width: 45,
                      child: Text(
                        '(${item.percentage.toStringAsFixed(1)}%)',
                        textAlign: TextAlign.left,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildExpensesByCategorySection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.category_outlined, size: 20, color: AppColors.primary),
              AppSpacing.gapHorizontalSm,
              Text('المصروفات حسب التصنيف', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          AppSpacing.gapMd,
          if (data.totalOperatingExpenses.isZero || data.expenseCategoriesBreakdown.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Text(
                  'لا توجد مصروفات خلال هذه الفترة',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...data.expenseCategoriesBreakdown.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(item.categoryName, style: AppTextStyles.bodyMedium),
                        const Spacer(),
                        Text(
                          '${item.count} مصروف',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                        AppSpacing.gapHorizontalMd,
                        Text(
                          '${item.totalAmount.toEgp.toStringAsFixed(2)} ج.م',
                          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                        AppSpacing.gapHorizontalSm,
                        SizedBox(
                          width: 45,
                          child: Text(
                            '(${item.percentage.toStringAsFixed(1)}%)',
                            textAlign: TextAlign.left,
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapXs,
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      child: LinearProgressIndicator(
                        value: (item.percentage / 100.0).clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: AppColors.backgroundSecondary,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.error),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildOutstandingOrdersSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.warning),
              AppSpacing.gapHorizontalSm,
              Text(
                'طلبات عليها مبالغ متبقية',
                style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${data.outstandingOrders.length} طلبات',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          AppSpacing.gapMd,
          if (data.outstandingOrders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: Text(
                  'لا توجد طلبات عليها مبالغ متبقية في هذه الفترة',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppColors.backgroundSecondary),
                columns: const [
                  DataColumn(label: Text('رقم الطلب')),
                  DataColumn(label: Text('التاريخ')),
                  DataColumn(label: Text('العميل')),
                  DataColumn(label: Text('الإجمالي')),
                  DataColumn(label: Text('المدفوع')),
                  DataColumn(label: Text('المتبقي')),
                ],
                rows: data.outstandingOrders.map((ord) {
                  return DataRow(
                    cells: [
                      DataCell(Text(ord.orderNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(DateFormatter.formatArabicDate(ord.createdAt))),
                      DataCell(Text(ord.customerName.isNotEmpty ? ord.customerName : '—')),
                      DataCell(Text('${ord.totalAmount.toEgp.toStringAsFixed(2)} ج.م')),
                      DataCell(Text('${ord.paidAmount.toEgp.toStringAsFixed(2)} ج.م')),
                      DataCell(
                        Text(
                          '${ord.remainingAmount.toEgp.toStringAsFixed(2)} ج.م',
                          style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpenseTransactionsSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined, size: 20, color: AppColors.primary),
              AppSpacing.gapHorizontalSm,
              Text(
                'سجل المصروفات',
                style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${data.expenseTransactions.length} مصروف',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          AppSpacing.gapMd,
          if (data.expenseTransactions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: Text(
                  'لا توجد مصروفات مسجلة في هذه الفترة',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppColors.backgroundSecondary),
                columns: const [
                  DataColumn(label: Text('التاريخ')),
                  DataColumn(label: Text('التصنيف')),
                  DataColumn(label: Text('المصروف / الملاحظات')),
                  DataColumn(label: Text('المبلغ')),
                ],
                rows: data.expenseTransactions.map((exp) {
                  final details = exp.expenseName ?? exp.notes ?? '—';
                  return DataRow(
                    cells: [
                      DataCell(Text(DateFormatter.formatArabicDate(exp.expenseDate.toDateTime()))),
                      DataCell(Text(exp.categoryNameSnapshot)),
                      DataCell(Text(details)),
                      DataCell(
                        Text(
                          '${exp.amount.toEgp.toStringAsFixed(2)} ج.م',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
