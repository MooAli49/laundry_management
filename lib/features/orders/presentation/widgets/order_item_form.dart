import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../domain/entities/carpet_size.dart';
import '../../../../domain/entities/item_definition.dart';
import '../../../../domain/entities/item_type.dart';
import '../../../../domain/entities/service.dart';
import '../../../../domain/enums/pricing_type.dart';
import '../../../../domain/value_objects/money.dart';
import '../cubit/create_order_cubit.dart';
import '../cubit/create_order_state.dart';

class OrderItemForm extends StatefulWidget {
  final CreateOrderState state;
  final CreateOrderCubit cubit;

  const OrderItemForm({
    super.key,
    required this.state,
    required this.cubit,
  });

  @override
  State<OrderItemForm> createState() => _OrderItemFormState();
}

class _OrderItemFormState extends State<OrderItemForm> {
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _lengthController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.state.draftUnitPrice != null) {
      _priceController.text =
          widget.state.draftUnitPrice!.toEgp.toStringAsFixed(2);
    }
    if (widget.state.draftCarpetLength > 0) {
      _lengthController.text = widget.state.draftCarpetLength.toString();
    }
    if (widget.state.draftCarpetWidth > 0) {
      _widthController.text = widget.state.draftCarpetWidth.toString();
    }
    if (widget.state.draftNotes != null) {
      _notesController.text = widget.state.draftNotes!;
    }
  }

  @override
  void didUpdateWidget(covariant OrderItemForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.draftUnitPrice != oldWidget.state.draftUnitPrice) {
      if (widget.state.draftUnitPrice != null) {
        _priceController.text = widget.state.draftUnitPrice!.toEgp.toStringAsFixed(2);
      } else {
        _priceController.clear();
      }
    }
    if (widget.state.draftCarpetLength != oldWidget.state.draftCarpetLength) {
      _lengthController.text = widget.state.draftCarpetLength > 0
          ? widget.state.draftCarpetLength.toString()
          : '';
    }
    if (widget.state.draftCarpetWidth != oldWidget.state.draftCarpetWidth) {
      _widthController.text = widget.state.draftCarpetWidth > 0
          ? widget.state.draftCarpetWidth.toString()
          : '';
    }
    if (widget.state.draftNotes != oldWidget.state.draftNotes) {
      final newNotes = widget.state.draftNotes ?? '';
      if (_notesController.text != newNotes) {
        _notesController.text = newNotes;
      }
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _pricingTypeLabel(PricingType type) {
    return switch (type) {
      PricingType.perPiece => 'بالقطعة',
      PricingType.perKilogram => 'بالكيلوجرام',
      PricingType.perSquareMeter => 'بالمتر المربع',
      PricingType.fixedPrice => 'سعر ثابت',
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final cubit = widget.cubit;

    final isCarpetPricing = state.draftService?.pricingType == PricingType.perSquareMeter;
    final hasDefinitions = state.itemDefinitions.isNotEmpty;
    final isPriceOverridden = state.draftUnitPrice != null &&
        state.draftService != null &&
        state.draftUnitPrice != state.draftService!.price;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إضافة قطعة للطلب',
            style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          AppSpacing.gapMd,

          // Row 1: Item Type * + Item Definition ("تعريف القطعة")
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('نوع القطعة *', style: AppTextStyles.labelLarge),
                    AppSpacing.gapXs,
                    DropdownButtonFormField<ItemType>(
                      key: ValueKey('itemType_${state.draftItemType?.id}'),
                      initialValue: state.draftItemType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        hintText: 'اختر نوع القطعة',
                      ),
                      items: state.itemTypes.map((type) {
                        return DropdownMenuItem<ItemType>(
                          value: type,
                          child: Text(type.name, style: AppTextStyles.bodyMedium),
                        );
                      }).toList(),
                      onChanged: (type) => cubit.selectItemType(type),
                    ),
                  ],
                ),
              ),
              if (hasDefinitions) ...[
                AppSpacing.gapHorizontalMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('تعريف القطعة', style: AppTextStyles.labelLarge),
                      AppSpacing.gapXs,
                      DropdownButtonFormField<ItemDefinition>(
                        key: ValueKey('itemDef_${state.draftItemDefinition?.id}'),
                        initialValue: state.draftItemDefinition,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          hintText: 'اختر التعريف',
                        ),
                        items: state.itemDefinitions.map((def) {
                          return DropdownMenuItem<ItemDefinition>(
                            value: def,
                            child: Text(def.name, style: AppTextStyles.bodyMedium),
                          );
                        }).toList(),
                        onChanged: (def) => cubit.selectItemDefinition(def),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          AppSpacing.gapMd,

          // Row 2: Service * (full width)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الخدمة *', style: AppTextStyles.labelLarge),
              AppSpacing.gapXs,
              DropdownButtonFormField<Service>(
                key: ValueKey('service_${state.draftService?.id}'),
                initialValue: state.draftService,
                isExpanded: true,
                decoration: InputDecoration(
                  hintText: state.draftItemType == null
                      ? 'اختر نوع القطعة أولاً'
                      : 'اختر الخدمة',
                ),
                items: state.compatibleServices.map((service) {
                  return DropdownMenuItem<Service>(
                    value: service,
                    child: Text(
                      '${service.name} (${service.price.toEgp.toStringAsFixed(2)} ج.م — ${_pricingTypeLabel(service.pricingType)})',
                      style: AppTextStyles.bodyMedium,
                    ),
                  );
                }).toList(),
                onChanged: state.draftItemType == null
                    ? null
                    : (service) => cubit.selectService(service),
              ),
            ],
          ),
          AppSpacing.gapMd,

          // Quantity (for Per Piece and Fixed Price items)
          if (!isCarpetPricing) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الكمية', style: AppTextStyles.labelLarge),
                AppSpacing.gapXs,
                Row(
                  children: [
                    // Quantity Stepper: Minus
                    InkWell(
                      onTap: state.draftQuantity > 1
                          ? () => cubit.updateQuantity(state.draftQuantity - 1)
                          : null,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Icon(
                          Icons.remove,
                          size: 18,
                          color: state.draftQuantity > 1
                              ? AppColors.textPrimary
                              : AppColors.textDisabled,
                        ),
                      ),
                    ),
                    Container(
                      width: 48,
                      alignment: Alignment.center,
                      child: Text(
                        '${state.draftQuantity}',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    // Quantity Stepper: Plus
                    InkWell(
                      onTap: () => cubit.updateQuantity(state.draftQuantity + 1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (state.draftService != null) ...[
                      AppSpacing.gapHorizontalMd,
                      Text(
                        '${(state.draftUnitPrice ?? state.draftService!.price).toEgp.toStringAsFixed(2)} ج.م / قطعة',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            AppSpacing.gapMd,
          ],

          // Carpet Specific Section (if perSquareMeter)
          if (isCarpetPricing) ...[
            // Predefined carpet size selector (standalone full-width field)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مقاس السجادة', style: AppTextStyles.labelLarge),
                AppSpacing.gapXs,
                DropdownButtonFormField<CarpetSize?>(
                  key: ValueKey('carpetSize_${state.draftCarpetSize?.id}'),
                  initialValue: state.draftCarpetSize,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    hintText: 'اختر مقاساً جاهزاً أو أدخل أبعاداً مخصصة',
                    helperText: 'اختر مقاساً جاهزاً أو أدخل أبعاداً مخصصة',
                  ),
                  items: [
                    const DropdownMenuItem<CarpetSize?>(
                      value: null,
                      child: Text('مقاس مخصص'),
                    ),
                    ...state.carpetSizes.map((size) {
                      return DropdownMenuItem<CarpetSize?>(
                        value: size,
                        child: Text(
                          '${size.length} × ${size.width} م (${size.area} م²)',
                          style: AppTextStyles.bodyMedium,
                        ),
                      );
                    }),
                  ],
                  onChanged: (size) => cubit.selectCarpetSize(size),
                ),
              ],
            ),
            AppSpacing.gapMd,

            // 3-column row: Length, Width, Readonly Area
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Length
                Expanded(
                  child: AppTextField(
                    controller: _lengthController,
                    label: 'الطول (م) *',
                    hintText: '0',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (val) {
                      final l = double.tryParse(val) ?? 0.0;
                      cubit.updateCarpetDimensions(length: l);
                    },
                  ),
                ),
                AppSpacing.gapHorizontalMd,

                // Width
                Expanded(
                  child: AppTextField(
                    controller: _widthController,
                    label: 'العرض (م) *',
                    hintText: '0',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (val) {
                      final w = double.tryParse(val) ?? 0.0;
                      cubit.updateCarpetDimensions(width: w);
                    },
                  ),
                ),
                AppSpacing.gapHorizontalMd,

                // Readonly Calculated Area
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('المساحة', style: AppTextStyles.labelLarge),
                      AppSpacing.gapXs,
                      Container(
                        height: 48,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundSecondary,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          '${(state.draftCarpetLength * state.draftCarpetWidth).toStringAsFixed(2)} م²',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'تُحسب تلقائياً',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            AppSpacing.gapMd,
          ],

          // Price Field + Helper Text + Reset Button
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('سعر العنصر (ج.م) *', style: AppTextStyles.labelLarge),
                  if (isPriceOverridden)
                    InkWell(
                      onTap: () {
                        cubit.updateUnitPrice(state.draftService!.price);
                        _priceController.text =
                            state.draftService!.price.toEgp.toStringAsFixed(2);
                      },
                      child: Text(
                        'إعادة الافتراضي',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              AppSpacing.gapXs,
              AppTextField(
                controller: _priceController,
                hintText: '0.00',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (val) {
                  final numVal = double.tryParse(val);
                  if (numVal != null && numVal > 0) {
                    cubit.updateUnitPrice(Money.fromEgp(numVal));
                  }
                },
              ),
              if (state.draftService != null) ...[
                AppSpacing.gapXs,
                Text(
                  isPriceOverridden
                      ? 'السعر الافتراضي للخدمة ${state.draftService!.price.toEgp.toStringAsFixed(2)} ج.م — تم تعديله لهذا العنصر'
                      : 'السعر الافتراضي للخدمة ${state.draftService!.price.toEgp.toStringAsFixed(2)} ج.م — يمكنك تعديله لهذا العنصر فقط',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isPriceOverridden ? AppColors.warning : AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
          AppSpacing.gapMd,

          // Item Notes
          AppTextField(
            controller: _notesController,
            label: 'ملاحظات القطعة',
            hintText: 'مثال: بقعة على الياقة',
            onChanged: (val) => cubit.updateDraftNotes(val),
          ),
          AppSpacing.gapLg,

          // Add Item Button
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'إضافة القطعة',
              icon: Icons.add,
              variant: AppButtonVariant.secondary,
              onPressed: state.draftItemType == null || state.draftService == null
                  ? null
                  : () {
                      cubit.addItemDraftToOrder();
                      _notesController.clear();
                    },
            ),
          ),
        ],
      ),
    );
  }
}
