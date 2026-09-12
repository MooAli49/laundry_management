import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/order_status_badge.dart';
import '../../../../domain/entities/dashboard_order_item.dart';
import '../../../../domain/enums/payment_method.dart';
import '../../../../domain/value_objects/money.dart';
import '../cubit/record_payment_cubit.dart';
import '../cubit/record_payment_state.dart';

class RecordPaymentDialog extends StatelessWidget {
  final VoidCallback? onPaymentSuccess;
  final RecordPaymentCubit? cubit;

  const RecordPaymentDialog({
    super.key,
    this.onPaymentSuccess,
    this.cubit,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => (cubit ?? getIt<RecordPaymentCubit>())..searchOrders(),
      child: _RecordPaymentDialogView(onPaymentSuccess: onPaymentSuccess),
    );
  }
}

class _RecordPaymentDialogView extends StatefulWidget {
  final VoidCallback? onPaymentSuccess;

  const _RecordPaymentDialogView({this.onPaymentSuccess});

  @override
  State<_RecordPaymentDialogView> createState() => _RecordPaymentDialogViewState();
}

class _RecordPaymentDialogViewState extends State<_RecordPaymentDialogView> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  PaymentMethod _selectedMethod = PaymentMethod.cash;
  String? _localValidationError;

  @override
  void dispose() {
    _searchController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _onOrderSelected(DashboardOrderItem order) {
    setState(() {
      _amountController.text = order.remainingAmount.toEgp.toStringAsFixed(2);
      _localValidationError = null;
    });
    context.read<RecordPaymentCubit>().selectOrder(order);
  }

  void _fillFullAmount(Money remaining) {
    setState(() {
      _amountController.text = remaining.toEgp.toStringAsFixed(2);
      _localValidationError = null;
    });
  }

  Future<void> _handleConfirmPayment(RecordPaymentState state) async {
    final selected = state.selectedOrder;
    if (selected == null) return;

    final text = _amountController.text.trim();
    final parsed = double.tryParse(text);

    if (parsed == null || parsed <= 0) {
      setState(() => _localValidationError = 'يرجى إدخال مبلغ أكبر من الصفر');
      return;
    }

    final enteredMoney = Money.fromEgp(parsed);
    if (enteredMoney > selected.remainingAmount) {
      setState(() => _localValidationError = 'المبلغ المدخل يتجاوز المبلغ المتبقي على الطلب');
      return;
    }

    setState(() => _localValidationError = null);

    final cubit = context.read<RecordPaymentCubit>();
    final payment = await cubit.recordPayment(
      amount: enteredMoney,
      method: _selectedMethod,
    );

    if (payment != null) {
      widget.onPaymentSuccess?.call();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecordPaymentCubit, RecordPaymentState>(
      builder: (context, state) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: state.step == RecordPaymentStep.selectOrder
                  ? _buildOrderSelectionStep(context, state)
                  : _buildPaymentEntryStep(context, state),
            ),
          ),
        );
      },
    );
  }

  // STEP 1: Select Order
  Widget _buildOrderSelectionStep(BuildContext context, RecordPaymentState state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('تسجيل دفعة', style: AppTextStyles.titleLarge),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        AppSpacing.gapMd,

        // Search Field (Order number, customer name, phone number)
        AppTextField(
          key: const ValueKey('payment_order_search_field'),
          controller: _searchController,
          hintText: 'ابحث برقم الطلب أو اسم العميل',
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
          onChanged: (query) {
            context.read<RecordPaymentCubit>().searchOrders(query);
          },
        ),
        AppSpacing.gapMd,

        if (state.errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.error),
                AppSpacing.gapHorizontalSm,
                Expanded(
                  child: Text(
                    state.errorMessage!,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapMd,
        ],

        // Results List
        Expanded(
          child: state.isLoadingOrders
              ? const Center(child: LoadingIndicator(message: 'جاري البحث عن الطلبات...'))
              : state.orders.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.trim().isNotEmpty
                            ? 'لا توجد طلبات مطابقة للبحث'
                            : 'لا توجد طلبات بمبالغ متبقية',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      key: const ValueKey('payment_order_selection_list'),
                      itemCount: state.orders.length,
                      separatorBuilder: (_, __) => AppSpacing.gapSm,
                      itemBuilder: (context, index) {
                        final item = state.orders[index];
                        return AppCard(
                          key: ValueKey('payment_order_item_${item.order.id}'),
                          onTap: () => _onOrderSelected(item),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.md,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.backgroundSecondary,
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                ),
                                child: Text(
                                  '#${item.order.orderNumber}',
                                  style: AppTextStyles.labelMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              AppSpacing.gapHorizontalMd,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.order.customerNameSnapshot,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    AppSpacing.gapXs,
                                    Text(
                                      'المتبقي: ${item.remainingAmount.toEgp.toStringAsFixed(2)} ج.م',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.warning,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AppSpacing.gapHorizontalSm,
                              OrderStatusBadge(status: item.order.status),
                              AppSpacing.gapHorizontalSm,
                              const Icon(
                                Icons.chevron_left,
                                color: AppColors.textTertiary,
                                size: 20,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
        AppSpacing.gapMd,

        // Actions
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AppButton(
              label: 'إلغاء',
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    );
  }

  // STEP 2: Payment Entry
  Widget _buildPaymentEntryStep(BuildContext context, RecordPaymentState state) {
    final selected = state.selectedOrder!;
    final error = _localValidationError ?? state.errorMessage;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('تسجيل دفعة', style: AppTextStyles.titleLarge),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          AppSpacing.gapLg,

          // Selected Order Card (Matching SCREENSHOT 2)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '#${selected.order.orderNumber}',
                          style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                        AppSpacing.gapHorizontalSm,
                        OrderStatusBadge(status: selected.order.status),
                      ],
                    ),
                    AppSpacing.gapXs,
                    Text(
                      selected.order.customerNameSnapshot,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push(AppRoutes.orderDetailPath(selected.order.id));
                  },
                  icon: const Icon(Icons.open_in_new_outlined, size: 18),
                  label: const Text('فتح الطلب'),
                ),
              ],
            ),
          ),
          AppSpacing.gapLg,

          // Remaining Banner
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'المبلغ المتبقي',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${selected.remainingAmount.toEgp.toStringAsFixed(2)} ج.م',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapLg,

          if (error != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error),
                  AppSpacing.gapHorizontalSm,
                  Expanded(
                    child: Text(
                      error,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.gapMd,
          ],

          // Amount Field with "المبلغ كامل" shortcut
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AppTextField(
                  key: const ValueKey('record_payment_amount_field'),
                  controller: _amountController,
                  label: 'المبلغ (ج.م) *',
                  hintText: '0.00',
                  keyboardType: TextInputType.number,
                ),
              ),
              AppSpacing.gapHorizontalSm,
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: AppButton(
                  key: const ValueKey('record_payment_full_amount_button'),
                  label: 'المبلغ كامل',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => _fillFullAmount(selected.remainingAmount),
                ),
              ),
            ],
          ),
          AppSpacing.gapLg,

          // Payment Method Selector
          Text('طريقة الدفع *', style: AppTextStyles.labelLarge),
          AppSpacing.gapSm,
          Row(
            children: [
              Expanded(
                child: _buildMethodButton(
                  PaymentMethod.cash,
                  'كاش',
                  Icons.payments_outlined,
                ),
              ),
              AppSpacing.gapHorizontalSm,
              Expanded(
                child: _buildMethodButton(
                  PaymentMethod.instapay,
                  'InstaPay',
                  Icons.flash_on,
                ),
              ),
              AppSpacing.gapHorizontalSm,
              Expanded(
                child: _buildMethodButton(
                  PaymentMethod.ewallet,
                  'محفظة إلكترونية',
                  Icons.account_balance_wallet_outlined,
                ),
              ),
            ],
          ),
          AppSpacing.gapXl,

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppButton(
                key: const ValueKey('record_payment_back_button'),
                label: 'اختيار طلب آخر',
                variant: AppButtonVariant.secondary,
                onPressed: state.isRecordingPayment
                    ? null
                    : () => context.read<RecordPaymentCubit>().backToOrderSelection(),
              ),
              AppButton(
                key: const ValueKey('record_payment_confirm_button'),
                label: 'تأكيد الدفع',
                isLoading: state.isRecordingPayment,
                onPressed: () => _handleConfirmPayment(state),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMethodButton(PaymentMethod method, String label, IconData icon) {
    final isSelected = _selectedMethod == method;
    return InkWell(
      key: ValueKey('payment_method_${method.name}'),
      onTap: () => setState(() => _selectedMethod = method),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLighter : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 24,
            ),
            AppSpacing.gapXs,
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
