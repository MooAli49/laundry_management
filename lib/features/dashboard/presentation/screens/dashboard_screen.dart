import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../domain/entities/customer.dart';
import '../../../../domain/entities/financial_report_data.dart';
import '../../../../domain/entities/orders_report_data.dart';
import '../../../../domain/enums/report_period.dart';
import '../../../../domain/repositories/customer_repository.dart';
import '../../../../domain/repositories/reports_repository.dart';
import '../../../customers/presentation/widgets/customer_form_dialog.dart';
import '../../../expenses/presentation/widgets/add_expense_dialog.dart';
import '../../../reports/presentation/widgets/report_metric_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  OrdersReportData _ordersData = OrdersReportData.empty;
  FinancialReportData _financialData = FinancialReportData.empty;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final range = ReportPeriod.today.resolveDateRange();
      final reportsRepo = getIt<ReportsRepository>();

      final orders = await reportsRepo.getOrdersReport(
        startDate: range.start,
        endDate: range.end,
      );

      final financial = await reportsRepo.getFinancialReport(
        startDate: range.start,
        endDate: range.end,
      );

      if (mounted) {
        setState(() {
          _ordersData = orders;
          _financialData = financial;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openAddCustomerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => CustomerFormDialog(
        onSave: ({required name, required phone, notes}) async {
          final repo = getIt<CustomerRepository>();
          final now = DateTime.now();
          final newCustomer = Customer(
            id: const Uuid().v4(),
            name: name,
            phone: phone,
            notes: notes,
            createdAt: now,
            updatedAt: now,
          );
          await repo.createCustomer(newCustomer);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تمت إضافة العميل بنجاح')),
            );
          }
        },
      ),
    );
  }

  void _openAddExpenseDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AddExpenseDialog(
        onExpenseCreated: (_) async {
          _loadDashboardData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: AppSpacing.paddingPage,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            PageHeader(
              title: AppStrings.dashboard,
              subtitle: 'نظرة عامة على العمليات التشغيلية والإجراءات السريعة',
              actions: [
                IconButton(
                  tooltip: 'تحديث',
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadDashboardData,
                ),
              ],
            ),

            // Quick Actions Bar
            Text('الإجراءات السريعة', style: AppTextStyles.titleLarge),
            AppSpacing.gapMd,
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                AppButton(
                  key: const ValueKey('dashboard_add_order_button'),
                  label: 'إضافة طلب',
                  icon: Icons.add,
                  variant: AppButtonVariant.primary,
                  onPressed: () => context.push(AppRoutes.ordersNew),
                ),
                AppButton(
                  key: const ValueKey('dashboard_add_customer_button'),
                  label: 'إضافة عميل',
                  icon: Icons.person_add_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: _openAddCustomerDialog,
                ),
                AppButton(
                  key: const ValueKey('dashboard_record_payment_button'),
                  label: 'تسجيل دفعة',
                  icon: Icons.payment_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => context.push(AppRoutes.orders),
                ),
                AppButton(
                  key: const ValueKey('dashboard_add_expense_button'),
                  label: 'إضافة مصروف',
                  icon: Icons.shopping_bag_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: _openAddExpenseDialog,
                ),
              ],
            ),
            AppSpacing.gapXxl,

            // Operational & Financial Summary
            Text('ملخص اليوم', style: AppTextStyles.titleLarge),
            AppSpacing.gapMd,

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(child: LoadingIndicator(message: 'جاري تحميل ملخص اليوم...')),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final isSmall = constraints.maxWidth < 650;
                  final cardWidth = isSmall
                      ? constraints.maxWidth
                      : (constraints.maxWidth - (AppSpacing.md * 2)) / 3;

                  return Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: ReportMetricCard(
                          title: 'طلبات اليوم',
                          value: '${_ordersData.totalOrders}',
                          icon: Icons.receipt_long,
                          subtitle: 'إجمالي الطلبات المستلمة اليوم',
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: ReportMetricCard(
                          title: 'قيد التنفيذ',
                          value: '${_ordersData.processingOrdersCount}',
                          icon: Icons.sync,
                          iconColor: AppColors.info,
                          iconBackground: AppColors.infoLight,
                          subtitle: 'طلبات جاري العمل عليها',
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: ReportMetricCard(
                          title: 'جاهزة للتسليم',
                          value: '${_ordersData.readyOrdersCount}',
                          icon: Icons.inventory_2_outlined,
                          iconColor: AppColors.warning,
                          iconBackground: AppColors.warningLight,
                          subtitle: 'طلبات جاهزة لتسليم العملاء',
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: ReportMetricCard(
                          title: 'مبيعات اليوم',
                          value: '${_financialData.totalSales.toEgp.toStringAsFixed(2)} ج.م',
                          icon: Icons.point_of_sale,
                          subtitle: 'إجمالي قيمة طلبات اليوم',
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: ReportMetricCard(
                          title: 'مصروفات اليوم',
                          value: '${_financialData.totalOperatingExpenses.toEgp.toStringAsFixed(2)} ج.م',
                          icon: Icons.shopping_bag_outlined,
                          iconColor: AppColors.error,
                          iconBackground: AppColors.errorLight,
                          valueColor: AppColors.error,
                          subtitle: 'مصروفات التشغيل المسجلة اليوم',
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: ReportMetricCard(
                          title: 'مبالغ متبقية',
                          value: '${_financialData.outstandingAmount.toEgp.toStringAsFixed(2)} ج.م',
                          icon: Icons.hourglass_bottom,
                          iconColor: _financialData.outstandingAmount.isPositive
                              ? AppColors.warning
                              : AppColors.textSecondary,
                          iconBackground: _financialData.outstandingAmount.isPositive
                              ? AppColors.warningLight
                              : AppColors.backgroundSecondary,
                          valueColor: _financialData.outstandingAmount.isPositive
                              ? AppColors.warning
                              : null,
                          subtitle: 'متبقي على طلبات اليوم',
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
