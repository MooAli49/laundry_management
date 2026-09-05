import '../enums/order_status.dart';
import '../value_objects/money.dart';
import '../value_objects/order_date.dart';

class Order {
  final String id;
  final String orderNumber;
  final String customerId;
  final OrderStatus status;
  final OrderDate expectedPickupDate;
  final String? notes;
  final bool customerPickupRequested;
  final Money customerPickupFee;
  final bool customerDeliveryRequested;
  final Money customerDeliveryFee;
  final Money subtotal;
  final Money discount;
  final Money tax;
  final Money total;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  Order({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    this.status = OrderStatus.processing,
    required this.expectedPickupDate,
    this.notes,
    this.customerPickupRequested = false,
    this.customerPickupFee = Money.zero,
    this.customerDeliveryRequested = false,
    this.customerDeliveryFee = Money.zero,
    required this.subtotal,
    this.discount = Money.zero,
    this.tax = Money.zero,
    required this.total,
    this.completedAt,
    this.cancelledAt,
    this.cancellationReason,
    required this.createdAt,
    required this.updatedAt,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('Order id cannot be empty');
    }
    if (orderNumber.trim().isEmpty) {
      throw ArgumentError('Order orderNumber cannot be empty');
    }
    if (customerId.trim().isEmpty) {
      throw ArgumentError('Order customerId cannot be empty');
    }
    if (customerPickupFee.isNegative) {
      throw ArgumentError('customerPickupFee cannot be negative');
    }
    if (customerDeliveryFee.isNegative) {
      throw ArgumentError('customerDeliveryFee cannot be negative');
    }
    if (subtotal.isNegative) {
      throw ArgumentError('subtotal cannot be negative');
    }
    if (discount.isNegative) {
      throw ArgumentError('discount cannot be negative');
    }
    if (tax.isNegative) {
      throw ArgumentError('tax cannot be negative');
    }
    if (total.isNegative) {
      throw ArgumentError('total cannot be negative');
    }

    final calculatedTotal = subtotal - discount + customerPickupFee + customerDeliveryFee + tax;
    if (total != calculatedTotal) {
      throw ArgumentError(
        'Order total ($total) does not equal subtotal ($subtotal) - discount ($discount) + '
        'pickupFee ($customerPickupFee) + deliveryFee ($customerDeliveryFee) + tax ($tax) = $calculatedTotal',
      );
    }

    if (status == OrderStatus.completed && completedAt == null) {
      throw ArgumentError('Completed order must have completedAt set');
    }

    if (status == OrderStatus.cancelled) {
      if (cancelledAt == null) {
        throw ArgumentError('Cancelled order must have cancelledAt set');
      }
      if (cancellationReason == null || cancellationReason!.trim().isEmpty) {
        throw ArgumentError('Cancelled order must have a non-empty cancellationReason');
      }
    }
  }

  /// Semantic handover confirmation timestamp derived from completedAt (Option A).
  DateTime? get customerHandoverConfirmedAt => completedAt;

  Money get totalDeliveryFees => customerPickupFee + customerDeliveryFee;

  bool get isOverdue =>
      (status == OrderStatus.processing || status == OrderStatus.ready) &&
      expectedPickupDate.isBeforeToday;

  Order copyWith({
    String? id,
    String? orderNumber,
    String? customerId,
    OrderStatus? status,
    OrderDate? expectedPickupDate,
    String? notes,
    bool? customerPickupRequested,
    Money? customerPickupFee,
    bool? customerDeliveryRequested,
    Money? customerDeliveryFee,
    Money? subtotal,
    Money? discount,
    Money? tax,
    Money? total,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? cancellationReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Order(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      customerId: customerId ?? this.customerId,
      status: status ?? this.status,
      expectedPickupDate: expectedPickupDate ?? this.expectedPickupDate,
      notes: notes ?? this.notes,
      customerPickupRequested:
          customerPickupRequested ?? this.customerPickupRequested,
      customerPickupFee: customerPickupFee ?? this.customerPickupFee,
      customerDeliveryRequested:
          customerDeliveryRequested ?? this.customerDeliveryRequested,
      customerDeliveryFee: customerDeliveryFee ?? this.customerDeliveryFee,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Order &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          orderNumber == other.orderNumber &&
          customerId == other.customerId &&
          status == other.status &&
          expectedPickupDate == other.expectedPickupDate &&
          notes == other.notes &&
          customerPickupRequested == other.customerPickupRequested &&
          customerPickupFee == other.customerPickupFee &&
          customerDeliveryRequested == other.customerDeliveryRequested &&
          customerDeliveryFee == other.customerDeliveryFee &&
          subtotal == other.subtotal &&
          discount == other.discount &&
          tax == other.tax &&
          total == other.total &&
          completedAt == other.completedAt &&
          cancelledAt == other.cancelledAt &&
          cancellationReason == other.cancellationReason &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        orderNumber,
        customerId,
        status,
        expectedPickupDate,
        customerPickupRequested,
        customerPickupFee,
        customerDeliveryRequested,
        customerDeliveryFee,
        subtotal,
        discount,
        tax,
        total,
        completedAt,
        cancelledAt,
        cancellationReason,
        createdAt,
        updatedAt,
      );

  @override
  String toString() => 'Order(id: $id, number: $orderNumber, status: $status, total: $total)';
}
