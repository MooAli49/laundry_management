import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../domain/entities/order_item.dart';
import '../../../../domain/entities/payment.dart';
import '../../../../domain/enums/order_status.dart';
import '../../../../domain/enums/payment_method.dart';
import '../../../../domain/enums/pricing_type.dart';
import '../../../../domain/value_objects/money.dart';
import '../cubit/order_detail_cubit.dart';
import '../cubit/order_detail_state.dart';
import '../widgets/add_payment_dialog.dart';
import '../widgets/cancel_order_dialog.dart';
import '../widgets/invoice_preview_dialog.dart';
import '../widgets/order_status_badge.dart';
import '../widgets/status_change_dialog.dart';
import '../widgets/store_items_dialog.dart';

class OrderDetailScreen extends StatelessWidget {
  final String orderId;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<OrderDetailCubit>(
      create: (context) => getIt<OrderDetailCubit>()..loadOrderDetail(orderId),
      child: const _OrderDetailView(),
    );
  }
}

class _OrderDetailView extends StatelessWidget {
  const _OrderDetailView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OrderDetailCubit>();

    return BlocConsumer<OrderDetailCubit, OrderDetailState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        if (state.actionSuccessMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.actionSuccessMessage!),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state.isLoading) {
          return const Scaffold(
            body: Center(child: LoadingIndicator()),
          );
        }

        if (state.errorMessage != null && state.order == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
            ),
            body: AppErrorState(
              title: 'تعذر تحميل بيانات الطلب',
              message: state.errorMessage!,
              onRetry: () => cubit.loadOrderDetail(state.order?.id ?? ''),
            ),
          );
        }

        final order = state.order;
        if (order == null) {
          return const Scaffold(
            body: Center(child: Text('الطلب غير موجود')),
          );
        }

        final isCancelled = order.status == OrderStatus.cancelled;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            title: Row(
              children: [
                Text(
                  'طلب #${order.orderNumber}',
                  style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold),
                ),
                AppSpacing.gapHorizontalMd,
                OrderStatusBadge(status: order.status),
              ],
            ),
            actions: [
              // Cancelled orders MUST NOT have any invoice actions!
              if (!isCancelled)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: AppButton(
                    label: 'معاينة الفاتورة',
                    icon: Icons.receipt_long,
                    variant: AppButtonVariant.secondary,
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => InvoicePreviewDialog(
                          order: order,
                          items: state.items,
                          totalPaid: state.totalPaid,
                          remainingAmount: state.remainingAmount,
                          customer: state.customer,
                          settings: state.settings,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: AppSpacing.paddingLg,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Right Column (Details, Items, Payments)
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Meta Card
                      _buildHeaderMetaCard(context, state),
                      AppSpacing.gapLg,

                      // Customer Details Card
                      _buildCustomerCard(context, state),
                      AppSpacing.gapLg,

                      // Items List Card
                      _buildItemsCard(context, state),
                      AppSpacing.gapLg,

                      // Payment History Card
                      _buildPaymentHistoryCard(context, state),
                    ],
                  ),
                ),
                AppSpacing.gapHorizontalLg,

                // Left Column (Financial Summary & Order Actions)
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Financial Summary Card
                      _buildFinancialSummaryCard(context, state),
                      AppSpacing.gapLg,

                      // Actions Card
                      _buildActionsCard(context, state),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderMetaCard(BuildContext context, OrderDetailState state) {
    final order = state.order!;
    final pickupDate = order.expectedPickupDate;
    final createdDate = order.createdAt;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تاريخ الاستلام المتوقع',
                    style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary),
                  ),
                  AppSpacing.gapXs,
                  Text(
                    pickupDate.toString(),
                    style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'تاريخ الإنشاء',
                    style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary),
                  ),
                  AppSpacing.gapXs,
                  Text(
                    '${createdDate.year}-${createdDate.month.toString().padLeft(2, '0')}-${createdDate.day.toString().padLeft(2, '0')}',
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
            ],
          ),

          // Delivery info
          if (order.customerPickupRequested || order.customerDeliveryRequested) ...[
            const Divider(height: AppSpacing.xxl, color: AppColors.divider),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (order.customerPickupRequested)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      children: [
                        const Icon(Icons.hail, size: 20, color: AppColors.primary),
                        AppSpacing.gapHorizontalSm,
                        Text(
                          'استلام من العميل (العميل → المغسلة) (+ ${order.customerPickupFee.toEgp.toStringAsFixed(2)} ج.م)',
                          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                if (order.customerDeliveryRequested)
                  Row(
                    children: [
                      const Icon(Icons.local_shipping, size: 20, color: AppColors.primary),
                      AppSpacing.gapHorizontalSm,
                      Text(
                        'توصيل للعميل (المغسلة → العميل) (+ ${order.customerDeliveryFee.toEgp.toStringAsFixed(2)} ج.م)',
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
              ],
            ),
          ],

          // Order Notes
          if (order.notes != null && order.notes!.isNotEmpty) ...[
            const Divider(height: AppSpacing.xxl, color: AppColors.divider),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes, size: 20, color: AppColors.textSecondary),
                AppSpacing.gapHorizontalSm,
                Expanded(
                  child: Text(
                    'ملاحظات الطلب: ${order.notes}',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomerCard(BuildContext context, OrderDetailState state) {
    final customer = state.customer;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.selectionBackground,
                child: Icon(Icons.person, color: AppColors.primary),
              ),
              AppSpacing.gapHorizontalMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer?.name ?? 'عميل غير مسجل',
                      style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (customer?.phone != null) ...[
                      AppSpacing.gapXs,
                      Text(
                        customer!.phone,
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (customer?.notes != null && customer!.notes!.isNotEmpty) ...[
            AppSpacing.gapSm,
            Text(
              'ملاحظات العميل: ${customer.notes}',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsCard(BuildContext context, OrderDetailState state) {
    final cubit = context.read<OrderDetailCubit>();
    final items = state.items;
    final unstoredCount = state.unstoredItems.length;
    final order = state.order!;
    final isFinal = order.status == OrderStatus.completed || order.status == OrderStatus.cancelled;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'عناصر الطلب (${items.length} قطع فيزيائية)',
                style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              if (!isFinal && unstoredCount > 0)
                AppButton(
                  label: 'تخزين العناصر ($unstoredCount)',
                  icon: Icons.inventory_2,
                  variant: AppButtonVariant.primary,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => StoreItemsDialog(
                        unstoredItems: state.unstoredItems,
                        availableLocations: state.allActiveLocations,
                        onStore: ({required orderItemIds, required storageLocationId}) async {
                          await cubit.storeItems(
                            orderItemIds: orderItemIds,
                            storageLocationId: storageLocationId,
                          );
                        },
                      ),
                    );
                  },
                ),
            ],
          ),
          AppSpacing.gapMd,

          if (unstoredCount > 0 && !isFinal)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                  AppSpacing.gapHorizontalSm,
                  Expanded(
                    child: Text(
                      'يوجد $unstoredCount عناصر لم يتم تخزينها بعد. لن يتحول الطلب إلى "جاهز" حتى يتم تخزين جميع العناصر.',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),

          // Items Table / List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: AppSpacing.lg, color: AppColors.divider),
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildPhysicalItemRow(context, item, index + 1, state);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPhysicalItemRow(
    BuildContext context,
    OrderItem item,
    int displayIndex,
    OrderDetailState state,
  ) {
    final storageRecord = state.activeStorageRecords[item.id];
    final location = storageRecord != null ? state.storageLocations[storageRecord.storageLocationId] : null;

    final isStored = location != null;
    final isCarpet = item.pricingType == PricingType.perSquareMeter;
    final carpet = item.carpetData;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Number badge
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Text(
            '$displayIndex',
            style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        AppSpacing.gapHorizontalMd,

        // Details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${item.itemTypeNameSnapshot} - ${item.serviceNameSnapshot}',
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (item.itemDefinitionNameSnapshot != null) ...[
                    AppSpacing.gapHorizontalSm,
                    Text(
                      '(${item.itemDefinitionNameSnapshot})',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                  if (isCarpet && carpet != null) ...[
                    AppSpacing.gapHorizontalSm,
                    Text(
                      '(${carpet.length} × ${carpet.width} م = ${carpet.area} م²)',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
              if (item.notes != null && item.notes!.isNotEmpty) ...[
                AppSpacing.gapXs,
                Text(
                  'ملاحظة: ${item.notes}',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textTertiary),
                ),
              ],
            ],
          ),
        ),

        // Storage status badge
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: isStored
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(
              color: isStored
                  ? AppColors.success.withValues(alpha: 0.3)
                  : AppColors.warning.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isStored ? Icons.inventory : Icons.pending,
                size: 14,
                color: isStored ? AppColors.success : AppColors.warning,
              ),
              AppSpacing.gapHorizontalXs,
              Text(
                isStored ? 'مخزن: ${location.name}' : 'غير مخزنة',
                style: AppTextStyles.labelSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isStored ? AppColors.success : AppColors.warning,
                ),
              ),
            ],
          ),
        ),
        AppSpacing.gapHorizontalLg,

        // Price
        Text(
          '${item.calculatedTotal.toEgp.toStringAsFixed(2)} ج.م',
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildPaymentHistoryCard(BuildContext context, OrderDetailState state) {
    final payments = state.payments;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'سجل المدفوعات',
            style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          AppSpacing.gapMd,
          if (payments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: Text(
                  'لم يتم تسجيل أي مدفوعات بعد.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: payments.length,
              separatorBuilder: (_, __) => const Divider(height: AppSpacing.md, color: AppColors.divider),
              itemBuilder: (context, index) {
                final payment = payments[index];
                return _buildPaymentRow(context, payment);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(BuildContext context, Payment payment) {
    final methodLabel = switch (payment.paymentMethod) {
      PaymentMethod.cash => 'كاش',
      PaymentMethod.instapay => 'InstaPay',
      PaymentMethod.ewallet => 'محفظة إلكترونية',
    };

    final date = payment.paidAt;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.selectionBackground,
              child: Icon(Icons.payment, size: 16, color: AppColors.primary),
            ),
            AppSpacing.gapHorizontalSm,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  methodLabel,
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
                AppSpacing.gapXs,
                Text(
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
        Text(
          '+ ${payment.amount.toEgp.toStringAsFixed(2)} ج.م',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.success,
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialSummaryCard(BuildContext context, OrderDetailState state) {
    final order = state.order!;
    final cubit = context.read<OrderDetailCubit>();
    final isFinal = order.status == OrderStatus.completed || order.status == OrderStatus.cancelled;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الملخص المالي',
            style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          AppSpacing.gapMd,
          _buildSummaryRow('المجموع الفرعي', '${order.subtotal.toEgp.toStringAsFixed(2)} ج.م'),
          if (order.customerPickupFee > Money.zero)
            _buildSummaryRow('رسوم استلام من العميل', '+ ${order.customerPickupFee.toEgp.toStringAsFixed(2)} ج.م'),
          if (order.customerDeliveryFee > Money.zero)
            _buildSummaryRow('رسوم توصيل للعميل', '+ ${order.customerDeliveryFee.toEgp.toStringAsFixed(2)} ج.م'),
          if (order.discount > Money.zero)
            _buildSummaryRow('الخصم', '- ${order.discount.toEgp.toStringAsFixed(2)} ج.م', isNegative: true),
          if (order.tax > Money.zero)
            _buildSummaryRow('الضريبة', '+ ${order.tax.toEgp.toStringAsFixed(2)} ج.م'),
          const Divider(height: AppSpacing.lg, color: AppColors.divider),
          _buildSummaryRow(
            'الإجمالي',
            '${order.total.toEgp.toStringAsFixed(2)} ج.م',
            isBold: true,
          ),
          _buildSummaryRow(
            'المدفوع',
            '${state.totalPaid.toEgp.toStringAsFixed(2)} ج.م',
            color: AppColors.success,
          ),
          _buildSummaryRow(
            'المتبقي',
            '${state.remainingAmount.toEgp.toStringAsFixed(2)} ج.م',
            isBold: true,
            color: state.isFullyPaid ? AppColors.success : AppColors.error,
          ),
          AppSpacing.gapLg,

          // Add Payment Button
          if (!isFinal && !state.isFullyPaid)
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'إضافة دفعة',
                icon: Icons.add,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AddPaymentDialog(
                      remainingAmount: state.remainingAmount,
                      onConfirm: ({required amount, required method}) async {
                        await cubit.recordPayment(amount: amount, method: method);
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    bool isNegative = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isBold
                ? AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)
                : AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: isBold
                ? AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color ?? AppColors.textPrimary,
                  )
                : AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isNegative ? AppColors.error : color ?? AppColors.textPrimary,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard(BuildContext context, OrderDetailState state) {
    final cubit = context.read<OrderDetailCubit>();
    final order = state.order!;

    if (order.status == OrderStatus.cancelled) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'حالة الطلب نهائية (ملغي)',
              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            AppSpacing.gapSm,
            Text(
              'تم إلغاء هذا الطلب (${order.cancellationReason ?? ''}). الطلب ملغي للقراءة التاريخية فقط ولا يمكن إجراء أي عمليات عليه.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (order.status == OrderStatus.completed) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                AppSpacing.gapHorizontalSm,
                Text(
                  'طلب مكتمل ومُسلّم',
                  style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            AppSpacing.gapSm,
            Text(
              'تم تسليم هذا الطلب للعميل واستيفاء كامل الحساب بنجاح.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            AppSpacing.gapLg,
            const Divider(height: AppSpacing.md, color: AppColors.divider),
            AppSpacing.gapSm,
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'إعادة إلى قيد التجهيز (تصحيح)',
                icon: Icons.restart_alt,
                variant: AppButtonVariant.secondary,
                isLoading: state.isActionLoading,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => StatusChangeDialog(
                      currentStatus: OrderStatus.completed,
                      targetStatus: OrderStatus.processing,
                      onConfirm: (reason) async {
                        await cubit.changeStatus(newStatus: OrderStatus.processing, reason: reason);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    final canComplete = order.status == OrderStatus.ready && state.remainingAmount <= Money.zero;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إجراءات الطلب',
            style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          AppSpacing.gapMd,

          // Manual Status Transition Section (Excludes 'completed' by design)
          _buildStatusTransitionSection(context, state),
          AppSpacing.gapLg,

          // Complete Order Button
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'تسليم وإكمال الطلب',
              icon: Icons.check_circle_outline,
              variant: AppButtonVariant.primary,
              isLoading: state.isActionLoading,
              onPressed: canComplete
                  ? () => _confirmAndCompleteOrder(context, cubit)
                  : null,
            ),
          ),
          if (!canComplete) ...[
            AppSpacing.gapXs,
            if (order.status != OrderStatus.ready)
              Text(
                '• يجب أن يكون الطلب في حالة "جاهز" للتسليم (جميع العناصر مخزنة).',
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
              ),
            if (state.remainingAmount > Money.zero)
              Text(
                '• يجب سداد المبلغ المتبقي بالكامل أولاً (${state.remainingAmount.toEgp.toStringAsFixed(2)} ج.م).',
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
              ),
          ],

          const Divider(height: AppSpacing.xxl, color: AppColors.divider),

          // Cancel Order Button
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'إلغاء الطلب',
              icon: Icons.cancel_outlined,
              variant: AppButtonVariant.destructive,
              isLoading: state.isActionLoading,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => CancelOrderDialog(
                    onConfirmCancel: (reason) async {
                      await cubit.cancelOrder(cancellationReason: reason);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTransitionSection(BuildContext context, OrderDetailState state) {
    final cubit = context.read<OrderDetailCubit>();
    final order = state.order!;

    if (order.status == OrderStatus.ready) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تصحيح الحالة التشغيلية', style: AppTextStyles.labelLarge),
          AppSpacing.gapXs,
          AppButton(
            label: 'إعادة إلى قيد التجهيز (تصحيح)',
            icon: Icons.restart_alt,
            variant: AppButtonVariant.secondary,
            isLoading: state.isActionLoading,
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => StatusChangeDialog(
                  currentStatus: OrderStatus.ready,
                  targetStatus: OrderStatus.processing,
                  onConfirm: (reason) async {
                    await cubit.changeStatus(newStatus: OrderStatus.processing, reason: reason);
                  },
                ),
              );
            },
          ),
        ],
      );
    }

    if (order.status == OrderStatus.processing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تحديث الحالة يدوياً', style: AppTextStyles.labelLarge),
          AppSpacing.gapXs,
          AppButton(
            label: 'تحديد كـ جاهز (تعديل يدوي)',
            icon: Icons.done_all,
            variant: AppButtonVariant.secondary,
            isLoading: state.isActionLoading,
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => StatusChangeDialog(
                  currentStatus: OrderStatus.processing,
                  targetStatus: OrderStatus.ready,
                  onConfirm: (reason) async {
                    await cubit.changeStatus(newStatus: OrderStatus.ready, reason: reason);
                  },
                ),
              );
            },
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  void _confirmAndCompleteOrder(BuildContext context, OrderDetailCubit cubit) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('تأكيد تسليم وإكمال الطلب'),
        content: const Text(
          'هل تم تسليم جميع عناصر الطلب للعميل فعلياً؟\nسيؤدي هذا الإجراء إلى إكمال الطلب وإلغاء حجز أماكن التخزين للملابس.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('إلغاء'),
          ),
          AppButton(
            label: 'تأكيد التسليم والإكمال',
            variant: AppButtonVariant.primary,
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              cubit.completeOrder(handoverConfirmed: true);
            },
          ),
        ],
      ),
    );
  }
}
