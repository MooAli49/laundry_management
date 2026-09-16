import 'dart:convert';

import '../../domain/entities/carpet_item_data.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_item.dart';
import '../../domain/entities/service.dart';
import '../../domain/entities/storage_record.dart';
import '../../domain/enums/order_status.dart';

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
      'pricing_type': item.pricingType.name,
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
      'pricing_type': service.pricingType.name,
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
}
