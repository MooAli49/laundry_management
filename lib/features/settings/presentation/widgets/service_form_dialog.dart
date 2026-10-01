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
import '../../../../domain/entities/service_item_type.dart';
import '../../../../domain/enums/pricing_type.dart';
import '../../../../domain/value_objects/money.dart';
import '../cubit/services_management_cubit.dart';

class ServiceFormDialog extends StatefulWidget {
  final Service? service;
  final List<ItemType> availableItemTypes;
  final List<ServiceItemType> initialConfigs;

  const ServiceFormDialog({
    super.key,
    this.service,
    required this.availableItemTypes,
    this.initialConfigs = const [],
  });

  static Future<bool?> show(
    BuildContext context, {
    Service? service,
    required List<ItemType> availableItemTypes,
    List<ServiceItemType> initialConfigs = const [],
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: context.read<ServicesManagementCubit>(),
        child: ServiceFormDialog(
          service: service,
          availableItemTypes: availableItemTypes,
          initialConfigs: initialConfigs,
        ),
      ),
    );
  }

  @override
  State<ServiceFormDialog> createState() => _ServiceFormDialogState();
}

class _ItemTypeRowConfig {
  final ItemType itemType;
  bool isEnabled;
  PricingType pricingType;
  final TextEditingController priceController;

  _ItemTypeRowConfig({
    required this.itemType,
    this.isEnabled = false,
    this.pricingType = PricingType.perPiece,
    String initialPriceText = '',
  }) : priceController = TextEditingController(text: initialPriceText);

  void dispose() {
    priceController.dispose();
  }
}

class _ServiceFormDialogState extends State<ServiceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final List<_ItemTypeRowConfig> _itemTypeRows;
  String? _inlineError;

  static const List<PricingType> _v1PricingTypes = [
    PricingType.perPiece,
    PricingType.perSquareMeter,
  ];

  @override
  void initState() {
    super.initState();
    final svc = widget.service;
    _nameController = TextEditingController(text: svc?.name ?? '');
    _descriptionController = TextEditingController(
      text: svc?.description ?? '',
    );

    _itemTypeRows = widget.availableItemTypes.map((type) {
      final existing = widget.initialConfigs
          .where((c) => c.itemTypeId == type.id)
          .firstOrNull;
      final isEnabled = existing != null;
      final pricingType = existing?.pricingType ?? PricingType.perPiece;
      final initialPriceText = existing != null
          ? (existing.price.toEgp == existing.price.toEgp.roundToDouble()
              ? existing.price.toEgp.toInt().toString()
              : existing.price.toEgp.toStringAsFixed(2))
          : '';
      return _ItemTypeRowConfig(
        itemType: type,
        isEnabled: isEnabled,
        pricingType: pricingType,
        initialPriceText: initialPriceText,
      );
    }).toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    for (final row in _itemTypeRows) {
      row.dispose();
    }
    super.dispose();
  }

  String _getPricingTypeLabel(PricingType type) {
    switch (type) {
      case PricingType.perPiece:
        return AppStrings.pricingPerPiece;
      case PricingType.perSquareMeter:
        return AppStrings.pricingPerSquareMeter;
    }
  }

  Future<void> _handleSubmit() async {
    setState(() => _inlineError = null);
    if (!_formKey.currentState!.validate()) return;

    final enabledRows = _itemTypeRows.where((r) => r.isEnabled).toList();
    if (enabledRows.isEmpty) {
      setState(() => _inlineError = AppStrings.selectAtLeastOneItemType);
      return;
    }

    final configs = <ServiceItemTypeConfig>[];
    for (final row in enabledRows) {
      final money = Money.tryParseEgp(row.priceController.text);
      if (money == null || money <= Money.zero) {
        setState(
          () => _inlineError =
              'يرجى إدخال سعر صحيح أكبر من الصفر لنوع القطعة: ${row.itemType.name}',
        );
        return;
      }
      configs.add(
        ServiceItemTypeConfig(
          itemTypeId: row.itemType.id,
          pricingType: row.pricingType,
          price: money,
        ),
      );
    }

    final cubit = context.read<ServicesManagementCubit>();
    bool success;

    if (widget.service == null) {
      success = await cubit.createService(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        itemTypeConfigs: configs,
      );
    } else {
      success = await cubit.updateService(
        service: widget.service!,
        itemTypeConfigs: configs,
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
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? AppStrings.editService : AppStrings.addService,
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                AppSpacing.gapLg,
                Flexible(
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
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusMd,
                              ),
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

                        // Item Type Pricing Matrix Header
                        Text(
                          AppStrings.supportedItemTypesLabel,
                          style: AppTextStyles.labelLarge.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        AppSpacing.gapXs,
                        Text(
                          AppStrings.itemTypePricingMatrixPrompt,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        AppSpacing.gapMd,

                        if (_itemTypeRows.isEmpty)
                          Text(
                            AppStrings.noItemTypes,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _itemTypeRows.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final row = _itemTypeRows[index];
                              return Container(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: row.isEnabled
                                      ? AppColors.primaryLighter.withValues(alpha: 0.15)
                                      : AppColors.backgroundSecondary,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusMd,
                                  ),
                                  border: Border.all(
                                    color: row.isEnabled
                                        ? AppColors.primary
                                        : AppColors.border,
                                    width: row.isEnabled ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: row.isEnabled,
                                          activeColor: AppColors.primary,
                                          onChanged: (val) {
                                            setState(() {
                                              row.isEnabled = val ?? false;
                                            });
                                          },
                                        ),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                row.isEnabled = !row.isEnabled;
                                              });
                                            },
                                            child: Text(
                                              row.itemType.name,
                                              style: AppTextStyles.titleSmall.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: row.isEnabled
                                                    ? AppColors.textPrimary
                                                    : AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (row.isEnabled) ...[
                                      const Divider(height: 16),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Pricing Type ChoiceChips
                                          Expanded(
                                            flex: 3,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  AppStrings.pricingTypeLabel,
                                                  style: AppTextStyles.labelSmall
                                                      .copyWith(
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                                AppSpacing.gapXs,
                                                Wrap(
                                                  spacing: 6,
                                                  children: _v1PricingTypes
                                                      .map((type) {
                                                    final isSelected =
                                                        row.pricingType == type;
                                                    return ChoiceChip(
                                                      label: Text(
                                                        _getPricingTypeLabel(type),
                                                        style: AppTextStyles
                                                            .labelSmall
                                                            .copyWith(
                                                          color: isSelected
                                                              ? AppColors
                                                                  .primaryDark
                                                              : AppColors
                                                                  .textPrimary,
                                                          fontWeight: isSelected
                                                              ? FontWeight.bold
                                                              : FontWeight
                                                                  .normal,
                                                        ),
                                                      ),
                                                      selected: isSelected,
                                                      selectedColor: AppColors
                                                          .primaryLighter,
                                                      onSelected: (selected) {
                                                        if (selected) {
                                                          setState(() {
                                                            row.pricingType =
                                                                type;
                                                          });
                                                        }
                                                      },
                                                    );
                                                  }).toList(),
                                                ),
                                              ],
                                            ),
                                          ),
                                          AppSpacing.gapHorizontalMd,
                                          // Price Field
                                          Expanded(
                                            flex: 2,
                                            child: AppTextField(
                                              controller: row.priceController,
                                              label:
                                                  '${AppStrings.servicePriceLabel} (ج.م)',
                                              hintText: '0.00',
                                              keyboardType:
                                                  const TextInputType
                                                      .numberWithOptions(
                                                decimal: true,
                                              ),
                                              validator: (val) {
                                                if (!row.isEnabled) return null;
                                                if (val == null ||
                                                    val.trim().isEmpty) {
                                                  return AppStrings
                                                      .servicePriceRequired;
                                                }
                                                final parsed =
                                                    Money.tryParseEgp(val);
                                                if (parsed == null ||
                                                    parsed <= Money.zero) {
                                                  return AppStrings
                                                      .servicePriceMustBePositive;
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        AppSpacing.gapMd,
                      ],
                    ),
                  ),
                ),
                AppSpacing.gapLg,
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    AppButton(
                      label: AppStrings.save,
                      onPressed: _handleSubmit,
                    ),
                    AppSpacing.gapHorizontalMd,
                    AppButton(
                      label: AppStrings.cancel,
                      variant: AppButtonVariant.text,
                      onPressed: () => Navigator.of(context).pop(false),
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
