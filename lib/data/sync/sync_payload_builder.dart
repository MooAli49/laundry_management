import 'dart:convert';

import '../../domain/entities/business_settings.dart';
import '../../domain/entities/carpet_item_data.dart';
import '../../domain/entities/carpet_size.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/entities/item_definition.dart';
import '../../domain/entities/item_type.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_item.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/service.dart';
import '../../domain/entities/storage_location.dart';
import '../../domain/entities/storage_record.dart';
import '../../domain/enums/order_status.dart';
import '../../domain/enums/payment_method.dart';

/// Strongly typed serializer in the Data Layer that constructs self-contained
/// JSON payloads for synchronization operations.
///
/// Follows Clean Architecture: domain entities remain pure and decoupled from
/// JSON, Retrofit, Dio, and Supabase.
class SyncPayloadBuilder {
  SyncPayloadBuilder._();

  // ===========================================================================
  // Customer Payloads
  // ===========================================================================

  /// Builds a self-contained payload for customer creation.
  static String buildCustomerPayload(Customer customer) {
    return jsonEncode(<String, dynamic>{
      'id': customer.id,
      'name': customer.name,
      'phone': customer.phone,
      'notes': customer.notes,
      'created_at': customer.createdAt.toIso8601String(),
      'updated_at': customer.updatedAt.toIso8601String(),
    });
  }

  /// Builds a self-contained payload for customer update.
  static String buildCustomerUpdatePayload(Customer customer) {
    return jsonEncode(<String, dynamic>{
      'id': customer.id,
      'name': customer.name,
      'phone': customer.phone,
      'notes': customer.notes,
      'updated_at': customer.updatedAt.toIso8601String(),
    });
  }

  // ===========================================================================
  // Order Payloads (Composite Aggregate)
  // ===========================================================================

  /// Builds a self-contained payload for order creation aggregate.
  ///
  /// Embeds child items and optional carpet metadata into a single composite
  /// operation to guarantee remote atomicity and prevent orphaned records.
  static String buildOrderCreatePayload(Order order, List<OrderItem> items) {
    return jsonEncode(<String, dynamic>{
      'id': order.id,
      'order_number': order.orderNumber,
      'customer_id': order.customerId,
      'customer_name_snapshot': order.customerNameSnapshot,
      'customer_phone_snapshot': order.customerPhoneSnapshot,
      'status': order.status.name,
      'expected_pickup_date': order.expectedPickupDate
          .toDateTime()
          .toIso8601String(),
      'notes': order.notes,
      'customer_pickup_requested': order.customerPickupRequested,
      'customer_pickup_fee': order.customerPickupFee.piastres,
      'customer_delivery_requested': order.customerDeliveryRequested,
      'customer_delivery_fee': order.customerDeliveryFee.piastres,
      'subtotal': order.subtotal.piastres,
      'discount': order.discount.piastres,
      'tax': order.tax.piastres,
      'total': order.total.piastres,
      'created_at': order.createdAt.toIso8601String(),
      'updated_at': order.updatedAt.toIso8601String(),
      'items': items.map(_serializeOrderItem).toList(),
    });
  }

  /// Builds a self-contained payload for general order update.
  static String buildOrderUpdatePayload(Order order) {
    return jsonEncode(<String, dynamic>{
      'id': order.id,
      'order_number': order.orderNumber,
      'customer_id': order.customerId,
      'status': order.status.name,
      'expected_pickup_date': order.expectedPickupDate
          .toDateTime()
          .toIso8601String(),
      'notes': order.notes,
      'customer_pickup_requested': order.customerPickupRequested,
      'customer_pickup_fee': order.customerPickupFee.piastres,
      'customer_delivery_requested': order.customerDeliveryRequested,
      'customer_delivery_fee': order.customerDeliveryFee.piastres,
      'subtotal': order.subtotal.piastres,
      'discount': order.discount.piastres,
      'tax': order.tax.piastres,
      'total': order.total.piastres,
      'completed_at': order.completedAt?.toIso8601String(),
      'cancelled_at': order.cancelledAt?.toIso8601String(),
      'cancellation_reason': order.cancellationReason,
      'updated_at': order.updatedAt.toIso8601String(),
    });
  }

  /// Builds a payload for order status transitions (ready, complete, cancel, correction).
  static String buildOrderStatusPayload(
    String orderId,
    OrderStatus status, {
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? cancellationReason,
    DateTime? updatedAt,
  }) {
    final now = updatedAt ?? DateTime.now();
    final map = <String, dynamic>{
      'id': orderId,
      'status': status.name,
      'updated_at': now.toIso8601String(),
    };
    if (completedAt != null) {
      map['completed_at'] = completedAt.toIso8601String();
    }
    if (cancelledAt != null) {
      map['cancelled_at'] = cancelledAt.toIso8601String();
    }
    if (cancellationReason != null && cancellationReason.trim().isNotEmpty) {
      map['cancellation_reason'] = cancellationReason.trim();
    }
    return jsonEncode(map);
  }

  static Map<String, dynamic> _serializeOrderItem(OrderItem item) {
    final map = <String, dynamic>{
      'id': item.id,
      'order_id': item.orderId,
      'item_type_id': item.itemTypeId,
      'item_definition_id': item.itemDefinitionId,
      'service_id': item.serviceId,
      'item_type_name_snapshot': item.itemTypeNameSnapshot,
      'item_definition_name_snapshot': item.itemDefinitionNameSnapshot,
      'service_name_snapshot': item.serviceNameSnapshot,
      'pricing_type': item.pricingType.value,
      'quantity': item.quantity,
      'unit_price': item.unitPrice.piastres,
      'calculated_total': item.calculatedTotal.piastres,
      'notes': item.notes,
      'created_at': item.createdAt.toIso8601String(),
      'updated_at': item.updatedAt.toIso8601String(),
    };
    if (item.carpetData != null) {
      map['carpet_data'] = _serializeCarpetData(item.carpetData!);
    }
    return map;
  }

  static Map<String, dynamic> _serializeCarpetData(CarpetItemData carpet) {
    return <String, dynamic>{
      'id': carpet.id,
      'order_item_id': carpet.orderItemId,
      'carpet_size_id': carpet.carpetSizeId,
      'length': carpet.length,
      'width': carpet.width,
      'area': carpet.area,
      'created_at': carpet.createdAt.toIso8601String(),
      'updated_at': carpet.updatedAt.toIso8601String(),
    };
  }

  // ===========================================================================
  // Service Payloads
  // ===========================================================================

  /// Builds a self-contained payload for service creation and update.
  static String buildServicePayload(
    Service service,
    List<String> supportedItemTypeIds,
  ) {
    return jsonEncode(<String, dynamic>{
      'id': service.id,
      'name': service.name,
      'description': service.description,
      'pricing_type': service.pricingType.value,
      'price': service.price.piastres,
      'is_active': service.isActive,
      'supported_item_type_ids': supportedItemTypeIds,
      'created_at': service.createdAt.toIso8601String(),
      'updated_at': service.updatedAt.toIso8601String(),
    });
  }

  /// Builds a payload for service activation/deactivation.
  static String buildServiceStatusPayload(
    String serviceId,
    bool isActive, {
    DateTime? updatedAt,
  }) {
    final now = updatedAt ?? DateTime.now();
    return jsonEncode(<String, dynamic>{
      'id': serviceId,
      'is_active': isActive,
      'updated_at': now.toIso8601String(),
    });
  }

  // ===========================================================================
  // Storage Record Payloads
  // ===========================================================================

  /// Builds a self-contained payload for storage record creation and relocation.
  static String buildStorageRecordPayload(StorageRecord record) {
    return jsonEncode(<String, dynamic>{
      'id': record.id,
      'order_item_id': record.orderItemId,
      'storage_location_id': record.storageLocationId,
      'is_active': record.isActive,
      'created_at': record.createdAt.toIso8601String(),
      'updated_at': record.updatedAt.toIso8601String(),
    });
  }

  /// Builds a payload for storage record status update (e.g. unstore / release).
  static String buildStorageRecordStatusPayload(
    String recordId,
    String orderItemId,
    bool isActive, {
    String? storageLocationId,
    DateTime? updatedAt,
  }) {
    final now = updatedAt ?? DateTime.now();
    final map = <String, dynamic>{
      'id': recordId,
      'order_item_id': orderItemId,
      'is_active': isActive,
      'updated_at': now.toIso8601String(),
    };
    if (storageLocationId != null) {
      map['storage_location_id'] = storageLocationId;
    }
    return jsonEncode(map);
  }

  // ===========================================================================
  // Payment Payloads
  // ===========================================================================

  /// Builds a self-contained payload for payment creation.
  ///
  /// Converts [PaymentMethod] to canonical backend snake_case ('cash', 'insta_pay', 'e_wallet')
  /// and amounts to integer minor units (piastres).
  static String buildPaymentPayload(Payment payment) {
    final paymentMethodStr = switch (payment.paymentMethod) {
      PaymentMethod.cash => 'cash',
      PaymentMethod.instapay => 'insta_pay',
      PaymentMethod.ewallet => 'e_wallet',
    };

    return jsonEncode(<String, dynamic>{
      'id': payment.id,
      'order_id': payment.orderId,
      'amount': payment.amount.piastres,
      'payment_method': paymentMethodStr,
      'paid_at': payment.paidAt.toUtc().toIso8601String(),
      'created_at': payment.createdAt.toUtc().toIso8601String(),
      'updated_at': payment.updatedAt.toUtc().toIso8601String(),
    });
  }

  // ===========================================================================
  // Expense Payloads
  // ===========================================================================

  /// Builds a self-contained payload for expense creation.
  ///
  /// Converts amounts to integer minor units (piastres) and preserves [expense_date]
  /// strictly as a date-only string ('YYYY-MM-DD').
  static String buildExpensePayload(Expense expense) {
    return jsonEncode(<String, dynamic>{
      'id': expense.id,
      'expense_category_id': expense.expenseCategoryId,
      'amount': expense.amount.piastres,
      'expense_name': expense.expenseName,
      'expense_date': expense.expenseDate.toString(),
      'notes': expense.notes,
      'category_name_snapshot': expense.categoryNameSnapshot,
      'created_at': expense.createdAt.toUtc().toIso8601String(),
      'updated_at': expense.updatedAt.toUtc().toIso8601String(),
    });
  }

  /// Builds a payload for expense update (PATCH contract).
  static String buildExpenseUpdatePayload(Expense expense) {
    return jsonEncode(<String, dynamic>{
      'amount': expense.amount.piastres,
      'expense_name': expense.expenseName,
      'expense_date': expense.expenseDate.toString(),
      'notes': expense.notes,
      'updated_at': expense.updatedAt.toUtc().toIso8601String(),
    });
  }

  // ===========================================================================
  // Expense Category Payloads
  // ===========================================================================

  /// Builds a self-contained payload for expense category creation.
  static String buildExpenseCategoryPayload(ExpenseCategory category) {
    return jsonEncode(<String, dynamic>{
      'id': category.id,
      'name': category.name,
      'is_active': category.isActive,
      'created_at': category.createdAt.toUtc().toIso8601String(),
      'updated_at': category.updatedAt.toUtc().toIso8601String(),
    });
  }

  /// Builds a payload for expense category update / rename (PATCH contract).
  static String buildExpenseCategoryUpdatePayload(ExpenseCategory category) {
    return jsonEncode(<String, dynamic>{
      'name': category.name,
      'is_active': category.isActive,
      'updated_at': category.updatedAt.toUtc().toIso8601String(),
    });
  }

  /// Builds a payload for expense category activation/deactivation status update.
  static String buildExpenseCategoryStatusPayload(
    String id,
    bool isActive, {
    DateTime? updatedAt,
  }) {
    final now = (updatedAt ?? DateTime.now()).toUtc();
    return jsonEncode(<String, dynamic>{
      'id': id,
      'is_active': isActive,
      'updated_at': now.toIso8601String(),
    });
  }

  // ===========================================================================
  // Item Type Payloads
  // ===========================================================================

  /// Builds a self-contained payload for item type creation.
  static String buildItemTypePayload(ItemType itemType) {
    return jsonEncode(<String, dynamic>{
      'id': itemType.id,
      'name': itemType.name,
      'is_active': itemType.isActive,
      'created_at': itemType.createdAt.toUtc().toIso8601String(),
      'updated_at': itemType.updatedAt.toUtc().toIso8601String(),
    });
  }

  /// Builds a payload for item type update (PATCH contract).
  static String buildItemTypeUpdatePayload(ItemType itemType) {
    return jsonEncode(<String, dynamic>{
      'name': itemType.name,
      'is_active': itemType.isActive,
      'updated_at': itemType.updatedAt.toUtc().toIso8601String(),
    });
  }

  /// Builds a payload for item type activation/deactivation status update.
  static String buildItemTypeStatusPayload(
    String id,
    bool isActive, {
    DateTime? updatedAt,
  }) {
    final now = (updatedAt ?? DateTime.now()).toUtc();
    return jsonEncode(<String, dynamic>{
      'id': id,
      'is_active': isActive,
      'isActive': isActive,
      'updated_at': now.toIso8601String(),
    });
  }

  // ===========================================================================
  // Item Definition Payloads
  // ===========================================================================

  /// Builds a self-contained payload for item definition creation.
  static String buildItemDefinitionPayload(ItemDefinition itemDefinition) {
    return jsonEncode(<String, dynamic>{
      'id': itemDefinition.id,
      'item_type_id': itemDefinition.itemTypeId,
      'name': itemDefinition.name,
      'is_active': itemDefinition.isActive,
      'created_at': itemDefinition.createdAt.toUtc().toIso8601String(),
      'updated_at': itemDefinition.updatedAt.toUtc().toIso8601String(),
    });
  }

  /// Builds a payload for item definition update (PATCH contract).
  static String buildItemDefinitionUpdatePayload(ItemDefinition itemDefinition) {
    return jsonEncode(<String, dynamic>{
      'item_type_id': itemDefinition.itemTypeId,
      'name': itemDefinition.name,
      'is_active': itemDefinition.isActive,
      'updated_at': itemDefinition.updatedAt.toUtc().toIso8601String(),
    });
  }

  /// Builds a payload for item definition activation/deactivation status update.
  static String buildItemDefinitionStatusPayload(
    String id,
    bool isActive, {
    DateTime? updatedAt,
  }) {
    final now = (updatedAt ?? DateTime.now()).toUtc();
    return jsonEncode(<String, dynamic>{
      'id': id,
      'is_active': isActive,
      'isActive': isActive,
      'updated_at': now.toIso8601String(),
    });
  }

  // ===========================================================================
  // Carpet Size Payloads
  // ===========================================================================

  /// Builds a self-contained payload for carpet size creation.
  static String buildCarpetSizePayload(CarpetSize carpetSize) {
    return jsonEncode(<String, dynamic>{
      'id': carpetSize.id,
      'length': carpetSize.length,
      'width': carpetSize.width,
      'area': carpetSize.area,
      'is_active': carpetSize.isActive,
      'created_at': carpetSize.createdAt.toUtc().toIso8601String(),
      'updated_at': carpetSize.updatedAt.toUtc().toIso8601String(),
    });
  }

  /// Builds a payload for carpet size update (PATCH contract).
  static String buildCarpetSizeUpdatePayload(CarpetSize carpetSize) {
    return jsonEncode(<String, dynamic>{
      'length': carpetSize.length,
      'width': carpetSize.width,
      'area': carpetSize.area,
      'is_active': carpetSize.isActive,
      'updated_at': carpetSize.updatedAt.toUtc().toIso8601String(),
    });
  }

  /// Builds a payload for carpet size activation/deactivation status update.
  static String buildCarpetSizeStatusPayload(
    String id,
    bool isActive, {
    DateTime? updatedAt,
  }) {
    final now = (updatedAt ?? DateTime.now()).toUtc();
    return jsonEncode(<String, dynamic>{
      'id': id,
      'is_active': isActive,
      'isActive': isActive,
      'updated_at': now.toIso8601String(),
    });
  }

  // ===========================================================================
  // Storage Location Payloads
  // ===========================================================================

  /// Builds a self-contained payload for storage location creation.
  static String buildStorageLocationPayload(
    StorageLocation location,
    List<String> supportedItemTypeIds,
  ) {
    return jsonEncode(<String, dynamic>{
      'id': location.id,
      'name': location.name,
      'is_active': location.isActive,
      'supported_item_type_ids': supportedItemTypeIds,
      'created_at': location.createdAt.toUtc().toIso8601String(),
      'updated_at': location.updatedAt.toUtc().toIso8601String(),
    });
  }

  /// Builds a payload for storage location update (PATCH contract).
  static String buildStorageLocationUpdatePayload(
    StorageLocation location,
    List<String> supportedItemTypeIds,
  ) {
    return jsonEncode(<String, dynamic>{
      'name': location.name,
      'is_active': location.isActive,
      'supported_item_type_ids': supportedItemTypeIds,
      'updated_at': location.updatedAt.toUtc().toIso8601String(),
    });
  }

  /// Builds a payload for storage location activation/deactivation status update.
  static String buildStorageLocationStatusPayload(
    String id,
    bool isActive, {
    DateTime? updatedAt,
  }) {
    final now = (updatedAt ?? DateTime.now()).toUtc();
    return jsonEncode(<String, dynamic>{
      'id': id,
      'is_active': isActive,
      'isActive': isActive,
      'updated_at': now.toIso8601String(),
    });
  }

  // ===========================================================================
  // Business Settings Payloads
  // ===========================================================================

  /// Builds a self-contained payload for business settings update.
  static String buildBusinessSettingsPayload(BusinessSettings settings) {
    return jsonEncode(<String, dynamic>{
      'id': settings.id,
      'business_name': settings.businessName,
      'address': settings.address,
      'phone': settings.phone,
      'logo_reference': settings.logoReference,
      'invoice_footer_text': settings.invoiceFooterText,
      'tax_enabled': settings.taxEnabled,
      'tax_rate': settings.taxRate,
      'created_at': settings.createdAt.toUtc().toIso8601String(),
      'updated_at': settings.updatedAt.toUtc().toIso8601String(),
    });
  }
}
