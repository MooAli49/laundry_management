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
import '../../../../domain/entities/carpet_size.dart';
import '../../../../domain/entities/item_definition.dart';
import '../../../../domain/entities/item_type.dart';
import '../../../../domain/entities/service.dart';
import '../../../../domain/enums/pricing_type.dart';
import '../../../../domain/value_objects/money.dart';
import '../../../../domain/value_objects/order_date.dart';
import '../cubit/edit_processing_order_cubit.dart';
import '../cubit/edit_processing_order_state.dart';
import '../models/editable_order_item.dart';
import '../widgets/customer_selector.dart';

class EditOrderScreen extends StatelessWidget {
  final String orderId;

  const EditOrderScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<EditProcessingOrderCubit>(
      create: (_) => getIt<EditProcessingOrderCubit>()..loadOrder(orderId),
      child: EditOrderView(orderId: orderId),
    );
  }
}

class EditOrderView extends StatefulWidget {
  final String orderId;

  const EditOrderView({super.key, required this.orderId});

  @override
  State<EditOrderView> createState() => _EditOrderViewState();
}

class _EditOrderViewState extends State<EditOrderView> {
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _pickupFeeController = TextEditingController();
  final TextEditingController _deliveryFeeController = TextEditingController();

  // Item form controllers
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );
  final TextEditingController _lengthController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _itemNotesController = TextEditingController();

  bool _initializedControllers = false;

  @override
  void dispose() {
    _notesController.dispose();
    _discountController.dispose();
    _pickupFeeController.dispose();
    _deliveryFeeController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _itemNotesController.dispose();
    super.dispose();
  }

  void _syncControllersFromState(EditProcessingOrderState state) {
    if (!_initializedControllers && state.initialOrder != null) {
      _notesController.text = state.notes ?? '';
      _discountController.text = state.discount > Money.zero
          ? state.discount.toEgp.toStringAsFixed(2)
          : '';
      _pickupFeeController.text = state.customerPickupFee > Money.zero
          ? state.customerPickupFee.toEgp.toStringAsFixed(2)
          : '';
      _deliveryFeeController.text = state.customerDeliveryFee > Money.zero
          ? state.customerDeliveryFee.toEgp.toStringAsFixed(2)
          : '';
      _initializedControllers = true;
    }
  }

  void _syncItemFormControllers(EditProcessingOrderState state) {
    if (state.draftUnitPrice != null) {
      final textVal = state.draftUnitPrice!.toEgp.toStringAsFixed(2);
      if (_priceController.text != textVal) {
        _priceController.text = textVal;
      }
    } else if (state.draftService != null) {
      final textVal = state.draftService!.price.toEgp.toStringAsFixed(2);
      if (_priceController.text != textVal) {
        _priceController.text = textVal;
      }
    } else {
      _priceController.clear();
    }

    final quantityText = state.draftQuantity.toString();
    if (_quantityController.text != quantityText) {
      _quantityController.text = quantityText;
    }
    _lengthController.text = state.draftCarpetLength > 0
        ? state.draftCarpetLength.toString()
        : '';
    _widthController.text = state.draftCarpetWidth > 0
        ? state.draftCarpetWidth.toString()
        : '';
    _itemNotesController.text = state.draftNotes ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EditProcessingOrderCubit, EditProcessingOrderState>(
      listener: (context, state) {
        _syncControllersFromState(state);

        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        if (state.savedOrder != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تعديل الطلب بنجاح'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          if (context.canPop()) {
            context.pop(true);
          } else {
            context.go(AppRoutes.orderDetailPath(widget.orderId));
          }
        }
      },
      builder: (context, state) {
        if (state.isLoading) {
          return const Scaffold(body: Center(child: LoadingIndicator()));
        }

        if (state.initialOrder == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('تعديل الطلب')),
            body: Center(
              child: Text(
                state.errorMessage ?? 'تعذر تحميل بيانات الطلب',
                style: AppTextStyles.bodyLarge,
              ),
            ),
          );
        }

        final cubit = context.read<EditProcessingOrderCubit>();
        final order = state.initialOrder!;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('تعديل الطلب '),
                Text('#${order.orderNumber}', textDirection: TextDirection.ltr),
              ],
            ),
            leading: BackButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.orderDetailPath(widget.orderId));
                }
              },
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Right Column (Main Editor)
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status & Rules Notice Banner
                      _buildHeaderNoticeCard(order, state),
                      AppSpacing.gapLg,

                      // Customer Selection Card
                      _buildCustomerSection(context, state, cubit),
                      AppSpacing.gapLg,

                      // Item Editor Card (Add / Edit Item)
                      _buildItemFormCard(context, state, cubit),
                      AppSpacing.gapLg,

                      // Items Table Card
                      _buildItemsListCard(context, state, cubit),
                      AppSpacing.gapLg,

                      // Delivery & Options Card
                      _buildOrderOptionsCard(context, state, cubit),
                    ],
                  ),
                ),
                AppSpacing.gapHorizontalLg,

                // Left Column (Financial Summary & Save Button)
                Expanded(
                  flex: 3,
                  child: _buildFinancialSummaryColumn(context, state, cubit),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderNoticeCard(dynamic order, EditProcessingOrderState state) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.edit_note,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  AppSpacing.gapHorizontalSm,
                  Text(
                    'تعديل تفاصيل الطلب قيد التجهيز',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  'قيد التجهيز',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.gapSm,
          Text(
            'يمكنك تعديل بنود الطلب، نوع الخدمة، الأسعار، أو إضافة بنود جديدة. '
            'لا يمكن تغيير العميل إذا تم تسجيل مدفوعات مسبقة. '
            'كما لا يمكن حذف القطع المرتبطة بسجلات تخزين في المستودع.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSection(
    BuildContext context,
    EditProcessingOrderState state,
    EditProcessingOrderCubit cubit,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'العميل',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!state.canChangeCustomer)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        size: 14,
                        color: AppColors.error,
                      ),
                      AppSpacing.gapHorizontalXs,
                      Text(
                        'العميل مقفل لوجود دفعات (${state.totalPaid.toEgp} ج.م)',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          AppSpacing.gapMd,
          CustomerSelector(
            selectedCustomer: state.selectedCustomer,
            searchResults: state.customerSearchResults,
            isSearching: state.isSearchingCustomer,
            onSearch: cubit.searchCustomers,
            onSelectCustomer: state.canChangeCustomer
                ? cubit.selectCustomer
                : (_) {},
            onAddNewCustomer: state.canChangeCustomer
                ? cubit.addNewCustomer
                : ({address, notes, required name, required phone}) async {},
          ),
        ],
      ),
    );
  }

  Widget _buildItemFormCard(
    BuildContext context,
    EditProcessingOrderState state,
    EditProcessingOrderCubit cubit,
  ) {
    final isEditing = state.editingItemIndex != null;
    final isExistingItem =
        isEditing && state.items[state.editingItemIndex!].isExisting;

    _syncItemFormControllers(state);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEditing ? 'تعديل بند من الطلب' : 'إضافة بند جديد',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isEditing ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              if (isEditing)
                TextButton.icon(
                  onPressed: cubit.cancelDraft,
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('إلغاء التعديل'),
                ),
            ],
          ),
          AppSpacing.gapMd,

          // Deduplicated items and validated selected values to prevent dropdown assertion crashes
          Builder(
            builder: (context) {
              final uniqueItemTypes = {
                for (final t in state.itemTypes) t.id: t,
              }.values.toList();
              if (state.draftItemType != null &&
                  !uniqueItemTypes.any(
                    (t) => t.id == state.draftItemType!.id,
                  )) {
                uniqueItemTypes.insert(0, state.draftItemType!);
              }
              final selectedItemType = state.draftItemType != null
                  ? uniqueItemTypes
                        .where((t) => t.id == state.draftItemType!.id)
                        .firstOrNull
                  : null;

              final uniqueItemDefs = {
                for (final d in state.itemDefinitions) d.id: d,
              }.values.toList();
              if (state.draftItemDefinition != null &&
                  !uniqueItemDefs.any(
                    (d) => d.id == state.draftItemDefinition!.id,
                  )) {
                uniqueItemDefs.insert(0, state.draftItemDefinition!);
              }
              final selectedItemDef = state.draftItemDefinition != null
                  ? uniqueItemDefs
                        .where((d) => d.id == state.draftItemDefinition!.id)
                        .firstOrNull
                  : null;

              final uniqueServices = {
                for (final s in state.compatibleServices) s.id: s,
              }.values.toList();
              if (state.draftService != null &&
                  !uniqueServices.any((s) => s.id == state.draftService!.id)) {
                uniqueServices.insert(0, state.draftService!);
              }
              final selectedService = state.draftService != null
                  ? uniqueServices
                        .where((s) => s.id == state.draftService!.id)
                        .firstOrNull
                  : null;

              final uniqueCarpetSizes = {
                for (final c in state.carpetSizes) c.id: c,
              }.values.toList();
              if (state.draftCarpetSize != null &&
                  !uniqueCarpetSizes.any(
                    (c) => c.id == state.draftCarpetSize!.id,
                  )) {
                uniqueCarpetSizes.insert(0, state.draftCarpetSize!);
              }
              final selectedCarpetSize = state.draftCarpetSize != null
                  ? uniqueCarpetSizes
                        .where((c) => c.id == state.draftCarpetSize!.id)
                        .firstOrNull
                  : null;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Item Type & Item Definition
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'نوع العنصر *',
                              style: AppTextStyles.labelMedium,
                            ),
                            AppSpacing.gapXs,
                            DropdownButtonFormField<ItemType>(
                              key: ValueKey(
                                'item_type_${selectedItemType?.id}',
                              ),
                              initialValue: selectedItemType,
                              isExpanded: true,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: isExistingItem
                                    ? AppColors.surfaceDisabled
                                    : null,
                                hintText: 'اختر نوع العنصر',
                                helperText: isExistingItem
                                    ? 'نوع العنصر غير قابل للتغيير للقطع الحالية'
                                    : null,
                                border: const OutlineInputBorder(),
                              ),
                              items: uniqueItemTypes.map((type) {
                                return DropdownMenuItem(
                                  value: type,
                                  child: Text(type.name),
                                );
                              }).toList(),
                              onChanged: isExistingItem
                                  ? null
                                  : cubit.selectItemType,
                            ),
                          ],
                        ),
                      ),
                      AppSpacing.gapHorizontalMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تعريف العنصر (اختياري)',
                              style: AppTextStyles.labelMedium,
                            ),
                            AppSpacing.gapXs,
                            DropdownButtonFormField<ItemDefinition?>(
                              key: ValueKey('item_def_${selectedItemDef?.id}'),
                              initialValue: selectedItemDef,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                hintText: 'اختر تعريف العنصر',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem<ItemDefinition?>(
                                  value: null,
                                  child: Text('بدون تعريف محدد'),
                                ),
                                ...uniqueItemDefs.map((def) {
                                  return DropdownMenuItem<ItemDefinition?>(
                                    value: def,
                                    child: Text(def.name),
                                  );
                                }),
                              ],
                              onChanged: state.draftItemType == null
                                  ? null
                                  : cubit.selectItemDefinition,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapMd,

                  // Row 2: Service & Unit Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('الخدمة *', style: AppTextStyles.labelMedium),
                            AppSpacing.gapXs,
                            DropdownButtonFormField<Service>(
                              key: ValueKey('service_${selectedService?.id}'),
                              initialValue: selectedService,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                hintText: 'اختر الخدمة',
                                border: OutlineInputBorder(),
                              ),
                              items: uniqueServices.map((service) {
                                return DropdownMenuItem(
                                  value: service,
                                  child: Text(
                                    '${service.name} (${service.price.toEgp} ج.م)',
                                  ),
                                );
                              }).toList(),
                              onChanged: state.draftItemType == null
                                  ? null
                                  : cubit.selectService,
                            ),
                          ],
                        ),
                      ),
                      AppSpacing.gapHorizontalMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'سعر الوحدة (ج.م) *',
                              style: AppTextStyles.labelMedium,
                            ),
                            AppSpacing.gapXs,
                            AppTextField(
                              controller: _priceController,
                              hintText: 'سعر الوحدة',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (val) {
                                final parsed = double.tryParse(val);
                                if (parsed != null && parsed > 0) {
                                  cubit.updateDraftUnitPrice(
                                    Money.fromEgp(parsed),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapMd,

                  // Row 3: Quantity (editable when adding new item; informational read-only when editing existing item)
                  if (!isEditing) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الكمية (عدد القطع) *',
                                style: AppTextStyles.labelMedium,
                              ),
                              AppSpacing.gapXs,
                              AppTextField(
                                key: const ValueKey(
                                  'draft_item_quantity_field',
                                ),
                                controller: _quantityController,
                                hintText: '1',
                                keyboardType: TextInputType.number,
                                onChanged: (val) {
                                  final q = int.tryParse(val) ?? 1;
                                  cubit.updateDraftQuantity(q);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapMd,
                  ] else ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSm,
                            ),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              AppSpacing.gapHorizontalXs,
                              Text(
                                'العدد: 1 قطعة',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapMd,
                  ],

                  // Row 4: Carpet details if perSquareMeter (independent from quantity)
                  if (state.draftService?.pricingType ==
                      PricingType.perSquareMeter) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'مقاس السجاد المسبق',
                                style: AppTextStyles.labelMedium,
                              ),
                              AppSpacing.gapXs,
                              DropdownButtonFormField<CarpetSize?>(
                                key: ValueKey(
                                  'carpet_size_${selectedCarpetSize?.id}',
                                ),
                                initialValue: selectedCarpetSize,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  hintText: 'اختر مقاس السجاد',
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  const DropdownMenuItem<CarpetSize?>(
                                    value: null,
                                    child: Text('مقاس يدوي مخصص'),
                                  ),
                                  ...uniqueCarpetSizes.map((size) {
                                    return DropdownMenuItem<CarpetSize?>(
                                      value: size,
                                      child: Text(
                                        '${size.length} × ${size.width} م (${size.area} م²)',
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: cubit.selectDraftCarpetSize,
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.gapHorizontalMd,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الطول (متر) *',
                                style: AppTextStyles.labelMedium,
                              ),
                              AppSpacing.gapXs,
                              AppTextField(
                                controller: _lengthController,
                                hintText: 'مثال: 3.0',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                onChanged: (val) {
                                  final l = double.tryParse(val) ?? 0.0;
                                  final w =
                                      double.tryParse(_widthController.text) ??
                                      0.0;
                                  cubit.updateDraftCarpetDimensions(l, w);
                                },
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.gapHorizontalMd,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'العرض (متر) *',
                                style: AppTextStyles.labelMedium,
                              ),
                              AppSpacing.gapXs,
                              AppTextField(
                                controller: _widthController,
                                hintText: 'مثال: 2.0',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                onChanged: (val) {
                                  final l =
                                      double.tryParse(_lengthController.text) ??
                                      0.0;
                                  final w = double.tryParse(val) ?? 0.0;
                                  cubit.updateDraftCarpetDimensions(l, w);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapMd,
                  ],
                ],
              );
            },
          ),

          // Notes
          AppTextField(
            controller: _itemNotesController,
            hintText: 'ملاحظات البند (اختياري)',
            onChanged: cubit.updateDraftNotes,
          ),
          AppSpacing.gapMd,

          // Action button
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: isEditing ? 'حفظ تعديل البند' : 'إضافة البند للطلب',
              icon: isEditing ? Icons.check : Icons.add,
              onPressed: cubit.saveDraftItem,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsListCard(
    BuildContext context,
    EditProcessingOrderState state,
    EditProcessingOrderCubit cubit,
  ) {
    final items = state.items;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'عناصر الطلب (${items.length})',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (items.isEmpty)
                Text(
                  'يجب أن يحتوي الطلب على عنصر واحد على الأقل',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
            ],
          ),
          AppSpacing.gapMd,

          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child: Text(
                  'لا توجد عناصر متبقية في الطلب',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(
                height: AppSpacing.lg,
                color: AppColors.divider,
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildItemRow(context, item, index, cubit);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildItemRow(
    BuildContext context,
    EditableOrderItem item,
    int index,
    EditProcessingOrderCubit cubit,
  ) {
    final isCarpet = item.pricingType == PricingType.perSquareMeter;

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
            '${index + 1}',
            style: AppTextStyles.labelSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        AppSpacing.gapHorizontalMd,

        // Item info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    item.itemDefinitionName != null
                        ? '${item.itemTypeName} - ${item.itemDefinitionName}'
                        : item.itemTypeName,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AppSpacing.gapHorizontalSm,
                  // Storage badge
                  if (item.hasStorageRecords)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: item.storageLocationName != null
                            ? AppColors.successLight
                            : AppColors.warningLight,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSm,
                        ),
                      ),
                      child: Text(
                        item.storageLocationName != null
                            ? 'مخزن: ${item.storageLocationName}'
                            : 'مرتبط بسجل تخزين',
                        style: AppTextStyles.labelSmall.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: item.storageLocationName != null
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.infoLight,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSm,
                        ),
                      ),
                      child: Text(
                        'غير مخزن',
                        style: AppTextStyles.labelSmall.copyWith(
                          fontSize: 10,
                          color: AppColors.info,
                        ),
                      ),
                    ),
                ],
              ),
              AppSpacing.gapXs,
              Text(
                'الخدمة: ${item.serviceName} • السعر: ${item.unitPrice.toEgp} ج.م'
                '${isCarpet ? " (${item.length}×${item.width} = ${item.carpetArea.toStringAsFixed(2)} م²)" : ""}'
                '${item.physicalQuantity > 1 ? " × ${item.physicalQuantity}" : ""}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (item.notes != null && item.notes!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'ملاحظة: ${item.notes}',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Calculated Total
        Text(
          '${item.calculatedTotal.toEgp.toStringAsFixed(2)} ج.م',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        AppSpacing.gapHorizontalMd,

        // Edit button
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 20),
          color: AppColors.primary,
          tooltip: 'تعديل البند',
          onPressed: () => cubit.startEditItem(index),
        ),

        // Delete button
        if (item.canDelete)
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: AppColors.error,
            tooltip: 'حذف البند',
            onPressed: () => cubit.deleteItem(index),
          )
        else
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: AppColors.textDisabled,
            tooltip: 'لا يمكن حذف عنصر له سجل تخزين',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'لا يمكن حذف هذا البند لأنه مرتبط بسجل تخزين في المستودع',
                  ),
                  backgroundColor: AppColors.warning,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildOrderOptionsCard(
    BuildContext context,
    EditProcessingOrderState state,
    EditProcessingOrderCubit cubit,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'خيارات ومواعيد الاستلام والتوصيل',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          AppSpacing.gapMd,

          // Expected Pickup Date
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تاريخ الاستلام المتوقع *',
                      style: AppTextStyles.labelMedium,
                    ),
                    AppSpacing.gapXs,
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: state.expectedPickupDate.toDateTime(),
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) {
                          cubit.updateExpectedPickupDate(
                            OrderDate.fromDate(picked),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: !state.isPickupDateValid
                                ? AppColors.error
                                : AppColors.border,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormatter.formatArabicDate(
                                state.expectedPickupDate.toDateTime(),
                              ),
                              style: AppTextStyles.bodyMedium,
                            ),
                            const Icon(Icons.calendar_today, size: 18),
                          ],
                        ),
                      ),
                    ),
                    if (!state.isPickupDateValid)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'تاريخ الاستلام المتوقع لا يمكن أن يكون في الماضي',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.gapMd,

          // Customer Pickup Toggle & Fee
          SwitchListTile(
            title: const Text('استلام من العميل (Pickup)'),
            value: state.customerPickupRequested,
            onChanged: cubit.toggleCustomerPickup,
          ),
          if (state.customerPickupRequested)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AppTextField(
                controller: _pickupFeeController,
                hintText: 'رسوم الاستلام (ج.م)',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (val) {
                  final parsed = double.tryParse(val) ?? 0.0;
                  cubit.updateCustomerPickupFee(Money.fromEgp(parsed));
                },
              ),
            ),

          // Customer Delivery Toggle & Fee
          SwitchListTile(
            title: const Text('توصيل للعميل (Delivery)'),
            value: state.customerDeliveryRequested,
            onChanged: cubit.toggleCustomerDelivery,
          ),
          if (state.customerDeliveryRequested)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AppTextField(
                controller: _deliveryFeeController,
                hintText: 'رسوم التوصيل (ج.م)',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (val) {
                  final parsed = double.tryParse(val) ?? 0.0;
                  cubit.updateCustomerDeliveryFee(Money.fromEgp(parsed));
                },
              ),
            ),

          // Order Notes
          AppSpacing.gapSm,
          Text('ملاحظات الطلب العامة', style: AppTextStyles.labelMedium),
          AppSpacing.gapXs,
          AppTextField(
            controller: _notesController,
            hintText: 'ملاحظات عامة على الطلب',
            maxLines: 2,
            onChanged: cubit.updateNotes,
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummaryColumn(
    BuildContext context,
    EditProcessingOrderState state,
    EditProcessingOrderCubit cubit,
  ) {
    return Column(
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الملخص المالي',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppSpacing.gapMd,

              _buildSummaryRow(
                'المجموع الفرعي',
                '${state.subtotal.toEgp.toStringAsFixed(2)} ج.م',
              ),
              if (state.customerPickupRequested)
                _buildSummaryRow(
                  'رسوم الاستلام',
                  '+ ${state.effectivePickupFee.toEgp.toStringAsFixed(2)} ج.م',
                ),
              if (state.customerDeliveryRequested)
                _buildSummaryRow(
                  'رسوم التوصيل',
                  '+ ${state.effectiveDeliveryFee.toEgp.toStringAsFixed(2)} ج.م',
                ),

              // Discount Field
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الخصم (ج.م)', style: AppTextStyles.bodySmall),
                    SizedBox(
                      width: 100,
                      child: AppTextField(
                        controller: _discountController,
                        hintText: '0.00',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (val) {
                          final parsed = double.tryParse(val) ?? 0.0;
                          cubit.updateDiscount(Money.fromEgp(parsed));
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: AppSpacing.lg, color: AppColors.divider),

              _buildSummaryRow(
                'الإجمالي الجديد',
                '${state.total.toEgp.toStringAsFixed(2)} ج.م',
                isBold: true,
              ),

              _buildSummaryRow(
                'المبلغ المدفوع سابقًا',
                '${state.totalPaid.toEgp.toStringAsFixed(2)} ج.م',
                color: AppColors.success,
              ),

              _buildSummaryRow(
                'المتبقي على العميل',
                '${state.remainingBalance.toEgp.toStringAsFixed(2)} ج.م',
                isBold: true,
                color: state.remainingBalance <= Money.zero
                    ? AppColors.success
                    : AppColors.warning,
              ),

              if (!state.isTotalValid) ...[
                AppSpacing.gapMd,
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 18,
                      ),
                      AppSpacing.gapHorizontalSm,
                      Expanded(
                        child: Text(
                          'تنبيه: إجمالي الطلب (${state.total.toEgp} ج.م) لا يمكن أن يكون أقل من المبلغ المدفوع (${state.totalPaid.toEgp} ج.م)',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              AppSpacing.gapLg,

              // Save button
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'حفظ التعديلات',
                  icon: Icons.save,
                  isLoading: state.isSubmitting,
                  onPressed: state.canSubmit ? cubit.submitEdit : null,
                ),
              ),
              AppSpacing.gapSm,

              // Cancel button
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'إلغاء والعودة',
                  variant: AppButtonVariant.secondary,
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(AppRoutes.orderDetailPath(widget.orderId));
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
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
                : AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
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
                    color: color ?? AppColors.textPrimary,
                  ),
          ),
        ],
      ),
    );
  }
}
