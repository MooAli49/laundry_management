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

        // ==========================================
        // SECTION 1: أهم المؤشرات (Primary Indicators)
        // ==========================================
        Text(
          'أهم المؤشرات',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        AppSpacing.gapSm,
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 650
                ? 1
                : (constraints.maxWidth < 950 ? 2 : 4);
            final cardWidth =
                (constraints.maxWidth - (AppSpacing.md * (columns - 1))) /
                columns;

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
                    subtitle: 'قيمة الطلبات غير الملغاة خلال الفترة',
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: ReportMetricCard(
                    title: 'صافي المدفوعات',
                    value: '${data.netPayments.toEgp.toStringAsFixed(2)} ج.م',
                    icon: Icons.account_balance_outlined,
                    iconColor: AppColors.primary,
                    iconBackground: AppColors.surfaceSelected,
                    subtitle: 'المدفوعات − الاستردادات',
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: ReportMetricCard(
                    title: 'المصروفات التشغيلية',
                    value:
                        '${data.totalOperatingExpenses.toEgp.toStringAsFixed(2)} ج.م',
                    icon: Icons.shopping_bag_outlined,
                    iconColor: AppColors.error,
                    iconBackground: AppColors.errorLight,
                    valueColor: AppColors.error,
                    subtitle: 'المصروفات المسجلة خلال الفترة',
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: ReportMetricCard(
                    title: 'صافي الربح',
                    value: '${data.netProfit.toEgp.toStringAsFixed(2)} ج.م',
                    icon: Icons.trending_up,
                    isProminent: true,
                    subtitle: 'المبيعات − المصروفات التشغيلية',
                  ),
                ),
              ],
            );
          },
        ),
        AppSpacing.gapXxl,

        // ==========================================
        // SECTION 2 & 3: حركة المدفوعات والتحصيل
        // ==========================================
        LayoutBuilder(
          builder: (context, constraints) {
            final isSmall = constraints.maxWidth < 900;
            if (isSmall) {
              return Column(
                children: [
                  _buildPaymentMovementSection(),
                  AppSpacing.gapXl,
                  _buildCollectionAndDiscountsSection(),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildPaymentMovementSection()),
                AppSpacing.gapHorizontalLg,
                Expanded(child: _buildCollectionAndDiscountsSection()),
              ],
            );
          },
        ),
        AppSpacing.gapXxl,

        // Payment Methods Breakdown & Expenses by Category Breakdown (Two Column / Responsive)
        LayoutBuilder(
          builder: (context, constraints) {
            final isSmall = constraints.maxWidth < 900;
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

        // ==========================================
        // SECTION 5: سجل المصروفات (Expense History)
        // ==========================================
        _buildExpenseTransactionsSection(),
        AppSpacing.gapXxl,

        // ==========================================
        // SECTION 6: الطلبات التي عليها مبالغ (Outstanding Orders)
        // ==========================================
        _buildOutstandingOrdersSection(),
      ],
    );
  }

  Widget _buildPaymentMovementSection() {
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
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.infoLight,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(
                  Icons.swap_horiz,
                  color: AppColors.info,
                  size: 20,
                ),
              ),
              AppSpacing.gapHorizontalSm,
              Text(
                'حركة المدفوعات',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          AppSpacing.gapLg,
          _buildMovementRow(
            title: 'إجمالي المدفوعات',
            subtitle: 'جميع المدفوعات المسجلة خلال الفترة',
            value: '${data.totalPayments.toEgp.toStringAsFixed(2)} ج.م',
            color: AppColors.textPrimary,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.remove, size: 16, color: AppColors.textTertiary),
                AppSpacing.gapHorizontalXs,
                Text(
                  'طرح الاستردادات',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          _buildMovementRow(
            title: 'إجمالي الاستردادات',
            subtitle: 'مبالغ تم ردها للعملاء خلال الفترة',
            value: '${data.totalRefunds.toEgp.toStringAsFixed(2)} ج.م',
            color: data.totalRefunds > Money.zero
                ? AppColors.warning
                : AppColors.textSecondary,
          ),
          const Divider(height: AppSpacing.lg, color: AppColors.divider),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceSelected,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: _buildMovementRow(
              title: 'صافي المدفوعات',
              subtitle: 'المدفوعات − الاستردادات',
              value: '${data.netPayments.toEgp.toStringAsFixed(2)} ج.م',
              color: AppColors.primary,
              isBold: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionAndDiscountsSection() {
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
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(
                  Icons.hourglass_bottom,
                  color: AppColors.warning,
                  size: 20,
                ),
              ),
              AppSpacing.gapHorizontalSm,
              Text(
                'التحصيل والخصومات',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          AppSpacing.gapLg,
          _buildMovementRow(
            title: 'المبالغ المستحقة',
            subtitle: 'المبالغ المتبقية على الطلبات غير الملغاة',
            value: '${data.outstandingAmount.toEgp.toStringAsFixed(2)} ج.م',
            color: data.outstandingAmount > Money.zero
                ? AppColors.warning
                : AppColors.textSecondary,
            isBold: true,
          ),
          const Divider(height: AppSpacing.lg, color: AppColors.divider),
          _buildMovementRow(
            title: 'إجمالي الخصومات',
            subtitle: 'الخصومات الممنوحة على الطلبات خلال الفترة',
            value: '${data.totalDiscounts.toEgp.toStringAsFixed(2)} ج.م',
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildMovementRow({
    required String title,
    required String subtitle,
    required String value,
    Color? color,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: (isBold
                        ? AppTextStyles.titleSmall
                        : AppTextStyles.bodyMedium)
                    .copyWith(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        AppSpacing.gapHorizontalSm,
        Text(
          value,
          style: (isBold ? AppTextStyles.titleMedium : AppTextStyles.bodyLarge)
              .copyWith(
            fontWeight: FontWeight.bold,
            color: color ?? AppColors.textPrimary,
          ),
        ),
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
              Text(
                'طرق الدفع',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
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
                    if (item.method.name == 'instapay') {
                      barColor = AppColors.info;
                    }
                    if (item.method.name == 'ewallet') {
                      barColor = AppColors.warning;
                    }

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
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    AppSpacing.gapHorizontalSm,
                    Text(item.arabicName, style: AppTextStyles.bodyMedium),
                    const Spacer(),
                    Text(
                      '${item.count} معاملة',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    AppSpacing.gapHorizontalMd,
                    Text(
                      '${item.totalAmount.toEgp.toStringAsFixed(2)} ج.م',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    AppSpacing.gapHorizontalSm,
                    SizedBox(
                      width: 45,
                      child: Text(
                        '(${item.percentage.toStringAsFixed(1)}%)',
                        textAlign: TextAlign.left,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
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
              const Icon(
                Icons.category_outlined,
                size: 20,
                color: AppColors.primary,
              ),
              AppSpacing.gapHorizontalSm,
              Text(
                'المصروفات حسب التصنيف',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          AppSpacing.gapMd,
          if (data.totalOperatingExpenses.isZero ||
              data.expenseCategoriesBreakdown.isEmpty)
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
                        Text(
                          item.categoryName,
                          style: AppTextStyles.bodyMedium,
                        ),
                        const Spacer(),
                        Text(
                          '${item.count} مصروف',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        AppSpacing.gapHorizontalMd,
                        Text(
                          '${item.totalAmount.toEgp.toStringAsFixed(2)} ج.م',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        AppSpacing.gapHorizontalSm,
                        SizedBox(
                          width: 45,
                          child: Text(
                            '(${item.percentage.toStringAsFixed(1)}%)',
                            textAlign: TextAlign.left,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textTertiary,
                            ),
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
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.error,
                        ),
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
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(
                  Icons.hourglass_bottom,
                  size: 20,
                  color: AppColors.warning,
                ),
              ),
              AppSpacing.gapHorizontalSm,
              Text(
                'طلبات عليها مبالغ متبقية',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                ),
                child: Text(
                  '${data.outstandingOrders.length} طلبات',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const double orderNumberWidth = 135.0;
                    const double totalWidth = 115.0;
                    const double paidWidth = 115.0;
                    const double remainingWidth = 135.0;
                    const double minTableWidth = 620.0;

                    final tableWidth = constraints.maxWidth < minTableWidth
                        ? minTableWidth
                        : constraints.maxWidth;

                    final tableContent = SizedBox(
                      width: tableWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Table Header
                          Container(
                            height: 42,
                            color: AppColors.backgroundSecondary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: orderNumberWidth,
                                  child: Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: Text(
                                      'رقم الطلب',
                                      style: AppTextStyles.labelMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.sm,
                                    ),
                                    child: Align(
                                      alignment: AlignmentDirectional.centerStart,
                                      child: Text(
                                        'العميل',
                                        style: AppTextStyles.labelMedium.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: totalWidth,
                                  child: Align(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: Text(
                                      'الإجمالي',
                                      textAlign: TextAlign.end,
                                      style: AppTextStyles.labelMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: paidWidth,
                                  child: Align(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: Text(
                                      'المدفوع',
                                      textAlign: TextAlign.end,
                                      style: AppTextStyles.labelMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: remainingWidth,
                                  child: Align(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: Text(
                                      'المتبقي',
                                      textAlign: TextAlign.end,
                                      style: AppTextStyles.labelMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.warning,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Table Rows
                          ...data.outstandingOrders.map((ord) {
                            final displayOrderNumber =
                                ord.orderNumber.startsWith('#')
                                    ? ord.orderNumber
                                    : '#${ord.orderNumber}';

                            return Container(
                              height: 48,
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: AppColors.border,
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: orderNumberWidth,
                                    child: Align(
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                      child: Tooltip(
                                        message: displayOrderNumber,
                                        child: Text(
                                          displayOrderNumber,
                                          textDirection: TextDirection.ltr,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style:
                                              AppTextStyles.bodyMedium.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.sm,
                                      ),
                                      child: Align(
                                        alignment:
                                            AlignmentDirectional.centerStart,
                                        child: Tooltip(
                                          message: ord.customerName.isNotEmpty
                                              ? ord.customerName
                                              : '—',
                                          child: Text(
                                            ord.customerName.isNotEmpty
                                                ? ord.customerName
                                                : '—',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.bodyMedium,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: totalWidth,
                                    child: Align(
                                      alignment: AlignmentDirectional.centerEnd,
                                      child: Text(
                                        '${ord.totalAmount.toEgp.toStringAsFixed(2)} ج.م',
                                        textAlign: TextAlign.end,
                                        maxLines: 1,
                                        softWrap: false,
                                        style: AppTextStyles.bodyMedium,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: paidWidth,
                                    child: Align(
                                      alignment: AlignmentDirectional.centerEnd,
                                      child: Text(
                                        '${ord.paidAmount.toEgp.toStringAsFixed(2)} ج.م',
                                        textAlign: TextAlign.end,
                                        maxLines: 1,
                                        softWrap: false,
                                        style:
                                            AppTextStyles.bodyMedium.copyWith(
                                          color: AppColors.success,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: remainingWidth,
                                    child: Align(
                                      alignment: AlignmentDirectional.centerEnd,
                                      child: Text(
                                        '${ord.remainingAmount.toEgp.toStringAsFixed(2)} ج.م',
                                        textAlign: TextAlign.end,
                                        maxLines: 1,
                                        softWrap: false,
                                        style:
                                            AppTextStyles.bodyMedium.copyWith(
                                          color: AppColors.warning,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    );

                    if (constraints.maxWidth < minTableWidth) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: tableContent,
                      );
                    }
                    return tableContent;
                  },
                ),
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
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  size: 20,
                  color: AppColors.error,
                ),
              ),
              AppSpacing.gapHorizontalSm,
              Text(
                'سجل المصروفات',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                ),
                child: Text(
                  '${data.expenseTransactions.length} مصروف',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth =
                        constraints.maxWidth - (AppSpacing.md * 2);
                    final dynamicSpacing =
                        ((availableWidth - 460) / 3).clamp(AppSpacing.lg, 100.0);
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: DataTable(
                          dataRowMinHeight: 44,
                          dataRowMaxHeight: 54,
                          headingRowHeight: 42,
                          headingRowColor: WidgetStateProperty.all(
                            AppColors.backgroundSecondary,
                          ),
                          horizontalMargin: AppSpacing.md,
                          columnSpacing: dynamicSpacing,
                    columns: [
                      DataColumn(
                        label: Text(
                          'التاريخ',
                          style: AppTextStyles.labelMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'التصنيف',
                          style: AppTextStyles.labelMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'المصروف والملاحظات',
                          style: AppTextStyles.labelMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      DataColumn(
                        numeric: true,
                        label: Text(
                          'المبلغ',
                          style: AppTextStyles.labelMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                    rows: data.expenseTransactions.map((exp) {
                      final hasName =
                          exp.expenseName != null &&
                          exp.expenseName!.trim().isNotEmpty;
                      final hasNotes =
                          exp.notes != null && exp.notes!.trim().isNotEmpty;
                      final title = hasName
                          ? exp.expenseName!
                          : (hasNotes ? exp.notes! : '—');

                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              DateFormatter.formatArabicDate(
                                exp.expenseDate.toDateTime(),
                              ),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundSecondary,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSm,
                                ),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                exp.categoryNameSnapshot,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    title,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (hasName && hasNotes) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      exp.notes!,
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textTertiary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${exp.amount.toEgp.toStringAsFixed(2)} ج.م',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      );
    }
  }
