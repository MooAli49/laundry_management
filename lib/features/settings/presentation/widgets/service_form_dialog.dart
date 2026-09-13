import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../domain/entities/item_type.dart';
import '../../../../domain/entities/service.dart';
import '../../../../domain/enums/pricing_type.dart';
import '../../../../domain/value_objects/money.dart';
import '../cubit/services_management_cubit.dart';

class ServiceFormDialog extends StatefulWidget {
  final Service? service;
  final List<ItemType> availableItemTypes;
  final List<String> initialSupportedTypeIds;

  const ServiceFormDialog({
    super.key,
    this.service,
    required this.availableItemTypes,
    this.initialSupportedTypeIds = const [],
  });

  static Future<bool?> show(
    BuildContext context, {
    Service? service,
    required List<ItemType> availableItemTypes,
    List<String> initialSupportedTypeIds = const [],
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: context.read<ServicesManagementCubit>(),
        child: ServiceFormDialog(
          service: service,
          availableItemTypes: availableItemTypes,
          initialSupportedTypeIds: initialSupportedTypeIds,
        ),
      ),
    );
  }

  @override
  State<ServiceFormDialog> createState() => _ServiceFormDialogState();
}

class _ServiceFormDialogState extends State<ServiceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;

  late PricingType _selectedPricingType;
  late Set<String> _selectedTypeIds;
  Money? _originalPrice;
  bool _priceChanged = false;
  String? _inlineError;

  // V1 allowed pricing types ONLY
  static const List<PricingType> _v1PricingTypes = [
    PricingType.perPiece,
    PricingType.perSquareMeter,
    PricingType.fixedPrice,
  ];

  @override
  void initState() {
    super.initState();
    final svc = widget.service;
    _nameController = TextEditingController(text: svc?.name ?? '');
    _descriptionController = TextEditingController(text: svc?.description ?? '');
    _selectedPricingType = (svc != null && _v1PricingTypes.contains(svc.pricingType))
        ? svc.pricingType
        : PricingType.perPiece;

    final initialPriceText = svc != null
        ? (svc.price.toEgp == svc.price.toEgp.roundToDouble()
            ? svc.price.toEgp.toInt().toString()
            : svc.price.toEgp.toStringAsFixed(2))
        : '';
    _priceController = TextEditingController(text: initialPriceText);
    _originalPrice = svc?.price;

    _selectedTypeIds = Set.from(widget.initialSupportedTypeIds);

    _priceController.addListener(_onPriceChanged);
  }

  @override
  void dispose() {
    _priceController.removeListener(_onPriceChanged);
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _onPriceChanged() {
    if (widget.service == null) return;
    final parsed = Money.tryParseEgp(_priceController.text);
    final changed = parsed != null && _originalPrice != null && parsed != _originalPrice;
    if (changed != _priceChanged) {
      setState(() {
        _priceChanged = changed;
      });
    }
  }

  String _getPriceLabel() {
    switch (_selectedPricingType) {
      case PricingType.perPiece:
        return AppStrings.priceLabelPerPiece;
      case PricingType.perSquareMeter:
        return AppStrings.priceLabelPerSquareMeter;
      case PricingType.fixedPrice:
        return AppStrings.priceLabelFixedPrice;
      default:
        return AppStrings.servicePriceLabel;
    }
  }

  String _getPricingTypeLabel(PricingType type) {
    switch (type) {
      case PricingType.perPiece:
        return AppStrings.pricingPerPiece;
      case PricingType.perSquareMeter:
        return AppStrings.pricingPerSquareMeter;
      case PricingType.fixedPrice:
        return AppStrings.pricingFixedPrice;
      case PricingType.perKilogram:
        return '';
    }
  }

  Future<void> _handleSubmit() async {
    setState(() => _inlineError = null);
    if (!_formKey.currentState!.validate()) return;

    final money = Money.tryParseEgp(_priceController.text);
    if (money == null || money <= Money.zero) {
      setState(() => _inlineError = AppStrings.servicePriceMustBePositive);
      return;
    }

    final cubit = context.read<ServicesManagementCubit>();
    bool success;

    if (widget.service == null) {
      success = await cubit.createService(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        pricingType: _selectedPricingType,
        price: money,
        supportedItemTypeIds: _selectedTypeIds.toList(),
      );
    } else {
      final updated = widget.service!.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        pricingType: _selectedPricingType,
        price: money,
      );
      success = await cubit.updateService(
        service: updated,
        supportedItemTypeIds: _selectedTypeIds.toList(),
      );
    }

    if (success && mounted) {
      Navigator.of(context).pop(true);
    } else if (mounted) {
      setState(() {
        _inlineError = cubit.state.errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.service != null;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? AppStrings.editService : AppStrings.addService,
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.lg, color: AppColors.divider),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_inlineError != null) ...[
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.errorLight,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: AppColors.error,
                                  size: 20,
                                ),
                                AppSpacing.gapHorizontalSm,
                                Expanded(
                                  child: Text(
                                    _inlineError!,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AppSpacing.gapMd,
                        ],
                        AppTextField(
                          controller: _nameController,
                          label: AppStrings.serviceNameLabel,
                          hintText: AppStrings.serviceNameHint,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return AppStrings.serviceNameRequired;
                            }
                            return null;
                          },
                        ),
                        AppSpacing.gapMd,
                        AppTextField(
                          controller: _descriptionController,
                          label: AppStrings.serviceDescriptionLabel,
                          hintText: AppStrings.serviceDescriptionHint,
                        ),
                        AppSpacing.gapLg,
                        // Pricing Type selector (V1 only)
                        Text(
                          AppStrings.pricingTypeLabel,
                          style: AppTextStyles.labelLarge.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        AppSpacing.gapSm,
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: _v1PricingTypes.map((type) {
                            final isSelected = _selectedPricingType == type;
                            return ChoiceChip(
                              label: Text(_getPricingTypeLabel(type)),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _selectedPricingType = type);
                                }
                              },
                              selectedColor: AppColors.primaryLighter,
                              backgroundColor: AppColors.surface,
                              labelStyle: AppTextStyles.labelMedium.copyWith(
                                color: isSelected
                                    ? AppColors.primaryDark
                                    : AppColors.textPrimary,
                                fontWeight:
                                    isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppSpacing.radiusMd),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        AppSpacing.gapLg,
                        // Price Field
                        AppTextField(
                          controller: _priceController,
                          label: '${_getPriceLabel()} (ج.م) *',
                          hintText: '0.00',
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return AppStrings.servicePriceRequired;
                            }
                            final parsed = Money.tryParseEgp(value);
                            if (parsed == null || parsed <= Money.zero) {
                              return AppStrings.servicePriceMustBePositive;
                            }
                            return null;
                          },
                        ),
                        // Service Price Change Notice (when editing price)
                        if (isEditing && _priceChanged) ...[
                          AppSpacing.gapSm,
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.warningLight,
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusMd),
                              border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  color: AppColors.warning,
                                  size: 20,
                                ),
                                AppSpacing.gapHorizontalSm,
                                Expanded(
                                  child: Text(
                                    AppStrings.servicePriceChangeNotice,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.warningDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        AppSpacing.gapLg,
                        // Supported Item Types
                        Text(
                          AppStrings.supportedItemTypesLabel,
                          style: AppTextStyles.labelLarge.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        AppSpacing.gapSm,
                        if (widget.availableItemTypes.isEmpty)
                          Text(
                            AppStrings.noItemTypes,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          )
                        else
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: widget.availableItemTypes.map((type) {
                              final isSelected = _selectedTypeIds.contains(type.id);
                              return FilterChip(
                                label: Text(type.name),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedTypeIds.add(type.id);
                                    } else {
                                      _selectedTypeIds.remove(type.id);
                                    }
                                  });
                                },
                                selectedColor: AppColors.primaryLighter,
                                backgroundColor: AppColors.surface,
                                labelStyle: AppTextStyles.labelMedium.copyWith(
                                  color: isSelected
                                      ? AppColors.primaryDark
                                      : AppColors.textPrimary,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppSpacing.radiusMd),
                                  side: BorderSide(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.border,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        AppSpacing.gapMd,
                      ],
                    ),
                  ),
                ),
                const Divider(height: AppSpacing.lg, color: AppColors.divider),
                AppSpacing.gapSm,
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton(
                      label: AppStrings.cancel,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    AppSpacing.gapHorizontalMd,
                    AppButton(
                      label: AppStrings.save,
                      onPressed: _handleSubmit,
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
}
