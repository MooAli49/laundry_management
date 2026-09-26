import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../domain/enums/payment_method.dart';
import '../../../../domain/enums/pricing_type.dart';
import '../../../../domain/value_objects/money.dart';
import '../../../../domain/value_objects/order_date.dart';
import '../cubit/create_order_cubit.dart';
import '../cubit/create_order_state.dart';
import '../widgets/customer_selector.dart';
import '../widgets/order_item_form.dart';
import '../widgets/order_summary_card.dart';

class CreateOrderScreen extends StatelessWidget {
  final String? initialCustomerId;

  const CreateOrderScreen({super.key, this.initialCustomerId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<CreateOrderCubit>()
            ..initialize(initialCustomerId: initialCustomerId),
      child: const _CreateOrderView(),
    );
  }
}

class _CreateOrderView extends StatefulWidget {
  const _CreateOrderView();

  @override
  State<_CreateOrderView> createState() => _CreateOrderViewState();
}

class _CreateOrderViewState extends State<_CreateOrderView> {
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _pickupFeeController = TextEditingController();
  final TextEditingController _deliveryFeeController = TextEditingController();
  final TextEditingController _initialPaymentController = TextEditingController();

  @override
  void dispose() {
    _discountController.dispose();
    _notesController.dispose();
    _pickupFeeController.dispose();
    _deliveryFeeController.dispose();
    _initialPaymentController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(
    BuildContext context,
    CreateOrderCubit cubit,
    OrderDate current,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current.toDateTime().isBefore(now)
          ? now
          : current.toDateTime(),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('ar'),
    );

    if (picked != null) {
      cubit.updateExpectedPickupDate(OrderDate.fromDate(picked));
    }
  }

  void _confirmDeleteItem(
    BuildContext context,
    CreateOrderCubit cubit,
    int index,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'حذف القطعة',
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                AppSpacing.gapLg,
                Text(
                  'هل أنت متأكد من حذف هذه القطعة من الطلب؟',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                AppSpacing.gapXxl,
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    AppButton(
                      label: 'حذف القطعة',
                      variant: AppButtonVariant.destructive,
                      onPressed: () {
                        Navigator.of(dialogCtx).pop();
                        cubit.removeItem(index);
                      },
                    ),
                    AppSpacing.gapHorizontalMd,
                    AppButton(
                      label: 'إلغاء',
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CreateOrderCubit>();

    return Scaffold(
      body: BlocConsumer<CreateOrderCubit, CreateOrderState>(
        listenWhen: (prev, curr) =>
            prev.createdOrder != curr.createdOrder ||
            (curr.errorMessage != null &&
                prev.errorMessage != curr.errorMessage) ||
            prev.initialPaymentAmount != curr.initialPaymentAmount,
        listener: (context, state) {
          if (state.createdOrder != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم إنشاء الطلب بنجاح'),
                backgroundColor: AppColors.success,
              ),
            );
            context.go(AppRoutes.orderDetailPath(state.createdOrder!.id));
          } else if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: AppColors.error,
              ),
            );
          }

          if (state.isInitialPaymentEnabled) {
            final currentParsed =
                double.tryParse(_initialPaymentController.text) ?? 0.0;
            if ((currentParsed - state.initialPaymentAmount.toEgp).abs() >
                0.001) {
              _initialPaymentController.text =
                  state.initialPaymentAmount.isPositive
                      ? state.initialPaymentAmount.toEgp.toStringAsFixed(2)
                      : '';
            }
          }
        },
        builder: (context, state) {
          if (state.isInitialLoading) {
            return const Center(child: LoadingIndicator());
          }

          return SafeArea(
            child: Padding(
              padding: AppSpacing.paddingPage,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Navigation Bar
                  Row(
                    children: [
                      BackButton(
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go(AppRoutes.orders);
                          }
                        },
                      ),
                      AppSpacing.gapHorizontalSm,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إضافة طلب',
                            style: AppTextStyles.headlineSmall.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'إنشاء طلب غسيل جديد وتحديد الأصناف والخدمات',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  AppSpacing.gapLg,

                  // Two-Column Layout
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Right Column (Main Form - Scrollable)
                        Expanded(
                          flex: 7,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Customer Selection Section
                                Text(
                                  'بيانات العميل',
                                  style: AppTextStyles.titleMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                AppSpacing.gapSm,
                                CustomerSelector(
                                  selectedCustomer: state.selectedCustomer,
                                  searchResults: state.customerSearchResults,
                                  isSearching: state.isSearchingCustomer,
                                  onSearch: cubit.searchCustomers,
                                  onSelectCustomer: cubit.selectCustomer,
                                  onAddNewCustomer: cubit.addNewCustomer,
                                ),
                                AppSpacing.gapLg,

                                // Order Item Form
                                OrderItemForm(state: state, cubit: cubit),
                                AppSpacing.gapLg,

                                // Added Items List
                                if (state.items.isNotEmpty) ...[
                                  Text(
                                    'القطع المضافة للطلب — ${state.items.length} قطعة',
                                    style: AppTextStyles.titleMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  AppSpacing.gapSm,
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: state.items.length,
                                    separatorBuilder: (_, __) =>
                                        AppSpacing.gapSm,
                                    itemBuilder: (context, index) {
                                      final item = state.items[index];
                                      return AppCard(
                                        padding: const EdgeInsets.all(
                                          AppSpacing.md,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${item.itemTypeName} - ${item.serviceName}',
                                                    style: AppTextStyles
                                                        .bodyMedium
                                                        .copyWith(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                  ),
                                                  if (item.itemDefinitionName !=
                                                      null) ...[
                                                    AppSpacing.gapXs,
                                                    Text(
                                                      'التعريف: ${item.itemDefinitionName}',
                                                      style: AppTextStyles
                                                          .labelSmall
                                                          .copyWith(
                                                            color: AppColors
                                                                .textSecondary,
                                                          ),
                                                    ),
                                                  ],
                                                  if (item.carpetArea > 0) ...[
                                                    AppSpacing.gapXs,
                                                    Text(
                                                      'أبعاد: ${item.length} × ${item.width} م (${item.carpetArea.toStringAsFixed(2)} م²)',
                                                      style: AppTextStyles
                                                          .labelSmall
                                                          .copyWith(
                                                            color: AppColors
                                                                .textTertiary,
                                                          ),
                                                    ),
                                                  ],
                                                  if (item.notes != null) ...[
                                                    AppSpacing.gapXs,
                                                    Text(
                                                      'ملاحظة: ${item.notes}',
                                                      style: AppTextStyles
                                                          .labelSmall
                                                          .copyWith(
                                                            color: AppColors
                                                                .textTertiary,
                                                          ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            Text(
                                              item.pricingType ==
                                                      PricingType.perSquareMeter
                                                  ? '${item.physicalQuantity} × ${(item.unitPrice.toEgp * item.carpetArea).toStringAsFixed(2)} ج.م'
                                                  : '${item.physicalQuantity} × ${item.unitPrice.toEgp.toStringAsFixed(2)} ج.م',
                                              style: AppTextStyles.bodyMedium
                                                  .copyWith(
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                            ),
                                            AppSpacing.gapHorizontalMd,
                                            Text(
                                              '${item.calculatedTotal.toEgp.toStringAsFixed(2)} ج.م',
                                              style: AppTextStyles.bodyMedium
                                                  .copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            AppSpacing.gapHorizontalSm,
                                            IconButton(
                                              onPressed: () =>
                                                  _confirmDeleteItem(
                                                    context,
                                                    cubit,
                                                    index,
                                                  ),
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: AppColors.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  AppSpacing.gapLg,
                                ],

                                // Order-Level Details (Date, Delivery, Discount, Notes)
                                Text(
                                  'بيانات الطلب',
                                  style: AppTextStyles.titleMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                AppSpacing.gapSm,
                                AppCard(
                                  padding: const EdgeInsets.all(AppSpacing.lg),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Expected Pickup Date
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'موعد الاستلام المتوقع *',
                                                  style:
                                                      AppTextStyles.labelLarge,
                                                ),
                                                AppSpacing.gapXs,
                                                InkWell(
                                                  onTap: () => _selectDate(
                                                    context,
                                                    cubit,
                                                    state.expectedPickupDate,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        AppSpacing.radiusMd,
                                                      ),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal:
                                                              AppSpacing.md,
                                                          vertical:
                                                              AppSpacing.md,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            AppSpacing.radiusMd,
                                                          ),
                                                      border: Border.all(
                                                        color: AppColors.border,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Text(
                                                          DateFormatter.formatArabicDate(
                                                            state
                                                                .expectedPickupDate
                                                                .toDateTime(),
                                                          ),
                                                          style: AppTextStyles
                                                              .bodyMedium,
                                                        ),
                                                        const Icon(
                                                          Icons.calendar_today,
                                                          size: 18,
                                                          color: AppColors
                                                              .textTertiary,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          AppSpacing.gapHorizontalMd,
                                          Expanded(
                                            child: AppTextField(
                                              controller: _discountController,
                                              label: 'خصم (ج.م)',
                                              hintText: '0.00',
                                              keyboardType:
                                                  const TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                              onChanged: (val) {
                                                final numVal =
                                                    double.tryParse(val) ?? 0.0;
                                                cubit.updateDiscount(
                                                  Money.fromEgp(numVal),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      AppSpacing.gapLg,

                                      // Delivery Options (Figma parity cards)
                                      Text(
                                        'التوصيل',
                                        style: AppTextStyles.labelLarge
                                            .copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      Text(
                                        'يمكن اختيار الاستلام والتوصيل معاً، ولكل منهما رسومه المستقلة.',
                                        style: AppTextStyles.labelSmall
                                            .copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                      ),
                                      AppSpacing.gapSm,

                                      // Pickup Option Card ("استلام من العميل")
                                      Container(
                                        padding: const EdgeInsets.all(
                                          AppSpacing.md,
                                        ),
                                        decoration: BoxDecoration(
                                          color: state.customerPickupRequested
                                              ? AppColors.primaryLighter
                                              : AppColors.surface,
                                          borderRadius: BorderRadius.circular(
                                            AppSpacing.radiusLg,
                                          ),
                                          border: Border.all(
                                            color: state.customerPickupRequested
                                                ? AppColors.primary
                                                : AppColors.border,
                                            width: state.customerPickupRequested
                                                ? 1.5
                                                : 1.0,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            InkWell(
                                              onTap: () => cubit.updateDelivery(
                                                pickupRequested: !state
                                                    .customerPickupRequested,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppSpacing.radiusMd,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Checkbox(
                                                    value: state
                                                        .customerPickupRequested,
                                                    activeColor:
                                                        AppColors.primary,
                                                    onChanged: (val) =>
                                                        cubit.updateDelivery(
                                                          pickupRequested:
                                                              val ?? false,
                                                        ),
                                                  ),
                                                  const Icon(
                                                    Icons.local_shipping,
                                                    size: 20,
                                                    color:
                                                        AppColors.textTertiary,
                                                  ),
                                                  AppSpacing.gapHorizontalSm,
                                                  Text(
                                                    'استلام من العميل',
                                                    style: AppTextStyles
                                                        .bodyMedium
                                                        .copyWith(
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: AppColors
                                                              .textPrimary,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (state
                                                .customerPickupRequested) ...[
                                              AppSpacing.gapSm,
                                              Padding(
                                                padding:
                                                    const EdgeInsetsDirectional.only(
                                                      start: 40.0,
                                                    ),
                                                child: SizedBox(
                                                  width: 180,
                                                  child: AppTextField(
                                                    controller:
                                                        _pickupFeeController,
                                                    label:
                                                        'رسوم الاستلام (ج.م)',
                                                    hintText: '0.00',
                                                    keyboardType:
                                                        const TextInputType.numberWithOptions(
                                                          decimal: true,
                                                        ),
                                                    onChanged: (val) {
                                                      final fee =
                                                          double.tryParse(
                                                            val,
                                                          ) ??
                                                          0.0;
                                                      cubit.updateDelivery(
                                                        pickupFee:
                                                            Money.fromEgp(fee),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      AppSpacing.gapSm,

                                      // Delivery Option Card ("توصيل للعميل")
                                      Container(
                                        padding: const EdgeInsets.all(
                                          AppSpacing.md,
                                        ),
                                        decoration: BoxDecoration(
                                          color: state.customerDeliveryRequested
                                              ? AppColors.primaryLighter
                                              : AppColors.surface,
                                          borderRadius: BorderRadius.circular(
                                            AppSpacing.radiusLg,
                                          ),
                                          border: Border.all(
                                            color:
                                                state.customerDeliveryRequested
                                                ? AppColors.primary
                                                : AppColors.border,
                                            width:
                                                state.customerDeliveryRequested
                                                ? 1.5
                                                : 1.0,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            InkWell(
                                              onTap: () => cubit.updateDelivery(
                                                deliveryRequested: !state
                                                    .customerDeliveryRequested,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppSpacing.radiusMd,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Checkbox(
                                                    value: state
                                                        .customerDeliveryRequested,
                                                    activeColor:
                                                        AppColors.primary,
                                                    onChanged: (val) =>
                                                        cubit.updateDelivery(
                                                          deliveryRequested:
                                                              val ?? false,
                                                        ),
                                                  ),
                                                  const Icon(
                                                    Icons.local_shipping,
                                                    size: 20,
                                                    color:
                                                        AppColors.textTertiary,
                                                  ),
                                                  AppSpacing.gapHorizontalSm,
                                                  Text(
                                                    'توصيل للعميل',
                                                    style: AppTextStyles
                                                        .bodyMedium
                                                        .copyWith(
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: AppColors
                                                              .textPrimary,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (state
                                                .customerDeliveryRequested) ...[
                                              AppSpacing.gapSm,
                                              Padding(
                                                padding:
                                                    const EdgeInsetsDirectional.only(
                                                      start: 40.0,
                                                    ),
                                                child: SizedBox(
                                                  width: 180,
                                                  child: AppTextField(
                                                    controller:
                                                        _deliveryFeeController,
                                                    label: 'رسوم التوصيل (ج.م)',
                                                    hintText: '0.00',
                                                    keyboardType:
                                                        const TextInputType.numberWithOptions(
                                                          decimal: true,
                                                        ),
                                                    onChanged: (val) {
                                                      final fee =
                                                          double.tryParse(
                                                            val,
                                                          ) ??
                                                          0.0;
                                                      cubit.updateDelivery(
                                                        deliveryFee:
                                                            Money.fromEgp(fee),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      AppSpacing.gapLg,

                                      // Order Notes
                                      AppTextField(
                                        controller: _notesController,
                                        label: 'ملاحظات الطلب',
                                        hintText:
                                            'أي ملاحظات عامة على الطلب (اختياري)',
                                        maxLines: 3,
                                        onChanged: cubit.updateOrderNotes,
                                      ),
                                    ],
                                  ),
                                ),
                                AppSpacing.gapXxl,
                              ],
                            ),
                          ),
                        ),
                        AppSpacing.gapHorizontalLg,

                        // Left Column (Advance Payment & Sticky Order Summary Card)
                        Expanded(
                          flex: 3,
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                _buildAdvancePaymentCard(context, state, cubit),
                                AppSpacing.gapLg,
                                OrderSummaryCard(
                                  state: state,
                                  onSubmit: cubit.submitOrder,
                                  onCancel: () => context.go(AppRoutes.orders),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdvancePaymentCard(
    BuildContext context,
    CreateOrderState state,
    CreateOrderCubit cubit,
  ) {
    final isEnabled = state.isInitialPaymentEnabled;
    final isFullyPaid =
        isEnabled && state.remainingAmount == Money.zero;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isEnabled
            ? (isFullyPaid
                ? AppColors.successLight
                : AppColors.primaryLighter.withValues(alpha: 0.5))
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(
          color: isEnabled
              ? (isFullyPaid ? AppColors.success : AppColors.primary)
              : AppColors.border,
          width: isEnabled ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header row ────────────────────────────────────────
              Row(
                children: [
                  Icon(
                    isFullyPaid
                        ? Icons.check_circle_outline
                        : Icons.payments_outlined,
                    size: 18,
                    color: isEnabled
                        ? (isFullyPaid
                            ? AppColors.success
                            : AppColors.primary)
                        : AppColors.textTertiary,
                  ),
                  AppSpacing.gapHorizontalSm,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تسجيل دفعة مقدمة',
                          style: AppTextStyles.labelLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isEnabled
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          isEnabled
                              ? (isFullyPaid
                                  ? 'مدفوع بالكامل ✓'
                                  : 'أدخل المبلغ المُقدَّم أدناه')
                              : 'اختياري — اضغط للتفعيل',
                          style: AppTextStyles.caption.copyWith(
                            color: isEnabled
                                ? (isFullyPaid
                                    ? AppColors.success
                                    : AppColors.primary)
                                : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    key: const ValueKey('advance_payment_switch'),
                    value: state.isInitialPaymentEnabled,
                    activeThumbColor: AppColors.primary,
                    inactiveThumbColor: AppColors.textTertiary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (enabled) {
                      cubit.toggleInitialPayment(enabled);
                      if (!enabled) {
                        _initialPaymentController.clear();
                      } else {
                        _initialPaymentController.text =
                            state.initialPaymentAmount.isPositive
                                ? state.initialPaymentAmount.toEgp
                                    .toStringAsFixed(2)
                                : '';
                      }
                    },
                  ),
                ],
              ),

              // ─── Expanded body (only when enabled) ─────────────────
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: isEnabled
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(
                            height: AppSpacing.lg,
                            color: AppColors.divider,
                          ),

                          // Amount field
                          AppTextField(
                            key: const ValueKey(
                              'advance_payment_amount_field',
                            ),
                            controller: _initialPaymentController,
                            label: 'مبلغ الدفعة (ج.م)',
                            hintText: '0.00',
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (val) {
                              final amount =
                                  double.tryParse(val) ?? 0.0;
                              cubit.updateInitialPaymentAmount(
                                Money.fromEgp(amount),
                              );
                            },
                          ),
                          AppSpacing.gapSm,

                          // Full-amount shortcut button
                          _buildFullAmountButton(state, cubit),
                          AppSpacing.gapMd,

                          // Payment method chips
                          Text(
                            'طريقة الدفع',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          AppSpacing.gapXs,
                          _buildPaymentMethodRow(state, cubit),
                          AppSpacing.gapSm,

                          // Remaining amount banner
                          _buildRemainingAmountBanner(state),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullAmountButton(
    CreateOrderState state,
    CreateOrderCubit cubit,
  ) {
    final isActive =
        state.total.isPositive && state.initialPaymentAmount == state.total;
    final canPress = state.total.isPositive;
    final activeColor = isActive ? AppColors.primaryDark : AppColors.primary;
    final inactiveColor = AppColors.textDisabled;
    final labelColor = canPress ? activeColor : inactiveColor;

    return SizedBox(
      height: 34,
      width: double.infinity,
      child: OutlinedButton.icon(
        key: const ValueKey('advance_payment_full_amount_button'),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: canPress
                ? (isActive ? AppColors.primary : AppColors.borderStrong)
                : AppColors.border,
            width: 1.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          backgroundColor: isActive ? AppColors.primaryLighter : AppColors.surface,
        ),
        onPressed: canPress
            ? () {
                cubit.setFullInitialPayment();
                _initialPaymentController.text =
                    state.total.toEgp.toStringAsFixed(2);
              }
            : null,
        icon: Icon(
          isActive ? Icons.check_circle : Icons.check_circle_outline,
          size: 15,
          color: labelColor,
        ),
        label: Text(
          canPress
              ? 'دفع الإجمالي (${state.total.toEgp.toStringAsFixed(2)} ج.م)'
              : 'دفع المبلغ بالكامل',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.labelMedium.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodRow(
    CreateOrderState state,
    CreateOrderCubit cubit,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildPaymentMethodChip(
            key: const ValueKey('advance_payment_method_cash'),
            label: 'كاش',
            icon: Icons.payments_outlined,
            isSelected: state.initialPaymentMethod == PaymentMethod.cash,
            onTap: () => cubit.updateInitialPaymentMethod(PaymentMethod.cash),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _buildPaymentMethodChip(
            key: const ValueKey('advance_payment_method_instapay'),
            label: 'إنستا باي',
            icon: Icons.bolt_outlined,
            isSelected:
                state.initialPaymentMethod == PaymentMethod.instapay,
            onTap: () =>
                cubit.updateInitialPaymentMethod(PaymentMethod.instapay),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _buildPaymentMethodChip(
            key: const ValueKey('advance_payment_method_wallet'),
            label: 'محفظة',
            icon: Icons.account_balance_wallet_outlined,
            isSelected:
                state.initialPaymentMethod == PaymentMethod.ewallet,
            onTap: () =>
                cubit.updateInitialPaymentMethod(PaymentMethod.ewallet),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodChip({
    required Key key,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 36,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceSelected : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? AppColors.primaryDark
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.labelSmall.copyWith(
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.primaryDark
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemainingAmountBanner(CreateOrderState state) {
    final isFullyPaid = state.remainingAmount == Money.zero;
    final bannerColor = isFullyPaid ? AppColors.successDark : AppColors.warningDark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isFullyPaid ? AppColors.successLight : AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: isFullyPaid
              ? AppColors.success.withValues(alpha: 0.35)
              : AppColors.warning.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isFullyPaid ? Icons.check_circle_outline : Icons.info_outline,
            size: 14,
            color: isFullyPaid ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              'المتبقي:',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: bannerColor,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            isFullyPaid
                ? 'مدفوع بالكامل'
                : '${state.remainingAmount.toEgp.toStringAsFixed(2)} ج.م',
            style: AppTextStyles.labelMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: bannerColor,
            ),
          ),
        ],
      ),
    );
  }
}
