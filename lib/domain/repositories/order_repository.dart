import '../../application/use_cases/edit_processing_order_use_case.dart';
import '../entities/customer_order_aggregate.dart';
import '../entities/order.dart';
import '../entities/order_item.dart';
import '../entities/payment.dart';
import '../enums/order_status.dart';
import '../value_objects/order_date.dart';

abstract class OrderRepository {
  Future<Order> createOrder({
    required Order order,
    required List<OrderItem> items,
    Payment? initialPayment,
  });

  Future<Order> editProcessingOrder(EditProcessingOrderInput input);

  Future<Order> updateOrder(Order order);

  Future<Order?> getOrderById(String id);

  Future<Order?> getOrderByNumber(String orderNumber);

  Future<List<OrderItem>> getOrderItems(String orderId);

  Future<OrderItem?> getOrderItemById(String id);

  Future<List<Order>> getOrders({
    OrderStatus? status,
    List<OrderStatus>? excludedStatuses,
    OrderDate? expectedPickupDate,
    bool? isOverdue,
    DateTime? referenceDate,
    DateTime? createdFrom,
    DateTime? createdTo,
    String? customerId,
    bool? hasRemaining,
    String? query,
    int limit = 20,
    int offset = 0,
  });

  Future<List<Order>> searchOrders({
    required String query,
    int limit = 20,
    int offset = 0,
  });

  Stream<List<Order>> watchRecentOrders({int limit = 20});

  Stream<Order?> watchOrderById(String id);

  Stream<void> watchOrderTableUpdates();

  Future<Order> markOrderReady(String orderId);

  Future<Order> completeOrder({
    required String orderId,
    required bool handoverConfirmed,
  });

  Future<Order> cancelOrder({
    required String orderId,
    required String cancellationReason,
  });

  Future<Order> correctOrderStatus({
    required String orderId,
    required OrderStatus newStatus,
    String? reason,
  });

  Future<int> getOrderCountByCustomerId(String customerId);

  Future<Map<String, int>> getOrderCountsByCustomer();

  Future<Map<String, int>> getOrderCountsByCustomerIds(
    List<String> customerIds,
  );

  Future<CustomerOrderAggregate> getCustomerOrderAggregate(String customerId);
}
