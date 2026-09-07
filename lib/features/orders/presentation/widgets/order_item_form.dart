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
  }

  @override
  void dispose() {
    _priceController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final cubit = widget.cubit;

    final isCarpetPricing = state.draftService?.pricingType == PricingType.perSquareMeter;

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

          // Row 1: Item Type & Service
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
              AppSpacing.gapHorizontalMd,
              Expanded(
                child: Column(
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
                            '${service.name} (${service.price.toEgp.toStringAsFixed(2)} ج.م)',
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
              ),
            ],
          ),
          AppSpacing.gapMd,

          // Row 2: Item Definition (optional) & Quantity & Price Override
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.itemDefinitions.isNotEmpty) ...[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('تفصيل القطعة', style: AppTextStyles.labelLarge),
                      AppSpacing.gapXs,
                      DropdownButtonFormField<ItemDefinition>(
                        key: ValueKey('itemDef_${state.draftItemDefinition?.id}'),
                        initialValue: state.draftItemDefinition,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          hintText: 'اختياري',
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
                AppSpacing.gapHorizontalMd,
              ],

              // Quantity Stepper
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الكمية *', style: AppTextStyles.labelLarge),
                    AppSpacing.gapXs,
                    Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: state.draftQuantity > 1
                              ? () => cubit.updateQuantity(state.draftQuantity - 1)
                              : null,
                          icon: const Icon(Icons.remove, size: 18),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              '${state.draftQuantity}',
                              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: () => cubit.updateQuantity(state.draftQuantity + 1),
                          icon: const Icon(Icons.add, size: 18),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              AppSpacing.gapHorizontalMd,

              // Price override input
              Expanded(
                child: AppTextField(
                  controller: _priceController,
                  label: 'السعر (ج.م) *',
                  hintText: '0.00',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) {
                    final numVal = double.tryParse(val);
                    if (numVal != null && numVal > 0) {
                      cubit.updateUnitPrice(Money.fromEgp(numVal));
                    }
                  },
                ),
              ),
            ],
          ),

          // Carpet Specific Section (if perSquareMeter)
          if (isCarpetPricing) ...[
            AppSpacing.gapMd,
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'أبعاد السجاد',
                    style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.bold),
                  ),
                  AppSpacing.gapSm,
                  Row(
                    children: [
                      // Predefined size dropdown
                      Expanded(
                        child: DropdownButtonFormField<CarpetSize>(
                          key: ValueKey('carpetSize_${state.draftCarpetSize?.id}'),
                          initialValue: state.draftCarpetSize,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'مقاس محدد مسبقاً',
                            hintText: 'اختياري',
                          ),
                          items: state.carpetSizes.map((size) {
                            return DropdownMenuItem<CarpetSize>(
                              value: size,
                              child: Text('${size.length} × ${size.width} م (${size.area} م²)', style: AppTextStyles.bodyMedium),
                            );
                          }).toList(),
                          onChanged: (size) => cubit.selectCarpetSize(size),
                        ),
                      ),
                      AppSpacing.gapHorizontalMd,
                      // Length
                      Expanded(
                        child: AppTextField(
                          controller: _lengthController,
                          label: 'الطول (متر) *',
                          hintText: 'مثال: 3.0',
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
                          label: 'العرض (متر) *',
                          hintText: 'مثال: 2.0',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (val) {
                            final w = double.tryParse(val) ?? 0.0;
                            cubit.updateCarpetDimensions(width: w);
                          },
                        ),
                      ),
                      AppSpacing.gapHorizontalMd,
                      // Calculated Area
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.md,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            'المساحة: ${(state.draftCarpetLength * state.draftCarpetWidth).toStringAsFixed(2)} م²',
                            style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          AppSpacing.gapMd,

          // Notes input
          AppTextField(
            controller: _notesController,
            label: 'ملاحظات على القطعة',
            hintText: 'أي بقع أو تعليمات غسيل خاصة بهذه القطعة',
            onChanged: (val) => cubit.updateDraftNotes(val),
          ),
          AppSpacing.gapLg,

          // Add item button
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: '+ إضافة القطعة',
              variant: AppButtonVariant.primary,
              onPressed: () {
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
