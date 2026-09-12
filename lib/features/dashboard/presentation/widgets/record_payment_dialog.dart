import 'dart:async';
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
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        context.read<RecordPaymentCubit>().searchOrders(query);
      }
    });
  }

  void _onOrderSelected(DashboardOrderItem order) {
    setState(() {
      _amountController.text = '0.00';
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
    final enteredMoney = Money.tryParseEgp(text);

    if (enteredMoney == null || enteredMoney.isZero || enteredMoney.isNegative) {
      setState(() => _localValidationError = 'يرجى إدخال مبلغ أكبر من الصفر');
      return;
    }

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
            constraints: const BoxConstraints(minWidth: 360, maxWidth: 380, maxHeight: 620),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
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
        // Header without X close icon
        Text('تسجيل دفعة', style: AppTextStyles.titleLarge),
        AppSpacing.gapMd,

        // Search Field (Order number, customer name, phone number)
        AppTextField(
          key: const ValueKey('payment_order_search_field'),
          controller: _searchController,
          hintText: 'ابحث برقم الطلب أو اسم العميل أو رقم الهاتف',
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
          onChanged: _onSearchChanged,
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
                        final rawNumber = item.order.orderNumber.replaceFirst('#', '');
                        final displayNumber = '#$rawNumber';

                        return AppCard(
                          key: ValueKey('payment_order_item_${item.order.id}'),
                          onTap: () => _onOrderSelected(item),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          child: Row(
                            children: [
                              // Right side: receipt icon in light square
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.backgroundSecondary,
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                ),
                                child: const Icon(
                                  Icons.receipt_outlined,
                                  size: 20,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              AppSpacing.gapHorizontalSm,
                              // Order number, status badge, customer name
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: AppSpacing.xs,
                                      runSpacing: AppSpacing.xs,
                                      children: [
                                        Text(
                                          displayNumber,
                                          style: AppTextStyles.labelMedium.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        OrderStatusBadge(status: item.order.status),
                                      ],
                                    ),
                                    AppSpacing.gapXs,
                                    Text(
                                      item.order.customerNameSnapshot,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              AppSpacing.gapHorizontalSm,
                              // Left side: remaining label and amount in warning color (no chevron)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'المتبقي',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textTertiary,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    '${item.remainingAmount.toEgp.toStringAsFixed(2)} ج.م',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
        AppSpacing.gapSm,

        // Bottom text-style action: إلغاء
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'إلغاء',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // STEP 2: Payment Entry
  Widget _buildPaymentEntryStep(BuildContext context, RecordPaymentState state) {
    final selected = state.selectedOrder!;
    final rawNumber = selected.order.orderNumber.replaceFirst('#', '');
    final displayNumber = '#$rawNumber';
    final error = _localValidationError ?? state.errorMessage;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header without X close icon
          Text('تسجيل دفعة', style: AppTextStyles.titleLarge),
          AppSpacing.gapMd,

          // Selected Order Card (SCREENSHOT 2: Primary border, light primary background)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.primaryLighter,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          Text(
                            displayNumber,
                            style: AppTextStyles.titleSmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          OrderStatusBadge(status: selected.order.status),
                        ],
                      ),
                      AppSpacing.gapXs,
                      Text(
                        selected.order.customerNameSnapshot,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // "فتح الطلب" text action without icon
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push(AppRoutes.orderDetailPath(selected.order.id));
                  },
                  child: Text(
                    'فتح الطلب',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapMd,

          // Remaining Banner (Semantic warning styling)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Text(
              'المتبقي: ${selected.remainingAmount.toEgp.toStringAsFixed(2)} ج.م',
              textAlign: TextAlign.center,
              style: AppTextStyles.titleSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.warning,
              ),
            ),
          ),
          AppSpacing.gapMd,

          if (error != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                  AppSpacing.gapHorizontalXs,
                  Expanded(
                    child: Text(
                      error,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.gapSm,
          ],

          // Amount Field with "المبلغ كامل" shortcut button
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AppTextField(
                  key: const ValueKey('record_payment_amount_field'),
                  controller: _amountController,
                  label: 'المبلغ (ج.م) *',
                  hintText: '0.00',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
          AppSpacing.gapMd,

          // Payment Method Selector — exactly 3 horizontal buttons without icons
          Text('طريقة الدفع *', style: AppTextStyles.labelLarge),
          AppSpacing.gapSm,
          Row(
            children: [
              Expanded(
                child: _buildMethodButton(
                  PaymentMethod.cash,
                  'كاش',
                ),
              ),
              AppSpacing.gapHorizontalXs,
              Expanded(
                child: _buildMethodButton(
                  PaymentMethod.instapay,
                  'InstaPay',
                ),
              ),
              AppSpacing.gapHorizontalXs,
              Expanded(
                child: _buildMethodButton(
                  PaymentMethod.ewallet,
                  'محفظة إلكترونية',
                ),
              ),
            ],
          ),
          AppSpacing.gapLg,

          // Bottom Actions: "اختيار طلب آخر" (text action) + "تأكيد الدفع" (primary button with card icon)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              TextButton(
                key: const ValueKey('record_payment_back_button'),
                onPressed: state.isRecordingPayment
                    ? null
                    : () {
                        setState(() {
                          _amountController.text = '0.00';
                          _localValidationError = null;
                        });
                        context.read<RecordPaymentCubit>().backToOrderSelection();
                      },
                child: Text(
                  'اختيار طلب آخر',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              AppButton(
                key: const ValueKey('record_payment_confirm_button'),
                label: 'تأكيد الدفع',
                icon: Icons.payments_outlined,
                isLoading: state.isRecordingPayment,
                onPressed: () => _handleConfirmPayment(state),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMethodButton(PaymentMethod method, String label) {
    final isSelected = _selectedMethod == method;
    return InkWell(
      key: ValueKey('payment_method_${method.name}'),
      onTap: () => setState(() => _selectedMethod = method),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLighter : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
